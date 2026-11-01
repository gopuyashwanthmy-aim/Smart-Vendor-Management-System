from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import category, inventory, ml_model_artifact, order, order_item, product, sale, user  # noqa: F401
from app.services import ai_planning


def test_purchase_plan_uses_active_orders_when_no_real_model(monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    db = Session()
    try:
        category_row = category.Category(name="Vegetables")
        db.add(category_row)
        db.flush()
        customer = user.User(name="Customer", phone="9000000099", password_hash="not-used", role="customer")
        db.add(customer)
        db.flush()
        tomato = product.Product(name="Tomato", unit="kg", price=30, stock_quantity=0, category_id=category_row.id)
        db.add(tomato)
        db.flush()
        active_order = order.Order(user_id=customer.id, status="PLACED", total_amount=450)
        db.add(active_order)
        db.flush()
        db.add(order_item.OrderItem(order_id=active_order.id, product_id=tomato.id, quantity=15, price=30, revenue=450, cost_of_goods_sold=0, profit=0))
        db.add(inventory.Inventory(product_id=tomato.id, purchased_quantity=7, purchase_cost_per_unit=20, total_purchase_cost=140, reserved_quantity=2, remaining_quantity=5))
        db.commit()

        monkeypatch.setattr(ai_planning, "model_exists", lambda *args, **kwargs: False)
        monkeypatch.setattr(ai_planning, "_real_history", lambda _db: [])
        result = ai_planning.build_production_planning_data(db)

        assert result["mode"] == "order_based"
        assert result["data_source"] == "order_based_fallback"
        item = result["products"][0]
        assert item["ai_forecast"]["status"] == "unavailable"
        assert item["ai_forecast"]["predicted_demand"] == 0
        assert item["inventory"]["total_on_hand"] == 7
        assert item["purchase_plan"]["recommended_purchase_quantity"] == 8
    finally:
        db.close()
