from pydantic import BaseModel, Field


class CreateSaleRequest(BaseModel):
    product_id: int = Field(gt=0)
    quantity: float = Field(gt=0, le=10000)
    selling_price: float = Field(gt=0, le=10000000)
