class RideStateManager {
  bool _isRiding = false;
  bool _isLapActive = false;

  bool get isRiding => _isRiding;
  bool get isLapActive => _isLapActive;

  void startRide() {
    _isRiding = true;
  }

  void stopRide() {
    _isRiding = false;
    _isLapActive = false;
  }

  void startLap() {
    _isLapActive = true;
  }

  void stopLap() {
    _isLapActive = false;
  }

  void toggleLap() {
    _isLapActive = !_isLapActive;
  }
}