"""Production AI planning: use verified real forecasts, otherwise order-only fallback."""
from __future__ import annotations

from datetime import date, timedelta
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.inventory import Inventory
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.ml.forecasting import get_model_metadata, model_exists, predict_next_day
from app.ml.purchase_planner import calculate_purchase_recommendation


def _as_float(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _real_history(db: Session) -> list[dict[str, Any]]:
    # Imported here to avoid an API/service import cycle.
    from app.api.demand import _collect_demand_history

    end_date = date.today()
    start_date = end_date - timedelta(days=89)
    return _collect_demand_history(start_date, end_date, db)


def _complete_through_today(
    history: list[dict[str, Any]], product_id: int, product_name: str, unit: str
) -> list[dict[str, Any]]:
    """Append zero-demand calendar days after the last recorded sale."""
    rows = [row for row in history if int(row["product_id"]) == product_id]
    if not rows:
        return []
    by_date = {date.fromisoformat(row["date"]): row for row in rows}
    first_day = min(by_date)
    today = date.today()
    completed: list[dict[str, Any]] = []
    current = first_day
    while current <= today:
        row = by_date.get(current)
        if row is None:
            completed.append({
                "date": current.isoformat(),
                "product_id": product_id,
                "product_name": product_name,
                "online_quantity": 0.0,
                "walk_in_quantity": 0.0,
                "total_quantity": 0.0,
            })
        else:
            completed.append(row)
        current += timedelta(days=1)
    return completed


def build_production_planning_data(db: Session) -> dict[str, Any]:
    """Build product-level purchase plans without ever using synthetic demand."""
    products = db.query(Product).order_by(Product.id.asc()).all()

    order_rows = (
        db.query(
            OrderItem.product_id,
            func.sum(OrderItem.quantity).label("active_order_quantity"),
        )
        .join(Order, Order.id == OrderItem.order_id)
        .filter(Order.status.in_(["PLACED", "CONFIRMED"]))
        .group_by(OrderItem.product_id)
        .all()
    )
    active_orders = {int(row.product_id): _as_float(row.active_order_quantity) for row in order_rows}

    inventory_rows = (
        db.query(
            Inventory.product_id,
            func.sum(Inventory.remaining_quantity).label("available_quantity"),
            func.sum(Inventory.reserved_quantity).label("reserved_quantity"),
        )
        .group_by(Inventory.product_id)
        .all()
    )
    inventory = {
        int(row.product_id): {
            "available": _as_float(row.available_quantity),
            "reserved": _as_float(row.reserved_quantity),
        }
        for row in inventory_rows
    }

    history = _real_history(db)
    real_model_available = model_exists("real", db=db)
    metadata: dict[str, Any] = {}
    if real_model_available:
        try:
            metadata = get_model_metadata("real", db=db) or {}
            if metadata.get("data_source") != "real":
                real_model_available = False
        except Exception:
            real_model_available = False
            metadata = {}

    trained_product_ids = set(metadata.get("product_ids") or [])
    results: list[dict[str, Any]] = []
    any_real_forecast = False
    forecast_date: str | None = None

    for product in products:
        product_id = int(product.id)
        order_quantity = active_orders.get(product_id, 0.0)
        stock = inventory.get(product_id, {"available": 0.0, "reserved": 0.0})
        available = stock["available"]
        reserved = stock["reserved"]
        total_on_hand = available + reserved

        product_history = [row for row in history if int(row["product_id"]) == product_id]
        transaction_dates = {
            date.fromisoformat(row["date"])
            for row in product_history
            if _as_float(row.get("total_quantity")) > 0
        }
        enough_product_history = (
            len(transaction_dates) >= 14
            and bool(transaction_dates)
            and (max(transaction_dates) - min(transaction_dates)).days >= 29
        )

        forecast: dict[str, Any] | None = None
        if (
            real_model_available
            and enough_product_history
            and (not trained_product_ids or product_id in trained_product_ids)
        ):
            try:
                forecast_rows = _complete_through_today(
                    history, product_id, product.name, product.unit
                )
                forecast = predict_next_day(forecast_rows, product_id, data_source="real", db=db)
                any_real_forecast = True
                forecast_date = forecast.get("forecast_date") or forecast_date
            except Exception:
                forecast = None

        predicted_demand = _as_float(forecast.get("predicted_demand")) if forecast else 0.0
        purchase = calculate_purchase_recommendation(
            confirmed_order_quantity=order_quantity,
            predicted_demand=predicted_demand,
            available_inventory=total_on_hand,
            unit=product.unit,
            safety_buffer_percent=10.0 if forecast else 0.0,
        )
        source = "real_business_data" if forecast else "order_based_fallback"

        results.append({
            "product_id": product_id,
            "product_name": product.name,
            "unit": product.unit,
            "confirmed_order_quantity": round(order_quantity, 2),
            "ai_forecast": {
                "status": "available" if forecast else "unavailable",
                "forecast_date": forecast.get("forecast_date") if forecast else None,
                "predicted_demand": round(predicted_demand, 2),
                "model": forecast.get("model") if forecast else None,
                "data_source": source,
                "error": None,
            },
            "inventory": {
                "available": round(available, 2),
                "reserved": round(reserved, 2),
                "total_on_hand": round(total_on_hand, 2),
            },
            "purchase_plan": purchase,
            # Backward-compatible fields used by the existing Flutter UI.
            "expected_demand": purchase["expected_demand"],
            "recommended_purchase_quantity": purchase["recommended_purchase_quantity"],
            "recommendation": purchase["recommendation"],
        })

    return {
        "status": "success",
        "mode": "real_ai" if any_real_forecast else "order_based",
        "data_source": "real_business_data" if any_real_forecast else "order_based_fallback",
        "forecast_date": forecast_date,
        "safety_buffer_percent": 10.0 if any_real_forecast else 0.0,
        "real_model_available": real_model_available,
        "products": results,
    }
