"""add purchase cost to inventory

Revision ID: daae7ae42592
Revises: 885c9e7a379c
Create Date: 2026-09-12
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "daae7ae42592"
down_revision: Union[str, Sequence[str], None] = "885c9e7a379c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add the columns as nullable first so existing
    # inventory records can receive a value.
    op.add_column(
        "inventory",
        sa.Column(
            "purchase_cost_per_unit",
            sa.Float(),
            nullable=True,
        ),
    )

    op.add_column(
        "inventory",
        sa.Column(
            "total_purchase_cost",
            sa.Float(),
            nullable=True,
        ),
    )

    # Existing inventory records have no historical
    # purchase-cost information, so initialize them to 0.
    op.execute(
        """
        UPDATE inventory
        SET purchase_cost_per_unit = 0
        WHERE purchase_cost_per_unit IS NULL
        """
    )

    op.execute(
        """
        UPDATE inventory
        SET total_purchase_cost = 0
        WHERE total_purchase_cost IS NULL
        """
    )

    # Batch alteration is compatible with SQLite test databases and
    # emits ordinary ALTER COLUMN operations on PostgreSQL.
    with op.batch_alter_table("inventory") as batch_op:
        batch_op.alter_column(
            "purchase_cost_per_unit",
            existing_type=sa.Float(),
            nullable=False,
        )
        batch_op.alter_column(
            "total_purchase_cost",
            existing_type=sa.Float(),
            nullable=False,
        )


def downgrade() -> None:
    op.drop_column(
        "inventory",
        "total_purchase_cost",
    )

    op.drop_column(
        "inventory",
        "purchase_cost_per_unit",
    )