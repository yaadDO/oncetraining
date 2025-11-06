import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/permissions.dart';
import '../../core/domain/sensor_type.dart'; // ADD THIS IMPORT

// REMOVE THIS DUPLICATE ENUM:
// enum SensorType {
//   powerMeter,
//   heartRate,
//   cadence,
//   speed,
// }

class PowerMeterService {
  static final Guid CYCLING_POWER_SERVICE = Guid("00001818-0000-1000-8000-00805f9b34fb");
  static final Guid POWER_MEASUREMENT_CHAR = Guid("00002A63-0000-1000-8000-00805f9b34fb");

  // New sensor UUIDs
  static final Guid HEART_RATE_SERVICE = Guid("0000180D-0000-1000-8000-00805f9b34fb");
  static final Guid HEART_RATE_MEASUREMENT_CHAR = Guid("00002A37-0000-1000-8000-00805f9b34fb");
  static final Guid CYCLING_SPEED_CADENCE_SERVICE = Guid("00001816-0000-1000-8000-00805f9b34fb");
  static final Guid CSC_MEASUREMENT_CHAR = Guid("00002A5B-0000-1000-8000-00805f9b34fb");

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
  bool get cadenceFromPowerMeter => _cadenceFromPowerMeter;

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

  // FIX: Instance variables for cadence calculation (not static)
  int _lastCumulativeRevs = 0;
  int _lastEventTime = 0;
  int _lastCadence = 0;

  // FIX: Instance variables for speed calculation
  int _lastCumulativeWheelRevs = 0;
  int _lastWheelEventTime = 0;
  double _lastSpeed = 0.0;

  // Add method to get connection status
  String getConnectionStatus(SensorType type) => _connectionStatus[type]!;

  // Add method to check if there's an error
  bool hasConnectionError(SensorType type) => _connectionErrors[type]!;

  // Add method to check if connected
  bool isConnected(SensorType type) => _connectionStatus[type] == "Connected";

  Future<void> startScan(SensorType sensorType) async {
    _currentScanType = sensorType;

    // Check if permissions are granted before scanning
    if (!await _requestPermissions()) {
      print('Bluetooth permissions not granted');
      return;
    }

    if (!_isScanning) {
      _foundDevices.clear();
      _isScanning = true;

      try {
        // Stop any ongoing scan first
        await FlutterBluePlus.stopScan();

        // Start new scan
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        print('Started scanning for ${sensorType.toString()}');

        FlutterBluePlus.scanResults.listen((results) {
          final newDevices = <BluetoothDevice>[];
          for (ScanResult r in results) {
            if (!_foundDevices.any((device) => device.id == r.device.id)) {
              // Case-insensitive check + null safety
              final deviceName = r.device.name ?? '';
              final advData = r.advertisementData;

              bool shouldAdd = false;

              switch (sensorType) {
                case SensorType.powerMeter:
                  shouldAdd = deviceName.toLowerCase().contains('4iiii') ||
                      deviceName.toLowerCase().contains('power') ||
                      advData.serviceUuids.contains(CYCLING_POWER_SERVICE);
                  break;
                case SensorType.heartRate:
                  shouldAdd = advData.serviceUuids.contains(HEART_RATE_SERVICE) ||
                      deviceName.toLowerCase().contains('heart');
                  break;
                case SensorType.cadence:
                  shouldAdd = advData.serviceUuids.contains(CYCLING_SPEED_CADENCE_SERVICE) ||
                      deviceName.toLowerCase().contains('cadence');
                  break;
                case SensorType.speed:
                  shouldAdd = advData.serviceUuids.contains(CYCLING_SPEED_CADENCE_SERVICE) ||
                      deviceName.toLowerCase().contains('speed');
                  break;
              }

              if (shouldAdd) {
                print('Found device: ${r.device.name} (${r.device.id}) for $sensorType');
                newDevices.add(r.device);
              }
            }
          }

          if (newDevices.isNotEmpty) {
            _foundDevices.addAll(newDevices);
            _scanResultsController.add(List.from(_foundDevices));
          }
        });

        // Auto-stop after timeout
        Timer(const Duration(seconds: 10), () {
          if (_isScanning) {
            stopScan();
          }
        });

      } catch (e) {
        print('Error starting scan: $e');
        _isScanning = false;
      }
    }
  }

  double _calculateSpeedFromCscData(int cumulativeRevs, int eventTime) {
    // FIX: Use instance variables instead of local variables
    // If we have previous data, calculate speed
    if (_lastCumulativeWheelRevs > 0 && _lastWheelEventTime > 0) {
      try {
        int revsDifference = cumulativeRevs - _lastCumulativeWheelRevs;
        int timeDifference = eventTime - _lastWheelEventTime;

        // Handle time rollover (eventTime is 16-bit, rolls over every 64 seconds)
        if (timeDifference < 0) {
          timeDifference += 65536; // 2^16
        }

        // Convert time from 1/1024 seconds to hours
        double timeInHours = timeDifference / (1024.0 * 3600.0);

        if (timeInHours > 0 && revsDifference >= 0) {
          // Default wheel circumference in meters (typical road bike)
          double wheelCircumference = 2.1;

          // Distance = revolutions * circumference
          double distance = revsDifference * wheelCircumference / 1000.0; // Convert to km

          // Speed = distance / time
          double speed = distance / timeInHours;

          // Filter out unrealistic speeds (0-100 km/h range)
          if (speed >= 0 && speed <= 100) {
            _lastSpeed = speed;
            print('Calculated speed: ${speed.toStringAsFixed(1)} km/h');
            return speed;
          } else {
            return _lastSpeed; // Return last valid speed
          }
        }
      } catch (e) {
        print('Error calculating speed: $e');
      }
    }

    // Update previous values
    _lastCumulativeWheelRevs = cumulativeRevs;
    _lastWheelEventTime = eventTime;

    return _lastSpeed;
  }

  Future<bool> _requestPermissions() async {
    try {
      print('Requesting location permission...');
      final locationGranted = await requestLocationPermission();
      if (!locationGranted) {
        print('Location permission denied');
        return false;
      }

      print('Requesting Bluetooth permissions...');
      final bluetoothGranted = await requestBluetoothPermissions();
      if (!bluetoothGranted) {
        print('Bluetooth permissions denied');
        return false;
      }

      print('All permissions granted');
      return true;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  void stopScan() {
    if (_isScanning) {
      FlutterBluePlus.stopScan();
      _isScanning = false;
      print('Scanning stopped');
    }
  }

  Future<void> connect(SensorType sensorType, BluetoothDevice device) async {
    try {
      _devices[sensorType] = device;
      _connectionStatus[sensorType] = "Connecting...";
      _connectionErrors[sensorType] = false;

      print('Connecting to ${device.name} for $sensorType...');

      // Set up connection state listener
      device.connectionState.listen((state) {
        print('Connection state for ${device.name}: $state');
        if (state == BluetoothConnectionState.connected) {
          print('Successfully connected to ${device.name}');
          _connectionStatus[sensorType] = "Discovering services...";
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectionStatus[sensorType] = "Disconnected";
          _connectionErrors[sensorType] = true;
        }
      }, onError: (error) {
        print('Connection state error: $error');
        _connectionStatus[sensorType] = "Error: $error";
        _connectionErrors[sensorType] = true;
      });

      // Connect with timeout
      await device.connect(timeout: const Duration(seconds: 15));
      print('Device connection established, discovering services...');

      // Wait a bit for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));

      await _discoverServices(sensorType);

      print('$sensorType connection and setup completed successfully');

    } catch (e) {
      print('Error connecting to device: $e');
      _connectionStatus[sensorType] = "Error: ${e.toString()}";
      _connectionErrors[sensorType] = true;

      // Try to disconnect if connection failed
      try {
        await device.disconnect();
      } catch (disconnectError) {
        print('Error during disconnect: $disconnectError');
      }
    }
  }

  Future<void> _discoverServices(SensorType sensorType) async {
    final device = _devices[sensorType];
    if (device == null) {
      print('No device found for $sensorType');
      return;
    }

    try {
      print('Discovering services for ${device.name}...');
      List<BluetoothService> services = await device.discoverServices();
      print('Found ${services.length} services');

      bool characteristicFound = false;

      for (var service in services) {
        print('Service: ${service.uuid}');

        for (var characteristic in service.characteristics) {
          print('  Characteristic: ${characteristic.uuid}');

          switch (sensorType) {
            case SensorType.powerMeter:
              if (service.uuid == CYCLING_POWER_SERVICE &&
                  characteristic.uuid == POWER_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parsePowerData);

                // Update connection status for power meter
                _connectionStatus[sensorType] = "Connected";
                _connectionErrors[sensorType] = false;

                // IMPORTANT: Force cadence to show as connected from power meter
                _cadenceFromPowerMeter = true;
                _connectionStatus[SensorType.cadence] = "Connected (Power Meter)";
                _connectionErrors[SensorType.cadence] = false;

                // Reset cadence calculation variables
                _lastCumulativeRevs = 0;
                _lastEventTime = 0;
                _lastCadence = 0;

                characteristicFound = true;
                print('✅ Power meter connected and cadence setup complete');
                print('🔧 Cadence will be calculated from power meter data');

                // Force a status update to the UI
                _cadenceController.add(0); // Add initial value to trigger stream
              }
              break;
            case SensorType.heartRate:
              if (service.uuid == HEART_RATE_SERVICE &&
                  characteristic.uuid == HEART_RATE_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parseHeartRateData);
                _connectionStatus[sensorType] = "Connected";
                characteristicFound = true;
                print('Heart rate measurement characteristic found and subscribed');
              }
              break;
            case SensorType.cadence:
            // Always prefer cadence from power meter if available
              if (_cadenceFromPowerMeter) {
                print('Using cadence from power meter, skipping separate cadence sensor');
                _connectionStatus[SensorType.cadence] = "Connected (Power Meter)";
                _connectionErrors[SensorType.cadence] = false;
                characteristicFound = true;
                break;
              }

              if (service.uuid == CYCLING_SPEED_CADENCE_SERVICE &&
                  characteristic.uuid == CSC_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parseCadenceData);
                _connectionStatus[sensorType] = "Connected";
                characteristicFound = true;
                print('Cadence characteristic found and subscribed');
              }
              break;
            case SensorType.speed:
              if (service.uuid == CYCLING_SPEED_CADENCE_SERVICE &&
                  characteristic.uuid == CSC_MEASUREMENT_CHAR) {
                _characteristics[sensorType] = characteristic;
                await characteristic.setNotifyValue(true);
                characteristic.value.listen(_parseSpeedData);
                _connectionStatus[sensorType] = "Connected";
                characteristicFound = true;
                print('Speed characteristic found and subscribed');
              }
              break;
          }
        }
      }

      // Update status if no characteristic was found
      if (!characteristicFound) {
        print('No characteristic found for $sensorType');
        _connectionStatus[sensorType] = "Service not found";
        _connectionErrors[sensorType] = true;
      }

    } catch (e) {
      print('Error discovering services: $e');
      _connectionStatus[sensorType] = "Error discovering services: ${e.toString()}";
      _connectionErrors[sensorType] = true;
    }
  }

  void _parsePowerData(List<int> value) {
    print('=== POWER METER DATA RECEIVED ===');
    print('Raw data length: ${value.length} bytes');
    print('Raw data: $value');
    print('Raw data (hex): ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    if (value.length >= 4) {
      try {
        // Parse flags (first 2 bytes, little-endian)
        int flags = (value[1] << 8) | value[0];
        print('Flags: 0x${flags.toRadixString(16).padLeft(4, '0')}');
        print('Flags binary: ${flags.toRadixString(2).padLeft(16, '0')}');

        // Check ALL flag bits to understand what data is present
        bool hasWheelData = (flags & 0x01) != 0;      // Bit 0
        bool hasCrankData = (flags & 0x02) != 0;      // Bit 1 - THIS IS THE IMPORTANT ONE
        bool hasExtremeForce = (flags & 0x04) != 0;   // Bit 2
        bool hasExtremeTorque = (flags & 0x08) != 0;  // Bit 3
        bool hasExtremeAngle = (flags & 0x10) != 0;   // Bit 4
        bool hasTopDeadSpot = (flags & 0x20) != 0;    // Bit 5
        bool hasBottomDeadSpot = (flags & 0x40) != 0; // Bit 6
        bool hasAccumulatedEnergy = (flags & 0x80) != 0; // Bit 7
        bool hasOffset = (flags & 0x100) != 0;        // Bit 8

        print('Flag breakdown:');
        print('  Wheel Data: $hasWheelData');
        print('  Crank Data: $hasCrankData (THIS SHOULD BE TRUE FOR CADENCE)');
        print('  Extreme Force: $hasExtremeForce');
        print('  Extreme Torque: $hasExtremeTorque');
        print('  Extreme Angle: $hasExtremeAngle');
        print('  Top Dead Spot: $hasTopDeadSpot');
        print('  Bottom Dead Spot: $hasBottomDeadSpot');
        print('  Accumulated Energy: $hasAccumulatedEnergy');
        print('  Offset: $hasOffset');

        // Parse power (bytes 2-3, little-endian, signed)
        int power = (value[3] << 8) | value[2];
        if (power > 32767) power = power - 65536;

        if (power >= 0 && power < 65535) {
          print('Power: $power watts');
          _powerController.add(power);
        }

        int currentOffset = 4; // Start after flags and power

        // Try multiple parsing strategies for 4iiii power meter
        bool cadenceParsed = false;

        // Strategy 1: Standard parsing with flags
        if (hasCrankData && value.length >= currentOffset + 6) {
          print('=== PARSING CRANK DATA (Standard) ===');
          int cumulativeCrankRevolutions = (value[currentOffset + 3] << 24) |
          (value[currentOffset + 2] << 16) |
          (value[currentOffset + 1] << 8) |
          value[currentOffset];

          int lastCrankEventTime = (value[currentOffset + 5] << 8) | value[currentOffset + 4];

          int cadence = _calculateCadenceFromPowerMeter(cumulativeCrankRevolutions, lastCrankEventTime);
          if (cadence > 0 && cadence < 255) {
            print('🎯 Cadence from standard parsing: $cadence RPM');
            _cadenceController.add(cadence);
            cadenceParsed = true;
          }
          currentOffset += 6;
        }

        // Strategy 2: Try fixed position for 4iiii (common pattern)
        if (!cadenceParsed && value.length >= 10) {
          print('=== PARSING CRANK DATA (4iiii Fixed Position) ===');
          try {
            int cumulativeCrankRevolutions = (value[7] << 24) | (value[6] << 16) | (value[5] << 8) | value[4];
            int lastCrankEventTime = (value[9] << 8) | value[8];

            int cadence = _calculateCadenceFromPowerMeter(cumulativeCrankRevolutions, lastCrankEventTime);
            if (cadence > 0 && cadence < 255) {
              print('🎯 Cadence from 4iiii fixed parsing: $cadence RPM');
              _cadenceController.add(cadence);
              cadenceParsed = true;
            }
          } catch (e) {
            print('4iiii fixed parsing failed: $e');
          }
        }

        // Strategy 3: Try alternative positions
        if (!cadenceParsed && value.length >= 8) {
          print('=== PARSING CRANK DATA (Alternative) ===');
          // Try different byte combinations
          for (int offset = 4; offset <= value.length - 4; offset++) {
            try {
              int potentialRevs = (value[offset + 3] << 24) | (value[offset + 2] << 16) |
              (value[offset + 1] << 8) | value[offset];
              int potentialTime = (value[offset + 5] << 8) | value[offset + 4];

              if (potentialRevs < 1000000 && potentialTime < 65536) { // Reasonable bounds
                int cadence = _calculateCadenceFromPowerMeter(potentialRevs, potentialTime);
                if (cadence > 10 && cadence < 250) {
                  print('🎯 Cadence from alternative parsing at offset $offset: $cadence RPM');
                  _cadenceController.add(cadence);
                  cadenceParsed = true;
                  break;
                }
              }
            } catch (e) {
              // Continue trying other offsets
            }
          }
        }

        if (!cadenceParsed) {
          print('❌ No cadence data could be parsed from this packet');
          print('Available bytes after power: ${value.length - 4}');
        }

      } catch (e) {
        print('❌ Error parsing power data: $e');
      }
    } else {
      print('❌ Power data too short: ${value.length} bytes');
    }
    print('=== END POWER METER DATA ===\n');
  }

  int _calculateCadenceFromPowerMeter(int cumulativeRevs, int eventTime) {
    // Store previous values if this is the first call
    if (_lastCumulativeRevs == 0 && _lastEventTime == 0) {
      _lastCumulativeRevs = cumulativeRevs;
      _lastEventTime = eventTime;
      return 0;
    }

    // Only calculate if we have movement
    if (cumulativeRevs != _lastCumulativeRevs) {
      int revsDifference = cumulativeRevs - _lastCumulativeRevs;
      int timeDifference = eventTime - _lastEventTime;

      // Handle time rollover
      if (timeDifference < 0) {
        timeDifference += 65536;
      }

      // Calculate cadence if we have a reasonable time difference
      if (timeDifference > 0 && revsDifference > 0) {
        double timeInMinutes = timeDifference / (1024.0 * 60.0);
        int cadence = (revsDifference / timeInMinutes).round();

        // Valid cadence range
        if (cadence >= 10 && cadence <= 250) {
          _lastCadence = cadence;
          print('✅ Calculated cadence: $cadence RPM (${revsDifference} revs in ${timeDifference}/1024s)');
          return cadence;
        }
      }
    }

    // Update for next calculation
    _lastCumulativeRevs = cumulativeRevs;
    _lastEventTime = eventTime;

    return _lastCadence; // Return last valid cadence
  }
  void _parseHeartRateData(List<int> value) {
    if (value.isNotEmpty) {
      // First byte: Flags
      // Second byte: Heart Rate Value (uint8)
      if (value.length >= 2) {
        final hr = value[1];
        print('Heart rate: $hr BPM');
        _heartRateController.add(hr);
      }
    }
  }

  void _parseCadenceData(List<int> value) {
    // Always skip if cadence is provided by power meter
    if (_cadenceFromPowerMeter) {
      return; // Completely ignore separate cadence sensor data
    }

    if (value.length >= 7) {
      try {
        // Parse CSC data for cadence
        int flags = value[0];

        // Check if cadence data is present (bit 1 of flags)
        if ((flags & 0x02) != 0 && value.length >= 7) {
          // Cumulative Crank Revolutions (UINT16) - little endian
          int cumulativeCrankRevolutions = (value[3] << 8) | value[2];

          // Last Crank Event Time (UINT16) - little endian
          int lastCrankEventTime = (value[5] << 8) | value[4];

          // Calculate cadence
          int cadence = _calculateCadenceFromCscData(cumulativeCrankRevolutions, lastCrankEventTime);

          if (cadence > 0 && cadence < 255) {
            print('Cadence from CSC: $cadence RPM');
            _cadenceController.add(cadence);
          }
        }
      } catch (e) {
        print('Error parsing cadence data: $e');
      }
    }
  }

  int _calculateCadenceFromCscData(int cumulativeRevs, int eventTime) {
    // FIX: Use separate instance variables for CSC cadence
    int _lastCumulativeRevsCsc = 0;
    int _lastEventTimeCsc = 0;
    int _lastCadenceCsc = 0;

    if (_lastCumulativeRevsCsc > 0 && _lastEventTimeCsc > 0) {
      try {
        int revsDifference = cumulativeRevs - _lastCumulativeRevsCsc;
        int timeDifference = eventTime - _lastEventTimeCsc;

        // Handle time rollover
        if (timeDifference < 0) {
          timeDifference += 65536;
        }

        if (timeDifference > 0) {
          // Cadence = (revolutions / time in minutes)
          // timeDifference is in 1/1024 seconds
          double timeInMinutes = timeDifference / (1024.0 * 60.0);
          int cadence = (revsDifference / timeInMinutes).round();

          // Valid cadence range
          if (cadence > 0 && cadence < 255) {
            _lastCadenceCsc = cadence;
            return cadence;
          }
        }
      } catch (e) {
        print('Error calculating cadence: $e');
      }
    }

    _lastCumulativeRevsCsc = cumulativeRevs;
    _lastEventTimeCsc = eventTime;

    return _lastCadenceCsc;
  }

  void _parseSpeedData(List<int> value) {
    if (value.length >= 7) {
      try {
        // Parse CSC (Cycling Speed and Cadence) data according to Bluetooth spec
        // Flags byte
        int flags = value[0];

        // Cumulative Wheel Revolutions (UINT32) - little endian
        int cumulativeWheelRevolutions = (value[4] << 24) |
        (value[3] << 16) |
        (value[2] << 8) |
        value[1];

        // Last Wheel Event Time (UINT16) - little endian (1/1024 seconds)
        int lastWheelEventTime = (value[6] << 8) | value[5];

        print('CSC Data - Cumulative Revs: $cumulativeWheelRevolutions, Event Time: $lastWheelEventTime');

        // Calculate speed based on wheel revolutions and time
        double speed = _calculateSpeedFromCscData(cumulativeWheelRevolutions, lastWheelEventTime);

        if (speed >= 0) {
          _speedController.add(speed);
        }

      } catch (e) {
        print('Error parsing speed data: $e');
      }
    } else {
      print('Invalid CSC data length: ${value.length}');
    }
  }

  Future<void> disconnect(SensorType sensorType) async {
    try {
      final characteristic = _characteristics[sensorType];
      if (characteristic != null) {
        await characteristic.setNotifyValue(false);
      }

      final device = _devices[sensorType];
      if (device != null) {
        await device.disconnect();
      }

      _characteristics[sensorType] = null;
      _devices[sensorType] = null;
      _connectionStatus[sensorType] = "Disconnected";
      _connectionErrors[sensorType] = false;

      // Reset cadence source if disconnecting power meter
      if (sensorType == SensorType.powerMeter && _cadenceFromPowerMeter) {
        _cadenceFromPowerMeter = false;
        _connectionStatus[SensorType.cadence] = "Not connected";
        _connectionErrors[SensorType.cadence] = false;
        _devices[SensorType.cadence] = null;
        _characteristics[SensorType.cadence] = null;
      }

      print('Disconnected $sensorType');
    } catch (e) {
      print('Error disconnecting $sensorType: $e');
    }
  }

  void disconnectAll() async {
    for (var type in SensorType.values) {
      if (_devices[type] != null) {
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