from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.user import User
from app.models.address import Address
from app.models.notification import Notification
from app.models.inventory import Inventory
from app.schemas.order import CreateOrderRequest

router = APIRouter(prefix="/orders", tags=["Orders"])

@router.post("/", status_code=status.HTTP_201_CREATED)
def create_order(request: CreateOrderRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not request.items:
        raise HTTPException(status_code=400, detail="Order must contain at least one product")
    address = None
    if request.delivery_address_id is not None:
        address = db.query(Address).filter(Address.id == request.delivery_address_id, Address.user_id == current_user.id).first()
        if not address: raise HTTPException(status_code=404, detail="Delivery address not found")
    scheduled_at = request.scheduled_delivery_at
    if scheduled_at is not None:
        from datetime import datetime, timezone
        if scheduled_at.tzinfo is not None:
            scheduled_at = scheduled_at.astimezone(timezone.utc).replace(tzinfo=None)
        if scheduled_at <= datetime.utcnow():
            raise HTTPException(status_code=400, detail="Scheduled delivery must be in the future")
        if not request.delivery_slot:
            raise HTTPException(status_code=400, detail="Choose a delivery time slot")
    total_amount = 0.0
    order_items_data = []
    for item in request.items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if not product: raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
        batches = db.query(Inventory).filter(Inventory.product_id == product.id).order_by(Inventory.created_at.asc(), Inventory.id.asc()).with_for_update().all()
        if batches:
            available = sum(float(batch.remaining_quantity or 0) for batch in batches)
        else:
            available = float(product.stock_quantity or 0)
        if available <= 0 or item.quantity > available:
            raise HTTPException(status_code=409, detail=f"Insufficient availability for {product.name}. Available: {available:g} {product.unit}")
        total_amount += product.price * item.quantity
        order_items_data.append({"product_id": product.id, "quantity": item.quantity, "price": product.price, "has_inventory_batches": bool(batches)})
    order = Order(user_id=current_user.id, status="PLACED", total_amount=total_amount,
                  delivery_address_id=address.id if address else None,
                  scheduled_delivery_at=scheduled_at,
                  delivery_slot=request.delivery_slot)
    db.add(order); db.flush()
    for data in order_items_data:
        revenue = data["price"] * data["quantity"]
        db.add(OrderItem(order_id=order.id, product_id=data["product_id"], quantity=data["quantity"], price=data["price"], revenue=revenue, cost_of_goods_sold=0, profit=0))
        if data["has_inventory_batches"]:
            remaining_to_reserve = float(data["quantity"])
            batches = db.query(Inventory).filter(Inventory.product_id == data["product_id"]).order_by(Inventory.created_at.asc(), Inventory.id.asc()).with_for_update().all()
            for batch in batches:
                if remaining_to_reserve <= 0:
                    break
                available_batch = float(batch.remaining_quantity or 0)
                take = min(available_batch, remaining_to_reserve)
                if take > 0:
                    batch.remaining_quantity -= take
                    batch.reserved_quantity = float(batch.reserved_quantity or 0) + take
                    remaining_to_reserve -= take
        else:
            product = db.query(Product).filter(Product.id == data["product_id"]).with_for_update().first()
            product.stock_quantity = max(0, float(product.stock_quantity or 0) - float(data["quantity"]))
    admins = db.query(User).filter(User.role == "admin").all()
    for admin in admins:
        db.add(Notification(user_id=admin.id, title="New customer order", message=f"{current_user.name} placed order #{order.id} for ₹{total_amount:.2f}.", order_id=order.id))
    db.add(Notification(user_id=current_user.id, title="Order placed successfully", message=f"Your order #{order.id} has been placed and is awaiting confirmation.", order_id=order.id))
    db.commit(); db.refresh(order)
    return {"message": "Order created successfully", "order_id": order.id, "status": order.status, "total_amount": order.total_amount, "user_id": order.user_id,
            "scheduled_delivery_at": order.scheduled_delivery_at.isoformat() if order.scheduled_delivery_at else None, "delivery_slot": order.delivery_slot}

@router.get("/my-orders")
def get_my_orders(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    orders = db.query(Order).filter(Order.user_id == current_user.id).order_by(Order.id.desc()).all()
    result = []
    for order in orders:
        order_items = db.query(OrderItem).filter(OrderItem.order_id == order.id).all()
        items = []
        for item in order_items:
            product = db.query(Product).filter(Product.id == item.product_id).first()
            items.append({"product_id": item.product_id, "product_name": product.name if product else "Unknown Product", "quantity": item.quantity, "price": item.price, "total": item.price * item.quantity})
        address = db.query(Address).filter(Address.id == order.delivery_address_id).first() if order.delivery_address_id else None
        result.append({"id": order.id, "status": order.status, "created_at": order.created_at.isoformat() if order.created_at else None,
                       "total_amount": order.total_amount, "scheduled_delivery_at": order.scheduled_delivery_at.isoformat() if order.scheduled_delivery_at else None,
                       "delivery_slot": order.delivery_slot, "delivery_address": (f"{address.address_line}, {address.city} - {address.pincode}" if address else None), "items": items})
    return result
