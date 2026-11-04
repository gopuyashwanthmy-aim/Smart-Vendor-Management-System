from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin
from app.models.product import Product
from app.models.inventory import Inventory
from app.models.category import Category
from app.models.user import User
from app.schemas.product import (
    ProductCreateRequest,
    ProductUpdateRequest,
)


router = APIRouter(
    prefix="/products",
    tags=["Products"]
)


# =========================================================
# GET ALL PRODUCTS
# =========================================================

@router.get("/")
def get_products(
    db: Session = Depends(get_db),
):
    products = db.query(Product).order_by(Product.name.asc()).all()
    result = []
    for product in products:
        batches = db.query(Inventory).filter(Inventory.product_id == product.id).all()
        if batches:
            available = sum(float(batch.remaining_quantity or 0) for batch in batches)
        else:
            available = float(product.stock_quantity or 0)
        category = db.query(Category).filter(Category.id == product.category_id).first()
        result.append({"id": product.id, "name": product.name, "unit": product.unit, "price": product.price,
                       "stock_quantity": product.stock_quantity, "available_quantity": max(0, available),
                       "image_url": product.image_url, "category_id": product.category_id,
                       "category_name": category.name if category else "Other"})
    return result


# =========================================================
# GET SINGLE PRODUCT
# =========================================================

@router.get("/{product_id}")
def get_product(
    product_id: int,
    db: Session = Depends(get_db),
):
    product = (
        db.query(Product)
        .filter(Product.id == product_id)
        .first()
    )

    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    return product


# =========================================================
# CREATE PRODUCT - ADMIN ONLY
# =========================================================

@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
)
def create_product(
    request: ProductCreateRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    product = Product(
        name=request.name.strip(),
        unit=request.unit.strip(),
        price=request.price,
        stock_quantity=request.stock_quantity,
        image_url=request.image_url,
        category_id=request.category_id,
    )

    db.add(product)
    db.commit()
    db.refresh(product)

    return product


# =========================================================
# UPDATE PRODUCT - ADMIN ONLY
# =========================================================

@router.put("/{product_id}")
def update_product(
    product_id: int,
    request: ProductUpdateRequest,
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    product = (
        db.query(Product)
        .filter(Product.id == product_id)
        .first()
    )

    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    update_data = request.model_dump(
        exclude_unset=True
    )

    if "name" in update_data:
        product.name = update_data["name"].strip()

    if "unit" in update_data:
        product.unit = update_data["unit"].strip()

    if "price" in update_data:
        product.price = update_data["price"]

    if "stock_quantity" in update_data:
        product.stock_quantity = update_data[
            "stock_quantity"
        ]

    if "image_url" in update_data:
        product.image_url = update_data["image_url"]

    if "category_id" in update_data:
        product.category_id = update_data[
            "category_id"
        ]

    db.commit()
    db.refresh(product)

    return product


# =========================================================
# DELETE PRODUCT - ADMIN ONLY
# =========================================================

@router.delete("/{product_id}")
def delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    product = (
        db.query(Product)
        .filter(Product.id == product_id)
        .first()
    )

    if not product:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    try:
        db.delete(product)
        db.commit()

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Product cannot be deleted because "
                "it is already used in existing orders, "
                "inventory, or sales."
            ),
        )

    return {
        "message": "Product deleted successfully",
        "product_id": product_id,
    }