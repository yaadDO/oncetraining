import 'package:flutter/material.dart';
import 'package:oncetraining/bluetooth/services/bluetooth_service.dart' show PowerMeterService;
import '../../../core/domain/sensor_type.dart';

import '../pages/cycle_screen_controller.dart';

class SensorAppBar extends StatelessWidget {
  final CycleScreenController controller;
  final PowerMeterService powerService;
  final VoidCallback onBackPressed;
  final VoidCallback onMetricEditorPressed;
  final VoidCallback onSensorSelectionPressed;

  const SensorAppBar({
    super.key,
    required this.controller,
    required this.powerService,
    required this.onBackPressed,
    required this.onMetricEditorPressed,
    required this.onSensorSelectionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 15),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: onBackPressed,
          ),
          Spacer(),
          _buildSensorIcon(SensorType.powerMeter, Icons.flash_on),
          _buildSensorIcon(SensorType.heartRate, Icons.favorite),
          _buildSensorIcon(SensorType.cadence, Icons.repeat),
          _buildSensorIcon(SensorType.speed, Icons.speed),
          SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.grid_on, color: Colors.white, size: 28),
            onPressed: onMetricEditorPressed,
          ),
          SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.bluetooth, color: Colors.white, size: 28),
            onPressed: onSensorSelectionPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildSensorIcon(SensorType type, IconData icon) {
    final bool isConnected = controller.sensorManager.isConnected(type);
    final bool hasError = controller.sensorManager.connectionErrors[type]!;

    // Special handling for cadence from power meter
    final bool isCadenceFromPower =
        type == SensorType.cadence &&
            controller.sensorManager.cadenceFromPowerMeter &&
            controller.sensorManager.connectionStatus[SensorType.powerMeter]!.contains("Connected");

    Color iconColor;

    if (hasError) {
      iconColor = Colors.red;
    } else if (isConnected || isCadenceFromPower) {
      iconColor = Colors.green;
    } else {
      iconColor = Colors.yellow;
    }

    return Tooltip(
      message: controller.sensorManager.getConnectionStatusText(type),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class SensorConnectionStatus extends StatelessWidget {
  final CycleScreenController controller;
  final PowerMeterService powerService;

  const SensorConnectionStatus({
    super.key,
    required this.controller,
    required this.powerService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        children: [
          for (var type in SensorType.values)
            if (_shouldShowStatus(type))
              Chip(
                label: Text(
                  controller.sensorManager.getConnectionStatusText(type as SensorType),
                  style: TextStyle(
                    color: controller.sensorManager.connectionErrors[type]!
                        ? Colors.red[300]
                        : Colors.green[300],
                    fontSize: 14,
                  ),
                ),
                backgroundColor: Colors.black.withOpacity(0.2),
              ),
        ],
      ),
    );
  }

  bool _shouldShowStatus(SensorType type) {
    return controller.sensorManager.connectionErrors[type]! ||
        controller.sensorManager.connectionStatus[type]!.contains("Error") ||
        controller.sensorManager.connectionStatus[type]!.contains("Connected") ||
        (type == SensorType.cadence &&
            controller.sensorManager.connectionStatus[SensorType.powerMeter]!.contains("Connected") &&
            powerService.cadenceFromPowerMeter);
  }
}