from datetime import datetime
from pydantic import BaseModel, Field

class OrderItemRequest(BaseModel):
    product_id: int = Field(gt=0)
    quantity: float = Field(gt=0, le=10000)

class CreateOrderRequest(BaseModel):
    items: list[OrderItemRequest] = Field(min_length=1, max_length=100)
    delivery_address_id: int | None = Field(default=None, gt=0)
    scheduled_delivery_at: datetime | None = None
    delivery_slot: str | None = Field(default=None, max_length=60)

class UpdateOrderStatusRequest(BaseModel):
    new_status: str = Field(min_length=1, max_length=30)
