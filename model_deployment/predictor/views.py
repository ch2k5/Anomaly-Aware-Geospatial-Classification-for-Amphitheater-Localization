import joblib
import numpy as np
from django.http import JsonResponse
from rest_framework.decorators import api_view


model = joblib.load('model_deployment/model.joblib')

@api_view(['POST'])
def predict(request):
    try:
        lat  = float(request.data.get('lat'))
        long = float(request.data.get('long'))
        alt  = float(request.data.get('alt'))
        accuracy = float(request.data.get('accuracy'))

        # Prepare input (same order as training!)
        features = np.array([[lat, long, accuracy, alt]])

        # Prediction
        prediction = model.predict(features)

        # If your model returns multiple outputs:
        # prediction[0] → [amphi, position]
        amphi = int(prediction[0][0])
        position = int(prediction[0][1])

        return JsonResponse({
            'amphi': amphi,
            'position': position
        })

    except Exception as e:
        return JsonResponse({
            'error': str(e)
        }, status=400)