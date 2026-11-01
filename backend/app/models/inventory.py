from datetime import datetime

from sqlalchemy import Float, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Inventory(Base):
    __tablename__ = "inventory"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True
    )

    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id"),
        nullable=False
    )

    purchased_quantity: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    purchase_cost_per_unit: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    total_purchase_cost: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    reserved_quantity: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    remaining_quantity: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow
    )