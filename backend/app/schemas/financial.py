from pydantic import BaseModel, Field


class FinancialSummaryResponse(BaseModel):
    start_date: str
    end_date: str

    online_revenue: float
    walk_in_revenue: float
    total_revenue: float

    online_cogs: float
    walk_in_cogs: float
    total_cogs: float

    gross_profit: float
    profit_margin: float

    online_transactions: int
    walk_in_transactions: int
    total_transactions: int