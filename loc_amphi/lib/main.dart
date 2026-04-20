import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'dart:convert';

class ApiResponse {
  final String prediction;
  final double confidence;

  ApiResponse({required this.prediction, required this.confidence});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      prediction: json['prediction'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
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
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? aggregatedPosition;
  ApiResponse? apiResponse;
  bool isLoading = false;

  Future<void> _collectAndSendLocation() async {
    setState(() {
      isLoading = true;
      apiResponse = null;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isLoading = false;
        apiResponse = null;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isLoading = false;
          apiResponse = null;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isLoading = false;
        apiResponse = null;
      });
      return;
    }

    List<Position> positions = [];
    for (int i = 0; i < 3; i++) {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      positions.add(position);
    }

    // Compute aggregated position
    double totalWeight = 0;
    for (var pos in positions) {
      totalWeight += 1 / pos.accuracy;
    }

    double lat = 0, lon = 0, alt = 0;
    for (var pos in positions) {
      double weight = (1 / pos.accuracy) / totalWeight;
      lat += pos.latitude * weight;
      lon += pos.longitude * weight;
      alt += pos.altitude * weight;
    }

    aggregatedPosition = Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
      accuracy: 0, // Not used
      altitude: alt,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

    // Mock API response
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
    final random = Random();
    final mockResult = random.nextBool() ? 'amphix' : 'out';
    final mockResponseJson =
        '{"prediction": "$mockResult", "confidence": ${(random.nextDouble() * 0.5 + 0.5).toStringAsFixed(2)}}';

    setState(() {
      isLoading = false;
      apiResponse = ApiResponse.fromJson(jsonDecode(mockResponseJson));
    });
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
                              apiResponse!.prediction == 'amphix'
                                  ? Icons.theater_comedy
                                  : Icons.outdoor_grill,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apiResponse!.prediction == 'amphix'
                                        ? 'Amphitheater'
                                        : 'Outside',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Confidence: ${(apiResponse!.confidence * 100).toStringAsFixed(1)}%',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
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
