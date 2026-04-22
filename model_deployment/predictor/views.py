from pathlib import Path

import joblib
import numpy as np
from django.http import JsonResponse
from rest_framework.decorators import api_view


MODEL_PATH = Path(__file__).resolve().parent.parent / "model.joblib"

try:
    model = joblib.load(MODEL_PATH)
    model_load_error = None
except Exception as exc:
    model = None
    model_load_error = str(exc)


@api_view(["POST"])
def predict(request):
    if model is None:
        return JsonResponse(
            {
                "error": "Model could not be loaded.",
                "details": model_load_error,
                "path": str(MODEL_PATH),
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
        prediction = model.predict(features)
        amphi = int(prediction[0][0])
        position = int(prediction[0][1])

        return JsonResponse({"amphi": amphi, "position": position})
    except Exception as exc:
        return JsonResponse({"error": str(exc)}, status=400)
