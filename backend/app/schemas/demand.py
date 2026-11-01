from pydantic import BaseModel


class DemandHistoryItem(BaseModel):
    date: str
    product_id: int
    product_name: str
    online_quantity: float
    walk_in_quantity: float
    total_quantity: float


class DemandHistoryResponse(BaseModel):
    start_date: str
    end_date: str
    data: list[DemandHistoryItem]