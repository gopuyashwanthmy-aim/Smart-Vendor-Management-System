from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin
from app.models.product import Product

from app.ml.demo_data import generate_demo_demand
from app.ml.forecasting import train_model


router = APIRouter(
    prefix="/admin/ai",
    tags=["AI Demo"],
)


@router.post("/train-demo")
def train_demo_model(
    db: Session = Depends(get_db),
    current_admin=Depends(get_current_admin),
):
    """
    Train the AI demand forecasting model using
    synthetic demonstration data.

    This endpoint DOES NOT modify business data.
    """

    products = (
        db.query(Product)
        .order_by(Product.id.asc())
        .all()
    )

    if not products:
        raise HTTPException(
            status_code=400,
            detail="No products available for demo training.",
        )

    product_data = [
        {
            "id": product.id,
            "name": product.name,
            "unit": product.unit,
        }
        for product in products
    ]

    # Generate 120 days of synthetic demand.
    # The data ends TODAY, allowing tomorrow's forecast.
    demo_data = generate_demo_demand(
        product_data,
        days=120,
    )

    if not demo_data:
        raise HTTPException(
            status_code=400,
            detail="Unable to generate demo demand data.",
        )

    training_result = train_model(
        demo_data,
        data_source="synthetic_demo_data",
    )

    return {
        "status": "success",
        "data_source": "synthetic_demo_data",
        "warning": (
            "This model was trained using synthetic "
            "development data. Do not use its evaluation "
            "metrics as real-world business accuracy."
        ),
        "products": len(products),
        "historical_days": 120,
        "generated_records": len(demo_data),
        "training_result": training_result,
    }