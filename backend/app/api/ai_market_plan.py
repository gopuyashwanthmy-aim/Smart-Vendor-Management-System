from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin
from app.services.ai_planning import build_production_planning_data

router = APIRouter(prefix="/admin/ai", tags=["AI Market Plan"])


@router.get("/market-plan")
def get_ai_market_plan(
    db: Session = Depends(get_db),
    current_admin=Depends(get_current_admin),
):
    """Return real-model recommendations or an order-based fallback.

    Synthetic demonstration demand is never used by this endpoint.
    """
    return build_production_planning_data(db)
