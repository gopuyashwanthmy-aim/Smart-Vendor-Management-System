from sqlalchemy.orm import Session

from app.models.inventory import Inventory


def calculate_fifo_cost(
    db: Session,
    product_id: int,
    quantity: float,
    include_reserved: bool = False
) -> float:
    """
    Calculate COGS using FIFO inventory batches.

    This function also consumes the stock from inventory.

    For walk-in sales:
        include_reserved=False

    For delivered online orders:
        include_reserved=True
    """

    if quantity <= 0:
        return 0.0

    remaining_to_consume = quantity
    total_cost = 0.0

    inventory_batches = (
        db.query(Inventory)
        .filter(
            Inventory.product_id == product_id
        )
        .order_by(
            Inventory.created_at.asc(),
            Inventory.id.asc()
        )
        .with_for_update()
        .all()
    )

    total_available = 0.0
    for batch in inventory_batches:
        batch_available = float(batch.remaining_quantity or 0)
        if include_reserved:
            batch_available += float(batch.reserved_quantity or 0)
        total_available += max(0.0, batch_available)

    # Validate the complete quantity before mutating any batch. This keeps
    # the service safe even when a caller forgets to roll back its session.
    if total_available + 1e-9 < quantity:
        shortage = quantity - total_available
        raise ValueError(
            f"Insufficient inventory for product {product_id}. "
            f"Required: {quantity}, shortage: {shortage}"
        )

    for batch in inventory_batches:

        if remaining_to_consume <= 0:
            break

        if include_reserved:
            available_quantity = (
                float(batch.reserved_quantity or 0)
                + float(batch.remaining_quantity or 0)
            )
        else:
            available_quantity = float(
                batch.remaining_quantity or 0
            )

        if available_quantity <= 0:
            continue

        quantity_from_batch = min(
            remaining_to_consume,
            available_quantity
        )

        cost_per_unit = float(
            batch.purchase_cost_per_unit or 0
        )

        total_cost += (
            quantity_from_batch * cost_per_unit
        )

        reserved_available = float(
            batch.reserved_quantity or 0
        )

        if include_reserved and reserved_available > 0:

            reserved_used = min(
                quantity_from_batch,
                reserved_available
            )

            batch.reserved_quantity -= reserved_used

            remaining_after_reserved = (
                quantity_from_batch - reserved_used
            )

            if remaining_after_reserved > 0:
                batch.remaining_quantity -= (
                    remaining_after_reserved
                )

        else:
            batch.remaining_quantity -= (
                quantity_from_batch
            )

        remaining_to_consume -= quantity_from_batch

    if remaining_to_consume > 0:
        raise ValueError(
            f"Insufficient inventory for product "
            f"{product_id}. Required: {quantity}, "
            f"shortage: {remaining_to_consume}"
        )

    return round(total_cost, 2)