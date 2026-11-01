from datetime import date, datetime, time, timedelta
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.sale import Sale
from app.models.user import User
from app.ml.dataset import build_features
from app.ml.forecasting import train_model


router = APIRouter(
    prefix="/admin/ai",
    tags=["AI Demand Forecasting"],
)


def _get_date_range(
    start_date: date | None,
    end_date: date | None,
) -> tuple[date, date]:

    today = date.today()

    if end_date is None:
        end_date = today

    if start_date is None:
        start_date = end_date - timedelta(days=89)

    return start_date, end_date


def _collect_demand_history(
    start_date: date,
    end_date: date,
    db: Session,
) -> list[dict[str, Any]]:

    start_datetime = datetime.combine(
        start_date,
        time.min,
    )

    end_datetime = datetime.combine(
        end_date + timedelta(days=1),
        time.min,
    )

    demand: dict[
        tuple[date, int],
        dict[str, Any],
    ] = {}

    # =========================================================
    # ONLINE ORDERS
    # =========================================================

    online_rows = (
        db.query(
            OrderItem.product_id,
            Product.name,
            Order.created_at,
            OrderItem.quantity,
        )
        .join(
            Order,
            Order.id == OrderItem.order_id,
        )
        .join(
            Product,
            Product.id == OrderItem.product_id,
        )
        .filter(
            Order.status == "DELIVERED",
            Order.created_at >= start_datetime,
            Order.created_at < end_datetime,
        )
        .all()
    )

    for row in online_rows:

        transaction_date = row.created_at.date()

        key = (
            transaction_date,
            row.product_id,
        )

        if key not in demand:
            demand[key] = {
                "date": transaction_date.isoformat(),
                "product_id": row.product_id,
                "product_name": row.name,
                "online_quantity": 0.0,
                "walk_in_quantity": 0.0,
            }

        demand[key]["online_quantity"] += float(
            row.quantity
        )

    # =========================================================
    # WALK-IN SALES
    # =========================================================

    walk_in_rows = (
        db.query(
            Sale.product_id,
            Product.name,
            Sale.created_at,
            Sale.quantity,
        )
        .join(
            Product,
            Product.id == Sale.product_id,
        )
        .filter(
            Sale.created_at >= start_datetime,
            Sale.created_at < end_datetime,
        )
        .all()
    )

    for row in walk_in_rows:

        transaction_date = row.created_at.date()

        key = (
            transaction_date,
            row.product_id,
        )

        if key not in demand:
            demand[key] = {
                "date": transaction_date.isoformat(),
                "product_id": row.product_id,
                "product_name": row.name,
                "online_quantity": 0.0,
                "walk_in_quantity": 0.0,
            }

        demand[key]["walk_in_quantity"] += float(
            row.quantity
        )

    # =========================================================
    # FINALIZE
    # =========================================================

    result = []

    for item in demand.values():

        online_quantity = float(
            item["online_quantity"]
        )

        walk_in_quantity = float(
            item["walk_in_quantity"]
        )

        total_quantity = (
            online_quantity
            + walk_in_quantity
        )

        result.append(
            {
                "date": item["date"],
                "product_id": item["product_id"],
                "product_name": item["product_name"],
                "online_quantity": round(
                    online_quantity,
                    2,
                ),
                "walk_in_quantity": round(
                    walk_in_quantity,
                    2,
                ),
                "total_quantity": round(
                    total_quantity,
                    2,
                ),
            }
        )

    result.sort(
        key=lambda x: (
            x["date"],
            x["product_name"],
        )
    )

    return result


# =============================================================
# DEMAND HISTORY
# =============================================================

@router.get("/demand-history")
def get_demand_history(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):

    start_date, end_date = _get_date_range(
        start_date,
        end_date,
    )

    if start_date > end_date:
        return {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "data": [],
        }

    data = _collect_demand_history(
        start_date,
        end_date,
        db,
    )

    return {
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "data": data,
    }


# =============================================================
# PRODUCT DEMAND HISTORY
# =============================================================

@router.get("/demand-history/{product_id}")
def get_product_demand_history(
    product_id: int,
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):

    start_date, end_date = _get_date_range(
        start_date,
        end_date,
    )

    product = (
        db.query(Product)
        .filter(Product.id == product_id)
        .first()
    )

    if not product:
        return {
            "product_id": product_id,
            "product_name": None,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "data": [],
        }

    start_datetime = datetime.combine(
        start_date,
        time.min,
    )

    end_datetime = datetime.combine(
        end_date + timedelta(days=1),
        time.min,
    )

    demand: dict[
        date,
        dict[str, float],
    ] = {}

    # =========================================================
    # ONLINE
    # =========================================================

    online_rows = (
        db.query(
            Order.created_at,
            OrderItem.quantity,
        )
        .join(
            Order,
            Order.id == OrderItem.order_id,
        )
        .filter(
            OrderItem.product_id == product_id,
            Order.status == "DELIVERED",
            Order.created_at >= start_datetime,
            Order.created_at < end_datetime,
        )
        .all()
    )

    for row in online_rows:

        transaction_date = row.created_at.date()

        if transaction_date not in demand:
            demand[transaction_date] = {
                "online_quantity": 0.0,
                "walk_in_quantity": 0.0,
            }

        demand[
            transaction_date
        ]["online_quantity"] += float(
            row.quantity
        )

    # =========================================================
    # WALK-IN
    # =========================================================

    walk_in_rows = (
        db.query(
            Sale.created_at,
            Sale.quantity,
        )
        .filter(
            Sale.product_id == product_id,
            Sale.created_at >= start_datetime,
            Sale.created_at < end_datetime,
        )
        .all()
    )

    for row in walk_in_rows:

        transaction_date = row.created_at.date()

        if transaction_date not in demand:
            demand[transaction_date] = {
                "online_quantity": 0.0,
                "walk_in_quantity": 0.0,
            }

        demand[
            transaction_date
        ]["walk_in_quantity"] += float(
            row.quantity
        )

    # =========================================================
    # COMPLETE DATE SERIES
    # =========================================================

    data = []

    current_date = start_date

    while current_date <= end_date:

        day_data = demand.get(
            current_date,
            {
                "online_quantity": 0.0,
                "walk_in_quantity": 0.0,
            },
        )

        online_quantity = float(
            day_data["online_quantity"]
        )

        walk_in_quantity = float(
            day_data["walk_in_quantity"]
        )

        total_quantity = (
            online_quantity
            + walk_in_quantity
        )

        data.append(
            {
                "date": current_date.isoformat(),
                "product_id": product_id,
                "product_name": product.name,
                "online_quantity": round(
                    online_quantity,
                    2,
                ),
                "walk_in_quantity": round(
                    walk_in_quantity,
                    2,
                ),
                "total_quantity": round(
                    total_quantity,
                    2,
                ),
            }
        )

        current_date += timedelta(days=1)

    return {
        "product_id": product_id,
        "product_name": product.name,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "data": data,
    }


# =============================================================
# ML DATASET
# =============================================================

@router.get("/dataset")
def get_ml_dataset(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):

    start_date, end_date = _get_date_range(
        start_date,
        end_date,
    )

    if start_date > end_date:
        return {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "feature_count": 0,
            "features": [],
        }

    demand_data = _collect_demand_history(
        start_date,
        end_date,
        db,
    )

    features = build_features(
        demand_data
    )

    return {
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "feature_count": len(features),
        "features": features,
    }


# =============================================================
# TRAIN REAL DEMAND MODEL
# =============================================================

@router.post("/train")
def train_demand_model(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):

    start_date, end_date = _get_date_range(
        start_date,
        end_date,
    )

    if start_date > end_date:
        return {
            "status": "error",
            "message": "Invalid date range.",
        }

    demand_data = _collect_demand_history(
        start_date,
        end_date,
        db,
    )

    # =========================================================
    # REAL DATA READINESS CHECK
    # =========================================================

    transaction_dates = {
        item["date"]
        for item in demand_data
    }

    product_ids = {
        int(item["product_id"])
        for item in demand_data
    }

    historical_days = (
        end_date - start_date
    ).days + 1

    transaction_days = len(
        transaction_dates
    )

    products_with_history = len(
        product_ids
    )

    minimum_historical_days = 30
    minimum_transaction_days = 14

    if historical_days < minimum_historical_days:
        return {
            "status": "not_ready",
            "message": (
                "At least 30 calendar days of "
                "historical data are recommended "
                "before training the real AI model."
            ),
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "historical_days": historical_days,
            "transaction_days": transaction_days,
            "products_with_history": products_with_history,
            "records": len(demand_data),
            "minimum_historical_days": minimum_historical_days,
            "minimum_transaction_days": minimum_transaction_days,
        }

    if transaction_days < minimum_transaction_days:
        return {
            "status": "not_ready",
            "message": (
                "Not enough transaction days are "
                "available for reliable real-data "
                "model training."
            ),
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "historical_days": historical_days,
            "transaction_days": transaction_days,
            "products_with_history": products_with_history,
            "records": len(demand_data),
            "minimum_historical_days": minimum_historical_days,
            "minimum_transaction_days": minimum_transaction_days,
        }

    if not demand_data:
        return {
            "status": "not_ready",
            "message": (
                "No real demand history is available "
                "for the selected date range."
            ),
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "historical_days": historical_days,
            "transaction_days": transaction_days,
            "products_with_history": 0,
            "records": 0,
        }

    # =========================================================
    # TRAIN
    # =========================================================

    try:

        result = train_model(
            demand_data,
            data_source="real",
            training_metadata={
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "historical_days": historical_days,
                "transaction_days": transaction_days,
                "products_with_history": products_with_history,
            },
            db=db,
        )

        return {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            **result,
        }

    except ValueError as exc:

        return {
            "status": "error",
            "message": str(exc),
        }


# =============================================================
# FORECAST NEXT DAY
# =============================================================

@router.get("/forecast/{product_id}")
def forecast_product_demand(
    product_id: int,
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):

    start_date, end_date = _get_date_range(
        start_date,
        end_date,
    )

    product = (
        db.query(Product)
        .filter(Product.id == product_id)
        .first()
    )

    if not product:
        return {
            "status": "error",
            "message": "Product not found.",
        }

    demand_data = _collect_demand_history(
        start_date,
        end_date,
        db,
    )

    try:

        result = predict_next_day(
            demand_data,
            product_id,
            data_source="real",
            db=db,
        )

        return {
            "status": "success",
            **result,
        }

    except FileNotFoundError as exc:

        return {
            "status": "error",
            "message": str(exc),
        }

    except ValueError as exc:

        return {
            "status": "error",
            "message": str(exc),
        }