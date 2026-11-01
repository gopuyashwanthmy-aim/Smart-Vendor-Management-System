from io import BytesIO

import joblib
from sklearn.dummy import DummyRegressor
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.ml.forecasting import get_model_metadata, load_model, model_exists
from app.models.ml_model_artifact import MLModelArtifact
from app.models import category, inventory, order, order_item, product, sale, user  # noqa: F401


def test_model_artifact_can_be_loaded_from_database(monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    db = Session()
    try:
        estimator = DummyRegressor(strategy="constant", constant=4.0)
        estimator.fit([[0.0], [1.0]], [4.0, 4.0])
        payload = {
            "model": estimator,
            "model_name": "DummyRegressor",
            "data_source": "real",
            "trained_records": 2,
            "metrics": {"mae": 0.0},
            "product_ids": [1],
        }
        buffer = BytesIO()
        joblib.dump(payload, buffer)
        db.add(MLModelArtifact(
            model_key="real",
            artifact_data=buffer.getvalue(),
            metadata_json={"model_name": "DummyRegressor", "data_source": "real"},
        ))
        db.commit()

        assert model_exists("real", db=db) is True
        assert get_model_metadata("real", db=db)["model_name"] == "DummyRegressor"
        assert load_model("real", db=db).predict([[2.0]]).tolist() == [4.0]
    finally:
        db.close()
