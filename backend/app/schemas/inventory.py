from pydantic import BaseModel, Field


class CreateInventoryRequest(BaseModel):
    product_id: int = Field(gt=0)

    purchased_quantity: float = Field(
        gt=0
    )

    purchase_cost_per_unit: float = Field(
        gt=0
    )

    reserved_quantity: float = Field(
        ge=0
    )