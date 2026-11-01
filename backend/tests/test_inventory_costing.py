import os
import sys
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.category import Category
from app.models.product import Product
from app.models.inventory import Inventory
from app.services.inventory_costing import calculate_fifo_cost


def make_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def seed_product(db):
    category = Category(name="Vegetables")
    db.add(category)
    db.flush()
    product = Product(name="Tomato", unit="kg", price=40, stock_quantity=0, category_id=category.id)
    db.add(product)
    db.flush()
    return product


def test_fifo_consumes_oldest_batch_first():
    db = make_session()
    product = seed_product(db)
    db.add_all([
        Inventory(product_id=product.id, purchased_quantity=10, purchase_cost_per_unit=20, total_purchase_cost=200, reserved_quantity=0, remaining_quantity=10),
        Inventory(product_id=product.id, purchased_quantity=10, purchase_cost_per_unit=25, total_purchase_cost=250, reserved_quantity=0, remaining_quantity=10),
    ])
    db.commit()

    cogs = calculate_fifo_cost(db, product.id, 12)
    db.commit()

    assert cogs == 250.0  # 10*20 + 2*25
    batches = db.query(Inventory).order_by(Inventory.id).all()
    assert batches[0].remaining_quantity == 0
    assert batches[1].remaining_quantity == 8
    db.close()


def test_fifo_uses_reserved_stock_for_online_delivery():
    db = make_session()
    product = seed_product(db)
    batch = Inventory(product_id=product.id, purchased_quantity=10, purchase_cost_per_unit=18, total_purchase_cost=180, reserved_quantity=4, remaining_quantity=6)
    db.add(batch)
    db.commit()

    cogs = calculate_fifo_cost(db, product.id, 5, include_reserved=True)
    db.commit()

    assert cogs == 90.0
    assert batch.reserved_quantity == 0
    assert batch.remaining_quantity == 5
    db.close()


def test_fifo_shortage_raises_without_committing_partial_consumption():
    db = make_session()
    product = seed_product(db)
    batch = Inventory(product_id=product.id, purchased_quantity=3, purchase_cost_per_unit=10, total_purchase_cost=30, reserved_quantity=0, remaining_quantity=3)
    db.add(batch)
    db.commit()

    try:
        calculate_fifo_cost(db, product.id, 5)
        assert False, "Expected insufficient stock error"
    except ValueError as exc:
        assert "Insufficient inventory" in str(exc)

    db.refresh(batch)
    assert batch.remaining_quantity == 3
    db.close()
