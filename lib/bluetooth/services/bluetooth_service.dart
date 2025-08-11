import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/permissions.dart';

// Add sensor type enum
enum SensorType {
  powerMeter,
  heartRate,
  cadence,
  speed,
}

class PowerMeterService {
  static final Guid CYCLING_POWER_SERVICE = Guid("00001818-0000-1000-8000-00805f9b34fb");
  static final Guid POWER_MEASUREMENT_CHAR = Guid("00002A63-0000-1000-8000-00805f9b34fb");

  // New sensor UUIDs
  static final Guid HEART_RATE_SERVICE = Guid("0000180D-0000-1000-8000-00805f9b34fb");
  static final Guid HEART_RATE_MEASUREMENT_CHAR = Guid("00002A37-0000-1000-8000-00805f9b34fb");
  static final Guid CYCLING_SPEED_CADENCE_SERVICE = Guid("00001816-0000-1000-8000-00805f9b34fb");
  static final Guid CSC_MEASUREMENT_CHAR = Guid("00002A5B-0000-1000-8000-00805f9b34fb");
  static final Guid SPEED_SERVICE = Guid("00001816-0000-1000-8000-00805f9b34fb"); // Same as CSC
  static final Guid SPEED_MEASUREMENT_CHAR = Guid("00002A5B-0000-1000-8000-00805f9b34fb"); // Same as CSC

  // Track devices for each sensor type
  final Map<SensorType, BluetoothDevice?> _devices = {
    SensorType.powerMeter: null,
    SensorType.heartRate: null,
    SensorType.cadence: null,
    SensorType.speed: null,
  };

  // Track characteristics for each sensor type
  final Map<SensorType, BluetoothCharacteristic?> _characteristics = {
    SensorType.powerMeter: null,
    SensorType.heartRate: null,
    SensorType.cadence: null,
    SensorType.speed: null,
  };

  // Track connection status for each sensor type
  final Map<SensorType, String> _connectionStatus = {
    SensorType.powerMeter: "Not connected",
    SensorType.heartRate: "Not connected",
    SensorType.cadence: "Not connected",
    SensorType.speed: "Not connected",
  };

  // Track connection errors for each sensor type
  final Map<SensorType, bool> _connectionErrors = {
    SensorType.powerMeter: false,
    SensorType.heartRate: false,
    SensorType.cadence: false,
    SensorType.speed: false,
  };

  // Add this to track if cadence is coming from power meter
  bool _cadenceFromPowerMeter = false;

  // Add these for device scanning
  final _foundDevices = <BluetoothDevice>[];
  final _scanResultsController = StreamController<List<BluetoothDevice>>.broadcast();
  Stream<List<BluetoothDevice>> get scanResults => _scanResultsController.stream;
  bool _isScanning = false;
  SensorType? _currentScanType;

  // Data streams
  final _powerController = StreamController<int>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _cadenceController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();

  Stream<int> get powerStream => _powerController.stream;
  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<int> get cadenceStream => _cadenceController.stream;
  Stream<double> get speedStream => _speedController.stream;

  // Add method to get connection status
  String getConnectionStatus(SensorType type) => _connectionStatus[type]!;

  // Add method to check if there's an error
  bool hasConnectionError(SensorType type) => _connectionErrors[type]!;

  // Add method to check if connected
  bool isConnected(SensorType type) => _connectionStatus[type] == "Connected";

  Future<void> startScan(SensorType sensorType) async {
    _currentScanType = sensorType;
    await _requestPermissions();

    if (!_isScanning) {
      _foundDevices.clear();
      _isScanning = true;
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) {
        final newDevices = <BluetoothDevice>[];
        for (ScanResult r in results) {
          if (!_foundDevices.contains(r.device)) {
            // Case-insensitive check + null safety
            final deviceName = r.device.name ?? '';
            final is4iiii = deviceName.toLowerCase().contains('4iiii');
            final hasPowerService = r.advertisementData.serviceUuids.contains(CYCLING_POWER_SERVICE);
            final hasHeartRateService = r.advertisementData.serviceUuids.contains(HEART_RATE_SERVICE);
            final hasCadenceService = r.advertisementData.serviceUuids.contains(CYCLING_SPEED_CADENCE_SERVICE);
            final hasSpeedService = r.advertisementData.serviceUuids.contains(SPEED_SERVICE);

            bool shouldAdd = false;

            switch (sensorType) {
              case SensorType.powerMeter:
                shouldAdd = is4iiii || hasPowerService;
                break;
              case SensorType.heartRate:
                shouldAdd = hasHeartRateService;
                break;
              case SensorType.cadence:
                shouldAdd = hasCadenceService;
                break;
              case SensorType.speed:
                shouldAdd = hasSpeedService;
                break;
            }

            if (shouldAdd) {
              newDevices.add(r.device);
            }
          }
        }

        if (newDevices.isNotEmpty) {
          _foundDevices.addAll(newDevices);
          _scanResultsController.add(List.from(_foundDevices));
        }
      });
    }
  }

  Future<void> _requestPermissions() async {
    await requestBluetoothPermissions();
  }

  void stopScan() {
    if (_isScanning) {
      FlutterBluePlus.stopScan();
      _isScanning = false;
    }
  }

  Future<void> connect(SensorType sensorType, BluetoothDevice device) async {
    try {
      _devices[sensorType] = device;
      _connectionStatus[sensorType] = "Connecting...";
      _connectionErrors[sensorType] = false;

      await device.connect();
      await _discoverServices(sensorType);

      // Automatically use power meter cadence if available
      if (sensorType == SensorType.powerMeter && _characteristics[SensorType.powerMeter] != null) {
        _cadenceFromPowerMeter = true;
        _connectionStatus[SensorType.cadence] = "Connected (Power Meter)";
      }
    } catch (e) {
      _connectionStatus[sensorType] = "Error: ${e.toString()}";
      _connectionErrors[sensorType] = true;
    }
  }

  Future<void> _discoverServices(SensorType sensorType) async {
    final device = _devices[sensorType];
    if (device == null) return;

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      switch (sensorType) {
        case SensorType.powerMeter:
          if (service.uuid == CYCLING_POWER_SERVICE) {
            for (var characteristic in service.characteristics) {
              if (characteristic.uuid == POWER_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parsePowerData);
                _connectionStatus[sensorType] = "Connected";
              }
            }
          }
          break;
        case SensorType.heartRate:
          if (service.uuid == HEART_RATE_SERVICE) {
            for (var characteristic in service.characteristics) {
              if (characteristic.uuid == HEART_RATE_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parseHeartRateData);
                _connectionStatus[sensorType] = "Connected";
              }
            }
          }
          break;
        case SensorType.cadence:
        // Skip if cadence is already provided by power meter
          if (_cadenceFromPowerMeter) break;

          if (service.uuid == CYCLING_SPEED_CADENCE_SERVICE) {
            for (var characteristic in service.characteristics) {
              if (characteristic.uuid == CSC_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parseCadenceData);
                _connectionStatus[sensorType] = "Connected";
              }
            }
          }
          break;
        case SensorType.speed:
          if (service.uuid == SPEED_SERVICE) {
            for (var characteristic in service.characteristics) {
              if (characteristic.uuid == SPEED_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parseSpeedData);
                _connectionStatus[sensorType] = "Connected";
              }
            }
          }
          break;
      }
    }

    // Update status if no characteristic was found
    if (_characteristics[sensorType] == null) {
      _connectionStatus[sensorType] = "Service not found";
      _connectionErrors[sensorType] = true;
    }
  }

  void _parsePowerData(List<int> value) {
    if (value.length >= 4) {
      final power = (value[3] << 8) | value[2];
      if (power < 65535) {
        _powerController.add(power);
      }

      // Use built-in cadence from power meter if available
      if (value.length >= 6) {
        final cadence = value[4];
        if (cadence > 0) {
          _cadenceController.add(cadence);
        }
      }
    }
  }

  void _parseHeartRateData(List<int> value) {
    if (value.isNotEmpty) {
      // First byte: Flags
      // Second byte: Heart Rate Value (uint8)
      final hr = value[1];
      _heartRateController.add(hr);
    }
  }

  void _parseCadenceData(List<int> value) {
    if (value.length >= 3) {
      // Cadence is in revolutions per minute (RPM)
      final cadence = value[0];
      _cadenceController.add(cadence);
    }
  }

  void _parseSpeedData(List<int> value) {
    if (value.length >= 7) {
      // Cumulative Wheel Revolutions (UINT32) + Last Wheel Event Time (UINT16)
      final wheelRevs = (value[3] << 24) | (value[2] << 16) | (value[1] << 8) | value[0];
      final eventTime = (value[5] << 8) | value[4];

      // Pass both values to controller
      _speedController.add(wheelRevs.toDouble());
    }
  }

  Future<void> disconnect(SensorType sensorType) async {
    await _characteristics[sensorType]?.setNotifyValue(false);
    await _devices[sensorType]?.disconnect();

    _characteristics[sensorType] = null;
    _devices[sensorType] = null;
    _connectionStatus[sensorType] = "Disconnected";
    _connectionErrors[sensorType] = false;

    // Reset cadence source if disconnecting power meter
    if (sensorType == SensorType.powerMeter && _cadenceFromPowerMeter) {
      _cadenceFromPowerMeter = false;
      _connectionStatus[SensorType.cadence] = "Not connected";
    }
  }

  void disconnectAll() async {
    for (var type in SensorType.values) {
      if (isConnected(type)) {
        await disconnect(type);
      }
    }
  }

  void dispose() {
    disconnectAll();
    _scanResultsController.close();
    _powerController.close();
    _heartRateController.close();
    _cadenceController.close();
    _speedController.close();
  }
}