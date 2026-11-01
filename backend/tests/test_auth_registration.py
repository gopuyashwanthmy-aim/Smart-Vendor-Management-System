import pytest
pytest.importorskip("pwdlib")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.auth import router as auth_router
from app.core.database import Base, get_db
from app.models import category, inventory, ml_model_artifact, order, order_item, product, sale, user  # noqa: F401


engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)
app = FastAPI()
app.include_router(auth_router)


def override_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_db
client = TestClient(app)


def test_public_registration_always_creates_customer():
    response = client.post("/auth/register", json={
        "name": "Test Customer",
        "phone": "9000000001",
        "password": "test-password-123",
        "role": "admin",
    })
    assert response.status_code == 201
    assert response.json()["role"] == "customer"


def test_duplicate_phone_registration_is_rejected():
    payload = {"name": "Test Customer", "phone": "9000000002", "password": "test-password-123"}
    assert client.post("/auth/register", json=payload).status_code == 201
    duplicate = client.post("/auth/register", json=payload)
    assert duplicate.status_code == 400


def test_registered_customer_can_login():
    payload = {"name": "Test Customer", "phone": "9000000003", "password": "test-password-123"}
    assert client.post("/auth/register", json=payload).status_code == 201
    login = client.post("/auth/login", json={"phone": payload["phone"], "password": payload["password"]})
    assert login.status_code == 200
    assert login.json()["user"]["role"] == "customer"
    assert login.json()["access_token"]
