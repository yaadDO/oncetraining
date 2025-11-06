import '../../core/domain/sensor_type.dart';

class SensorListenerService {
  final Function(int) onPowerUpdate;
  final Function(int) onHeartRateUpdate;
  final Function(int) onCadenceUpdate;
  final Function(double) onSpeedUpdate;
  final Function(SensorType, String, bool) onConnectionUpdate;

  SensorListenerService({
    required this.onPowerUpdate,
    required this.onHeartRateUpdate,
    required this.onCadenceUpdate,
    required this.onSpeedUpdate,
    required this.onConnectionUpdate,
  });

  void setupPowerListener(Stream<int> powerStream) {
    powerStream.listen((power) {
      onPowerUpdate(power);
      onConnectionUpdate(SensorType.powerMeter, "Connected", false);
    }, onError: (error) {
      onConnectionUpdate(SensorType.powerMeter, "Error: $error", true);
    });
  }

  void setupHeartRateListener(Stream<int> heartRateStream) {
    heartRateStream.listen((hr) {
      onHeartRateUpdate(hr);
      onConnectionUpdate(SensorType.heartRate, "Connected", false);
    }, onError: (error) {
      onConnectionUpdate(SensorType.heartRate, "Error: $error", true);
    });
  }

  void setupCadenceListener(Stream<int> cadenceStream) {
    cadenceStream.listen((cadence) {
      onCadenceUpdate(cadence);
      onConnectionUpdate(SensorType.cadence, "Connected", false);
    }, onError: (error) {
      onConnectionUpdate(SensorType.cadence, "Error: $error", true);
    });
  }

  void setupSpeedListener(Stream<double> speedStream) {
    speedStream.listen((speed) {
      onSpeedUpdate(speed);
      onConnectionUpdate(SensorType.speed, "Connected", false);
    }, onError: (error) {
      onConnectionUpdate(SensorType.speed, "Error: $error", true);
    });
  }
}