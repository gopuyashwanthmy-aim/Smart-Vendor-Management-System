from fastapi import APIRouter, Depends, HTTPException, status

from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user

from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.user import User


from app.schemas.order import CreateOrderRequest


router = APIRouter(
    prefix="/orders",
    tags=["Orders"]
)


# =========================================================
# CREATE ORDER
# =========================================================

@router.post(
    "/",
    status_code=status.HTTP_201_CREATED
)
def create_order(
    request: CreateOrderRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):

    if not request.items:
        raise HTTPException(
            status_code=400,
            detail="Order must contain at least one product"
        )

    total_amount = 0

    order_items_data = []

    for item in request.items:

        product = (
            db.query(Product)
            .filter(Product.id == item.product_id)
            .first()
        )

        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Product {item.product_id} not found"
            )

        item_total = (
            product.price *
            item.quantity
        )

        total_amount += item_total

        order_items_data.append({
            "product_id": product.id,
            "quantity": item.quantity,
            "price": product.price
        })

    order = Order(
        user_id=current_user.id,
        status="PLACED",
        total_amount=total_amount
    )

    db.add(order)

    db.flush()

    for item_data in order_items_data:

        revenue = (
            item_data["price"] *
            item_data["quantity"]
        )

        order_item = OrderItem(
            order_id=order.id,
            product_id=item_data["product_id"],
            quantity=item_data["quantity"],
            price=item_data["price"],
            revenue=revenue,
            cost_of_goods_sold=0,
            profit=0
        )

        db.add(order_item)

    db.commit()
    db.refresh(order)

    return {
        "message": "Order created successfully",
        "order_id": order.id,
        "status": order.status,
        "total_amount": order.total_amount,
        "user_id": order.user_id
    }


# =========================================================
# GET MY ORDERS
# =========================================================

@router.get("/my-orders")
def get_my_orders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):

    orders = (
        db.query(Order)
        .filter(
            Order.user_id == current_user.id
        )
        .order_by(
            Order.id.desc()
        )
        .all()
    )

    result = []

    for order in orders:

        order_items = (
            db.query(OrderItem)
            .filter(
                OrderItem.order_id == order.id
            )
            .all()
        )

        items = []

        for item in order_items:

            product = (
                db.query(Product)
                .filter(
                    Product.id == item.product_id
                )
                .first()
            )

            items.append({
                "product_id": item.product_id,

                "product_name": (
                    product.name
                    if product
                    else "Unknown Product"
                ),

                "quantity": item.quantity,

                "price": item.price,

                "total":
                    item.price * item.quantity
            })

        result.append({
            "id": order.id,

            "status": order.status,

            "total_amount":
                order.total_amount,

            "items": items
        })

    return result