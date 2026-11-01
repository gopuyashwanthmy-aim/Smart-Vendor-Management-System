from datetime import datetime

from sqlalchemy import DateTime, Integer, LargeBinary, String, JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class MLModelArtifact(Base):
    """Persist trained model bytes in PostgreSQL so free-host restarts do not erase them."""

    __tablename__ = "ml_model_artifacts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    model_key: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    artifact_data: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
