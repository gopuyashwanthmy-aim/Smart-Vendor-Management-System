from pydantic import BaseModel, Field, ConfigDict


class OrderItemRequest(BaseModel):
    product_id: int = Field(gt=0)
    quantity: float = Field(gt=0, le=10000)


class CreateOrderRequest(BaseModel):
    items: list[OrderItemRequest] = Field(min_length=1, max_length=100)


class UpdateOrderStatusRequest(BaseModel):
    new_status: str = Field(min_length=1, max_length=30)
