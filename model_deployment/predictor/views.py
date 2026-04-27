from pathlib import Path

import joblib
import numpy as np
from django.http import JsonResponse
from rest_framework.decorators import api_view


MODEL_PATH1 = Path(__file__).resolve().parent.parent / "models" / "model.joblib"
MODEL_PATH2 = Path(__file__).resolve().parent.parent / "models" / "anomaly_detection_model.joblib"
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
        model = joblib.load(MODEL_PATH1)
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
        features = np.array([[lat, longitude, accuracy, alt]])
        anomaly_prediction = anomaly_model.predict(features)
        if anomaly_prediction.item() == -1: # outside
            return JsonResponse({"amphi":-1,"position":-1})  # type: ignore
        prediction = loaded_model.predict(features)
        amphi = int(prediction[0][0])
        position = int(prediction[0][1])

        return JsonResponse({"amphi": amphi, "position": position})
    except Exception as exc:
        return JsonResponse({"error": str(exc)}, status=400)
