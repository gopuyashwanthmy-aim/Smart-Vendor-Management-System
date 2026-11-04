from getpass import getpass

from pwdlib import PasswordHash

from app.core.config import DATABASE_URL
from app.core.database import SessionLocal
from app.models.user import User

# Safety guard: allow only the isolated local test database.
if "localhost:5433/smart_vendor_upgrade_test" not in DATABASE_URL:
    raise SystemExit(
        "SAFETY CHECK FAILED: This script only works with "
        "the isolated test database on localhost:5433."
    )

name = input("Admin name: ").strip()
phone = input("Admin phone number: ").strip()
password = getpass("Admin password: ")
confirm_password = getpass("Confirm password: ")

if not name or not phone or not password:
    raise SystemExit("All fields are required.")

if password != confirm_password:
    raise SystemExit("Passwords do not match.")

if len(password) < 8:
    raise SystemExit("Password must contain at least 8 characters.")

db = SessionLocal()

try:
    existing = db.query(User).filter(User.phone == phone).first()

    if existing:
        raise SystemExit(
            "This phone number already exists. No account was changed."
        )

    admin = User(
        name=name,
        phone=phone,
        password_hash=PasswordHash.recommended().hash(password),
        role="admin",
    )

    db.add(admin)
    db.commit()

    print("\nLocal test admin created successfully!")
    print(f"Name: {admin.name}")
    print(f"Phone: {admin.phone}")
    print(f"Role: {admin.role}")

except Exception:
    db.rollback()
    raise

finally:
    db.close()