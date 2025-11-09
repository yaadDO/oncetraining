import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // ADD THIS IMPORT

import '../../../core/services/gpx_storage_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/domain/sensor_type.dart'; // ADD THIS IMPORT
import '../../domain/metric_model.dart';
import '../../domain/ride_data.dart';
import '../../domain/ride_session.dart';
import '../../services/ride_service.dart';
import '../../services/sensor_connection_manager.dart';
import '../../services/timer_manager.dart';
import '../../services/metrics_data_processor.dart';
import '../../services/ride_state_manager.dart';

class CycleScreenController {
  final RideData rideData = RideData();
  final RideService rideService;
  final GpxStorageService storageService;
  final PreferencesService preferencesService;

  final SensorConnectionManager sensorManager = SensorConnectionManager();
  final TimerManager timerManager = TimerManager();
  final MetricsDataProcessor dataProcessor = MetricsDataProcessor();
  final RideStateManager rideState = RideStateManager();

  bool isLocationPermissionGranted = false;
  List<MetricBlock> displayedMetrics = [];
  List<MetricBlock> allMetrics = [];
  final List<int> _cadence3sBuffer = [];
  final List<int> _cadence10sBuffer = [];

  // User settings (loaded from preferences)
  double userWeight = 70.0; // kg
  int userFtp = 250; // watts
  int userMaxHr = 190; // bpm

  CycleScreenController({
    required this.rideService,
    required this.storageService,
    required this.preferencesService,
  });

  Future<void> initializeMetrics() async {
    allMetrics = [
      // Power metrics
      'power', 'avg_power', 'max_power', 'power_3s_avg', 'power_10s_avg', 'power_20s_avg',
      'normalised_power', 'watts_kg', 'ftp_percentage', 'ftp_zone',
      'lap_avg_power', 'lap_max_power', 'last_lap_avg_power', 'last_lap_max_power', 'lap_normalised',

      // Speed metrics
      'speed', 'avg_speed', 'max_speed', 'lap_avg_speed', 'lap_max_speed', 'last_lap_avg_speed',

      // Time metrics
      'time', 'local_time', 'ride_time', 'trip_time', 'lap_time', 'last_lap_time', 'lap_count',

      // Distance metrics
      'distance', 'lap_distance', 'last_lap_distance',

      // Energy metrics
      'kj', 'calories',

      // Heart rate metrics
      'hr', 'avg_hr', 'max_hr', 'hr_percentage_max', 'hr_zone', 'lap_avg_hr', 'last_lap_avg_hr',

      // Cadence metrics
      'cadence', 'avg_cadence', 'max_cadence', 'lap_avg_cadence', 'last_lap_avg_cadence',

      // Altitude metrics
      'altitude', 'alt_gain', 'max_alt',

      // Sensor metrics
      'sensor_speed'
    ].map((key) => MetricBlock.fromKey(key)).toList();

    await loadDisplayedMetrics();
    await _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userWeight = prefs.getDouble('userWeight') ?? 70.0;
      userFtp = prefs.getInt('userFtp') ?? 250;
      userMaxHr = prefs.getInt('userMaxHr') ?? 190;
      rideData.wheelCircumference = prefs.getDouble('wheelCircumference') ?? 2.1;
    });
  }

  void setState(void Function() fn) {
    fn();
  }

  Future<void> loadDisplayedMetrics() async {
    final savedKeys = await preferencesService.getDisplayedMetrics();

    if (savedKeys.isNotEmpty) {
      displayedMetrics = savedKeys.map((key) {
        return allMetrics.firstWhere((m) => m.key == key);
      }).toList();
    } else {
      displayedMetrics = [
        allMetrics.firstWhere((m) => m.key == 'power'),
        allMetrics.firstWhere((m) => m.key == 'speed'),
        allMetrics.firstWhere((m) => m.key == 'distance'),
        allMetrics.firstWhere((m) => m.key == 'cadence'),
        allMetrics.firstWhere((m) => m.key == 'hr'),
        allMetrics.firstWhere((m) => m.key == 'time'),
      ];
    }
  }

  Future<void> saveDisplayedMetrics() async {
    await preferencesService.saveDisplayedMetrics(
        displayedMetrics.map((m) => m.key).toList()
    );
  }

  void startRide() {
    rideState.startRide();
    rideData.isRiding = true;

    // Clear all buffers
    dataProcessor.clearAllBuffers();

    // Reset metrics
    _resetRideMetrics();

    rideService.reset();
    resetLap();
  }

  void _resetRideMetrics() {
    rideData.avgPower = 0;
    rideData.maxPower = 0;
    rideData.powerKjoules = 0;
    rideData.calories = 0.0;
    rideData.maxSpeed = 0.0;
    rideData.maxCadence = 0;
    rideData.maxHeartRate = 0;
    rideData.lapCount = 0;
    rideData.cadence = 0;
    rideData.heartRate = 0;
    rideData.avgSpeed = 0.0;
    rideData.avgCadence = 0;
    rideData.avgHeartRate = 0;
    rideData.normalisedPower = 0.0;
    rideData.ftpPercentage = 0.0;
    rideData.hrPercentageMax = 0;
    rideData.hrZone = 0;
    rideData.power10sAvg = 0;
    rideData.power20sAvg = 0;
    rideData.ftpZone = 0;
    rideData.lapMaxSpeed = 0.0;

    // Reset altitude
    dataProcessor.currentAltitude = 0.0;
    dataProcessor.maxAltitude = 0.0;
    dataProcessor.totalAltitudeGain = 0.0;
    dataProcessor.lastRecordedAltitude = 0.0;
  }

  void resetLap() {
    rideData.lapDuration = Duration.zero;
    rideData.lapDistance = 0.0;
    rideData.lapAvgSpeed = 0.0;
    rideData.lapAvgPower = 0;
    rideData.lapAvgHeartRate = 0;
    rideData.lapAvgCadence = 0;
    rideData.lapMaxPower = 0;
    rideData.lapNormalised = 0.0;
    rideData.lapMaxSpeed = 0.0;

    dataProcessor.clearLapBuffers();

    // Reset lap metrics display
    updateMetric('lap_time', formatDuration(rideData.lapDuration));
    updateMetric('lap_avg_speed', '0.0');
    updateMetric('lap_avg_power', '0');
    updateMetric('lap_max_power', '0');
    updateMetric('lap_avg_hr', '0');
    updateMetric('lap_avg_cadence', '0');
    updateMetric('lap_normalised', '0');
    updateMetric('lap_max_speed', '0.0');
  }

  void startLap() {
    // Save previous lap data if this isn't the first lap
    if (timerManager.lapTimer != null) {
      calculateLapAverages();

      rideData.lastLapAvgPower = rideData.lapAvgPower;
      rideData.lastLapMaxPower = rideData.lapMaxPower;
      rideData.lastLapAvgSpeed = rideData.lapAvgSpeed;
      rideData.lastLapDistance = rideData.lapDistance;
      rideData.lastLapTime = rideData.lapDuration;
      rideData.lastLapAvgHr = rideData.lapAvgHeartRate;
      rideData.lastLapAvgCadence = rideData.lapAvgCadence;

      // Update metrics for last lap
      updateMetric('last_lap_avg_power', '${rideData.lastLapAvgPower}');
      updateMetric('last_lap_max_power', '${rideData.lastLapMaxPower}');
      updateMetric('last_lap_avg_speed', rideData.lastLapAvgSpeed.toStringAsFixed(1));
      updateMetric('last_lap_distance', rideData.lastLapDistance.toStringAsFixed(2));
      updateMetric('last_lap_time', formatDuration(rideData.lastLapTime));
      updateMetric('last_lap_avg_hr', '${rideData.lastLapAvgHr}');
      updateMetric('last_lap_avg_cadence', '${rideData.lastLapAvgCadence}');
    }

    rideData.lapCount++;
    updateMetric('lap_count', '${rideData.lapCount}');

    // Reset lap distance in ride service
    rideService.resetLap();

    resetLap();
    rideState.startLap();
  }

  void stopLap() {
    if (timerManager.lapTimer != null) {
      calculateLapAverages();
      updateLapNormalisedPower();

      // Update final lap metrics
      updateMetric('lap_avg_power', '${rideData.lapAvgPower}');
      updateMetric('lap_max_power', '${rideData.lapMaxPower}');
      updateMetric('lap_avg_speed', rideData.lapAvgSpeed.toStringAsFixed(1));
      updateMetric('lap_avg_hr', '${rideData.lapAvgHeartRate}');
      updateMetric('lap_avg_cadence', '${rideData.lapAvgCadence}');
      updateMetric('lap_normalised', rideData.lapNormalised.toStringAsFixed(0));
      updateMetric('lap_max_speed', rideData.lapMaxSpeed.toStringAsFixed(1));

      // Save this lap data as "last lap" metrics
      rideData.lastLapAvgPower = rideData.lapAvgPower;
      rideData.lastLapMaxPower = rideData.lapMaxPower;
      rideData.lastLapAvgSpeed = rideData.lapAvgSpeed;
      rideData.lastLapDistance = rideData.lapDistance;
      rideData.lastLapTime = rideData.lapDuration;
      rideData.lastLapAvgHr = rideData.lapAvgHeartRate;
      rideData.lastLapAvgCadence = rideData.lapAvgCadence;

      // Update metrics for last lap
      updateMetric('last_lap_avg_power', '${rideData.lastLapAvgPower}');
      updateMetric('last_lap_max_power', '${rideData.lastLapMaxPower}');
      updateMetric('last_lap_avg_speed', rideData.lastLapAvgSpeed.toStringAsFixed(1));
      updateMetric('last_lap_distance', rideData.lastLapDistance.toStringAsFixed(2));
      updateMetric('last_lap_time', formatDuration(rideData.lastLapTime));
      updateMetric('last_lap_avg_hr', '${rideData.lastLapAvgHr}');
      updateMetric('last_lap_avg_cadence', '${rideData.lastLapAvgCadence}');

      print('Lap stopped - Avg Power: ${rideData.lapAvgPower}, Duration: ${rideData.lapDuration}');
    }
    rideState.stopLap();
  }

  void calculateLapAverages() {
    if (dataProcessor.lapPowerSamples.isNotEmpty) {
      final totalPower = dataProcessor.lapPowerSamples.reduce((a, b) => a + b);
      rideData.lapAvgPower = totalPower ~/ dataProcessor.lapPowerSamples.length;
    }

    if (dataProcessor.lapHeartRateSamples.isNotEmpty) {
      final totalHR = dataProcessor.lapHeartRateSamples.reduce((a, b) => a + b);
      rideData.lapAvgHeartRate = totalHR ~/ dataProcessor.lapHeartRateSamples.length;
    }

    if (dataProcessor.lapCadenceSamples.isNotEmpty) {
      final totalCadence = dataProcessor.lapCadenceSamples.reduce((a, b) => a + b);
      rideData.lapAvgCadence = totalCadence ~/ dataProcessor.lapCadenceSamples.length;
    }
  }

  void updatePowerData(int power) {
    rideData.currentPower = power;
    updateMetric('power', '$power');
    updateWattsPerKilo();

    if (rideData.isRiding) {
      dataProcessor.powerSamples.add(power);

      if (rideState.isLapActive) {
        dataProcessor.lapPowerSamples.add(power);
      }

      if (power > rideData.maxPower) {
        rideData.maxPower = power;
      }
      updateMetric('max_power', '${rideData.maxPower}');

      updateAveragePower();
      updateKiloJoules();
      updateCalories();

      dataProcessor.updatePowerAverages(
        power,
            (avg) {
          rideData.power3sAvg = avg;
          updateMetric('power_3s_avg', '$avg');
        },
            (avg) {
          rideData.power10sAvg = avg;
          updateMetric('power_10s_avg', '$avg');
        },
            (avg) {
          rideData.power20sAvg = avg;
          updateMetric('power_20s_avg', '$avg');
        },
      );

      if (rideState.isLapActive && power > rideData.lapMaxPower) {
        rideData.lapMaxPower = power;
        updateMetric('lap_max_power', '${rideData.lapMaxPower}');
      }

      updateFtpZone();
    }
  }

  void updateWattsPerKilo() {
    rideData.wattsPerKilo = rideData.currentPower / userWeight;
    updateMetric('watts_kg', rideData.wattsPerKilo.toStringAsFixed(1));
  }

  void updateCalories() {
    final hours = rideData.rideDuration.inSeconds / 3600;
    rideData.calories = rideData.avgPower * hours * 3.6;
    updateMetric('calories', rideData.calories.toStringAsFixed(0));
  }

  void updateKiloJoules() {
    rideData.powerKjoules = dataProcessor.powerSamples.fold(0, (sum, power) => sum + power) ~/ 1000;
    updateMetric('kj', '${rideData.powerKjoules}');
  }

  void updateAvgSpeed() {
    if (rideData.rideDuration.inSeconds > 0) {
      rideData.avgSpeed = (rideService.distance / rideData.rideDuration.inSeconds) * 3.6;
      updateMetric('avg_speed', rideData.avgSpeed.toStringAsFixed(1));
    }
  }

  void updateLapAvgSpeed() {
    if (rideData.lapDuration.inSeconds > 0) {
      rideData.lapAvgSpeed = (rideService.lapDistance / rideData.lapDuration.inSeconds) * 3.6;
      updateMetric('lap_avg_speed', rideData.lapAvgSpeed.toStringAsFixed(1));
    }
  }

  void updateLapMaxSpeed(double speed) {
    if (speed > rideData.lapMaxSpeed) {
      rideData.lapMaxSpeed = speed;
      updateMetric('lap_max_speed', rideData.lapMaxSpeed.toStringAsFixed(1));
    }
  }

  void updateAveragePower() {
    if (dataProcessor.powerSamples.isEmpty) return;
    final total = dataProcessor.powerSamples.reduce((a, b) => a + b);
    rideData.avgPower = total ~/ dataProcessor.powerSamples.length;
    updateMetric('avg_power', '${rideData.avgPower}');
  }

  void updateAverageHeartRate() {
    if (dataProcessor.heartRateSamples.isEmpty) return;
    final total = dataProcessor.heartRateSamples.reduce((a, b) => a + b);
    rideData.avgHeartRate = total ~/ dataProcessor.heartRateSamples.length;
    updateMetric('avg_hr', '${rideData.avgHeartRate}');
  }

  void updateAverageCadence() {
    if (dataProcessor.cadenceSamples.isEmpty) return;
    final total = dataProcessor.cadenceSamples.reduce((a, b) => a + b);
    rideData.avgCadence = total ~/ dataProcessor.cadenceSamples.length;
    updateMetric('avg_cadence', '${rideData.avgCadence}');
  }

  void updateNormalisedPower() {
    if (dataProcessor.powerSamples.length >= 30) {
      rideData.normalisedPower = dataProcessor.calculateNormalisedPower(dataProcessor.powerSamples);
      updateMetric('normalised_power', rideData.normalisedPower.toStringAsFixed(0));
    }
  }

  void updateFtpPercentage() {
    if (userFtp <= 0) return;
    rideData.ftpPercentage = (rideData.currentPower / userFtp) * 100;
    updateMetric('ftp_percentage', rideData.ftpPercentage.toStringAsFixed(0));
  }

  void updateFtpZone() {
    if (userFtp <= 0) return;
    final percentage = (rideData.currentPower / userFtp) * 100;
    rideData.ftpZone = dataProcessor.calculateFtpZone(percentage);
    updateMetric('ftp_zone', '${rideData.ftpZone}');
  }

  void updateHrMetrics(int heartRate) {
    rideData.heartRate = heartRate;
    updateMetric('hr', '$heartRate');

    if (heartRate > rideData.maxHeartRate) {
      rideData.maxHeartRate = heartRate;
    }
    updateMetric('max_hr', '${rideData.maxHeartRate}');

    if (userMaxHr > 0) {
      rideData.hrPercentageMax = ((heartRate / userMaxHr) * 100).round();
    }
    updateMetric('hr_percentage_max', '${rideData.hrPercentageMax}%');

    rideData.hrZone = dataProcessor.calculateHrZone(heartRate, userMaxHr);
    updateMetric('hr_zone', '${rideData.hrZone}');

    dataProcessor.heartRateSamples.add(heartRate);
    if (rideState.isLapActive) {
      dataProcessor.lapHeartRateSamples.add(heartRate);
    }
  }

  void updateCadenceMetrics(int cadence) {
    rideData.cadence = cadence;
    updateMetric('cadence', '$cadence');

    if (cadence > rideData.maxCadence) {
      rideData.maxCadence = cadence;
    }
    updateMetric('max_cadence', '${rideData.maxCadence}');

    dataProcessor.cadenceSamples.add(cadence);
    if (rideState.isLapActive) {
      dataProcessor.lapCadenceSamples.add(cadence);
    }
  }

  void updateSensorSpeed(double speedKmh) {
    rideData.currentSensorSpeed = speedKmh;
    updateMetric('sensor_speed', speedKmh.toStringAsFixed(1));

    if (speedKmh > rideData.maxSpeed) {
      rideData.maxSpeed = speedKmh;
      updateMetric('max_speed', rideData.maxSpeed.toStringAsFixed(1));
    }

    if (rideState.isLapActive) {
      updateLapMaxSpeed(speedKmh);
    }

    print('Speed updated: ${speedKmh.toStringAsFixed(1)} km/h');
  }

  void updateAltitudeMetrics(double altitude) {
    dataProcessor.updateAltitudeMetrics(
      altitude,
          (alt) {
        rideData.altitude = alt;
        updateMetric('altitude', alt.toStringAsFixed(0));
      },
          (maxAlt) {
        rideData.maxAltitude = maxAlt;
        updateMetric('max_alt', maxAlt.toStringAsFixed(0));
      },
          (gain) {
        rideData.altitudeGain = gain;
        updateMetric('alt_gain', gain.toStringAsFixed(0));
      },
    );
  }

  void updateLapNormalisedPower() {
    if (dataProcessor.lapPowerSamples.length >= 30) {
      rideData.lapNormalised = dataProcessor.calculateNormalisedPower(dataProcessor.lapPowerSamples);
      updateMetric('lap_normalised', rideData.lapNormalised.toStringAsFixed(0));
    }
  }

  void updateMetric(String key, String value) {
    final index = displayedMetrics.indexWhere((m) => m.key == key);
    if (index != -1) {
      displayedMetrics[index] = displayedMetrics[index].copyWith(value: value);
    }
  }

  Future<void> saveRideSession(BluetoothDevice? device) async {
    if (rideData.rideDuration.inSeconds < 5 && dataProcessor.powerSamples.isEmpty) {
      return;
    }

    if (dataProcessor.powerSamples.isNotEmpty) {
      final total = dataProcessor.powerSamples.reduce((a, b) => a + b);
      rideData.avgPower = total ~/ dataProcessor.powerSamples.length;
    }

    if (dataProcessor.heartRateSamples.isNotEmpty) {
      final total = dataProcessor.heartRateSamples.reduce((a, b) => a + b);
      rideData.avgHeartRate = total ~/ dataProcessor.heartRateSamples.length;
    }

    if (dataProcessor.cadenceSamples.isNotEmpty) {
      final total = dataProcessor.cadenceSamples.reduce((a, b) => a + b);
      rideData.avgCadence = total ~/ dataProcessor.cadenceSamples.length;
    }

    if (dataProcessor.powerSamples.length >= 30) {
      updateNormalisedPower();
    }

    final gpsPoints = _getGpsPointsForSession();
    final enrichedGpsPoints = _enrichGpsPoints(gpsPoints);

    final session = RideSession(
      id: DateTime.now().toIso8601String(),
      startTime: timerManager.rideStartTime ?? DateTime.now(),
      durationSeconds: rideData.rideDuration.inSeconds,
      avgPower: rideData.avgPower,
      maxPower: rideData.maxPower,
      deviceName: device?.name,
      gpsPoints: enrichedGpsPoints,
      avgHeartRate: rideData.avgHeartRate,
      maxHeartRate: rideData.maxHeartRate,
      avgCadence: rideData.avgCadence,
      maxCadence: rideData.maxCadence,
      distance: rideData.distance,
      calories: rideData.calories,
      kiloJoules: rideData.powerKjoules,
      normalizedPower: rideData.normalisedPower,
      avgSpeed: rideData.avgSpeed,
      maxSpeed: rideData.maxSpeed,
      wattsPerKilo: rideData.wattsPerKilo,
      power3sAvg: rideData.power3sAvg,
      ftpPercentage: rideData.ftpPercentage,
      hrZone: rideData.hrZone,
      power10sAvg: rideData.power10sAvg,
      power20sAvg: rideData.power20sAvg,
      ftpZone: rideData.ftpZone,
      altitude: dataProcessor.currentAltitude,
      altitudeGain: dataProcessor.totalAltitudeGain,
      maxAltitude: dataProcessor.maxAltitude,
    );

    await storageService.saveSession(session);
  }

  List<Map<String, double>> _enrichGpsPoints(List<Map<String, double>> originalPoints) {
    if (originalPoints.length > 10) {
      return originalPoints;
    }

    final enrichedPoints = <Map<String, double>>[];
    final duration = rideData.rideDuration.inSeconds;

    if (duration > 0 && originalPoints.isNotEmpty) {
      final pointsCount = duration ~/ 5;
      final firstPoint = originalPoints.first;

      for (int i = 0; i < pointsCount; i++) {
        final timeOffset = (i * 5).toDouble();
        enrichedPoints.add({
          'lat': firstPoint['lat'] ?? 0.0,
          'lon': firstPoint['lon'] ?? 0.0,
          'ele': firstPoint['ele'] ?? 0.0,
          'timeOffset': timeOffset,
        });
      }
    } else {
      for (int i = 0; i < 10; i++) {
        enrichedPoints.add({
          'lat': 0.0,
          'lon': 0.0,
          'ele': 0.0,
          'timeOffset': i * 10.0,
        });
      }
    }

    return enrichedPoints;
  }

  List<Map<String, double>> _getGpsPointsForSession() {
    final positions = rideService.gpsPositions;

    if (positions.isEmpty) {
      return [
        {
          'lat': 0.0,
          'lon': 0.0,
          'ele': 0.0,
          'timeOffset': 0.0,
        }
      ];
    }

    return positions.map((position) {
      final timeOffset = position.timestamp != null
          ? position.timestamp!.difference(timerManager.rideStartTime!).inSeconds.toDouble()
          : 0.0;

      return {
        'lat': position.latitude,
        'lon': position.longitude,
        'ele': position.altitude,
        'timeOffset': timeOffset,
      };
    }).toList();
  }

  void dispose() {
    timerManager.dispose();
    rideService.dispose();
  }
}