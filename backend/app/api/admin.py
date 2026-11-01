from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin

from app.models.order import Order
from app.models.order_item import OrderItem
from app.models.product import Product
from app.models.user import User
from app.models.inventory import Inventory
from app.models.sale import Sale

from app.schemas.order import UpdateOrderStatusRequest

from app.services.inventory_costing import calculate_fifo_cost

from app.ml.forecasting import predict_next_day
from app.api.demand import _collect_demand_history


router = APIRouter(
    prefix="/admin",
    tags=["Admin"]
)


# =========================================================
# GET ALL ORDERS
# =========================================================

@router.get("/orders")
def get_all_orders(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    orders = (
        db.query(Order)
        .order_by(Order.created_at.desc())
        .all()
    )

    result = []

    for order in orders:

        customer = (
            db.query(User)
            .filter(User.id == order.user_id)
            .first()
        )

        items = (
            db.query(OrderItem)
            .filter(OrderItem.order_id == order.id)
            .all()
        )

        order_items = []

        for item in items:

            product = (
                db.query(Product)
                .filter(Product.id == item.product_id)
                .first()
            )

            order_items.append({
                "product_id": item.product_id,

                "product_name": (
                    product.name
                    if product
                    else "Unknown"
                ),

                "quantity": item.quantity,

                "price": item.price,

                "total":
                    item.quantity * item.price,

                "revenue": item.revenue,

                "cost_of_goods_sold":
                    item.cost_of_goods_sold,

                "profit": item.profit
            })

        result.append({
            "id": order.id,

            "customer": {
                "id": (
                    customer.id
                    if customer
                    else None
                ),

                "name": (
                    customer.name
                    if customer
                    else "Unknown"
                ),

                "phone": (
                    customer.phone
                    if customer
                    else "Unknown"
                )
            },

            "status": order.status,

            "total_amount":
                order.total_amount,

            "created_at":
                order.created_at,

            "items": order_items
        })

    return result


# =========================================================
# GET SINGLE ORDER
# =========================================================

@router.get("/orders/{order_id}")
def get_order_details(
    order_id: int,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    order = (
        db.query(Order)
        .filter(Order.id == order_id)
        .first()
    )

    if not order:
        raise HTTPException(
            status_code=404,
            detail="Order not found"
        )

    customer = (
        db.query(User)
        .filter(User.id == order.user_id)
        .first()
    )

    items = (
        db.query(OrderItem)
        .filter(OrderItem.order_id == order.id)
        .all()
    )

    order_items = []

    for item in items:

        product = (
            db.query(Product)
            .filter(Product.id == item.product_id)
            .first()
        )

        order_items.append({
            "product_id": item.product_id,

            "product_name": (
                product.name
                if product
                else "Unknown"
            ),

            "quantity": item.quantity,

            "price": item.price,

            "total":
                item.quantity * item.price,

            "revenue": item.revenue,

            "cost_of_goods_sold":
                item.cost_of_goods_sold,

            "profit": item.profit
        })

    return {
        "id": order.id,

        "customer": {
            "id": (
                customer.id
                if customer
                else None
            ),

            "name": (
                customer.name
                if customer
                else "Unknown"
            ),

            "phone": (
                customer.phone
                if customer
                else "Unknown"
            )
        },

        "status": order.status,

        "total_amount":
            order.total_amount,

        "created_at":
            order.created_at,

        "items": order_items
    }


# =========================================================
# UPDATE ORDER STATUS
# =========================================================

@router.patch("/orders/{order_id}/status")
def update_order_status(
    order_id: int,
    request: UpdateOrderStatusRequest,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    transitions = {
        "PLACED": "CONFIRMED",
        "CONFIRMED": "PURCHASING",
        "PURCHASING": "READY",
        "READY": "DELIVERED",
        "DELIVERED": None,
    }

    new_status = request.new_status.strip().upper()
    if new_status not in transitions:
        raise HTTPException(status_code=400, detail="Invalid order status")

    order = (
        db.query(Order)
        .filter(Order.id == order_id)
        .first()
    )

    if not order:
        raise HTTPException(
            status_code=404,
            detail="Order not found"
        )

    # Repeating the current status is idempotent; backward or skipped
    # transitions are rejected so delivery/COGS cannot be applied twice.
    if order.status == new_status:
        return {"message": "Order already has this status", "order_id": order.id, "status": order.status}

    expected_next = transitions.get(order.status)
    if expected_next != new_status:
        raise HTTPException(
            status_code=409,
            detail=f"Invalid status transition: {order.status} -> {new_status}. Next status must be {expected_next or 'none' }.",
        )

    # -----------------------------------------------------
    # ONLINE ORDER DELIVERY
    # -----------------------------------------------------

    if (
        new_status == "DELIVERED"
        and order.status != "DELIVERED"
    ):

        order_items = (
            db.query(OrderItem)
            .filter(
                OrderItem.order_id == order.id
            )
            .all()
        )

        calculated_items = []

        try:

            for item in order_items:

                product = (
                    db.query(Product)
                    .filter(
                        Product.id == item.product_id
                    )
                    .first()
                )

                if not product:
                    raise ValueError(
                        f"Product {item.product_id} not found"
                    )

                cogs = calculate_fifo_cost(
                    db=db,
                    product_id=item.product_id,
                    quantity=item.quantity,
                    include_reserved=True
                )

                revenue = (
                    item.price *
                    item.quantity
                )

                profit = revenue - cogs

                calculated_items.append({
                    "item": item,
                    "revenue": revenue,
                    "cogs": cogs,
                    "profit": profit
                })

        except ValueError as e:

            db.rollback()

            raise HTTPException(
                status_code=400,
                detail=str(e)
            )

        # -------------------------------------------------
        # Save financial results
        # -------------------------------------------------

        for data in calculated_items:

            item = data["item"]

            item.revenue = data["revenue"]

            item.cost_of_goods_sold = data["cogs"]

            item.profit = data["profit"]

    order.status = new_status

    db.commit()
    db.refresh(order)

    return {
        "message":
            "Order status updated successfully",

        "order_id":
            order.id,

        "status":
            order.status
    }


# =========================================================
# MARKET PURCHASE PLAN
# =========================================================

@router.get("/market-plan")
def get_market_plan(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    # -----------------------------------------------------
    # ACTIVE CUSTOMER ORDERS
    # -----------------------------------------------------

    active_statuses = [
        "PLACED",
        "CONFIRMED"
    ]

    order_rows = (
        db.query(
            Product.id,
            Product.name,
            Product.unit,
            func.sum(
                OrderItem.quantity
            ).label(
                "required_quantity"
            )
        )
        .join(
            OrderItem,
            Product.id == OrderItem.product_id
        )
        .join(
            Order,
            Order.id == OrderItem.order_id
        )
        .filter(
            Order.status.in_(active_statuses)
        )
        .group_by(
            Product.id,
            Product.name,
            Product.unit
        )
        .order_by(
            Product.name
        )
        .all()
    )

    # -----------------------------------------------------
    # GET REAL DEMAND HISTORY FOR AI
    # -----------------------------------------------------

    try:

        today = date.today()
        demand_history = _collect_demand_history(
            db=db,
            start_date=today - timedelta(days=89),
            end_date=today,
        )

    except Exception:

        demand_history = []

    # -----------------------------------------------------
    # CURRENT INVENTORY
    # -----------------------------------------------------

    inventory_records = (
        db.query(Inventory)
        .order_by(
            Inventory.created_at.desc(),
            Inventory.id.desc()
        )
        .all()
    )

    inventory_totals = {}
    for inventory in inventory_records:
        totals = inventory_totals.setdefault(
            inventory.product_id,
            {"available": 0.0, "reserved": 0.0},
        )
        totals["available"] += float(inventory.remaining_quantity or 0)
        totals["reserved"] += float(inventory.reserved_quantity or 0)

    # -----------------------------------------------------
    # BUILD ACTIVE ORDER LOOKUP
    # -----------------------------------------------------

    order_quantities = {}

    for row in order_rows:

        order_quantities[row.id] = {
            "product_id": row.id,
            "product_name": row.name,
            "unit": row.unit,
            "required_quantity": float(
                row.required_quantity or 0
            )
        }

    # -----------------------------------------------------
    # INCLUDE PRODUCTS WITH INVENTORY / AI DATA
    # -----------------------------------------------------

    product_ids = set(
        order_quantities.keys()
    )

    for product in db.query(Product).all():

        product_ids.add(product.id)

    # -----------------------------------------------------
    # GENERATE AI-ENHANCED PLAN
    # -----------------------------------------------------

    result = []

    for product_id in sorted(product_ids):

        product = (
            db.query(Product)
            .filter(
                Product.id == product_id
            )
            .first()
        )

        if not product:
            continue

        # -------------------------------------------------
        # CONFIRMED CUSTOMER DEMAND
        # -------------------------------------------------

        confirmed_quantity = float(
            order_quantities.get(
                product_id,
                {}
            ).get(
                "required_quantity",
                0
            )
        )

        # -------------------------------------------------
        # CURRENT INVENTORY
        # -------------------------------------------------

        inventory = inventory_totals.get(
            product_id,
            {"available": 0.0, "reserved": 0.0},
        )
        available_inventory = inventory["available"]
        reserved_inventory = inventory["reserved"]
        total_inventory = available_inventory + reserved_inventory

        # -------------------------------------------------
        # AI FORECAST
        # -------------------------------------------------

        predicted_demand = 0.0

        forecast_available = False

        forecast_date = None

        forecast_model = None

        forecast_error = None

        try:

            forecast = predict_next_day(
                demand_data=demand_history,
                product_id=product_id,
                db=db,
            )

            predicted_demand = float(
                forecast.get(
                    "predicted_demand",
                    0
                )
            )

            forecast_available = True

            forecast_date = forecast.get(
                "forecast_date"
            )

            forecast_model = forecast.get(
                "model"
            )

        except Exception as exc:

            forecast_error = str(exc)

        # -------------------------------------------------
        # EXPECTED DEMAND
        # -------------------------------------------------

        expected_demand = (
            confirmed_quantity
            + predicted_demand
        )

        # -------------------------------------------------
        # RECOMMENDED PURCHASE
        # -------------------------------------------------

        # Reserved stock is already held for customer orders; count it as
        # on-hand supply for the combined confirmed + forecast demand.
        recommended_purchase = max(
            0.0,
            expected_demand - total_inventory,
        )

        # -------------------------------------------------
        # ROUNDING
        # -------------------------------------------------

        confirmed_quantity = round(
            confirmed_quantity,
            2
        )

        predicted_demand = round(
            predicted_demand,
            2
        )

        expected_demand = round(
            expected_demand,
            2
        )

        available_inventory = round(
            available_inventory,
            2
        )

        reserved_inventory = round(
            reserved_inventory,
            2
        )

        recommended_purchase = round(
            recommended_purchase,
            2
        )

        result.append({

            # Basic product information
            "product_id":
                product.id,

            "product_name":
                product.name,

            "unit":
                product.unit,

            # Existing market-plan field
            "required_quantity":
                confirmed_quantity,

            # Customer demand
            "confirmed_order_quantity":
                confirmed_quantity,

            # AI prediction
            "ai_forecast": {
                "available":
                    forecast_available,

                "forecast_date":
                    forecast_date,

                "predicted_demand":
                    predicted_demand,

                "model":
                    forecast_model,

                "error":
                    forecast_error
            },

            # Inventory
            "inventory": {
                "available_quantity": available_inventory,
                "reserved_quantity": reserved_inventory,
                "total_quantity": round(total_inventory, 2),
            },

            # Combined planning values
            "expected_demand":
                expected_demand,

            "recommended_purchase_quantity":
                recommended_purchase,

            "recommendation": (
                "Purchase additional stock"
                if recommended_purchase > 0
                else "No additional purchase required"
            )
        })

    return result


# =========================================================
# VENDOR DASHBOARD ANALYTICS
# =========================================================

@router.get("/dashboard")
def get_dashboard(
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):

    today = date.today()

    # -----------------------------------------------------
    # TODAY'S ONLINE ORDERS
    # -----------------------------------------------------

    today_orders = (
        db.query(Order)
        .filter(
            func.date(Order.created_at) == today
        )
        .all()
    )

    online_orders_today = len(today_orders)

    # Recognize online revenue only after an order is delivered.
    online_revenue_today = sum(
        float(order.total_amount or 0)
        for order in today_orders
        if order.status == "DELIVERED"
    )

    pending_statuses = [
        "PLACED",
        "CONFIRMED",
        "PURCHASING",
        "READY"
    ]

    pending_orders = (
        db.query(Order)
        .filter(
            Order.status.in_(pending_statuses)
        )
        .count()
    )

    completed_orders = (
        db.query(Order)
        .filter(
            Order.status == "DELIVERED"
        )
        .count()
    )

    # -----------------------------------------------------
    # TODAY'S WALK-IN SALES
    # -----------------------------------------------------

    today_sales = (
        db.query(Sale)
        .filter(
            func.date(Sale.created_at) == today
        )
        .all()
    )

    walk_in_sales_today = len(today_sales)

    walk_in_revenue_today = sum(
        float(sale.total_amount or 0)
        for sale in today_sales
    )

    walk_in_products_sold_today = sum(
        float(sale.quantity or 0)
        for sale in today_sales
    )

    # -----------------------------------------------------
    # ONLINE PRODUCTS SOLD TODAY
    # -----------------------------------------------------

    online_products_sold_today = (
        db.query(
            func.sum(OrderItem.quantity)
        )
        .join(
            Order,
            Order.id == OrderItem.order_id
        )
        .filter(
            Order.status == "DELIVERED",
            func.date(Order.created_at) == today
        )
        .scalar()
        or 0
    )

    products_sold_today = (
        float(online_products_sold_today)
        + walk_in_products_sold_today
    )

    # -----------------------------------------------------
    # TOTAL TODAY REVENUE
    # -----------------------------------------------------

    total_revenue_today = (
        online_revenue_today
        + walk_in_revenue_today
    )

    # -----------------------------------------------------
    # INVENTORY
    # -----------------------------------------------------

    inventory_records = (
        db.query(Inventory)
        .order_by(
            Inventory.created_at.desc()
        )
        .all()
    )

    inventory_totals = {}
    for inventory in inventory_records:
        totals = inventory_totals.setdefault(
            inventory.product_id,
            {"available": 0.0, "reserved": 0.0},
        )
        totals["available"] += float(inventory.remaining_quantity or 0)
        totals["reserved"] += float(inventory.reserved_quantity or 0)

    total_inventory_products = len(inventory_totals)
    low_stock_products = []
    LOW_STOCK_LIMIT = 5

    for product_id, inventory in inventory_totals.items():

        product = (
            db.query(Product)
            .filter(Product.id == product_id)
            .first()
        )

        if not product:
            continue

        remaining = float(inventory["available"] or 0)

        if remaining <= LOW_STOCK_LIMIT:

            low_stock_products.append({
                "product_id": product.id,
                "product_name": product.name,
                "unit": product.unit,
                "remaining_quantity": remaining
            })

    # -----------------------------------------------------
    # TOP SELLING PRODUCTS
    # -----------------------------------------------------

    online_top_products = (
        db.query(
            Product.id,
            Product.name,
            Product.unit,
            func.sum(
                OrderItem.quantity
            ).label("quantity")
        )
        .join(
            OrderItem,
            Product.id == OrderItem.product_id
        )
        .join(
            Order,
            Order.id == OrderItem.order_id
        )
        .filter(
            Order.status == "DELIVERED",
            func.date(Order.created_at) == today
        )
        .group_by(
            Product.id,
            Product.name,
            Product.unit
        )
        .all()
    )

    walk_in_top_products = (
        db.query(
            Product.id,
            Product.name,
            Product.unit,
            func.sum(
                Sale.quantity
            ).label("quantity")
        )
        .join(
            Sale,
            Product.id == Sale.product_id
        )
        .filter(
            func.date(Sale.created_at) == today
        )
        .group_by(
            Product.id,
            Product.name,
            Product.unit
        )
        .all()
    )

    product_sales = {}

    for row in online_top_products:

        product_sales[row.id] = {
            "product_id": row.id,
            "product_name": row.name,
            "unit": row.unit,
            "quantity": float(
                row.quantity or 0
            )
        }

    for row in walk_in_top_products:

        if row.id in product_sales:

            product_sales[row.id]["quantity"] += float(
                row.quantity or 0
            )

        else:

            product_sales[row.id] = {
                "product_id": row.id,
                "product_name": row.name,
                "unit": row.unit,
                "quantity": float(
                    row.quantity or 0
                )
            }

    top_products = sorted(
        product_sales.values(),
        key=lambda item: item["quantity"],
        reverse=True
    )[:5]

    # -----------------------------------------------------
    # RECENT ORDERS
    # -----------------------------------------------------

    recent_orders = (
        db.query(Order)
        .order_by(
            Order.created_at.desc()
        )
        .limit(5)
        .all()
    )

    recent_orders_result = []

    for order in recent_orders:

        customer = (
            db.query(User)
            .filter(User.id == order.user_id)
            .first()
        )

        recent_orders_result.append({
            "id": order.id,

            "customer_name": (
                customer.name
                if customer
                else "Unknown"
            ),

            "status": order.status,

            "total_amount": float(
                order.total_amount or 0
            ),

            "created_at":
                order.created_at
        })

    return {
        "today": {
            "online_orders":
                online_orders_today,

            "walk_in_sales":
                walk_in_sales_today,

            "revenue": round(
                total_revenue_today,
                2
            ),

            "online_revenue": round(
                online_revenue_today,
                2
            ),

            "walk_in_revenue": round(
                walk_in_revenue_today,
                2
            ),

            "products_sold":
                products_sold_today
        },

        "orders": {
            "pending":
                pending_orders,

            "completed":
                completed_orders
        },

        "inventory": {
            "total_products":
                total_inventory_products,

            "low_stock_count":
                len(low_stock_products),

            "low_stock_products":
                low_stock_products
        },

        "top_products":
            top_products,

        "recent_orders":
            recent_orders_result
    }