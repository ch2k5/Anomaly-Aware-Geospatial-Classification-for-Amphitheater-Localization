# Anomaly-Aware-Geospatial-Classification-for-Amphitheater-Localization

## 📌 Project Overview

This project is an end-to-end geospatial system that filters noisy GPS data, detects anomalies, and classifies student locations within amphitheaters. It also determines whether a student is inside a specific amphitheater or outside all defined zones.

The system combines **anomaly detection, machine learning classification, and mobile + backend integration** to achieve robust and accurate localization.

---

## 🧠 Problem Statement

GPS data collected from mobile devices is often noisy and unreliable due to:
- Low accuracy signals
- Environmental interference
- Device limitations

This project aims to:
- Filter unreliable GPS points using anomaly detection
- Classify the amphitheater of a student (8 amphitheaters: 0-7)
- Estimate the position within the amphitheater (3 positions: 0-front, 1-middle, 2-back)
- Detect if the student is outside all amphitheaters

---

## ⚙️ System Architecture

### 1. Data Collection & Preprocessing
- **Data Sources**: GPS coordinates from mobile devices (latitude, longitude, altitude, accuracy)
- **Data Collection Website**: Web interface for collecting GPS data points
- **Preprocessing**: Cleaning, outlier removal, feature engineering
- **Feature Engineering**: Distance-to-centroid calculations for improved classification

### 2. Model Training Pipeline

#### 🔹 Anomaly Detection (Noise Filtering)
- **Purpose**: Identify and filter unreliable GPS points
- **Model**: Isolation Forest
- **Input**: Raw GPS coordinates (latitude, longitude, altitude, accuracy)
- **Output**: Binary classification (normal/anomaly)

#### 🔹 Amphitheater & Position Classification
- **Purpose**: Predict amphitheater and position within amphitheater
- **Model**: Random Forest with MultiOutputClassifier
- **Features**: Original GPS data + distance-to-centroid features
- **Output**: Amphitheater (0-7) and Position (0-2)

### 3. Mobile Application (Flutter)

**App Name**: loc_amphi

**Key Features**:
- GPS permission handling
- Collection of 3 GPS readings for accuracy improvement
- Weighted averaging based on GPS accuracy
- Real-time API communication
- User-friendly interface showing predictions

**Dependencies**:
- geolocator: ^13.0.1 (GPS functionality)
- http: ^1.2.2 (API communication)

### 4. Backend API (Django REST Framework)

**Framework**: Django 6.0.4 with Django REST Framework

**API Endpoint**: `POST /model_prediction/predict/`

**Request Format**:
```json
{
  "lat": 36.6883642,
  "long": 2.8666613,
  "alt": 16.6,
  "accuracy": 6.2
}
```

**Response Format**:
```json
{
  "amphi": 5,
  "position": 1
}
```
*Note: Returns `{"amphi": -1, "position": -1}` for anomalies/outside locations*

**Key Components**:
- Custom `DistanceToCentroids` transformer for feature engineering
- Model loading with pickle compatibility handling
- Error handling and validation

### 5. Model Performance

#### Anomaly Detection:
- **Model**: Isolation Forest
- **Purpose**: Filter noisy GPS data

#### Classification Performance:
- **Model**: Random Forest (MultiOutput)
- **Amphitheater Classification**: 8 classes (0-7)
- **Position Classification**: 3 classes (0-front, 1-middle, 2-back)
- **Features**: GPS coordinates + 8 distance-to-centroid features

---

## 🚀 Technologies Used

### Backend & ML:
- **Python** 3.9+
- **Django** 6.0.4 (REST API)
- **Django REST Framework** 3.17.1
- **Scikit-learn** (ML models)
- **Pandas**, **NumPy** (data processing)
- **Joblib** (model serialization)

### Mobile App:
- **Flutter** (Dart SDK ^3.9.2)
- **Geolocator** package (GPS functionality)
- **HTTP** package (API communication)

### Data & Analysis:
- **Jupyter Notebooks** (EDA and model development)
- **Matplotlib**, **Seaborn** (visualization)
- **Pandas** (data manipulation)

---

## 🧩 Key Features

- **Hybrid ML Pipeline**: Anomaly detection + multi-output classification
- **Advanced Feature Engineering**: Distance-to-centroid calculations
- **Weighted GPS Fusion**: Accuracy-based averaging of multiple readings
- **Robust Error Handling**: Comprehensive validation and error responses
- **Cross-Platform Mobile App**: Flutter-based iOS/Android application
- **RESTful API**: Clean Django REST Framework implementation
- **Real-time Predictions**: Low-latency model inference

---

## 📁 Project Structure

```
├── client/                          # Flutter mobile application
│   ├── lib/main.dart               # Main app logic
│   ├── pubspec.yaml               # Flutter dependencies
│   └── android/ios/               # Platform-specific code
├── model_deployment/               # Django backend API
│   ├── predictor/                 # Main prediction app
│   │   ├── views.py              # API endpoints
│   │   └── urls.py               # URL routing
│   ├── models/                   # Trained ML models
│   │   ├── model_pipeline.pkl    # Main classification model
│   │   └── anomaly_detection_model.joblib  # Anomaly detector
│   └── requirements.txt          # Python dependencies
├── study/                         # ML development & analysis
│   ├── notebook.ipynb            # Main analysis notebook
│   ├── df_no_rendandancy.csv     # Cleaned dataset
│   └── X_train_centroids.csv     # Centroid data
├── Study/                         # Additional analysis
│   └── data_preprocessing_and_cleaning.ipynb
├── data/                          # Raw data files
│   ├── a1.csv - a8.csv           # Individual amphitheater data
│   ├── df.csv                    # Combined dataset
│   └── extern.csv                # External/outside data
├── Data Collection Website/       # Web data collection interface
└── README.md
```

---

## 🏃‍♂️ Getting Started

### Prerequisites
- Python 3.9+
- Flutter SDK
- Django 6.0+

### Backend Setup
```bash
cd model_deployment
pip install -r requirements.txt
python manage.py runserver
```

### Mobile App Setup
```bash
cd client
flutter pub get
flutter run
```

### API Usage
```bash
curl -X POST http://127.0.0.1:8000/model_prediction/predict/ \
  -H "Content-Type: application/json" \
  -d '{"lat": 36.6883642, "long": 2.8666613, "alt": 16.6, "accuracy": 6.2}'
```

---

## 📊 Data Insights

- **8 Amphitheaters**: Distributed across 2 floors
- **GPS Challenges**: Indoor positioning with accuracy issues
- **Feature Engineering**: Distance-to-centroid features improve classification
- **Class Distribution**: Some amphitheaters have fewer samples (imbalanced data)
- **Position Classes**: Front, middle, back positions within amphitheaters

---

## 🔧 Model Architecture Details

### DistanceToCentroids Transformer
- Calculates Euclidean distance from GPS point to each amphitheater centroid
- Adds 8 new features to the original 4 GPS features
- Improves model performance by capturing spatial relationships

### MultiOutput Random Forest
- Simultaneously predicts amphitheater and position
- Handles correlated outputs effectively
- Robust to outliers and missing data

---

## 📈 Future Improvements

- **Model Enhancement**: Try ensemble methods, neural networks
- **Additional Features**: Time-based features, movement patterns
- **Real-time Updates**: Model retraining with new data
- **Extended Coverage**: Support for more locations
- **Performance Optimization**: Model compression for mobile deployment

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Contributors

- Developed as part of ENSIA Machine Learning semester project
- Focus on practical geospatial ML applications

## 🚀 Technologies Used

- Python
- Scikit-learn
- Pandas / NumPy
- Django (backend API)
- Flutter (mobile app)
- Geospatial data processing

---

## 🧩 Key Features

- Hybrid ML pipeline (anomaly detection + classification)
- Weighted GPS fusion using accuracy values
- Robust handling of noisy real-world GPS data
- End-to-end mobile + backend system

---

## 📌 Example Output

Input:
```json
{
  "lat": 36.6883642,
  "long": 2.8666613,
  "alt": 16.6,
  "accuracy": 6.2
}
```

Processing:
- Anomaly detection → Normal (not an outlier)
- Feature engineering → Add distance-to-centroid features
- Classification → Predict amphitheater and position

Output:
```json
{
  "amphi": 5,
  "position": 1
}
```

*Note: Returns `{"amphi": -1, "position": -1}` for detected anomalies or outside locations*

---

## 📊 Data Insights

- **8 Amphitheaters**: Distributed across 2 floors (4 per floor)
- **GPS Challenges**: Indoor positioning with variable accuracy (0-400m)
- **Feature Engineering**: Distance-to-centroid features significantly improve classification
- **Class Distribution**: Some amphitheaters have fewer samples (imbalanced data)
- **Position Classes**: 3 positions within amphitheaters (front=0, middle=1, back=2)
- **Data Quality**: High accuracy points (>25m) were filtered out as noise

---

## 🔧 Model Architecture Details

### DistanceToCentroids Transformer
- **Purpose**: Convert GPS coordinates to spatial relationship features
- **Method**: Calculate Euclidean distance from input point to each amphitheater centroid
- **Output**: 8 new distance features added to original 4 GPS features
- **Impact**: Improves model performance by capturing spatial relationships

### MultiOutput Random Forest
- **Architecture**: Single model predicting both amphitheater and position simultaneously
- **Advantages**: Captures correlations between outputs, efficient inference
- **Robustness**: Handles outliers and missing data effectively

### Isolation Forest (Anomaly Detection)
- **Purpose**: Identify and filter noisy GPS readings
- **Method**: Unsupervised anomaly detection based on isolation in feature space
- **Threshold**: Contamination factor tuned for optimal noise filtering

---

## 📈 Future Improvements

- **Model Enhancement**: Experiment with ensemble methods, neural networks, and advanced architectures
- **Additional Features**: Time-based features, movement patterns, device-specific calibration
- **Real-time Updates**: Continuous model retraining with new collected data
- **Extended Coverage**: Support for additional buildings and outdoor spaces
- **Performance Optimization**: Model compression and quantization for mobile deployment
- **Advanced Anomaly Detection**: Multi-modal anomaly detection with temporal features

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Contributors

- Developed as part of ENSIA Machine Learning semester project
- Focus on practical geospatial ML applications for indoor positioning
