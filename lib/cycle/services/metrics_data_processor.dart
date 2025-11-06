import 'dart:math';

class MetricsDataProcessor {
  // Data buffers
  final List<int> powerSamples = [];
  final List<int> lapPowerSamples = [];
  final List<int> power3sBuffer = [];
  final List<int> power10sBuffer = [];
  final List<int> power20sBuffer = [];
  final List<int> lapHeartRateSamples = [];
  final List<int> lapCadenceSamples = [];
  final List<int> heartRateSamples = [];
  final List<int> cadenceSamples = [];
  final List<int> sensorSpeedSamples = [];

  // Altitude tracking
  double currentAltitude = 0.0;
  double maxAltitude = 0.0;
  double totalAltitudeGain = 0.0;
  double lastRecordedAltitude = 0.0;

  void clearAllBuffers() {
    powerSamples.clear();
    lapPowerSamples.clear();
    power3sBuffer.clear();
    power10sBuffer.clear();
    power20sBuffer.clear();
    lapHeartRateSamples.clear();
    lapCadenceSamples.clear();
    heartRateSamples.clear();
    cadenceSamples.clear();
    sensorSpeedSamples.clear();
  }

  void clearLapBuffers() {
    lapPowerSamples.clear();
    lapHeartRateSamples.clear();
    lapCadenceSamples.clear();
  }

  void updatePowerAverages(int power, Function(int) update3sAvg, Function(int) update10sAvg, Function(int) update20sAvg) {
    // Update 3s average
    update3sPowerAvg(power, update3sAvg);

    // Update 10s average
    power10sBuffer.add(power);
    if (power10sBuffer.length > 10) {
      power10sBuffer.removeAt(0);
    }
    if (power10sBuffer.isNotEmpty) {
      final total = power10sBuffer.reduce((a, b) => a + b);
      update10sAvg(total ~/ power10sBuffer.length);
    }

    // Update 20s average
    power20sBuffer.add(power);
    if (power20sBuffer.length > 20) {
      power20sBuffer.removeAt(0);
    }
    if (power20sBuffer.isNotEmpty) {
      final total = power20sBuffer.reduce((a, b) => a + b);
      update20sAvg(total ~/ power20sBuffer.length);
    }
  }

  void update3sPowerAvg(int power, Function(int) update3sAvg) {
    power3sBuffer.add(power);
    if (power3sBuffer.length > 3) {
      power3sBuffer.removeAt(0);
    }
    if (power3sBuffer.isNotEmpty) {
      final total = power3sBuffer.reduce((a, b) => a + b);
      update3sAvg(total ~/ power3sBuffer.length);
    }
  }

  double calculateNormalisedPower(List<int> samples) {
    if (samples.length < 30) return 0.0;

    final List<double> rollingAverages = [];
    for (int i = 0; i <= samples.length - 30; i++) {
      final sum = samples.sublist(i, i + 30).reduce((a, b) => a + b);
      rollingAverages.add(sum / 30);
    }

    final raisedValues = rollingAverages.map((v) => pow(v, 4)).toList();
    final avgRaised = raisedValues.reduce((a, b) => a + b) / raisedValues.length;
    return pow(avgRaised, 1/4).toDouble();
  }

  void updateAltitudeMetrics(double altitude, Function(double) updateAltitude, Function(double) updateMaxAltitude, Function(double) updateAltitudeGain) {
    currentAltitude = altitude;
    updateAltitude(altitude);

    if (altitude > maxAltitude) {
      maxAltitude = altitude;
      updateMaxAltitude(maxAltitude);
    }

    if (lastRecordedAltitude > 0) {
      final gain = altitude - lastRecordedAltitude;
      if (gain > 0) {
        totalAltitudeGain += gain;
        updateAltitudeGain(totalAltitudeGain);
      }
    }
    lastRecordedAltitude = altitude;
  }

  int calculateHrZone(int heartRate, int userMaxHr) {
    if (userMaxHr <= 0) return 0;
    final percentage = (heartRate / userMaxHr) * 100;

    if (percentage < 60) return 1;
    if (percentage < 70) return 2;
    if (percentage < 80) return 3;
    if (percentage < 90) return 4;
    return 5;
  }

  int calculateFtpZone(double percentage) {
    if (percentage < 55) return 1;
    if (percentage < 75) return 2;
    if (percentage < 90) return 3;
    if (percentage < 105) return 4;
    if (percentage < 120) return 5;
    if (percentage < 150) return 6;
    return 7;
  }
}