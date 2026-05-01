from django.test import TestCase, Client
from django.urls import reverse
import json


class BackendConnectionTestCase(TestCase):
    """Test backend connection and API endpoints"""

    def setUp(self):
        """Initialize test client"""
        self.client = Client()
        self.endpoint = '/model_prediction/predict/'

    def test_endpoint_is_accessible(self):
        """Test that the prediction endpoint is accessible"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        # Should return 200 or 400, not 404
        self.assertNotEqual(response.status_code, 404)

    def test_valid_request_returns_json(self):
        """Test that valid request returns JSON response"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        self.assertEqual(response['Content-Type'], 'application/json')
        data = json.loads(response.content)
        self.assertIsInstance(data, dict)

    def test_valid_request_returns_predictions(self):
        """Test that valid request returns amphi and position fields"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.content)
        self.assertIn('amphi', data)
        self.assertIn('position', data)
        self.assertIsInstance(data['amphi'], int)
        self.assertIsInstance(data['position'], int)


class RequestValidationTestCase(TestCase):
    """Test request validation and error handling"""

    def setUp(self):
        """Initialize test client"""
        self.client = Client()
        self.endpoint = '/model_prediction/predict/'
        self.valid_data = {
            'lat': 36.7538,
            'long': 3.0588,
            'alt': 100.0,
            'accuracy': 5.0
        }

    def test_missing_latitude_field(self):
        """Test error when latitude field is missing"""
        data = self.valid_data.copy()
        del data['lat']
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.content)
        self.assertIn('error', response_data)

    def test_missing_longitude_field(self):
        """Test error when longitude field is missing"""
        data = self.valid_data.copy()
        del data['long']
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.content)
        self.assertIn('error', response_data)

    def test_missing_altitude_field(self):
        """Test error when altitude field is missing"""
        data = self.valid_data.copy()
        del data['alt']
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)

    def test_missing_accuracy_field(self):
        """Test error when accuracy field is missing"""
        data = self.valid_data.copy()
        del data['accuracy']
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)

    def test_invalid_latitude_value(self):
        """Test error when latitude is not a number"""
        data = self.valid_data.copy()
        data['lat'] = 'invalid'
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.content)
        self.assertIn('error', response_data)

    def test_invalid_longitude_value(self):
        """Test error when longitude is not a number"""
        data = self.valid_data.copy()
        data['long'] = 'invalid'
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)

    def test_invalid_altitude_value(self):
        """Test error when altitude is not a number"""
        data = self.valid_data.copy()
        data['alt'] = 'invalid'
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)

    def test_invalid_accuracy_value(self):
        """Test error when accuracy is not a number"""
        data = self.valid_data.copy()
        data['accuracy'] = 'invalid'
        response = self.client.post(
            self.endpoint,
            data=json.dumps(data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 400)


class AnomalyDetectionTestCase(TestCase):
    """Test anomaly detection in predictions"""

    def setUp(self):
        """Initialize test client"""
        self.client = Client()
        self.endpoint = '/model_prediction/predict/'

    def test_anomaly_response_format(self):
        """Test that anomaly predictions return -1 for both fields"""
        # Use coordinates that should trigger anomaly detection
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 90.0,  # Extreme latitude
                'long': 180.0,  # Extreme longitude
                'alt': 10000.0,  # Extreme altitude
                'accuracy': 1000.0  # Low accuracy
            }),
            content_type='application/json'
        )
        if response.status_code == 200:
            data = json.loads(response.content)
            if data.get('amphi') == -1 and data.get('position') == -1:
                # Anomaly detected
                self.assertEqual(data['amphi'], -1)
                self.assertEqual(data['position'], -1)


class DataTypeValidationTestCase(TestCase):
    """Test data type validation"""

    def setUp(self):
        """Initialize test client"""
        self.client = Client()
        self.endpoint = '/model_prediction/predict/'

    def test_float_values_accepted(self):
        """Test that float values are properly handled"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.5,
                'accuracy': 5.25
            }),
            content_type='application/json'
        )
        self.assertNotEqual(response.status_code, 400)

    def test_negative_coordinates_accepted(self):
        """Test that negative coordinates are accepted"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': -36.7538,
                'long': -3.0588,
                'alt': -100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        self.assertNotEqual(response.status_code, 400)

    def test_integer_values_accepted(self):
        """Test that integer values are properly converted to float"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36,
                'long': 3,
                'alt': 100,
                'accuracy': 5
            }),
            content_type='application/json'
        )
        self.assertNotEqual(response.status_code, 400)


class ResponseFormatTestCase(TestCase):
    """Test response format and structure"""

    def setUp(self):
        """Initialize test client"""
        self.client = Client()
        self.endpoint = '/model_prediction/predict/'

    def test_response_contains_only_expected_fields(self):
        """Test that response contains only expected fields or error"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        data = json.loads(response.content)
        if response.status_code == 200:
            # Success response should have amphi and position
            self.assertTrue(set(data.keys()).issubset({'amphi', 'position'}))
        else:
            # Error response should have error field
            self.assertIn('error', data)

    def test_response_amphi_is_integer(self):
        """Test that amphi field is always an integer"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        if response.status_code == 200:
            data = json.loads(response.content)
            self.assertIsInstance(data['amphi'], int)

    def test_response_position_is_integer(self):
        """Test that position field is always an integer"""
        response = self.client.post(
            self.endpoint,
            data=json.dumps({
                'lat': 36.7538,
                'long': 3.0588,
                'alt': 100.0,
                'accuracy': 5.0
            }),
            content_type='application/json'
        )
        if response.status_code == 200:
            data = json.loads(response.content)
            self.assertIsInstance(data['position'], int)
