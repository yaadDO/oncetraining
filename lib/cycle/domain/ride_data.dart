class RideData {
  bool isRiding = false;
  Duration rideDuration = Duration.zero;
  int currentPower = 0;
  int avgPower = 0;
  int maxPower = 0;
  double currentSpeed = 0.0;
  double maxSpeed = 0.0;
  int lapCount = 0;
  int cadence = 0;
  int heartRate = 0;
  double distance = 0.0;
  double wattsPerKilo = 0.0;
  int powerKjoules = 0;
  double calories = 0.0;
  double avgSpeed = 0.0;
  int avgCadence = 0;
  int avgHeartRate = 0;

  // Added maxCadence and maxHeartRate with setters
  int maxCadence = 0;
  int maxHeartRate = 0;

  // Lap metrics
  Duration lapDuration = Duration.zero;
  double lapDistance = 0.0;
  double lapAvgSpeed = 0.0;
  int lapAvgPower = 0;
  int lapAvgHeartRate = 0;
  int lapMaxPower = 0;
  int lapAvgCadence = 0;

  // Last lap metrics
  int lastLapAvgPower = 0;
  int lastLapMaxPower = 0;
  double lastLapAvgSpeed = 0.0;
  double lastLapDistance = 0.0;
  Duration lastLapTime = Duration.zero;
  int lastLapAvgHr = 0;
  int lastLapAvgCadence = 0;

  // 3-second power
  int power3sAvg = 0;

  double normalisedPower = 0.0;
  double ftpPercentage = 0.0;
  double lapNormalised = 0.0;
  int hrPercentageMax = 0;
  int hrZone = 0;

  int currentHeartRate = 0;
  int currentCadence = 0;
  double currentSensorSpeed = 0.0;
  double wheelCircumference = 2.1;

  int power10sAvg = 0;
  int power20sAvg = 0;
  int ftpZone = 0;

  // New altitude metrics
  double altitude = 0.0;
  double altitudeGain = 0.0;
  double maxAltitude = 0.0;
  double lastAltitude = 0.0;

  // Existing metrics we need to ensure are tracked
  double lapMaxSpeed = 0.0;
}