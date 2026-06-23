from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from pypmml import Model
except ImportError:  # pragma: no cover - exercised when pypmml is installed
    Model = None


class ModelUnavailableError(RuntimeError):
    pass


@dataclass(frozen=True)
class ModelStatus:
    available: bool
    error: str | None = None


class PMMLEvaluator:
    def __init__(self, model_path: Path) -> None:
        self._model_path = model_path
        self._model: Any | None = None
        self._status = self._load_model()

    @property
    def status(self) -> ModelStatus:
        return self._status

    def predict_effectiveness(self, features: dict[str, Any]) -> str:
        if not self._status.available or self._model is None:
            raise ModelUnavailableError(self._status.error or "PMML model is unavailable")

        prediction = self._model.predict(features)
        label = _extract_predicted_label(prediction)
        if not label:
            raise ModelUnavailableError("PMML model returned an empty prediction")

        return label

    def _load_model(self) -> ModelStatus:
        if Model is None:
            return ModelStatus(
                available=False,
                error="pypmml is not installed in the current environment",
            )

        try:
            self._model = Model.load(str(self._model_path))
            return ModelStatus(available=True)
        except Exception as error:  # pragma: no cover - depends on runtime model load
            return ModelStatus(available=False, error=str(error))


def _extract_predicted_label(prediction: Any) -> str:
    if isinstance(prediction, str):
        return prediction

    if isinstance(prediction, dict):
        return _select_prediction_value(prediction)

    if hasattr(prediction, "to_dict"):
        data = prediction.to_dict(orient="records")
        if isinstance(data, list) and data:
            first_record = data[0]
            if isinstance(first_record, dict):
                return _select_prediction_value(first_record)

    if isinstance(prediction, list) and prediction:
        first_item = prediction[0]
        if isinstance(first_item, dict):
            return _select_prediction_value(first_item)

    return ""


def _select_prediction_value(values: dict[str, Any]) -> str:
    preferred_keys = (
        "predicted_Категория эффективности",
        "Категория эффективности",
        "prediction",
        "predictedValue",
    )
    for key in preferred_keys:
        value = values.get(key)
        if value:
            return str(value)

    for key, value in values.items():
        if "Категория эффективности" in key and value:
            return str(value)

    return ""
