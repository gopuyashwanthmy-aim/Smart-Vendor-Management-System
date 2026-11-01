from __future__ import annotations

from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.demand import _collect_demand_history
from app.core.database import get_db
from app.core.security import get_current_admin
from app.ml.forecasting import get_model_metadata, model_exists
from app.models.user import User

router = APIRouter(prefix="/admin/ai", tags=["AI Management"])
MINIMUM_HISTORICAL_DAYS = 30
MINIMUM_TRANSACTION_DAYS = 14


@router.get("/readiness")
def get_ai_readiness(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    today = date.today()
    end_date = end_date or today
    start_date = start_date or (end_date - timedelta(days=89))
    if start_date > end_date:
        return {"status": "error", "message": "Invalid date range.", "ready_for_training": False}

    demand_data = _collect_demand_history(start_date, end_date, db)
    transaction_dates = {date.fromisoformat(item["date"]) for item in demand_data}
    observed_days = (max(transaction_dates) - min(transaction_dates)).days + 1 if transaction_dates else 0
    transaction_days = len(transaction_dates)
    product_ids = {int(item["product_id"]) for item in demand_data}
    ready = bool(demand_data) and observed_days >= MINIMUM_HISTORICAL_DAYS and transaction_days >= MINIMUM_TRANSACTION_DAYS

    if ready:
        status, message = "READY", "Enough real business history is available for model training."
    elif not demand_data:
        status, message = "NO_DATA", "No delivered orders or walk-in sales were found in this date range."
    else:
        status, message = "INSUFFICIENT_DATA", "Continue recording actual delivered orders and walk-in sales before training the real-data model."

    real_available = model_exists("real", db=db)
    real_metadata = None
    if real_available:
        try:
            real_metadata = get_model_metadata("real", db=db)
            if real_metadata.get("data_source") != "real":
                real_available = False
                real_metadata = None
        except Exception:
            real_available = False

    return {
        "status": status,
        "message": message,
        "ready_for_training": ready,
        "data": {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "historical_days": (end_date - start_date).days + 1,
            "observed_calendar_days": observed_days,
            "transaction_days": transaction_days,
            "products_with_history": len(product_ids),
            "total_records": len(demand_data),
        },
        "requirements": {
            "minimum_historical_days": MINIMUM_HISTORICAL_DAYS,
            "minimum_transaction_days": MINIMUM_TRANSACTION_DAYS,
        },
        "models": {
            "real_model_available": real_available,
            "demo_model_available": False,
            "real_model": real_metadata,
        },
    }


@router.get("/model-status")
def get_ai_model_status(
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    real_available = model_exists("real", db=db)
    real_metadata = None
    if real_available:
        try:
            real_metadata = get_model_metadata("real", db=db)
            if real_metadata.get("data_source") != "real":
                real_available = False
                real_metadata = None
        except Exception:
            real_available = False
            real_metadata = None
    return {
        "real_model": {"available": real_available, "metadata": real_metadata},
        "demo_model": {"available": False, "metadata": None, "disabled": True},
        "recommended_mode": "real" if real_available else "order_based",
    }
