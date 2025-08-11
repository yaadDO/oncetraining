import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/gpx_storage_service.dart';
import '../../../core/services/preferences_service.dart';
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
      'power', 'speed', 'avg_speed', 'lap_max_speed', 'last_lap_avg_speed',
      'lap_avg_speed', 'max_speed', 'time', 'local_time', 'last_lap_time',
      'lap_count', 'lap_time', 'trip_time', 'ride_time', 'distance',
      'lap_distance', 'last_lap_distance', 'kj', 'calories', 'hr', 'avg_hr',
      'max_hr', 'hr_percentage_max', 'hr_zone', 'lap_avg_hr', 'last_lap_avg_hr',
      'cadence', 'avg_cadence', 'max_cadence', 'lap_avg_cadence',
      'last_lap_avg_cadence', 'watts_kg', 'lap_avg_power', 'lap_max_power',
      'power_3s_avg', 'normalised_power', 'ftp_percentage', 'last_lap_avg_power',
      'last_lap_max_power', 'lap_normalised', 'sensor_speed'
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
    powerSamples.clear();
    heartRateSamples.clear();
    cadenceSamples.clear();
    sensorSpeedSamples.clear();
    rideData.avgPower = 0;
    rideData.maxPower = 0;
    rideData.powerKjoules = 0;
    rideData.calories = 0.0;
    rideService.reset();
    rideData.maxSpeed = 0.0;
    rideData.maxCadence = 0;
    rideData.maxHeartRate = 0;
    rideData.lapCount = 0;

    // Reset metrics
    rideData.cadence = 0;
    rideData.heartRate = 0;
    rideData.avgSpeed = 0.0;
    rideData.avgCadence = 0;
    rideData.avgHeartRate = 0;
    rideData.normalisedPower = 0.0;
    rideData.ftpPercentage = 0.0;
    rideData.hrPercentageMax = 0;
    rideData.hrZone = 0;

    // Reset lap metrics
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
    lapPowerSamples.clear();
    lapHeartRateSamples.clear();
    lapCadenceSamples.clear();
    lapStartTime = DateTime.now();
  }

  void startLap() {
    // Save previous lap data
    if (lapTimer != null) {
      rideData.lastLapAvgPower = rideData.lapAvgPower;
      rideData.lastLapMaxPower = rideData.lapMaxPower;
      rideData.lastLapAvgSpeed = rideData.lapAvgSpeed;
      rideData.lastLapDistance = rideData.lapDistance;
      rideData.lastLapTime = rideData.lapDuration;
      rideData.lastLapAvgHr = rideData.lapAvgHeartRate;
      rideData.lastLapAvgCadence = rideData.lapAvgCadence;
      lastLapPowerSamples.addAll(lapPowerSamples);
      lastLapHeartRateSamples.addAll(lapHeartRateSamples);
      lastLapCadenceSamples.addAll(lapCadenceSamples);
    }

    rideData.lapCount++;
    resetLap();
  }

  void stopLap() {
    lapTimer?.cancel();
    calculateLapAverages();
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

  void updateSensorSpeed(double wheelRevs, double eventTime) {
    if (lastWheelRevs > 0 && lastWheelTime > 0) {
      final revolutions = wheelRevs - lastWheelRevs;
      final timeDelta = (eventTime - lastWheelTime) / 1024.0; // Time in seconds

      if (timeDelta > 0) {
        // Calculate speed in m/s: (wheel revolutions * circumference) / time
        final speedMs = (revolutions * rideData.wheelCircumference) / timeDelta;
        // Convert to km/h
        final speedKmh = speedMs * 3.6;

        rideData.currentSensorSpeed = speedKmh;
        updateMetric('sensor_speed', speedKmh.toStringAsFixed(1));

        // Update max speed if needed
        if (speedKmh > rideData.maxSpeed) {
          rideData.maxSpeed = speedKmh;
          updateMetric('max_speed', rideData.maxSpeed.toStringAsFixed(1));
        }
      }
    }

    // Update last values
    lastWheelRevs = wheelRevs;
    lastWheelTime = eventTime;
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
    if (lapPowerSamples.isNotEmpty) {

      // Same algorithm as normalised power but for lap samples
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
    if (rideStartTime == null || powerSamples.isEmpty) return;

    final session = RideSession(
      id: DateTime.now().toIso8601String(),
      startTime: rideStartTime!,
      durationSeconds: rideData.rideDuration.inSeconds,
      avgPower: rideData.avgPower,
      maxPower: rideData.maxPower,
      deviceName: device?.name,
      gpsPoints: [],
      // Sensor data
      avgHeartRate: rideData.avgHeartRate,
      maxHeartRate: rideData.maxHeartRate,
      avgCadence: rideData.avgCadence,
      maxCadence: rideData.maxCadence,
      // Additional metrics
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
    );

    await storageService.saveSession(session);
  }

  void dispose() {
    rideTimer?.cancel();
    lapTimer?.cancel();
    rideService.dispose();
  }
}