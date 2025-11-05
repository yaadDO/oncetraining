// [file name]: cycle_screen_controller.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/gpx_storage_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/utils/formatters.dart';
import '../../domain/metric_model.dart';
import '../../domain/ride_data.dart';
import '../../domain/ride_session.dart';
import '../../services/ride_service.dart';

class CycleScreenController {
  final RideData rideData = RideData();
  final RideService rideService;
  final GpxStorageService storageService;
  final PreferencesService preferencesService;

  String connectionStatus = "";
  bool isError = false;
  bool isLocationPermissionGranted = false;
  List<MetricBlock> displayedMetrics = [];
  List<MetricBlock> allMetrics = [];

  Timer? rideTimer;
  Timer? lapTimer;
  DateTime? rideStartTime;
  DateTime? lapStartTime;

  // Data buffers
  final List<int> powerSamples = [];
  final List<int> lapPowerSamples = [];
  final List<int> power3sBuffer = [];
  final List<int> power10sBuffer = [];
  final List<int> power20sBuffer = [];
  final List<int> lapHeartRateSamples = [];
  final List<int> lapCadenceSamples = [];
  final List<int> lastLapPowerSamples = [];
  final List<int> lastLapHeartRateSamples = [];
  final List<int> lastLapCadenceSamples = [];

  // Sensor data buffers
  final List<int> heartRateSamples = [];
  final List<int> cadenceSamples = [];
  final List<int> sensorSpeedSamples = [];
  double lastWheelRevs = 0.0;
  double lastWheelTime = 0.0;

  // Altitude tracking
  double currentAltitude = 0.0;
  double maxAltitude = 0.0;
  double totalAltitudeGain = 0.0;
  double lastRecordedAltitude = 0.0;

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
    rideData.isRiding = true;
    rideStartTime = DateTime.now();
    rideData.rideDuration = Duration.zero;

    // Clear all buffers
    powerSamples.clear();
    heartRateSamples.clear();
    cadenceSamples.clear();
    sensorSpeedSamples.clear();
    power3sBuffer.clear();
    power10sBuffer.clear();
    power20sBuffer.clear();

    // Reset metrics
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
    currentAltitude = 0.0;
    maxAltitude = 0.0;
    totalAltitudeGain = 0.0;
    lastRecordedAltitude = 0.0;

    rideService.reset();
    resetLap();
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

    lapPowerSamples.clear();
    lapHeartRateSamples.clear();
    lapCadenceSamples.clear();

    lapStartTime = DateTime.now();

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
    if (lapTimer != null) {
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
  }

  void stopLap() {
    if (lapTimer != null) {
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
  }

  void calculateLapAverages() {
    if (lapPowerSamples.isNotEmpty) {
      final totalPower = lapPowerSamples.reduce((a, b) => a + b);
      rideData.lapAvgPower = totalPower ~/ lapPowerSamples.length;
    }

    if (lapHeartRateSamples.isNotEmpty) {
      final totalHR = lapHeartRateSamples.reduce((a, b) => a + b);
      rideData.lapAvgHeartRate = totalHR ~/ lapHeartRateSamples.length;
    }

    if (lapCadenceSamples.isNotEmpty) {
      final totalCadence = lapCadenceSamples.reduce((a, b) => a + b);
      rideData.lapAvgCadence = totalCadence ~/ lapCadenceSamples.length;
    }
  }

  void updatePowerAverages(int power) {
    // Update 3s average
    update3sPowerAvg(power);

    // Update 10s average
    power10sBuffer.add(power);
    if (power10sBuffer.length > 10) {
      power10sBuffer.removeAt(0);
    }
    if (power10sBuffer.isNotEmpty) {
      final total = power10sBuffer.reduce((a, b) => a + b);
      rideData.power10sAvg = total ~/ power10sBuffer.length;
      updateMetric('power_10s_avg', '${rideData.power10sAvg}');
    }

    // Update 20s average
    power20sBuffer.add(power);
    if (power20sBuffer.length > 20) {
      power20sBuffer.removeAt(0);
    }
    if (power20sBuffer.isNotEmpty) {
      final total = power20sBuffer.reduce((a, b) => a + b);
      rideData.power20sAvg = total ~/ power20sBuffer.length;
      updateMetric('power_20s_avg', '${rideData.power20sAvg}');
    }

    // Update FTP Zone
    updateFtpZone();
  }

  void updateFtpZone() {
    if (userFtp <= 0) return;

    final percentage = (rideData.currentPower / userFtp) * 100;

    if (percentage < 55) {
      rideData.ftpZone = 1;
    } else if (percentage < 75) {
      rideData.ftpZone = 2;
    } else if (percentage < 90) {
      rideData.ftpZone = 3;
    } else if (percentage < 105) {
      rideData.ftpZone = 4;
    } else if (percentage < 120) {
      rideData.ftpZone = 5;
    } else if (percentage < 150) {
      rideData.ftpZone = 6;
    } else {
      rideData.ftpZone = 7;
    }

    updateMetric('ftp_zone', '${rideData.ftpZone}');
  }

  void updateWattsPerKilo() {
    rideData.wattsPerKilo = rideData.currentPower / userWeight;
    updateMetric('watts_kg', rideData.wattsPerKilo.toStringAsFixed(1));
  }

  void updateCalories() {
    // More accurate calorie calculation based on power
    final hours = rideData.rideDuration.inSeconds / 3600;
    // Calories = power (watts) * time (hours) * 3.6
    rideData.calories = rideData.avgPower * hours * 3.6;
    updateMetric('calories', rideData.calories.toStringAsFixed(0));
  }

  void updateKiloJoules() {
    rideData.powerKjoules = powerSamples.fold(0, (sum, power) => sum + power) ~/ 1000;
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
    if (powerSamples.isEmpty) return;
    final total = powerSamples.reduce((a, b) => a + b);
    rideData.avgPower = total ~/ powerSamples.length;
    updateMetric('avg_power', '${rideData.avgPower}');
  }

  void updateAverageHeartRate() {
    if (heartRateSamples.isEmpty) return;
    final total = heartRateSamples.reduce((a, b) => a + b);
    rideData.avgHeartRate = total ~/ heartRateSamples.length;
    updateMetric('avg_hr', '${rideData.avgHeartRate}');
  }

  void updateAverageCadence() {
    if (cadenceSamples.isEmpty) return;
    final total = cadenceSamples.reduce((a, b) => a + b);
    rideData.avgCadence = total ~/ cadenceSamples.length;
    updateMetric('avg_cadence', '${rideData.avgCadence}');
  }

  void update3sPowerAvg(int power) {
    // Add new power value to buffer
    power3sBuffer.add(power);

    // Keep only last 3 values (assuming 1 value per second)
    if (power3sBuffer.length > 3) {
      power3sBuffer.removeAt(0);
    }

    // Calculate average
    if (power3sBuffer.isNotEmpty) {
      final total = power3sBuffer.reduce((a, b) => a + b);
      rideData.power3sAvg = total ~/ power3sBuffer.length;
      updateMetric('power_3s_avg', '${rideData.power3sAvg}');
    }
  }

  void updateNormalisedPower() {
    if (powerSamples.isEmpty) return;

    // 1. Calculate 30-second rolling average
    final List<double> rollingAverages = [];
    for (int i = 0; i <= powerSamples.length - 30; i++) {
      final sum = powerSamples.sublist(i, i + 30).reduce((a, b) => a + b);
      rollingAverages.add(sum / 30);
    }

    if (rollingAverages.isEmpty) return;

    // 2. Raise to 4th power
    final raisedValues = rollingAverages.map((v) => pow(v, 4)).toList();

    // 3. Calculate average of raised values
    final avgRaised = raisedValues.reduce((a, b) => a + b) / raisedValues.length;

    // 4. Take 4th root
    rideData.normalisedPower = pow(avgRaised, 1/4).toDouble();
    updateMetric('normalised_power', rideData.normalisedPower.toStringAsFixed(0));
  }

  void updateFtpPercentage() {
    if (userFtp <= 0) return;
    rideData.ftpPercentage = (rideData.currentPower / userFtp) * 100;
    updateMetric('ftp_percentage', rideData.ftpPercentage.toStringAsFixed(0));
  }

  void updateHrMetrics(int heartRate) {
    rideData.heartRate = heartRate;

    // Update max HR
    if (heartRate > rideData.maxHeartRate) {
      rideData.maxHeartRate = heartRate;
    }

    // Update HR % of max
    if (userMaxHr > 0) {
      rideData.hrPercentageMax = ((heartRate / userMaxHr) * 100).round();
    }

    // Calculate HR zone
    rideData.hrZone = _calculateHrZone(heartRate);

    // Update metrics
    updateMetric('hr', '$heartRate');
    updateMetric('max_hr', '${rideData.maxHeartRate}');
    updateMetric('hr_percentage_max', '${rideData.hrPercentageMax}%');
    updateMetric('hr_zone', '${rideData.hrZone}');

    // Add to samples
    heartRateSamples.add(heartRate);

    if (lapTimer != null) {
      lapHeartRateSamples.add(heartRate);
    }
  }

  void updateCadenceMetrics(int cadence) {
    rideData.cadence = cadence;

    // Update max cadence
    if (cadence > rideData.maxCadence) {
      rideData.maxCadence = cadence;
    }

    // Update metrics
    updateMetric('cadence', '$cadence');
    updateMetric('max_cadence', '${rideData.maxCadence}');

    // Add to samples
    cadenceSamples.add(cadence);

    if (lapTimer != null) {
      lapCadenceSamples.add(cadence);
    }
  }

  void updateSensorSpeed(double speedKmh) {
    // Directly use the calculated speed from the Bluetooth service
    rideData.currentSensorSpeed = speedKmh;

    updateMetric('sensor_speed', speedKmh.toStringAsFixed(1));

    // Update max speed if needed
    if (speedKmh > rideData.maxSpeed) {
      rideData.maxSpeed = speedKmh;
      updateMetric('max_speed', rideData.maxSpeed.toStringAsFixed(1));
    }

    // Update lap max speed if lap is active
    if (lapTimer != null) {
      updateLapMaxSpeed(speedKmh);
    }

    print('Speed updated: ${speedKmh.toStringAsFixed(1)} km/h');
  }

  void updateAltitudeMetrics(double altitude) {
    rideData.altitude = altitude;
    currentAltitude = altitude;

    // Update max altitude
    if (altitude > maxAltitude) {
      maxAltitude = altitude;
      rideData.maxAltitude = maxAltitude;
    }

    // Calculate altitude gain (only count positive changes)
    if (lastRecordedAltitude > 0) {
      final gain = altitude - lastRecordedAltitude;
      if (gain > 0) { // Only count ascending
        totalAltitudeGain += gain;
        rideData.altitudeGain = totalAltitudeGain;
      }
    }
    lastRecordedAltitude = altitude;

    // Update metrics
    updateMetric('altitude', altitude.toStringAsFixed(0));
    updateMetric('max_alt', maxAltitude.toStringAsFixed(0));
    updateMetric('alt_gain', totalAltitudeGain.toStringAsFixed(0));
  }

  int _calculateHrZone(int heartRate) {
    if (userMaxHr <= 0) return 0;

    final percentage = (heartRate / userMaxHr) * 100;

    if (percentage < 60) return 1;
    if (percentage < 70) return 2;
    if (percentage < 80) return 3;
    if (percentage < 90) return 4;
    return 5;
  }

  void updateLapNormalisedPower() {
    if (lapPowerSamples.length >= 30) {
      final List<double> rollingAverages = [];
      for (int i = 0; i <= lapPowerSamples.length - 30; i++) {
        final sum = lapPowerSamples.sublist(i, i + 30).reduce((a, b) => a + b);
        rollingAverages.add(sum / 30);
      }

      if (rollingAverages.isEmpty) return;

      final raisedValues = rollingAverages.map((v) => pow(v, 4)).toList();
      final avgRaised = raisedValues.reduce((a, b) => a + b) / raisedValues.length;
      rideData.lapNormalised = pow(avgRaised, 1/4).toDouble();
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
    // Don't save if no meaningful ride data exists
    if (rideData.rideDuration.inSeconds < 5 && powerSamples.isEmpty) {
      return;
    }

    // Calculate final averages before saving
    if (powerSamples.isNotEmpty) {
      final total = powerSamples.reduce((a, b) => a + b);
      rideData.avgPower = total ~/ powerSamples.length;
    }

    if (heartRateSamples.isNotEmpty) {
      final total = heartRateSamples.reduce((a, b) => a + b);
      rideData.avgHeartRate = total ~/ heartRateSamples.length;
    }

    if (cadenceSamples.isNotEmpty) {
      final total = cadenceSamples.reduce((a, b) => a + b);
      rideData.avgCadence = total ~/ cadenceSamples.length;
    }

    // Calculate normalized power if we have enough samples
    if (powerSamples.length >= 30) {
      updateNormalisedPower();
    }

    // Ensure we have GPS data for Strava
    final gpsPoints = _getGpsPointsForSession();

    // If we have very few GPS points, create interpolated points for Strava
    final enrichedGpsPoints = _enrichGpsPoints(gpsPoints);

    final session = RideSession(
      id: DateTime.now().toIso8601String(),
      startTime: rideStartTime ?? DateTime.now(),
      durationSeconds: rideData.rideDuration.inSeconds,
      avgPower: rideData.avgPower,
      maxPower: rideData.maxPower,
      deviceName: device?.name,
      gpsPoints: enrichedGpsPoints, // Use enriched GPS points
      // ... rest of your parameters
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
      altitude: currentAltitude,
      altitudeGain: totalAltitudeGain,
      maxAltitude: maxAltitude,
    );

    await storageService.saveSession(session);
  }

  List<Map<String, double>> _enrichGpsPoints(List<Map<String, double>> originalPoints) {
    if (originalPoints.length > 10) {
      return originalPoints; // We have enough points
    }

    // If we have very few points, create interpolated points for Strava
    final enrichedPoints = <Map<String, double>>[];
    final duration = rideData.rideDuration.inSeconds;

    if (duration > 0 && originalPoints.isNotEmpty) {
      // Create points at regular intervals
      final pointsCount = duration ~/ 5; // One point every 5 seconds
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
      // Fallback: ensure at least 10 points
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
      // If no GPS data, create minimal data points for Strava
      return [
        {
          'lat': 0.0,
          'lon': 0.0,
          'ele': 0.0,
          'timeOffset': 0.0,
        }
      ];
    }

    // Convert positions to the format expected by GPX storage
    return positions.map((position) {
      final timeOffset = position.timestamp != null
          ? position.timestamp!.difference(rideStartTime!).inSeconds.toDouble()
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
    rideTimer?.cancel();
    lapTimer?.cancel();
    rideService.dispose();
  }
}