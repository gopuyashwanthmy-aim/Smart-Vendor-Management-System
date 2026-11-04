"""Initialize a new database or safely recognize a restored current database."""
from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect

from app.core.database import engine
# Import all models so Alembic sees the complete metadata.
from app.models import category, inventory, order, order_item, product, sale, user, ml_model_artifact  # noqa: F401
from app.models import address, notification  # noqa: F401


def main() -> None:
    backend_dir = Path(__file__).resolve().parents[1]
    alembic_cfg = Config(str(backend_dir / "alembic.ini"))
    tables = set(inspect(engine).get_table_names())
    core_tables = {"users", "categories", "products", "orders", "order_items"}

    if not core_tables.intersection(tables):
        command.upgrade(alembic_cfg, "head")
        print("Database initialized from the versioned schema.")
        return

    if "alembic_version" in tables:
        command.upgrade(alembic_cfg, "head")
        print("Database migrations checked and applied.")
        return

    # Safe additive table creation for a restored current database that was
    # historically initialized with SQLAlchemy create_all (no Alembic table).
    from app.core.database import Base
    Base.metadata.create_all(bind=engine)
    tables = set(inspect(engine).get_table_names())

    # Additive compatibility for restored/current databases without Alembic history.
    # New tables are created by metadata.create_all above; these columns are added
    # only when absent. Existing customer/order data is never rewritten.
    from sqlalchemy import text
    order_columns = {column["name"] for column in inspect(engine).get_columns("orders")}
    with engine.begin() as connection:
        if "delivery_address_id" not in order_columns:
            connection.execute(text("ALTER TABLE orders ADD COLUMN delivery_address_id INTEGER NULL"))
        if "scheduled_delivery_at" not in order_columns:
            connection.execute(text("ALTER TABLE orders ADD COLUMN scheduled_delivery_at TIMESTAMP NULL"))
        if "delivery_slot" not in order_columns:
            connection.execute(text("ALTER TABLE orders ADD COLUMN delivery_slot VARCHAR(60) NULL"))
        if engine.dialect.name == "postgresql":
            connection.execute(text("DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_delivery_address') THEN ALTER TABLE orders ADD CONSTRAINT fk_orders_delivery_address FOREIGN KEY (delivery_address_id) REFERENCES customer_addresses(id); END IF; END $$;"))

    required_columns = {
        "users": {"id", "name", "phone", "password_hash", "role"},
        "categories": {"id", "name"},
        "products": {"id", "name", "unit", "price", "stock_quantity", "category_id"},
        "orders": {"id", "user_id", "status", "total_amount", "created_at", "delivery_address_id", "scheduled_delivery_at", "delivery_slot"},
        "customer_addresses": {"id", "user_id", "label", "recipient_name", "phone", "address_line", "city", "pincode", "is_default", "created_at"},
        "notifications": {"id", "user_id", "title", "message", "order_id", "is_read", "created_at"},
        "order_items": {"id", "order_id", "product_id", "quantity", "price", "revenue", "cost_of_goods_sold", "profit"},
        "inventory": {"id", "product_id", "purchased_quantity", "purchase_cost_per_unit", "total_purchase_cost", "reserved_quantity", "remaining_quantity", "created_at"},
        "sales": {"id", "product_id", "quantity", "selling_price", "total_amount", "cost_of_goods_sold", "profit", "created_at"},
        "ml_model_artifacts": {"id", "model_key", "artifact_data", "metadata_json", "updated_at"},
    }
    inspector = inspect(engine)
    missing = []
    for table, columns in required_columns.items():
        if table not in tables:
            missing.append(f"missing table {table}")
            continue
        absent = columns - {column["name"] for column in inspector.get_columns(table)}
        if absent:
            missing.append(f"{table}: missing columns {', '.join(sorted(absent))}")

    if missing:
        raise RuntimeError(
            "Existing database schema is not recognized as the current Smart Vendor schema. "
            "No schema changes were made. Back up the database and review migrations first. "
            + "; ".join(missing)
        )

    # A full pg_dump from the current local application can lack Alembic's
    # version table. Mark it at head only after verifying all current tables
    # and columns; no user/business rows are changed.
    command.stamp(alembic_cfg, "head")
    print("Recognized restored current schema and recorded migration head; data was preserved.")


if __name__ == "__main__":
    main()
