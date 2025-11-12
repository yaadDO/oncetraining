import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/utils/permissions.dart';
import '../../core/domain/sensor_type.dart';

class PowerMeterService {
  static final Guid CYCLING_POWER_SERVICE = Guid("00001818-0000-1000-8000-00805f9b34fb");
  static final Guid POWER_MEASUREMENT_CHAR = Guid("00002A63-0000-1000-8000-00805f9b34fb");

  static final Guid HEART_RATE_SERVICE = Guid("0000180D-0000-1000-8000-00805f9b34fb");
  static final Guid HEART_RATE_MEASUREMENT_CHAR = Guid("00002A37-0000-1000-8000-00805f9b34fb");
  static final Guid CYCLING_SPEED_CADENCE_SERVICE = Guid("00001816-0000-1000-8000-00805f9b34fb");
  static final Guid CSC_MEASUREMENT_CHAR = Guid("00002A5B-0000-1000-8000-00805f9b34fb");

  final Map<SensorType, BluetoothDevice?> _devices = {
    SensorType.powerMeter: null,
    SensorType.heartRate: null,
    SensorType.cadence: null,
    SensorType.speed: null,
  };

  final Map<SensorType, BluetoothCharacteristic?> _characteristics = {
    SensorType.powerMeter: null,
    SensorType.heartRate: null,
    SensorType.cadence: null,
    SensorType.speed: null,
  };

  final Map<SensorType, String> _connectionStatus = {
    SensorType.powerMeter: "Not connected",
    SensorType.heartRate: "Not connected",
    SensorType.cadence: "Not connected",
    SensorType.speed: "Not connected",
  };

  final Map<SensorType, bool> _connectionErrors = {
    SensorType.powerMeter: false,
    SensorType.heartRate: false,
    SensorType.cadence: false,
    SensorType.speed: false,
  };

  bool _cadenceFromPowerMeter = false;
  bool get cadenceFromPowerMeter => _cadenceFromPowerMeter;

  final _foundDevices = <BluetoothDevice>[];
  final _scanResultsController = StreamController<List<BluetoothDevice>>.broadcast();
  Stream<List<BluetoothDevice>> get scanResults => _scanResultsController.stream;
  bool _isScanning = false;
  SensorType? _currentScanType;

  final _powerController = StreamController<int>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();
  final _cadenceController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final Random _random = Random();

  Stream<int> get powerStream => _powerController.stream;
  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<int> get cadenceStream => _cadenceController.stream;
  Stream<double> get speedStream => _speedController.stream;

  int _lastCumulativeRevs = 0;
  int _lastEventTime = 0;
  int _lastCadence = 0;
  int _lastCumulativeWheelRevs = 0;
  int _lastWheelEventTime = 0;
  double _lastSpeed = 0.0;

  // Add these fields for speed smoothing and wheel circumference
  double _wheelCircumference = 2.1; // Default, will be updated from user settings
  final List<double> _speedBuffer = []; // For smoothing
  static const int _speedBufferSize = 5; // Number of samples to average
  Timer? _speedResetTimer;
  DateTime? _lastValidSpeedTime;
  int _duplicateCount = 0;

  String getConnectionStatus(SensorType type) => _connectionStatus[type]!;
  bool hasConnectionError(SensorType type) => _connectionErrors[type]!;
  bool isConnected(SensorType type) => _connectionStatus[type] == "Connected";

  // Add setter for wheel circumference
  void setWheelCircumference(double circumference) {
    _wheelCircumference = circumference;
    print('Wheel circumference set to: ${_wheelCircumference}m');
  }

  Future<void> startScan(SensorType sensorType) async {
    _currentScanType = sensorType;

    if (!await _requestPermissions()) {
      print('Bluetooth permissions not granted');
      return;
    }

    if (!_isScanning) {
      _foundDevices.clear();
      _isScanning = true;

      try {
        await FlutterBluePlus.stopScan();
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        print('Started scanning for ${sensorType.toString()}');

        FlutterBluePlus.scanResults.listen((results) {
          final newDevices = <BluetoothDevice>[];
          for (ScanResult r in results) {
            if (!_foundDevices.any((device) => device.id == r.device.id)) {
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
    // If we're getting the same data repeatedly for too long, assume we've stopped
    if (cumulativeRevs == _lastCumulativeWheelRevs && eventTime == _lastWheelEventTime) {
      _duplicateCount++;
      if (_duplicateCount > 5) { // Increased threshold for more stability
        print('Persistent duplicate data - setting speed to 0');
        _resetSpeedBuffer();
        return 0.0;
      }
      // Return smoothed speed for a few duplicate readings
      return _calculateSmoothedSpeed();
    } else {
      _duplicateCount = 0;
    }

    double calculatedSpeed = _lastSpeed;

    if (_lastCumulativeWheelRevs > 0 && _lastWheelEventTime > 0) {
      try {
        int revsDifference = cumulativeRevs - _lastCumulativeWheelRevs;
        int timeDifference = eventTime - _lastWheelEventTime;

        // Handle time rollover (eventTime is 16-bit, rolls over every 64 seconds)
        if (timeDifference < 0) {
          timeDifference += 65536;
        }

        // If no revolutions in a reasonable time, we've stopped
        if (revsDifference == 0 && timeDifference > 3072) { // 3 seconds at 1024Hz
          print('No wheel revolutions for 3+ seconds - setting speed to 0');
          _resetSpeedBuffer();
          return 0.0;
        }

        double timeInHours = timeDifference / (1024.0 * 3600.0);

        if (timeInHours > 0 && revsDifference > 0) {
          // Use user's wheel circumference
          double wheelCircumference = _wheelCircumference;

          // Distance = revolutions * circumference
          double distance = revsDifference * wheelCircumference / 1000.0; // Convert to km
          double rawSpeed = distance / timeInHours;

          if (rawSpeed >= 0 && rawSpeed <= 100) {
            calculatedSpeed = rawSpeed;
            _lastValidSpeedTime = DateTime.now();
          } else {
            print('Invalid speed calculation: ${rawSpeed.toStringAsFixed(1)} km/h');
          }
        }
      } catch (e) {
        print('Error calculating speed: $e');
      }
    }

    _lastCumulativeWheelRevs = cumulativeRevs;
    _lastWheelEventTime = eventTime;

    return calculatedSpeed;
  }

  // Helper method to reset speed buffer
  void _resetSpeedBuffer() {
    _speedBuffer.clear();
    _lastSpeed = 0.0;
  }

  // Updated speed parsing with smoothing
  void _parseSpeedData(List<int> value) {
    if (value.length >= 7) {
      try {
        int flags = value[0];
        int cumulativeWheelRevolutions = (value[4] << 24) |
        (value[3] << 16) |
        (value[2] << 8) |
        value[1];
        int lastWheelEventTime = (value[6] << 8) | value[5];

        print('CSC Data - Cumulative Revs: $cumulativeWheelRevolutions, Event Time: $lastWheelEventTime');

        double instantaneousSpeed = _calculateSpeedFromCscData(cumulativeWheelRevolutions, lastWheelEventTime);

        // Reset the speed reset timer since we got new data
        _speedResetTimer?.cancel();

        if (instantaneousSpeed > 0.5) { // Only consider speeds above 0.5 km/h as valid movement
          _lastValidSpeedTime = DateTime.now();

          // Add to smoothing buffer
          _speedBuffer.add(instantaneousSpeed);

          // Keep buffer at fixed size
          if (_speedBuffer.length > _speedBufferSize) {
            _speedBuffer.removeAt(0);
          }

          // Calculate smoothed speed (weighted average of buffer)
          double smoothedSpeed = _calculateSmoothedSpeed();

          // Set up timer to reset speed if no updates for 4 seconds
          _speedResetTimer = Timer(Duration(seconds: 4), () {
            print('No speed updates for 4 seconds - resetting to 0');
            _resetSpeedBuffer();
            _speedController.add(0.0);
          });

          _lastSpeed = smoothedSpeed;
          print('Smoothed speed: ${smoothedSpeed.toStringAsFixed(1)} km/h (raw: ${instantaneousSpeed.toStringAsFixed(1)})');
          _speedController.add(smoothedSpeed);
        } else {
          // Speed is 0 or very low
          if (_lastValidSpeedTime != null &&
              DateTime.now().difference(_lastValidSpeedTime!).inSeconds > 3) {
            // If it's been more than 3 seconds since valid movement, reset to 0
            print('No valid movement for 3+ seconds - resetting to 0');
            _resetSpeedBuffer();
            _speedController.add(0.0);
          } else {
            // Otherwise, use smoothed deceleration
            double smoothedSpeed = _calculateSmoothedSpeed();
            if (smoothedSpeed > 0.5) {
              _speedController.add(smoothedSpeed);
            } else {
              _speedController.add(0.0);
            }
          }
        }

      } catch (e) {
        print('Error parsing speed data: $e');
      }
    } else {
      print('Invalid CSC data length: ${value.length}');
    }
  }

  // Calculate smoothed speed using weighted average (more recent = higher weight)
  double _calculateSmoothedSpeed() {
    if (_speedBuffer.isEmpty) return 0.0;
    if (_speedBuffer.length == 1) return _speedBuffer.first;

    double total = 0.0;
    double weightSum = 0.0;

    for (int i = 0; i < _speedBuffer.length; i++) {
      double weight = (i + 1).toDouble(); // Linear weighting: recent samples have higher weight
      total += _speedBuffer[i] * weight;
      weightSum += weight;
    }

    return total / weightSum;
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

      await device.connect(timeout: const Duration(seconds: 15));
      print('Device connection established, discovering services...');

      await Future.delayed(const Duration(milliseconds: 1000));

      await _discoverServices(sensorType);

      print('$sensorType connection and setup completed successfully');

    } catch (e) {
      print('Error connecting to device: $e');
      _connectionStatus[sensorType] = "Error: ${e.toString()}";
      _connectionErrors[sensorType] = true;

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
                _connectionStatus[sensorType] = "Connected";
                _connectionErrors[sensorType] = false;
                _cadenceFromPowerMeter = true;
                _connectionStatus[SensorType.cadence] = "Connected (Power Meter)";
                _connectionErrors[SensorType.cadence] = false;

                _lastCumulativeRevs = 0;
                _lastEventTime = 0;
                _lastCadence = 0;

                characteristicFound = true;
                print('✅ Power meter connected and cadence setup complete');
                print('🔧 Cadence will be calculated from power meter data');

                _cadenceController.add(0);
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

        // Parse power (bytes 2-3, little-endian, signed)
        int power = (value[3] << 8) | value[2];
        if (power > 32767) power = power - 65536;

        if (power >= 0 && power < 65535) {
          print('Power: $power watts');
          _powerController.add(power);
        }

        // RESET: Clear cadence buffer when power is 0 (not pedaling)
        if (power == 0) {
          print('⚡ Power is 0, setting cadence to 0');
          _cadenceController.add(0);
          _lastCadence = 0;
          return;
        }

        if (value.length >= 8) {
          print('=== PROPER 4IIII CADENCE EXTRACTION ===');


          bool hasCrankData = (flags & 0x02) != 0;
          print('Crank data present: $hasCrankData');

          if (hasCrankData) {
            int cumulativeCrankRevolutions = (value[5] << 8) | value[4];
            int lastCrankEventTime = (value[7] << 8) | value[6];
            print('Crank Revolutions: $cumulativeCrankRevolutions');
            print('Crank Event Time: $lastCrankEventTime');
            int cadence = _calculateCadenceFromCrankData(cumulativeCrankRevolutions, lastCrankEventTime);

            if (cadence >= 30 && cadence <= 170) {
              print('🎯 4iiii Cadence (from crank data): $cadence RPM');
              _cadenceController.add(cadence);
              return;
            } else {
              print('⚠️ Cadence out of 4iiii range: $cadence RPM');
            }
          }

          print('=== TRYING 4IIII FALLBACK PARSING ===');


          for (int offset = 4; offset <= value.length - 4; offset++) {
            try {
              int revs = (value[offset + 1] << 8) | value[offset];
              int time = (value[offset + 3] << 8) | value[offset + 2];

              if (revs < 10000 && time < 65536 && time > 0) {
                int cadence = _calculateCadenceFromCrankData(revs, time);
                if (cadence >= 30 && cadence <= 170) {
                  print('🎯 4iiii Cadence (fallback offset $offset): $cadence RPM');
                  _cadenceController.add(cadence);
                  return;
                }
              }
            } catch (e) {
              continue;
            }
          }

          if (value.length >= 5) {
            int directCadence = value[4];
            if (directCadence >= 30 && directCadence <= 170) {
              print('🎯 4iiii Cadence (direct): $directCadence RPM');
              _cadenceController.add(directCadence);
              return;
            }
          }

          print('❌ No valid cadence data found in 4iiii power meter');
        }

      } catch (e) {
        print('❌ Error parsing power data: $e');
      }
    } else {
      print('❌ Power data too short: ${value.length} bytes');
    }
    print('=== END POWER METER DATA ===\n');
  }

  int _calculateCadenceFromCrankData(int cumulativeRevs, int eventTime) {
    print('🔧 Calculating cadence from crank data:');
    print('   Current revs: $cumulativeRevs, Current time: $eventTime');
    print('   Previous revs: $_lastCumulativeRevs, Previous time: $_lastEventTime');

    // Initialize if first reading
    if (_lastCumulativeRevs == 0 && _lastEventTime == 0) {
      _lastCumulativeRevs = cumulativeRevs;
      _lastEventTime = eventTime;
      print('   📍 First reading, storing initial values');
      return 0;
    }

    // Check if we have new data
    if (cumulativeRevs != _lastCumulativeRevs || eventTime != _lastEventTime) {
      int revsDifference = cumulativeRevs - _lastCumulativeRevs;
      int timeDifference = eventTime - _lastEventTime;

      // Handle time rollover (eventTime is 16-bit, rolls over every 64 seconds)
      if (timeDifference < 0) {
        timeDifference += 65536; // 2^16
        print('   ⏰ Time rollover handled: $timeDifference');
      }

      // Only calculate if we have meaningful data
      if (timeDifference > 0 && revsDifference > 0) {
        double timeInMinutes = timeDifference / (1024.0 * 60.0);

        if (timeInMinutes > 0.001) {
          int cadence = (revsDifference / timeInMinutes).round();
          print('   🎯 Raw cadence calculation: $cadence RPM (${revsDifference} revs in ${timeDifference}/1024s)');


          if (cadence >= 30 && cadence <= 170) {
            print('   ✅ Valid 4iiii cadence: $cadence RPM');

            _lastCumulativeRevs = cumulativeRevs;
            _lastEventTime = eventTime;
            _lastCadence = cadence;

            return cadence;
          } else {
            print('   ⚠️ Cadence outside 4iiii range: $cadence RPM');
          }
        } else {
          print('   ⚠️ Time difference too small: $timeInMinutes minutes');
        }
      } else {
        print('   ⚠️ No movement or invalid time difference');
      }
    } else {
      print('   🔄 Same data as previous reading');
    }

    print('   📍 Returning last valid cadence: $_lastCadence RPM');
    return _lastCadence;
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
    if (_cadenceFromPowerMeter) {
      return;
    }

    if (value.length >= 7) {
      try {
        int flags = value[0];

        if ((flags & 0x02) != 0 && value.length >= 7) {
          int cumulativeCrankRevolutions = (value[3] << 8) | value[2];
          int lastCrankEventTime = (value[5] << 8) | value[4];
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
    int _lastCumulativeRevsCsc = 0;
    int _lastEventTimeCsc = 0;
    int _lastCadenceCsc = 0;

    if (_lastCumulativeRevsCsc > 0 && _lastEventTimeCsc > 0) {
      try {
        int revsDifference = cumulativeRevs - _lastCumulativeRevsCsc;
        int timeDifference = eventTime - _lastEventTimeCsc;

        if (timeDifference < 0) {
          timeDifference += 65536;
        }

        if (timeDifference > 0) {
          double timeInMinutes = timeDifference / (1024.0 * 60.0);
          int cadence = (revsDifference / timeInMinutes).round();
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
    _speedResetTimer?.cancel();
  }
}