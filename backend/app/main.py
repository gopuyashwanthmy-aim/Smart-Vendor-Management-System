from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.auth import router as auth_router
from app.api.categories import router as category_router
from app.api.customer import router as customer_router
from app.api.products import router as product_router
from app.api.orders import router as order_router
from app.api.admin import router as admin_router
from app.api.inventory import router as inventory_router
from app.api.sales import router as sales_router
from app.api.ai_management import router as ai_management_router
from app.api import financial, demand
from app.api.ai_market_plan import router as ai_market_plan_router
from app.api.ai_insights import router as ai_insights_router
from app.core.config import APP_ENV, CORS_ORIGINS, ENABLE_DEMO_AI
from app.core.database import engine

app = FastAPI(
    title="Smart Vendor API",
    description="Customer ordering and vendor operations platform",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_origin_regex=(r"http://(localhost|127\.0\.0\.1)(:\d+)?" if APP_ENV != "production" else None),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

app.include_router(product_router)
app.include_router(category_router)
app.include_router(customer_router)
app.include_router(auth_router)
app.include_router(order_router)
app.include_router(admin_router)
app.include_router(inventory_router)
app.include_router(sales_router)
app.include_router(financial.router)
app.include_router(demand.router)
app.include_router(ai_insights_router)
app.include_router(ai_market_plan_router)
app.include_router(ai_management_router)

if ENABLE_DEMO_AI:
    from app.api.ai_demo import router as ai_demo_router
    app.include_router(ai_demo_router)


@app.get("/")
def root():
    return {"message": "Smart Vendor API is running", "status": "success", "environment": APP_ENV}


@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "smart-vendor-api"}


@app.get("/health/ready")
def readiness_check():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return {"status": "ready", "database": "connected"}
    except Exception:
        raise HTTPException(status_code=503, detail="Database is unavailable")
