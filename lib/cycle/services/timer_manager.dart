import 'dart:async';

class TimerManager {
  Timer? rideTimer;
  Timer? lapTimer;
  DateTime? rideStartTime;
  DateTime? lapStartTime;

  void startRideTimer(void Function(Duration) onTick) {
    rideStartTime = DateTime.now();
    rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final duration = DateTime.now().difference(rideStartTime!);
      onTick(duration);
    });
  }

  void startLapTimer(void Function(Duration) onTick) {
    lapStartTime = DateTime.now();
    lapTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final duration = DateTime.now().difference(lapStartTime!);
      onTick(duration);
    });
  }

  void stopRideTimer() {
    rideTimer?.cancel();
    rideTimer = null;
  }

  void stopLapTimer() {
    lapTimer?.cancel();
    lapTimer = null;
  }

  void dispose() {
    rideTimer?.cancel();
    lapTimer?.cancel();
  }
}