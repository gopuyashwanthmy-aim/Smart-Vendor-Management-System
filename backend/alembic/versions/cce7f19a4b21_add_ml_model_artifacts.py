"""Persist trained ML model artifacts in PostgreSQL."""
from alembic import op
import sqlalchemy as sa

revision = "cce7f19a4b21"
down_revision = "bd31a3700465"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ml_model_artifacts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("model_key", sa.String(length=50), nullable=False),
        sa.Column("artifact_data", sa.LargeBinary(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_ml_model_artifacts_id", "ml_model_artifacts", ["id"], unique=False)
    op.create_index("ix_ml_model_artifacts_model_key", "ml_model_artifacts", ["model_key"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_ml_model_artifacts_model_key", table_name="ml_model_artifacts")
    op.drop_index("ix_ml_model_artifacts_id", table_name="ml_model_artifacts")
    op.drop_table("ml_model_artifacts")
