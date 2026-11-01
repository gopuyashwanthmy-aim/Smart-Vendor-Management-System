from __future__ import annotations


def get_purchase_unit_precision(unit: str) -> int:
    """
    Decide how many decimal places should be used
    when recommending purchase quantities.
    """

    normalized = unit.strip().lower()

    if normalized in {
        "piece",
        "pieces",
        "bunch",
        "bunches",
        "dozen",
        "dozens",
    }:
        return 0

    # Weight-based products can use decimals.
    if normalized in {
        "kg",
        "kilogram",
        "kilograms",
    }:
        return 2

    return 2


def round_purchase_quantity(
    quantity: float,
    unit: str,
) -> float:

    quantity = max(
        0.0,
        float(quantity),
    )

    precision = get_purchase_unit_precision(
        unit
    )

    rounded = round(
        quantity,
        precision,
    )

    # For count-based products, never recommend 0
    # when there is a positive requirement.
    if (
        precision == 0
        and quantity > 0
        and rounded == 0
    ):
        rounded = 1

    return float(rounded)


def calculate_purchase_recommendation(
    confirmed_order_quantity: float,
    predicted_demand: float,
    available_inventory: float,
    unit: str,
    safety_buffer_percent: float = 10.0,
) -> dict:

    confirmed_order_quantity = max(
        0.0,
        float(confirmed_order_quantity),
    )

    predicted_demand = max(
        0.0,
        float(predicted_demand),
    )

    available_inventory = max(
        0.0,
        float(available_inventory),
    )

    safety_buffer_percent = max(
        0.0,
        float(safety_buffer_percent),
    )

    # -----------------------------------------------------
    # Expected demand
    # -----------------------------------------------------

    expected_demand = (
        confirmed_order_quantity
        + predicted_demand
    )

    # -----------------------------------------------------
    # Safety stock
    # -----------------------------------------------------

    safety_stock = (
        predicted_demand
        * safety_buffer_percent
        / 100.0
    )

    # -----------------------------------------------------
    # Required stock after safety buffer
    # -----------------------------------------------------

    target_stock = (
        expected_demand
        + safety_stock
    )

    # -----------------------------------------------------
    # Purchase requirement
    # -----------------------------------------------------

    raw_purchase_quantity = max(
        0.0,
        target_stock
        - available_inventory,
    )

    recommended_purchase = (
        round_purchase_quantity(
            raw_purchase_quantity,
            unit,
        )
    )

    # -----------------------------------------------------
    # Recommendation level
    # -----------------------------------------------------

    if recommended_purchase <= 0:

        recommendation = (
            "NO_PURCHASE"
        )

        recommendation_label = (
            "No additional purchase required"
        )

    elif (
        recommended_purchase
        >= expected_demand * 0.75
    ):

        recommendation = (
            "HIGH_PURCHASE"
        )

        recommendation_label = (
            "High purchase requirement"
        )

    elif (
        recommended_purchase
        >= expected_demand * 0.35
    ):

        recommendation = (
            "MEDIUM_PURCHASE"
        )

        recommendation_label = (
            "Moderate purchase requirement"
        )

    else:

        recommendation = (
            "LOW_PURCHASE"
        )

        recommendation_label = (
            "Small additional purchase"
        )

    return {
        "confirmed_order_quantity":
            round(
                confirmed_order_quantity,
                2,
            ),

        "predicted_demand":
            round(
                predicted_demand,
                2,
            ),

        "expected_demand":
            round(
                expected_demand,
                2,
            ),

        "safety_buffer_percent":
            round(
                safety_buffer_percent,
                2,
            ),

        "safety_stock":
            round(
                safety_stock,
                2,
            ),

        "target_stock":
            round(
                target_stock,
                2,
            ),

        "available_inventory":
            round(
                available_inventory,
                2,
            ),

        "recommended_purchase_quantity":
            recommended_purchase,

        "recommendation":
            recommendation,

        "recommendation_label":
            recommendation_label,
    }