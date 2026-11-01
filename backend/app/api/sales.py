from fastapi import APIRouter, Depends, HTTPException

from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin

from app.models.inventory import Inventory
from app.models.product import Product
from app.models.sale import Sale
from app.models.user import User

from app.schemas.sale import CreateSaleRequest
from app.services.inventory_costing import calculate_fifo_cost


router = APIRouter(
    prefix="/admin/sales",
    tags=["Sales"]
)


# =========================================================
# CREATE WALK-IN SALE
# =========================================================

@router.post("/")
def create_sale(
    request: CreateSaleRequest,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    product = (
        db.query(Product)
        .filter(Product.id == request.product_id)
        .first()
    )

    if not product:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    inventory_exists = (
        db.query(Inventory)
        .filter(
            Inventory.product_id == request.product_id,
            Inventory.remaining_quantity > 0
        )
        .first()
    )

    if not inventory_exists:
        raise HTTPException(
            status_code=400,
            detail="No available stock for this product"
        )

    total_amount = (
        request.quantity *
        request.selling_price
    )

    try:
        cogs = calculate_fifo_cost(
            db=db,
            product_id=request.product_id,
            quantity=request.quantity,
            include_reserved=False
        )

    except ValueError as e:
        db.rollback()

        raise HTTPException(
            status_code=400,
            detail=str(e)
        )

    profit = total_amount - cogs

    sale = Sale(
        product_id=request.product_id,
        quantity=request.quantity,
        selling_price=request.selling_price,
        total_amount=total_amount,
        cost_of_goods_sold=cogs,
        profit=profit
    )

    db.add(sale)
    db.commit()
    db.refresh(sale)

    return {
        "message": "Walk-in sale completed successfully",

        "sale": {
            "id": sale.id,
            "product_id": product.id,
            "product_name": product.name,
            "quantity": sale.quantity,
            "selling_price": sale.selling_price,
            "total_amount": sale.total_amount,
            "cost_of_goods_sold": sale.cost_of_goods_sold,
            "profit": sale.profit
        }
    }


# =========================================================
# GET SALES HISTORY
# =========================================================

@router.get("/")
def get_sales(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    sales = (
        db.query(Sale)
        .order_by(
            Sale.created_at.desc()
        )
        .all()
    )

    result = []

    for sale in sales:

        product = (
            db.query(Product)
            .filter(Product.id == sale.product_id)
            .first()
        )

        result.append({
            "id": sale.id,

            "product_id": sale.product_id,

            "product_name": (
                product.name
                if product
                else "Unknown"
            ),

            "unit": (
                product.unit
                if product
                else ""
            ),

            "quantity": sale.quantity,

            "selling_price":
                sale.selling_price,

            "total_amount":
                sale.total_amount,

            "cost_of_goods_sold":
                sale.cost_of_goods_sold,

            "profit":
                sale.profit,

            "created_at":
                sale.created_at
        })

    return result