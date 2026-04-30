from pathlib import Path

import sys
import joblib
import pandas as pd
import numpy as np
from django.http import JsonResponse
from rest_framework.decorators import api_view
from sklearn.base import BaseEstimator, TransformerMixin


class DistanceToCentroids(BaseEstimator, TransformerMixin):
    def __init__(self, centroids):
        self.centroids = centroids

    def fit(self, X, y=None):
        return self

    def transform(self, X):
        X = X.copy()
        for i, row in enumerate(self.centroids.itertuples()):
            X[f'Distance_to_Centroid_{i}'] = np.sqrt(
                (X['Longitude'] - row.Center_Longitude) ** 2 +
                (X['Latitude'] - row.Center_Latitude) ** 2
            )
        return X


MODEL_PATH1 = Path(__file__).resolve().parent.parent / "models" / "model_pipeline.pkl"
MODEL_PATH2 = Path(__file__).resolve().parent.parent / "models" / "anomaly_detection_model.pkl"
model = None
anomaly_detection_model = None
model_load_error = None


def get_model():
    global model, anomaly_detection_model, model_load_error

    if model is not None and  anomaly_detection_model is not None:
        return (model,anomaly_detection_model)

    if model_load_error is not None:
        raise RuntimeError(model_load_error)

    try:
        anomaly_detection_model = joblib.load(MODEL_PATH2)
        
        # Inject DistanceToCentroids into __main__ for pickle to find it
        class _Main:
            DistanceToCentroids = DistanceToCentroids
        
        old_main = sys.modules.get('__main__')
        sys.modules['__main__'] = _Main()
        try:
            model = joblib.load(MODEL_PATH1)
        finally:
            if old_main:
                sys.modules['__main__'] = old_main
            else:
                del sys.modules['__main__']
        
        return (model,anomaly_detection_model)
    except Exception as exc:
        model_load_error = str(exc)
        raise RuntimeError(model_load_error) from exc


@api_view(["POST"])
def predict(request):
    try:
        models = get_model()
        loaded_model = models[0]
        anomaly_model=models[1]
    except RuntimeError as exc:
        return JsonResponse(
            {
                "error": "Model could not be loaded.",
                "details": str(exc),
            },
            status=500,
        )

    try:
        lat = float(request.data["lat"])
        longitude = float(request.data["long"])
        alt = float(request.data["alt"])
        accuracy = float(request.data["accuracy"])
    except KeyError as exc:
        return JsonResponse(
            {"error": f"Missing required field: {exc.args[0]}"},
            status=400,
        )
    except (TypeError, ValueError):
        return JsonResponse(
            {"error": "lat, long, alt, and accuracy must be valid numbers."},
            status=400,
        )

    try:
        # Anomaly detection with numpy array
        features_array = np.array([[lat, longitude, accuracy, alt]])
        anomaly_prediction = anomaly_model.predict(features_array)
        if anomaly_prediction.item() == -1:  # outside
            return JsonResponse({"amphi": -1, "position": -1})  # type: ignore
        
        # Main model with DataFrame (for DistanceToCentroids transformer)
        features_df = pd.DataFrame({
            'Latitude': [lat],
            'Longitude': [longitude],
            'Accuracy_m': [accuracy],
            'Altitude_m': [alt]
        })
        prediction = loaded_model.predict(features_df)
        amphi = int(prediction[0][0])
        position = int(prediction[0][1])

        return JsonResponse({"amphi": amphi, "position": position})
    except Exception as exc:
        return JsonResponse({"error": str(exc)}, status=400)
