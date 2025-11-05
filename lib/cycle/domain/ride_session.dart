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
  final int power10sAvg;
  final int power20sAvg;
  final int ftpZone;
  final double altitude;
  final double altitudeGain;
  final double maxAltitude;

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

    // New metrics with defaults
    this.power10sAvg = 0,
    this.power20sAvg = 0,
    this.ftpZone = 0,
    this.altitude = 0.0,
    this.altitudeGain = 0.0,
    this.maxAltitude = 0.0,
  });
}