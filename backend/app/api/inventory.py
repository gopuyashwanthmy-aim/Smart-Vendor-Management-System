from fastapi import APIRouter, Depends, HTTPException

from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin

from app.models.inventory import Inventory
from app.models.product import Product
from app.models.user import User

from app.schemas.inventory import CreateInventoryRequest


router = APIRouter(
    prefix="/admin/inventory",
    tags=["Inventory"]
)


# =========================================================
# CREATE INVENTORY / RECORD MARKET PURCHASE
# =========================================================

@router.post("/")
def create_inventory(
    request: CreateInventoryRequest,
    current_admin: User = Depends(
        get_current_admin
    ),
    db: Session = Depends(get_db)
):
    product = (
        db.query(Product)
        .filter(
            Product.id == request.product_id
        )
        .first()
    )

    if not product:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    if (
        request.purchased_quantity
        < request.reserved_quantity
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Purchased quantity cannot be "
                "less than reserved quantity"
            )
        )

    remaining_quantity = (
        request.purchased_quantity
        - request.reserved_quantity
    )

    total_purchase_cost = (
        request.purchased_quantity
        * request.purchase_cost_per_unit
    )

    inventory = Inventory(
        product_id=request.product_id,
        purchased_quantity=request.purchased_quantity,
        purchase_cost_per_unit=(
            request.purchase_cost_per_unit
        ),
        total_purchase_cost=total_purchase_cost,
        reserved_quantity=request.reserved_quantity,
        remaining_quantity=remaining_quantity
    )

    db.add(inventory)
    db.commit()
    db.refresh(inventory)

    return {
        "message": "Inventory added successfully",
        "inventory_id": inventory.id,
        "product_id": product.id,
        "product_name": product.name,
        "purchased_quantity":
            inventory.purchased_quantity,
        "purchase_cost_per_unit":
            inventory.purchase_cost_per_unit,
        "total_purchase_cost":
            inventory.total_purchase_cost,
        "reserved_quantity":
            inventory.reserved_quantity,
        "remaining_quantity":
            inventory.remaining_quantity
    }


# =========================================================
# GET INVENTORY
# =========================================================

@router.get("/")
def get_inventory(
    current_admin: User = Depends(
        get_current_admin
    ),
    db: Session = Depends(get_db)
):
    inventory_records = (
        db.query(Inventory)
        .order_by(
            Inventory.created_at.desc()
        )
        .all()
    )

    result = []

    for inventory in inventory_records:

        product = (
            db.query(Product)
            .filter(
                Product.id == inventory.product_id
            )
            .first()
        )

        result.append({
            "id": inventory.id,

            "product_id":
                inventory.product_id,

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

            "purchased_quantity":
                inventory.purchased_quantity,

            "purchase_cost_per_unit":
                inventory.purchase_cost_per_unit,

            "total_purchase_cost":
                inventory.total_purchase_cost,

            "reserved_quantity":
                inventory.reserved_quantity,

            "remaining_quantity":
                inventory.remaining_quantity,

            "created_at":
                inventory.created_at
        })

    return result