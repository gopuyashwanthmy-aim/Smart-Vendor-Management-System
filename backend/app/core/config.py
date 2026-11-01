"""Environment-backed configuration for Smart Vendor."""
from __future__ import annotations

import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
except ImportError:
    pass

APP_ENV = os.getenv("APP_ENV", "development").strip().lower()

def _database_url() -> str:
    value = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg2://smart_vendor:smart_vendor_password@localhost:5432/smart_vendor",
    ).strip()
    if value.startswith("postgres://"):
        value = "postgresql+psycopg2://" + value[len("postgres://"): ]
    elif value.startswith("postgresql://"):
        value = "postgresql+psycopg2://" + value[len("postgresql://"): ]
    return value

DATABASE_URL = _database_url()
SECRET_KEY = os.getenv("SECRET_KEY", "smart-vendor-development-secret-key")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
SQLALCHEMY_ECHO = os.getenv("SQLALCHEMY_ECHO", "false").lower() == "true"
DB_POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "3"))
DB_MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "2"))

CORS_ORIGINS = [
    origin.strip().rstrip("/")
    for origin in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5000,http://localhost:8080,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:5000,http://127.0.0.1:8080,http://127.0.0.1:5173",
    ).split(",")
    if origin.strip()
]

# Synthetic training is an optional development-only tool. It is always off
# when APP_ENV=production, even if someone accidentally sets the flag true.
ENABLE_DEMO_AI = (
    os.getenv("ENABLE_DEMO_AI", "false").strip().lower() == "true"
    and APP_ENV != "production"
)

if APP_ENV == "production":
    if SECRET_KEY == "smart-vendor-development-secret-key" or len(SECRET_KEY) < 32:
        raise RuntimeError("Set a unique SECRET_KEY of at least 32 characters before production startup.")
    if not os.getenv("DATABASE_URL", "").strip():
        raise RuntimeError("DATABASE_URL must be set in production.")
    if not os.getenv("CORS_ORIGINS", "").strip():
        raise RuntimeError("Set CORS_ORIGINS to the deployed website origin in production.")

if len(SECRET_KEY) < 32:
    raise RuntimeError("SECRET_KEY must contain at least 32 characters.")
if ACCESS_TOKEN_EXPIRE_MINUTES < 5:
    raise RuntimeError("ACCESS_TOKEN_EXPIRE_MINUTES must be at least 5.")
