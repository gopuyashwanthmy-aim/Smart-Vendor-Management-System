from datetime import datetime

from sqlalchemy import Float, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Sale(Base):
    __tablename__ = "sales"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True
    )

    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id"),
        nullable=False
    )

    quantity: Mapped[float] = mapped_column(
        Float,
        nullable=False
    )

    selling_price: Mapped[float] = mapped_column(
        Float,
        nullable=False
    )

    total_amount: Mapped[float] = mapped_column(
        Float,
        nullable=False
    )

    # Financial fields
    cost_of_goods_sold: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    profit: Mapped[float] = mapped_column(
        Float,
        default=0
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow
    )