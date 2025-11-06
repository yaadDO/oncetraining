import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/domain/sensor_type.dart';

class SensorConnectionManager {
  final Map<SensorType, String> connectionStatus = {
    SensorType.powerMeter: "Not connected",
    SensorType.heartRate: "Not connected",
    SensorType.cadence: "Not connected",
    SensorType.speed: "Not connected",
  };

  final Map<SensorType, bool> connectionErrors = {
    SensorType.powerMeter: false,
    SensorType.heartRate: false,
    SensorType.cadence: false,
    SensorType.speed: false,
  };

  bool cadenceFromPowerMeter = false;

  void updateConnectionStatus(SensorType type, String status, {bool error = false}) {
    connectionStatus[type] = status;
    connectionErrors[type] = error;

    // If power meter connects and has cadence capability, update cadence status
    if (type == SensorType.powerMeter && status.contains("Connected") && !error) {
      cadenceFromPowerMeter = true;
      connectionStatus[SensorType.cadence] = "Connected (Power Meter)";
      connectionErrors[SensorType.cadence] = false;
    }

    // If power meter disconnects, also disconnect cadence
    if (type == SensorType.powerMeter && (status.contains("Disconnected") || error)) {
      cadenceFromPowerMeter = false;
      connectionStatus[SensorType.cadence] = "Not connected";
    }
  }

  void resetAllConnections() {
    for (var type in SensorType.values) {
      connectionStatus[type] = "Not connected";
      connectionErrors[type] = false;
    }
    cadenceFromPowerMeter = false;
  }

  String getConnectionStatusText(SensorType type) {
    if (type == SensorType.cadence && cadenceFromPowerMeter) {
      return "Cadence: Connected (Power Meter)";
    }

    final typeName = type.toString().split('.').last;
    final formattedName = typeName.replaceAllMapped(
        RegExp(r'^[a-z]|[A-Z]'),
            (Match m) => m[0] == m[0]!.toLowerCase() ? m[0]!.toUpperCase() : " ${m[0]}"
    ).trim();

    return "$formattedName: ${connectionStatus[type]}";
  }

  bool isConnected(SensorType type) {
    if (type == SensorType.cadence) {
      return connectionStatus[type]!.contains("Connected") || cadenceFromPowerMeter;
    }
    return connectionStatus[type]!.contains("Connected");
  }
}