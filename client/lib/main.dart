import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// const hostIp = "192.168.100.4";

// const String _modelPredictionUrl =
//     'http://$hostIp:8000/model_prediction/predict/';

const String _modelPredictionUrl =
    'https://anomaly-aware-geospatial-classification-kknf.onrender.com/model_prediction/predict/';

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
      return 'Outside expected area';
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7FF),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF2E1065),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
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
        errorMessage = 'We could not find your amphitheater right now.';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Amphitheater Locator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.my_location,
                              color: colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Find your amphitheater',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap the button and we will use your current location to find the nearest amphitheater.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        onPressed: isLoading ? null : _collectAndSendLocation,
                        icon: isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            : const Icon(Icons.near_me),
                        label: Text(
                          isLoading ? 'Locating...' : 'Locate amphitheater',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: _StatusPanel(
                    icon: Icons.sensors,
                    title: 'Finding your location',
                    message: 'Keep the app open for a moment.',
                  ),
                ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _StatusPanel(
                    icon: Icons.error_outline,
                    title: 'Could not find your location',
                    message: errorMessage!,
                    isError: true,
                  ),
                ),
              if (apiResponse != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _PredictionPanel(response: apiResponse!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isError
        ? colorScheme.errorContainer
        : const Color(0xFFF3E8FF);
    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : const Color(0xFF4C1D95);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? colorScheme.error.withValues(alpha: 0.22)
              : const Color(0xFFC084FC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionPanel extends StatelessWidget {
  final ModelPredictionResponse response;

  const _PredictionPanel({required this.response});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAnomaly = response.isAnomaly;
    final accentColor = isAnomaly
        ? const Color(0xFF9333EA)
        : const Color(0xFF6D28D9);
    final backgroundColor = isAnomaly
        ? const Color(0xFFF5EDFF)
        : const Color(0xFFF1E9FF);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isAnomaly ? Icons.warning_amber : Icons.theater_comedy,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnomaly ? 'Model result' : 'Predicted location',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      response.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAnomaly
                          ? 'This location does not match a known amphitheater.'
                          : 'Predicted position: ${response.position}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
