"""Create or promote an admin account from a trusted terminal session."""
from getpass import getpass

from pwdlib import PasswordHash

from app.core.database import SessionLocal
from app.models.user import User


def main() -> None:
    print("Smart Vendor admin bootstrap (run only on your own database)")
    name = input("Admin name: ").strip()
    phone = input("Admin phone: ").strip()
    password = getpass("Admin password (minimum 8 characters): ")
    confirm = getpass("Confirm password: ")
    if len(name) < 2 or len(phone) < 10 or len(password) < 8 or password != confirm:
        raise SystemExit("Invalid input or passwords do not match.")

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.phone == phone).first()
        hashed = PasswordHash.recommended().hash(password)
        if user is None:
            user = User(name=name, phone=phone, password_hash=hashed, role="admin")
            db.add(user)
        else:
            user.name = name
            user.password_hash = hashed
            user.role = "admin"
        db.commit()
        print(f"Admin account ready for phone {phone}.")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
