class RideSession {
  final String id;
  final DateTime startTime;
  final int durationSeconds;
  final int avgPower;
  final int maxPower;
  final String? deviceName;
  final List<Map<String, double>> gpsPoints;
  final List<RideDataPoint> dataPoints;
  final int avgHeartRate;
  final int maxHeartRate;
  final int avgCadence;
  final int maxCadence;
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
  final List<LapData> laps;

  RideSession({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.avgPower,
    required this.maxPower,
    this.deviceName,
    required this.gpsPoints,
    required this.dataPoints,
    this.avgHeartRate = 0,
    this.maxHeartRate = 0,
    this.avgCadence = 0,
    this.maxCadence = 0,
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
    this.power10sAvg = 0,
    this.power20sAvg = 0,
    this.ftpZone = 0,
    this.altitude = 0.0,
    this.altitudeGain = 0.0,
    this.maxAltitude = 0.0,
    this.laps = const [],
  });
}

class RideDataPoint {
  final DateTime timestamp;
  final int power;
  final int heartRate;
  final int cadence;
  final double speed;
  final double distance;
  final double altitude;

  RideDataPoint({
    required this.timestamp,
    required this.power,
    required this.heartRate,
    required this.cadence,
    required this.speed,
    required this.distance,
    required this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'power': power,
      'heartRate': heartRate,
      'cadence': cadence,
      'speed': speed,
      'distance': distance,
      'altitude': altitude,
    };
  }

  factory RideDataPoint.fromJson(Map<String, dynamic> json) {
    return RideDataPoint(
      timestamp: DateTime.parse(json['timestamp']),
      power: json['power'] ?? 0,
      heartRate: json['heartRate'] ?? 0,
      cadence: json['cadence'] ?? 0,
      speed: json['speed']?.toDouble() ?? 0.0,
      distance: json['distance']?.toDouble() ?? 0.0,
      altitude: json['altitude']?.toDouble() ?? 0.0,
    );
  }
}

class LapData {
  final int lapNumber;
  final Duration duration;
  final double distance;
  final int avgPower;
  final int maxPower;
  final double avgSpeed;
  final double maxSpeed;
  final int avgHeartRate;
  final int avgCadence;
  final double normalizedPower;

  LapData({
    required this.lapNumber,
    required this.duration,
    required this.distance,
    required this.avgPower,
    required this.maxPower,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.avgHeartRate,
    required this.avgCadence,
    required this.normalizedPower,
  });

  Map<String, dynamic> toJson() {
    return {
      'lapNumber': lapNumber,
      'duration': duration.inSeconds,
      'distance': distance,
      'avgPower': avgPower,
      'maxPower': maxPower,
      'avgSpeed': avgSpeed,
      'maxSpeed': maxSpeed,
      'avgHeartRate': avgHeartRate,
      'avgCadence': avgCadence,
      'normalizedPower': normalizedPower,
    };
  }

  factory LapData.fromJson(Map<String, dynamic> json) {
    return LapData(
      lapNumber: json['lapNumber'] ?? 0,
      duration: Duration(seconds: json['duration'] ?? 0),
      distance: json['distance']?.toDouble() ?? 0.0,
      avgPower: json['avgPower'] ?? 0,
      maxPower: json['maxPower'] ?? 0,
      avgSpeed: json['avgSpeed']?.toDouble() ?? 0.0,
      maxSpeed: json['maxSpeed']?.toDouble() ?? 0.0,
      avgHeartRate: json['avgHeartRate'] ?? 0,
      avgCadence: json['avgCadence'] ?? 0,
      normalizedPower: json['normalizedPower']?.toDouble() ?? 0.0,
    );
  }
}