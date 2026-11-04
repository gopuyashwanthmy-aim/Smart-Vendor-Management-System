"""Add customer addresses, scheduled delivery and in-app notifications.

Revision ID: f47a91c2d801
Revises: cce7f19a4b21
"""
from alembic import op
import sqlalchemy as sa

revision = "f47a91c2d801"
down_revision = "cce7f19a4b21"
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        "customer_addresses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.String(40), nullable=False, server_default="Home"),
        sa.Column("recipient_name", sa.String(100), nullable=False),
        sa.Column("phone", sa.String(20), nullable=False),
        sa.Column("address_line", sa.String(300), nullable=False),
        sa.Column("landmark", sa.String(200), nullable=True),
        sa.Column("city", sa.String(100), nullable=False),
        sa.Column("pincode", sa.String(12), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_customer_addresses_user_id", "customer_addresses", ["user_id"])
    with op.batch_alter_table("orders") as batch:
        batch.add_column(sa.Column("delivery_address_id", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("scheduled_delivery_at", sa.DateTime(), nullable=True))
        batch.add_column(sa.Column("delivery_slot", sa.String(length=60), nullable=True))
        batch.create_foreign_key("fk_orders_delivery_address", "customer_addresses", ["delivery_address_id"], ["id"], ondelete="SET NULL")
    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(140), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="SET NULL"), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])

def downgrade():
    op.drop_index("ix_notifications_user_id", table_name="notifications")
    op.drop_table("notifications")
    op.drop_index("ix_customer_addresses_user_id", table_name="customer_addresses")
    op.drop_table("customer_addresses")
    with op.batch_alter_table("orders") as batch:
        batch.drop_constraint("fk_orders_delivery_address", type_="foreignkey")
        batch.drop_column("delivery_slot")
        batch.drop_column("scheduled_delivery_at")
        batch.drop_column("delivery_address_id")
