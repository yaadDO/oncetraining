class RideSession {
  final String id;
  final DateTime startTime;
  final int durationSeconds;
  final int avgPower;
  final int maxPower;
  final String? deviceName;
  final List<Map<String, double>> gpsPoints;

  // Sensor metrics
  final int avgHeartRate;
  final int maxHeartRate;
  final int avgCadence;
  final int maxCadence;

  // Additional metrics
  final double distance;
  final double calories;
  final int kiloJoules;
  final double normalizedPower;
  final double avgSpeed;
  final double maxSpeed;
  final double wattsPerKilo;
  final int power3sAvg;
  final double ftpPercentage;
  final int hrZone;

  RideSession({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.avgPower,
    required this.maxPower,
    this.deviceName,
    required this.gpsPoints,
    // Initialize new fields with default values
    this.avgHeartRate = 0,
    this.maxHeartRate = 0,
    this.avgCadence = 0,
    this.maxCadence = 0,
    // Additional metrics
    required this.distance,
    required this.calories,
    required this.kiloJoules,
    required this.normalizedPower,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.wattsPerKilo,
    required this.power3sAvg,
    required this.ftpPercentage,
    required this.hrZone,
  });
}