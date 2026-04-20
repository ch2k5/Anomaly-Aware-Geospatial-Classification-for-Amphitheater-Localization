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
- Filter unreliable GPS points
- Classify the amphitheater of a student
- Estimate the position within the amphitheater
- Detect if the student is outside all amphitheaters

---

## ⚙️ System Architecture

### 1. Data Preprocessing & Feature Engineering
- Cleaning raw GPS data (latitude, longitude, altitude, accuracy)
- Exploratory Data Analysis (EDA)
- Feature engineering (distance, movement patterns, weighted averages)
- Preventing data leakage

---

### 2. Model Training

#### 🔹 Anomaly Detection (Noise Filtering)
- Detect unreliable GPS points
- Models:
  - Isolation Forest
  - Local Outlier Factor (LOF)

#### 🔹 Amphitheater Classification
- Multi-class classification:
  - Amphitheater A / B / C / ...
  - Outside detection via model logic or thresholding

- Models explored:
  - K-Nearest Neighbors (KNN)
  - Random Forest
  - Neural Networks
  - Ensemble methods

---

### 3. Mobile Application (Frontend)

Inputs:
- Latitude
- Longitude
- Altitude
- Accuracy

Process:
- Collect 3 GPS points
- Compute weighted average based on accuracy
- Send processed data to backend

Output:
- Amphitheater prediction
- Position inside amphitheater

---

### 4. Backend (Django Deployment)

Workflow:
1. Receive GPS input from mobile app
2. Run anomaly detection model
   - If anomaly → return "Outside / Invalid"
3. Otherwise run classification model
4. Return final result:
   - (Amphitheater, Position)

---

### 5. Evaluation Metrics

#### Anomaly Detection:
- Precision / Recall
- F1-score
- ROC-AUC

#### Classification:
- Accuracy
- Confusion Matrix
- F1-score (macro/micro)

---

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
- (latitude, longitude, altitude, accuracy)

Processing:
- Anomaly check → valid
- Classification model → amphitheater prediction

Output:
- Amphitheater: B  
- Position: Zone 3
