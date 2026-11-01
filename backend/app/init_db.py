"""Initialize a new database or safely recognize a restored current database."""
from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect

from app.core.database import engine
# Import all models so Alembic sees the complete metadata.
from app.models import category, inventory, order, order_item, product, sale, user, ml_model_artifact  # noqa: F401


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

    required_columns = {
        "users": {"id", "name", "phone", "password_hash", "role"},
        "categories": {"id", "name"},
        "products": {"id", "name", "unit", "price", "stock_quantity", "category_id"},
        "orders": {"id", "user_id", "status", "total_amount", "created_at"},
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
