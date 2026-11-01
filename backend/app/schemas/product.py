from pydantic import BaseModel, Field


class ProductCreateRequest(BaseModel):
    name: str = Field(
        min_length=1,
        max_length=100
    )

    unit: str = Field(
        min_length=1,
        max_length=20
    )

    price: float = Field(
        gt=0
    )

    stock_quantity: float = Field(
        default=0,
        ge=0
    )

    image_url: str | None = Field(
        default=None,
        max_length=500
    )

    category_id: int = Field(
        gt=0
    )


class ProductUpdateRequest(BaseModel):
    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=100
    )

    unit: str | None = Field(
        default=None,
        min_length=1,
        max_length=20
    )

    price: float | None = Field(
        default=None,
        gt=0
    )

    stock_quantity: float | None = Field(
        default=None,
        ge=0
    )

    image_url: str | None = Field(
        default=None,
        max_length=500
    )

    category_id: int | None = Field(
        default=None,
        gt=0
    )