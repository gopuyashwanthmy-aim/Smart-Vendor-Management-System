"""add financial transaction fields

Revision ID: bd31a3700465
Revises: daae7ae42592
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "bd31a3700465"
down_revision: Union[str, Sequence[str], None] = "daae7ae42592"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # -----------------------------
    # ORDER ITEMS
    # -----------------------------

    op.add_column(
        "order_items",
        sa.Column(
            "revenue",
            sa.Float(),
            nullable=True,
        ),
    )

    op.add_column(
        "order_items",
        sa.Column(
            "cost_of_goods_sold",
            sa.Float(),
            nullable=True,
        ),
    )

    op.add_column(
        "order_items",
        sa.Column(
            "profit",
            sa.Float(),
            nullable=True,
        ),
    )

    # -----------------------------
    # WALK-IN SALES
    # -----------------------------

    op.add_column(
        "sales",
        sa.Column(
            "cost_of_goods_sold",
            sa.Float(),
            nullable=True,
        ),
    )

    op.add_column(
        "sales",
        sa.Column(
            "profit",
            sa.Float(),
            nullable=True,
        ),
    )

    # -----------------------------
    # EXISTING ORDER ITEMS
    # -----------------------------

    op.execute(
        """
        UPDATE order_items
        SET revenue = quantity * price
        WHERE revenue IS NULL
        """
    )

    op.execute(
        """
        UPDATE order_items
        SET cost_of_goods_sold = 0
        WHERE cost_of_goods_sold IS NULL
        """
    )

    op.execute(
        """
        UPDATE order_items
        SET profit = revenue - cost_of_goods_sold
        WHERE profit IS NULL
        """
    )

    # -----------------------------
    # EXISTING SALES
    # -----------------------------

    op.execute(
        """
        UPDATE sales
        SET cost_of_goods_sold = 0
        WHERE cost_of_goods_sold IS NULL
        """
    )

    op.execute(
        """
        UPDATE sales
        SET profit = total_amount - cost_of_goods_sold
        WHERE profit IS NULL
        """
    )

    # -----------------------------
    # MAKE FINANCIAL FIELDS REQUIRED
    # -----------------------------

    with op.batch_alter_table("order_items") as batch_op:
        batch_op.alter_column("revenue", existing_type=sa.Float(), nullable=False)
        batch_op.alter_column("cost_of_goods_sold", existing_type=sa.Float(), nullable=False)
        batch_op.alter_column("profit", existing_type=sa.Float(), nullable=False)

    with op.batch_alter_table("sales") as batch_op:
        batch_op.alter_column("cost_of_goods_sold", existing_type=sa.Float(), nullable=False)
        batch_op.alter_column("profit", existing_type=sa.Float(), nullable=False)


def downgrade() -> None:
    op.drop_column(
        "sales",
        "profit",
    )

    op.drop_column(
        "sales",
        "cost_of_goods_sold",
    )

    op.drop_column(
        "order_items",
        "profit",
    )

    op.drop_column(
        "order_items",
        "cost_of_goods_sold",
    )

    op.drop_column(
        "order_items",
        "revenue",
    )