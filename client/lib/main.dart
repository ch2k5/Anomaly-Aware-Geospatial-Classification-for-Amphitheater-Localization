import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// const String _modelPredictionUrl =
//     'https://anomaly-aware-geospatial-classification-kknf.onrender.com/model_prediction/predict/';

const String _modelPredictionUrl =
    'http://192.168.8.142:8000/model_prediction/predict/';

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

class SelectedPointData {
  final Position position;
  final ModelPredictionResponse response;

  SelectedPointData({required this.position, required this.response});
}

void main() {
  runApp(const MyApp());
}

// ─── Design tokens ──────────────────────────────────────────────────────────

class _AppColors {
  static const background = Color(0xFF0A0E1A);
  static const surface = Color(0xFF111827);
  static const surfaceElevated = Color(0xFF1A2235);
  static const border = Color(0xFF1E2D45);
  static const borderBright = Color(0xFF2A3F5F);

  static const primary = Color(0xFF38BDF8);       // sky-400
  static const primaryDim = Color(0xFF0EA5E9);     // sky-500
  static const primaryGlow = Color(0x2238BDF8);

  static const success = Color(0xFF34D399);        // emerald-400
  static const successGlow = Color(0x2234D399);
  static const successDim = Color(0xFF0D4A35);

  static const warning = Color(0xFFFBBF24);        // amber-400
  static const warningGlow = Color(0x22FBBF24);
  static const warningDim = Color(0xFF4A3500);

  static const error = Color(0xFFF87171);
  static const errorGlow = Color(0x22F87171);
  static const errorDim = Color(0xFF3A0F0F);

  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF475569);
}

// ─── App ────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amphitheater Locator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: _AppColors.primary,
          surface: _AppColors.surface,
          onSurface: _AppColors.textPrimary,
          onSurfaceVariant: _AppColors.textSecondary,
          outline: _AppColors.border,
          outlineVariant: _AppColors.borderBright,
        ),
        fontFamily: 'Roboto',
      ),
      home: const LocationPage(),
    );
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? aggregatedPosition;
  List<Position> collectedPositions = [];
  List<SelectedPointData> selectedPoints = [];
  ModelPredictionResponse? apiResponse;
  String? errorMessage;
  String capturingMessage = '';
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
      capturingMessage = '';
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
      setState(() {
        capturingMessage = 'Capturing point ${i + 1} of 3';
      });

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      positions.add(position);

      if (i < 2) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    setState(() {
      capturingMessage = 'Processing data';
    });

    final aggregated = _aggregatePositions(positions);
    aggregatedPosition = aggregated;

    setState(() {
      capturingMessage = 'Requesting prediction';
    });

    try {
      final response = await _sendPrediction(aggregated);
      setState(() {
        collectedPositions = positions;
        apiResponse = response;
        isLoading = false;
        capturingMessage = '';
      });
    } catch (error) {
      setState(() {
        errorMessage = 'We could not find your amphitheater right now.';
        isLoading = false;
      });
    }
  }

  Future<void> _onLocatePressed(Position position) async {
    Navigator.pop(context);
    setState(() {
      isLoading = true;
      capturingMessage = 'Requesting point prediction';
      errorMessage = null;
    });

    try {
      final response = await _sendPrediction(position);
      setState(() {
        selectedPoints.add(
          SelectedPointData(position: position, response: response),
        );
        isLoading = false;
        capturingMessage = '';
      });
    } catch (error) {
      setState(() {
        errorMessage = 'We could not predict that selected point right now.';
        isLoading = false;
        capturingMessage = '';
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
    final normalizedTotalWeight =
        totalWeight > 0 ? totalWeight : positions.length.toDouble();

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
      backgroundColor: _AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _AppColors.background,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _AppColors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.stadium_rounded,
                      color: _AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AMPHILOCATOR',
                    style: TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _AppColors.border),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeroLocateCard(
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _collectAndSendLocation,
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  _StatusCard(
                    step: capturingMessage,
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: errorMessage!),
                ],
                if (apiResponse != null && aggregatedPosition != null) ...[
                  const SizedBox(height: 16),
                  _PredictionCard(
                    response: apiResponse!,
                    position: aggregatedPosition!,
                    collectedPositions: collectedPositions,
                    onLocatePressed: _onLocatePressed,
                  ),
                ],
                ...List.generate(selectedPoints.length, (index) {
                  final sp = selectedPoints[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _SelectedPointCard(
                      selectedPoint: sp,
                      onRemove: () => setState(() => selectedPoints.removeAt(index)),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Locate Card ────────────────────────────────────────────────────────

class _HeroLocateCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _HeroLocateCard({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top illustrative band
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _AppColors.primary.withValues(alpha: 0.12),
                  _AppColors.surface,
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Concentric rings
                for (final size in [88.0, 64.0, 42.0])
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _AppColors.primary.withValues(
                          alpha: 0.06 + (88 - size) / 88 * 0.10,
                        ),
                        width: 1,
                      ),
                    ),
                  ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: _AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Find your amphitheater',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Uses your GPS coordinates across 3 captures to pinpoint the nearest amphitheater.',
                  style: TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _LocateButton(isLoading: isLoading, onPressed: onPressed),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _LocateButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: isLoading
              ? _AppColors.surface
              : _AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLoading
                ? _AppColors.borderBright
                : _AppColors.primary,
          ),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: _AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _AppColors.textSecondary,
                ),
              )
            else
              const Icon(Icons.near_me_rounded, size: 18, color: Color(0xFF0A0E1A)),
            const SizedBox(width: 8),
            Text(
              isLoading ? 'Locating…' : 'Locate amphitheater',
              style: TextStyle(
                color: isLoading ? _AppColors.textSecondary : const Color(0xFF0A0E1A),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Card (loading) ────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String step;

  const _StatusCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.primaryGlow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scanning location',
                  style: TextStyle(
                    color: _AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (step.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    step,
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error Card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.errorDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location error',
                  style: TextStyle(
                    color: _AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
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

// ─── Prediction Card ──────────────────────────────────────────────────────────

class _PredictionCard extends StatelessWidget {
  final ModelPredictionResponse response;
  final Position position;
  final List<Position> collectedPositions;
  final Future<void> Function(Position) onLocatePressed;

  const _PredictionCard({
    required this.response,
    required this.position,
    required this.collectedPositions,
    required this.onLocatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isAnomaly = response.isAnomaly;
    final accentColor = isAnomaly ? _AppColors.warning : _AppColors.primary;
    final glowColor = isAnomaly ? _AppColors.warningGlow : _AppColors.primaryGlow;
    final dimColor = isAnomaly ? _AppColors.warningDim : _AppColors.surface;
    final iconData = isAnomaly ? Icons.warning_amber_rounded : Icons.theater_comedy_rounded;

    return Container(
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header band
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: glowColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dimColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(iconData, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnomaly ? 'ANOMALY DETECTED' : 'MATCH FOUND',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        response.label,
                        style: const TextStyle(
                          color: _AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAnomaly
                      ? 'This location does not match a known amphitheater.'
                      : 'Predicted seat position: ${response.position}',
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                _CoordGrid(position: position),
                const SizedBox(height: 14),
                _OutlineButton(
                  label: 'View all captured points',
                  icon: Icons.list_alt_rounded,
                  accentColor: accentColor,
                  onPressed: () => _showDetailsDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _PointsDialog(
        collectedPositions: collectedPositions,
        onLocatePressed: (pos) => onLocatePressed(pos),
      ),
    );
  }
}

// ─── Selected Point Card ──────────────────────────────────────────────────────

class _SelectedPointCard extends StatelessWidget {
  final SelectedPointData selectedPoint;
  final VoidCallback onRemove;

  const _SelectedPointCard({
    required this.selectedPoint,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final response = selectedPoint.response;
    final position = selectedPoint.position;
    final isAnomaly = response.isAnomaly;

    return Container(
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.success.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: _AppColors.successGlow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: _AppColors.success.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _AppColors.successDim,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: _AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POINT PREDICTION',
                        style: TextStyle(
                          color: _AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        response.label,
                        style: const TextStyle(
                          color: _AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _AppColors.border),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: _AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAnomaly
                      ? 'This point does not match a known amphitheater.'
                      : 'Predicted seat position: ${response.position}',
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _CoordGrid(position: position),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared: Coordinate Grid ──────────────────────────────────────────────────

class _CoordGrid extends StatelessWidget {
  final Position position;

  const _CoordGrid({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CoordItem(
                  label: 'LAT',
                  value: position.latitude.toStringAsFixed(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CoordItem(
                  label: 'LON',
                  value: position.longitude.toStringAsFixed(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CoordItem(
                  label: 'ALT',
                  value: '${position.altitude.toStringAsFixed(1)} m',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CoordItem(
                  label: 'ACC',
                  value: '±${position.accuracy.toStringAsFixed(1)} m',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoordItem extends StatelessWidget {
  final String label;
  final String value;

  const _CoordItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: _AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ─── Shared: Outline Button ────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Points Dialog ────────────────────────────────────────────────────────────

class _PointsDialog extends StatelessWidget {
  final List<Position> collectedPositions;
  final Future<void> Function(Position) onLocatePressed;

  const _PointsDialog({
    required this.collectedPositions,
    required this.onLocatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Collected Points',
                      style: TextStyle(
                        color: _AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _AppColors.border),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: _AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(collectedPositions.length, (index) {
                final pos = collectedPositions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _AppColors.primaryGlow,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'Point ${index + 1}',
                                style: const TextStyle(
                                  color: _AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _CoordGrid(position: pos),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => onLocatePressed(pos),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _AppColors.success.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 15, color: _AppColors.success),
                                SizedBox(width: 7),
                                Text(
                                  'Predict this point',
                                  style: TextStyle(
                                    color: _AppColors.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}