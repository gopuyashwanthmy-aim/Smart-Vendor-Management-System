"""Print non-sensitive table counts to verify a database restore."""
from sqlalchemy import inspect, text

from app.core.database import engine

TABLES = ("users", "categories", "products", "orders", "order_items", "inventory", "sales", "ml_model_artifacts")


def main() -> None:
    inspector = inspect(engine)
    available = set(inspector.get_table_names())
    with engine.connect() as connection:
        print("Smart Vendor database verification")
        for table in TABLES:
            if table not in available:
                print(f"{table}: MISSING")
                continue
            count = connection.execute(text(f'SELECT COUNT(*) FROM "{table}"')).scalar_one()
            print(f"{table}: {count}")
        if "users" in available:
            admin_count = connection.execute(text("SELECT COUNT(*) FROM users WHERE role = 'admin'")).scalar_one()
            customer_count = connection.execute(text("SELECT COUNT(*) FROM users WHERE role = 'customer'")).scalar_one()
            print(f"admin_accounts: {admin_count}")
            print(f"customer_accounts: {customer_count}")
    print("Verification complete. Compare these counts with the local source database before switching traffic.")


if __name__ == "__main__":
    main()
