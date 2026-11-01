from __future__ import annotations

from datetime import date, timedelta
from typing import Any


def build_features(
    demand_data: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """
    Convert daily demand history into ML-ready features.

    Expected input:
        [
            {
                "date": "2026-09-01",
                "product_id": 1,
                "product_name": "Tomato",
                "online_quantity": 2,
                "walk_in_quantity": 5,
                "total_quantity": 7
            },
            ...
        ]

    Output contains:
        - calendar features
        - lag features
        - rolling demand features
    """

    if not demand_data:
        return []

    # ---------------------------------------------------------
    # Group data by product
    # ---------------------------------------------------------

    products: dict[int, list[dict[str, Any]]] = {}

    for row in demand_data:
        product_id = int(row["product_id"])

        products.setdefault(product_id, []).append(row)

    result: list[dict[str, Any]] = []

    # ---------------------------------------------------------
    # Build features product by product
    # ---------------------------------------------------------

    for product_id, rows in products.items():

        rows.sort(key=lambda x: x["date"])

        # Convert demand into date -> quantity mapping
        demand_by_date: dict[date, float] = {}

        product_name = ""

        for row in rows:
            current_date = date.fromisoformat(row["date"])

            demand_by_date[current_date] = float(
                row.get("total_quantity", 0)
            )

            product_name = row.get(
                "product_name",
                "",
            )

        if not demand_by_date:
            continue

        first_date = min(demand_by_date.keys())
        last_date = max(demand_by_date.keys())

        # -----------------------------------------------------
        # Fill missing dates with zero demand
        # -----------------------------------------------------

        current_date = first_date

        while current_date <= last_date:

            demand_by_date.setdefault(
                current_date,
                0.0,
            )

            current_date += timedelta(days=1)

        # -----------------------------------------------------
        # Generate features
        # -----------------------------------------------------

        sorted_dates = sorted(demand_by_date.keys())

        for current_date in sorted_dates:

            current_demand = demand_by_date[current_date]

            lag_1_date = current_date - timedelta(days=1)
            lag_7_date = current_date - timedelta(days=7)
            lag_14_date = current_date - timedelta(days=14)

            lag_1 = demand_by_date.get(
                lag_1_date,
                0.0,
            )

            lag_7 = demand_by_date.get(
                lag_7_date,
                0.0,
            )

            lag_14 = demand_by_date.get(
                lag_14_date,
                0.0,
            )

            # -------------------------------------------------
            # Rolling averages
            # -------------------------------------------------

            previous_7_days = [
                demand_by_date.get(
                    current_date - timedelta(days=i),
                    0.0,
                )
                for i in range(1, 8)
            ]

            previous_14_days = [
                demand_by_date.get(
                    current_date - timedelta(days=i),
                    0.0,
                )
                for i in range(1, 15)
            ]

            rolling_7 = (
                sum(previous_7_days) / len(previous_7_days)
            )

            rolling_14 = (
                sum(previous_14_days) / len(previous_14_days)
            )

            # -------------------------------------------------
            # Calendar features
            # -------------------------------------------------

            day_of_week = current_date.weekday()

            day_of_month = current_date.day

            month = current_date.month

            is_weekend = (
                1
                if day_of_week >= 5
                else 0
            )

            result.append(
                {
                    "date": current_date.isoformat(),
                    "product_id": product_id,
                    "product_name": product_name,

                    # Target
                    "demand": round(
                        current_demand,
                        2,
                    ),

                    # Calendar
                    "day_of_week": day_of_week,
                    "day_of_month": day_of_month,
                    "month": month,
                    "is_weekend": is_weekend,

                    # Lag features
                    "lag_1": round(
                        lag_1,
                        2,
                    ),
                    "lag_7": round(
                        lag_7,
                        2,
                    ),
                    "lag_14": round(
                        lag_14,
                        2,
                    ),

                    # Rolling features
                    "rolling_7": round(
                        rolling_7,
                        2,
                    ),
                    "rolling_14": round(
                        rolling_14,
                        2,
                    ),
                }
            )

    result.sort(
        key=lambda x: (
            x["product_id"],
            x["date"],
        )
    )

    return result