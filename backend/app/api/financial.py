from datetime import date, datetime, time, timedelta

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin

from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.sale import Sale
from app.models.user import User


router = APIRouter(
    prefix="/admin/financial",
    tags=["Financial"]
)


# =========================================================
# FINANCIAL SUMMARY
# =========================================================

@router.get("/summary")
def get_financial_summary(
    start_date: date | None = Query(
        default=None
    ),
    end_date: date | None = Query(
        default=None
    ),
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    if start_date is None:
        start_date = date.today()

    if end_date is None:
        end_date = start_date

    if end_date < start_date:
        raise HTTPException(
            status_code=400,
            detail="end_date cannot be before start_date",
        )

    start_datetime = datetime.combine(
        start_date,
        time.min
    )

    end_datetime = datetime.combine(
        end_date + timedelta(days=1),
        time.min
    )

    # -----------------------------------------------------
    # ONLINE ORDERS
    # -----------------------------------------------------

    delivered_orders = (
        db.query(Order)
        .filter(
            Order.status == "DELIVERED",
            Order.created_at >= start_datetime,
            Order.created_at < end_datetime
        )
        .all()
    )

    online_revenue = 0.0
    online_cogs = 0.0
    online_transactions = len(
        delivered_orders
    )

    for order in delivered_orders:

        online_revenue += float(
            order.total_amount or 0
        )

        items = (
            db.query(OrderItem)
            .filter(
                OrderItem.order_id == order.id
            )
            .all()
        )

        for item in items:

            online_cogs += float(
                item.cost_of_goods_sold or 0
            )

    # -----------------------------------------------------
    # WALK-IN SALES
    # -----------------------------------------------------

    sales = (
        db.query(Sale)
        .filter(
            Sale.created_at >= start_datetime,
            Sale.created_at < end_datetime
        )
        .all()
    )

    walk_in_revenue = sum(
        float(sale.total_amount or 0)
        for sale in sales
    )

    walk_in_cogs = sum(
        float(sale.cost_of_goods_sold or 0)
        for sale in sales
    )

    walk_in_transactions = len(sales)

    # -----------------------------------------------------
    # TOTALS
    # -----------------------------------------------------

    total_revenue = (
        online_revenue
        + walk_in_revenue
    )

    total_cogs = (
        online_cogs
        + walk_in_cogs
    )

    gross_profit = (
        total_revenue
        - total_cogs
    )

    profit_margin = (
        (gross_profit / total_revenue) * 100
        if total_revenue > 0
        else 0
    )

    return {
        "start_date": str(start_date),
        "end_date": str(end_date),

        "online_revenue":
            round(online_revenue, 2),

        "walk_in_revenue":
            round(walk_in_revenue, 2),

        "total_revenue":
            round(total_revenue, 2),

        "online_cogs":
            round(online_cogs, 2),

        "walk_in_cogs":
            round(walk_in_cogs, 2),

        "total_cogs":
            round(total_cogs, 2),

        "gross_profit":
            round(gross_profit, 2),

        "profit_margin":
            round(profit_margin, 2),

        "online_transactions":
            online_transactions,

        "walk_in_transactions":
            walk_in_transactions,

        "total_transactions":
            online_transactions
            + walk_in_transactions
    }