import sys
from pathlib import Path
from datetime import date, timedelta

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.ml.dataset import build_features


def test_feature_builder_creates_lags_and_rolling_features():
    start = date(2026, 1, 1)
    rows = []
    for index in range(20):
        current = start + timedelta(days=index)
        rows.append({
            "date": current.isoformat(),
            "product_id": 1,
            "product_name": "Tomato",
            "online_quantity": 0,
            "walk_in_quantity": index + 1,
            "total_quantity": index + 1,
        })

    features = build_features(rows)
    day_15 = next(row for row in features if row["date"] == (start + timedelta(days=14)).isoformat())
    assert day_15["lag_1"] == 14
    assert day_15["lag_7"] == 8
    assert day_15["lag_14"] == 1
    assert day_15["rolling_7"] == 11


def test_purchase_plan_counts_total_stock_and_safety_buffer():
    from app.ml.purchase_planner import calculate_purchase_recommendation

    result = calculate_purchase_recommendation(
        confirmed_order_quantity=8,
        predicted_demand=10,
        available_inventory=12,
        unit="kg",
        safety_buffer_percent=10,
    )
    assert result["expected_demand"] == 18
    assert result["safety_stock"] == 1
    assert result["recommended_purchase_quantity"] == 7.0
