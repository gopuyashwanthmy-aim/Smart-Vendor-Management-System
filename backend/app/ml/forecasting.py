from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from io import BytesIO
from typing import Any

import joblib
from sqlalchemy.orm import Session

from app.core.config import APP_ENV
import numpy as np

from sklearn.ensemble import (
    GradientBoostingRegressor,
    RandomForestRegressor,
)
from sklearn.metrics import (
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)

from app.ml.dataset import build_features


MODEL_DIR = Path(__file__).resolve().parent / "models"

# Real production model
MODEL_PATH = MODEL_DIR / "demand_forecast_model.joblib"

# Synthetic demo model
DEMO_MODEL_PATH = MODEL_DIR / "demand_forecast_demo.joblib"


FEATURE_COLUMNS = [
    "product_id",
    "day_of_week",
    "day_of_month",
    "month",
    "is_weekend",
    "lag_1",
    "lag_7",
    "lag_14",
    "rolling_7",
    "rolling_14",
]


def _get_model_path(data_source: str) -> Path:
    normalized_source = data_source.strip().lower()

    if normalized_source in {
        "synthetic_demo_data",
        "demo",
        "synthetic",
    }:
        return DEMO_MODEL_PATH

    return MODEL_PATH


def _prepare_features(
    demand_data: list[dict[str, Any]],
):
    features = build_features(demand_data)

    if len(features) < 10:
        raise ValueError(
            "Not enough historical data to train the model. "
            "At least 10 feature records are required."
        )

    return features


def _time_series_split(features):
    """
    Chronological train/test split separately for each product.
    """

    products: dict[int, list[dict[str, Any]]] = {}

    for row in features:
        product_id = int(row["product_id"])
        products.setdefault(product_id, []).append(row)

    train_features = []
    test_features = []

    for product_id, rows in products.items():
        rows.sort(key=lambda row: row["date"])

        if len(rows) < 10:
            train_features.extend(rows)
            continue

        split_index = int(len(rows) * 0.80)

        split_index = max(
            1,
            min(
                split_index,
                len(rows) - 1,
            ),
        )

        train_features.extend(rows[:split_index])
        test_features.extend(rows[split_index:])

    if len(train_features) < 5:
        raise ValueError(
            "Not enough data for model training."
        )

    if len(test_features) < 2:
        raise ValueError(
            "Not enough data for model evaluation."
        )

    return train_features, test_features


def _to_xy(features):
    X = np.array(
        [
            [
                float(row[column])
                for column in FEATURE_COLUMNS
            ]
            for row in features
        ],
        dtype=float,
    )

    y = np.array(
        [
            float(row["demand"])
            for row in features
        ],
        dtype=float,
    )

    return X, y


def _evaluate_model(
    model,
    X_test,
    y_test,
):
    predictions = model.predict(X_test)

    mae = mean_absolute_error(
        y_test,
        predictions,
    )

    rmse = float(
        np.sqrt(
            mean_squared_error(
                y_test,
                predictions,
            )
        )
    )

    # R2 can be undefined when all test values are identical.
    if len(set(y_test.tolist())) < 2:
        r2 = 0.0
    else:
        r2 = r2_score(
            y_test,
            predictions,
        )

    return {
        "mae": round(float(mae), 3),
        "rmse": round(float(rmse), 3),
        "r2": round(float(r2), 3),
    }


def _baseline_predictions(
    test_features,
):
    """
    Simple rolling 7-day average baseline.
    """

    predictions = []

    for row in test_features:
        prediction = float(
            row.get(
                "rolling_7",
                0.0,
            )
        )

        predictions.append(
            max(
                0.0,
                prediction,
            )
        )

    return np.array(
        predictions,
        dtype=float,
    )


def _evaluate_baseline(
    test_features,
    y_test,
):
    predictions = _baseline_predictions(
        test_features
    )

    mae = mean_absolute_error(
        y_test,
        predictions,
    )

    rmse = float(
        np.sqrt(
            mean_squared_error(
                y_test,
                predictions,
            )
        )
    )

    if len(set(y_test.tolist())) < 2:
        r2 = 0.0
    else:
        r2 = r2_score(
            y_test,
            predictions,
        )

    return {
        "mae": round(float(mae), 3),
        "rmse": round(float(rmse), 3),
        "r2": round(float(r2), 3),
    }


def train_model(
    demand_data: list[dict[str, Any]],
    data_source: str = "real",
    training_metadata: dict[str, Any] | None = None,
    db: Session | None = None,
):
    """
    Train and evaluate demand forecasting models.

    Models:
    - Rolling 7-day average baseline
    - Random Forest
    - Gradient Boosting

    The ML model with the lowest MAE is selected.

    training_metadata can contain:
    - start_date
    - end_date
    - historical_days
    - products_with_history
    - transaction_days
    """

    model_path = _get_model_path(
        data_source
    )

    features = _prepare_features(
        demand_data
    )

    train_features, test_features = (
        _time_series_split(features)
    )

    X_train, y_train = _to_xy(
        train_features
    )

    X_test, y_test = _to_xy(
        test_features
    )

    # =========================================================
    # BASELINE
    # =========================================================

    baseline_metrics = _evaluate_baseline(
        test_features,
        y_test,
    )

    # =========================================================
    # RANDOM FOREST
    # =========================================================

    random_forest = RandomForestRegressor(
        n_estimators=300,
        max_depth=14,
        min_samples_leaf=2,
        random_state=42,
        n_jobs=-1,
    )

    random_forest.fit(
        X_train,
        y_train,
    )

    random_forest_metrics = _evaluate_model(
        random_forest,
        X_test,
        y_test,
    )

    # =========================================================
    # GRADIENT BOOSTING
    # =========================================================

    gradient_boosting = GradientBoostingRegressor(
        n_estimators=200,
        learning_rate=0.05,
        max_depth=4,
        min_samples_leaf=2,
        random_state=42,
        loss="squared_error",
    )

    gradient_boosting.fit(
        X_train,
        y_train,
    )

    gradient_boosting_metrics = _evaluate_model(
        gradient_boosting,
        X_test,
        y_test,
    )

    # =========================================================
    # MODEL COMPARISON
    # =========================================================

    model_results = {
        "Rolling7Baseline": baseline_metrics,
        "RandomForestRegressor": random_forest_metrics,
        "GradientBoostingRegressor": gradient_boosting_metrics,
    }

    best_model_name = min(
        model_results,
        key=lambda name: model_results[name]["mae"],
    )

    if best_model_name == "RandomForestRegressor":
        best_metrics = random_forest_metrics

    elif best_model_name == "GradientBoostingRegressor":
        best_metrics = gradient_boosting_metrics

    else:
        # Baseline is useful for comparison,
        # but we still deploy a proper ML model.
        best_model_name = "RandomForestRegressor"
        best_metrics = random_forest_metrics

    # =========================================================
    # RETRAIN SELECTED ML MODEL ON ALL DATA
    # =========================================================

    X_all, y_all = _to_xy(
        features
    )

    if best_model_name == "RandomForestRegressor":

        final_model = RandomForestRegressor(
            n_estimators=300,
            max_depth=14,
            min_samples_leaf=2,
            random_state=42,
            n_jobs=-1,
        )

    else:

        final_model = GradientBoostingRegressor(
            n_estimators=200,
            learning_rate=0.05,
            max_depth=4,
            min_samples_leaf=2,
            random_state=42,
            loss="squared_error",
        )

    final_model.fit(
        X_all,
        y_all,
    )

    # =========================================================
    # FEATURE IMPORTANCE
    # =========================================================

    feature_importance = {}

    if hasattr(
        final_model,
        "feature_importances_",
    ):

        importance_values = (
            final_model.feature_importances_
        )

        feature_importance = {
            FEATURE_COLUMNS[index]: round(
                float(value),
                4,
            )
            for index, value in enumerate(
                importance_values
            )
        }

    # =========================================================
    # TRAINING METADATA
    # =========================================================

    metadata = training_metadata or {}

    trained_at = datetime.now(
        timezone.utc
    ).isoformat()

    products = sorted(
        {
            int(row["product_id"])
            for row in demand_data
            if row.get("product_id") is not None
        }
    )

    model_metadata = {
        "model_name": best_model_name,
        "feature_columns": FEATURE_COLUMNS,
        "trained_records": len(features),
        "data_source": data_source,
        "metrics": best_metrics,
        "model_comparison": model_results,
        "feature_importance": feature_importance,
        "trained_at": trained_at,
        "product_count": len(products),
        "product_ids": products,
        "training_metadata": metadata,
    }

    # =========================================================
    # SAVE MODEL
    # =========================================================

    MODEL_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    artifact_payload = {"model": final_model, **model_metadata}
    if db is not None:
        from app.models.ml_model_artifact import MLModelArtifact
        buffer = BytesIO()
        joblib.dump(artifact_payload, buffer)
        artifact = (
            db.query(MLModelArtifact)
            .filter(MLModelArtifact.model_key == data_source)
            .first()
        )
        if artifact is None:
            artifact = MLModelArtifact(
                model_key=data_source,
                artifact_data=buffer.getvalue(),
                metadata_json=model_metadata,
            )
            db.add(artifact)
        else:
            artifact.artifact_data = buffer.getvalue()
            artifact.metadata_json = model_metadata
            artifact.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.commit()
    else:
        joblib.dump(artifact_payload, model_path)

    return {
        "status": "success",
        "model": best_model_name,
        "data_source": data_source,
        "training_records": len(train_features),
        "testing_records": len(test_features),
        "total_records": len(features),
        "metrics": best_metrics,
        "model_comparison": model_results,
        "baseline": {
            "model": "Rolling7Baseline",
            "metrics": baseline_metrics,
        },
        "feature_importance": feature_importance,
        "trained_at": trained_at,
        "product_count": len(products),
        "training_metadata": metadata,
        "model_path": "postgresql://ml_model_artifacts" if db is not None else str(model_path),
    }


def _load_saved_payload(data_source: str = "real", db: Session | None = None):
    if db is not None:
        from app.models.ml_model_artifact import MLModelArtifact
        artifact = (
            db.query(MLModelArtifact)
            .filter(MLModelArtifact.model_key == data_source)
            .first()
        )
        if artifact is not None:
            return joblib.load(BytesIO(artifact.artifact_data))

    model_path = _get_model_path(data_source)
    if db is not None and APP_ENV == "production":
        raise FileNotFoundError(
            f"Demand forecasting model for '{data_source}' has not been trained in the hosted database."
        )
    if not model_path.exists():
        raise FileNotFoundError(
            f"Demand forecasting model for '{data_source}' has not been trained yet."
        )
    return joblib.load(model_path)


def load_model(data_source: str = "real", db: Session | None = None):
    return _load_saved_payload(data_source, db)["model"]


def get_model_metadata(
    data_source: str = "real",
    db: Session | None = None,
):
    """
    Return model metadata without exposing
    the model object.
    """

    saved = _load_saved_payload(data_source, db)
    model_path = _get_model_path(data_source)

    return {
        "model_name": saved.get(
            "model_name"
        ),
        "data_source": saved.get(
            "data_source",
            data_source,
        ),
        "trained_records": saved.get(
            "trained_records",
            0,
        ),
        "metrics": saved.get(
            "metrics",
            {},
        ),
        "model_comparison": saved.get(
            "model_comparison",
            {},
        ),
        "feature_importance": saved.get(
            "feature_importance",
            {},
        ),
        "trained_at": saved.get(
            "trained_at"
        ),
        "product_count": saved.get(
            "product_count",
            0,
        ),
        "product_ids": saved.get(
            "product_ids",
            [],
        ),
        "training_metadata": saved.get(
            "training_metadata",
            {},
        ),
        "model_path": "postgresql://ml_model_artifacts" if db is not None else str(model_path),
    }


def model_exists(
    data_source: str = "real",
    db: Session | None = None,
) -> bool:
    if db is not None:
        from app.models.ml_model_artifact import MLModelArtifact
        if db.query(MLModelArtifact.id).filter(MLModelArtifact.model_key == data_source).first():
            return True
    if db is not None and APP_ENV == "production":
        return False
    return _get_model_path(data_source).exists()


def predict_next_day(
    demand_data: list[dict[str, Any]],
    product_id: int,
    data_source: str = "real",
    db: Session | None = None,
):
    model = load_model(data_source=data_source, db=db)

    features = build_features(
        demand_data
    )

    product_features = [
        row
        for row in features
        if int(row["product_id"]) == product_id
    ]

    if not product_features:
        raise ValueError(
            f"No historical demand found "
            f"for product {product_id}."
        )

    product_features.sort(
        key=lambda row: row["date"]
    )

    latest = product_features[-1]

    latest_date = date.fromisoformat(
        latest["date"]
    )

    forecast_date = (
        latest_date + timedelta(days=1)
    )

    # =========================================================
    # HISTORICAL DEMAND LOOKUP
    # =========================================================

    demand_by_date = {
        date.fromisoformat(
            row["date"]
        ): float(
            row["demand"]
        )
        for row in product_features
    }

    lag_1 = demand_by_date.get(
        forecast_date - timedelta(days=1),
        0.0,
    )

    lag_7 = demand_by_date.get(
        forecast_date - timedelta(days=7),
        0.0,
    )

    lag_14 = demand_by_date.get(
        forecast_date - timedelta(days=14),
        0.0,
    )

    previous_7_days = [
        demand_by_date.get(
            forecast_date - timedelta(days=i),
            0.0,
        )
        for i in range(1, 8)
    ]

    previous_14_days = [
        demand_by_date.get(
            forecast_date - timedelta(days=i),
            0.0,
        )
        for i in range(1, 15)
    ]

    rolling_7 = (
        sum(previous_7_days)
        / len(previous_7_days)
    )

    rolling_14 = (
        sum(previous_14_days)
        / len(previous_14_days)
    )

    day_of_week = forecast_date.weekday()
    day_of_month = forecast_date.day
    month = forecast_date.month

    is_weekend = (
        1
        if day_of_week >= 5
        else 0
    )

    # =========================================================
    # FUTURE FEATURE VECTOR
    # =========================================================

    X_future = np.array(
        [[
            float(product_id),
            float(day_of_week),
            float(day_of_month),
            float(month),
            float(is_weekend),
            float(lag_1),
            float(lag_7),
            float(lag_14),
            float(rolling_7),
            float(rolling_14),
        ]],
        dtype=float,
    )

    prediction = float(
        model.predict(
            X_future
        )[0]
    )

    prediction = max(
        0.0,
        prediction,
    )

    prediction = round(
        prediction,
        2,
    )

    metadata = get_model_metadata(
        data_source=data_source,
        db=db,
    )

    return {
        "product_id": product_id,
        "product_name": latest["product_name"],
        "forecast_date": forecast_date.isoformat(),
        "predicted_demand": prediction,
        "model": metadata.get(
            "model_name",
            type(model).__name__,
        ),
        "data_source": metadata.get(
            "data_source",
            data_source,
        ),
        "metrics": metadata.get(
            "metrics",
            {},
        ),
        "trained_at": metadata.get(
            "trained_at"
        ),
    }