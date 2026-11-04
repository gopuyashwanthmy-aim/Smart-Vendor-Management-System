from datetime import datetime
from sqlalchemy import String, Float, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base
from app.models.address import Address  # register the referenced table in shared metadata

class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="PLACED", nullable=False)
    total_amount: Mapped[float] = mapped_column(Float, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    delivery_address_id: Mapped[int | None] = mapped_column(ForeignKey("customer_addresses.id", ondelete="SET NULL"), nullable=True)
    scheduled_delivery_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    delivery_slot: Mapped[str | None] = mapped_column(String(60), nullable=True)
