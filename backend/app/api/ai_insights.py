from __future__ import annotations

from datetime import date
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin
from app.services.ai_planning import build_production_planning_data

router = APIRouter(prefix="/admin/ai", tags=["AI Insights"])


def _round(value: Any) -> float:
    try:
        return round(max(0.0, float(value or 0)), 2)
    except (TypeError, ValueError):
        return 0.0


@router.get("/insights")
def get_ai_insights(
    db: Session = Depends(get_db),
    current_admin=Depends(get_current_admin),
):
    """Generate insights from verified real forecasts or actual active orders.

    When real model history is not available, this endpoint explicitly reports
    an order-based fallback and never fabricates demand values.
    """
    plan = build_production_planning_data(db)
    insights: list[dict[str, Any]] = []
    high_attention = purchase_required = inventory_sufficient = no_purchase = 0

    for item in plan["products"]:
        forecast = item["ai_forecast"]
        inventory = item["inventory"]
        purchase = item["purchase_plan"]
        order_quantity = _round(item["confirmed_order_quantity"])
        predicted = _round(forecast["predicted_demand"])
        expected = _round(purchase["expected_demand"])
        safety = _round(purchase["safety_stock"])
        target = _round(purchase["target_stock"])
        on_hand = _round(inventory["total_on_hand"])
        gap = _round(purchase["recommended_purchase_quantity"])
        has_real_forecast = forecast["status"] == "available"

        if gap > 0:
            insight_type, priority = "PURCHASE_REQUIRED", "high"
            title = f"Purchase {item['product_name']}"
            message = (
                f"Active customer orders require {order_quantity:g} {item['unit']}. "
                f"Total on-hand inventory is {on_hand:g} {item['unit']}; "
                f"purchase {gap:g} {item['unit']}."
            )
            purchase_required += 1
            high_attention += 1
        elif order_quantity > 0:
            insight_type, priority = "ORDER_COVERED", "low"
            title = f"Orders covered: {item['product_name']}"
            message = f"Current on-hand inventory covers the {order_quantity:g} {item['unit']} in active customer orders."
            inventory_sufficient += 1
        elif on_hand > 0:
            insight_type, priority = "NO_ACTIVE_ORDERS", "low"
            title = f"No active orders: {item['product_name']}"
            message = f"There are no active customer orders for this product. {on_hand:g} {item['unit']} are on hand."
            no_purchase += 1
        else:
            insight_type, priority = "NO_DEMAND_DATA", "medium"
            title = f"No demand recorded: {item['product_name']}"
            message = "No active customer orders or usable real-data forecast are available. Review manually."
            high_attention += 1

        demand_level = "HIGH" if predicted >= 20 else "MEDIUM" if predicted >= 10 else "LOW" if predicted > 0 else "UNKNOWN"
        insights.append({
            "product_id": item["product_id"],
            "product_name": item["product_name"],
            "unit": item["unit"],
            "insight_type": insight_type,
            "priority": priority,
            "title": title,
            "message": message,
            "demand_level": demand_level,
            "forecast": {
                "status": forecast["status"],
                "forecast_date": forecast["forecast_date"],
                "predicted_demand": predicted,
                "model": forecast["model"],
                "data_source": forecast["data_source"],
            },
            "orders": {"confirmed_quantity": order_quantity},
            "inventory": {
                "available": _round(inventory["available"]),
                "reserved": _round(inventory["reserved"]),
                "total_position": on_hand,
            },
            "planning": {
                "expected_demand": expected,
                "safety_stock": safety,
                "target_stock": target,
                "stock_gap": gap,
            },
            "planning_mode": plan["mode"],
        })

    if high_attention:
        overall_status = "ATTENTION_REQUIRED"
        headline = f"{high_attention} product(s) need attention before the next market trip."
    elif purchase_required:
        overall_status = "PURCHASE_RECOMMENDED"
        headline = f"Purchasing is recommended for {purchase_required} product(s)."
    else:
        overall_status = "STABLE"
        headline = "No additional purchases are currently indicated by active orders and recorded inventory."

    priority_order = {"high": 0, "medium": 1, "low": 2}
    insights.sort(key=lambda row: (priority_order.get(row["priority"], 99), row["product_name"]))

    return {
        "status": "success",
        "mode": plan["mode"],
        "data_source": plan["data_source"],
        "forecast_date": plan["forecast_date"],
        "generated_on": date.today().isoformat(),
        "overall_status": overall_status,
        "headline": headline,
        "fallback_message": (
            "Real-data forecasting is not currently available. This plan uses active customer orders and recorded inventory only."
            if plan["mode"] == "order_based" else None
        ),
        "summary": {
            "products_analyzed": len(insights),
            "high_attention": high_attention,
            "purchase_required": purchase_required,
            "inventory_sufficient": inventory_sufficient,
            "no_purchase": no_purchase,
        },
        "insights": insights,
    }
