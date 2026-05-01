import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const hostIp = "10.246.247.102";

const String _modelPredictionUrl =
    'http://$hostIp:8000/model_prediction/predict/';

class ModelPredictionRequest {
  final double lat;
  final double long;
  final double alt;
  final double accuracy;

  ModelPredictionRequest({
    required this.lat,
    required this.long,
    required this.alt,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() {
    return {'lat': lat, 'long': long, 'alt': alt, 'accuracy': accuracy};
  }
}

class ModelPredictionResponse {
  final int amphi;
  final int position;

  ModelPredictionResponse({required this.amphi, required this.position});

  factory ModelPredictionResponse.fromJson(Map<String, dynamic> json) {
    return ModelPredictionResponse(
      amphi: (json['amphi'] as num).toInt(),
      position: (json['position'] as num).toInt(),
    );
  }

  bool get isAnomaly => amphi == -1 && position == -1;

  String get label {
    if (isAnomaly) {
      return 'Outside / anomaly detected';
    }
    return 'Amphitheater $amphi';
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Collector',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const LocationPage(),
    );
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? aggregatedPosition;
  ModelPredictionResponse? apiResponse;
  String? errorMessage;
  bool isLoading = false;

  Future<ModelPredictionResponse> _sendPrediction(Position position) async {
    final request = ModelPredictionRequest(
      lat: position.latitude,
      long: position.longitude,
      alt: position.altitude,
      accuracy: position.accuracy,
    );

    final uri = Uri.parse(_modelPredictionUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend returned status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ModelPredictionResponse.fromJson(body);
  }

  Future<void> _collectAndSendLocation() async {
    setState(() {
      isLoading = true;
      apiResponse = null;
      errorMessage = null;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isLoading = false;
        errorMessage = 'Location services are disabled.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isLoading = false;
          errorMessage = 'Location permission was denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isLoading = false;
        errorMessage = 'Location permission is permanently denied.';
      });
      return;
    }

    final positions = <Position>[];
    for (int i = 0; i < 3; i++) {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      positions.add(position);
    }

    final aggregated = _aggregatePositions(positions);
    aggregatedPosition = aggregated;

    try {
      final response = await _sendPrediction(aggregated);
      setState(() {
        apiResponse = response;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = 'Failed to send location: $error';
        isLoading = false;
      });
    }
  }

  Position _aggregatePositions(List<Position> positions) {
    double totalWeight = 0;
    double weightedLat = 0;
    double weightedLon = 0;
    double weightedAlt = 0;
    double accuracySum = 0;

    for (final pos in positions) {
      final weight = pos.accuracy > 0 ? 1 / pos.accuracy : 1.0;
      totalWeight += weight;
      weightedLat += pos.latitude * weight;
      weightedLon += pos.longitude * weight;
      weightedAlt += pos.altitude * weight;
      accuracySum += pos.accuracy;
    }

    final averageAccuracy = accuracySum / positions.length;
    final normalizedTotalWeight = totalWeight > 0
        ? totalWeight
        : positions.length.toDouble();

    return Position(
      latitude: weightedLat / normalizedTotalWeight,
      longitude: weightedLon / normalizedTotalWeight,
      timestamp: DateTime.now(),
      accuracy: averageAccuracy,
      altitude: weightedAlt / normalizedTotalWeight,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Collector'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Collect Location Data',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the button to collect your location and send it to the model.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _collectAndSendLocation,
                      icon: const Icon(Icons.location_searching),
                      label: const Text('Collect & Send Location'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Collecting location data...'),
                    ],
                  ),
                ),
              ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                ),
              ),
            if (apiResponse != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              apiResponse!.isAnomaly
                                  ? Icons.warning
                                  : Icons.theater_comedy,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apiResponse!.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  if (!apiResponse!.isAnomaly)
                                    Text(
                                      'Predicted position: ${apiResponse!.position}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  if (apiResponse!.isAnomaly)
                                    Text(
                                      'The backend marked this point as an anomaly.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
