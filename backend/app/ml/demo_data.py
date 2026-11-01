from __future__ import annotations

from datetime import date, timedelta
from typing import Any

import numpy as np


def generate_demo_demand(
    products: list[dict[str, Any]],
    days: int = 120,
) -> list[dict[str, Any]]:
    """
    Generate deterministic synthetic demand data for demonstration.

    IMPORTANT:
    The generated history ends TODAY.
    Therefore predict_next_day() forecasts TOMORROW.
    """

    if not products:
        return []

    if days < 30:
        raise ValueError(
            "Demo demand generation requires at least 30 days."
        )

    today = date.today()

    # Historical data ends today so that the next forecast
    # represents tomorrow's expected demand.
    last_historical_date = today

    start_date = (
        last_historical_date
        - timedelta(days=days - 1)
    )

    # Base demand used only for demonstration.
    base_demand = {
        "tomato": 24.0,
        "onion": 20.0,
        "potato": 17.0,
        "carrot": 13.0,
        "cabbage": 10.0,
        "spinach": 22.0,
        "banana": 11.0,
        "apple": 10.0,
        "orange": 8.0,
        "rose": 7.0,
        "jasmine": 6.0,
    }

    result: list[dict[str, Any]] = []

    # Deterministic random generator.
    # Same data is produced each time for reproducibility.
    rng = np.random.default_rng(42)

    for product in products:

        product_id = int(
            product["id"]
        )

        product_name = str(
            product["name"]
        )

        unit = str(
            product.get(
                "unit",
                "",
            )
        )

        normalized_name = (
            product_name.strip().lower()
        )

        base = base_demand.get(
            normalized_name,
            10.0,
        )

        current_date = start_date

        while current_date <= last_historical_date:

            day_index = (
                current_date - start_date
            ).days

            day_of_week = (
                current_date.weekday()
            )

            # Weekend demand tends to be slightly higher.
            weekend_multiplier = (
                1.15
                if day_of_week >= 5
                else 1.0
            )

            # Small upward trend over time.
            trend_multiplier = (
                1.0
                + (day_index / max(days - 1, 1))
                * 0.08
            )

            # Seasonal component.
            seasonal_multiplier = (
                1.0
                + 0.08
                * np.sin(
                    2
                    * np.pi
                    * day_index
                    / 30.0
                )
            )

            # Controlled random variation.
            noise = rng.normal(
                loc=0.0,
                scale=max(
                    base * 0.08,
                    0.5,
                ),
            )

            demand = (
                base
                * weekend_multiplier
                * trend_multiplier
                * seasonal_multiplier
                + noise
            )

            demand = max(
                0.0,
                demand,
            )

            demand = round(
                float(demand),
                2,
            )

            # Split total demand between online and walk-in
            # purely for demonstration.
            online_ratio = (
                0.55
                + 0.05
                * np.sin(
                    day_index
                    / 10.0
                )
            )

            online_ratio = min(
                0.70,
                max(
                    0.40,
                    online_ratio,
                ),
            )

            online_quantity = round(
                demand * online_ratio,
                2,
            )

            walk_in_quantity = round(
                demand - online_quantity,
                2,
            )

            result.append(
                {
                    "date": current_date.isoformat(),
                    "product_id": product_id,
                    "product_name": product_name,
                    "unit": unit,
                    "online_quantity": online_quantity,
                    "walk_in_quantity": walk_in_quantity,
                    "total_quantity": demand,
                }
            )

            current_date += timedelta(
                days=1
            )

    result.sort(
        key=lambda row: (
            row["product_id"],
            row["date"],
        )
    )

    return result