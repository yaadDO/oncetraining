import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import '../../../bluetooth/presentation/device_scan_screen.dart';
import '../../../bluetooth/services/bluetooth_service.dart';
import '../../../core/services/gpx_storage_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/permissions.dart';
import '../../services/ride_service.dart';
import '../components/metrics_grid.dart';
import '../components/ride_controls.dart';
import '../widgets/metric_editor.dart';
import 'cycle_screen_controller.dart';

class PowerDisplayScreen extends StatefulWidget {
  final BluetoothDevice? device;

  const PowerDisplayScreen({super.key, this.device});

  @override
  PowerDisplayScreenState createState() => PowerDisplayScreenState();
}

class PowerDisplayScreenState extends State<PowerDisplayScreen> {
  late final CycleScreenController controller;
  final PreferencesService _prefsService = PreferencesService();
  final GpxStorageService _storage = GpxStorageService();
  final RideService _rideService = RideService();
  late PowerMeterService _powerService;

  // Sensor connection status
  Map<SensorType, String> connectionStatus = {
    SensorType.powerMeter: "Not connected",
    SensorType.heartRate: "Not connected",
    SensorType.cadence: "Not connected",
    SensorType.speed: "Not connected",
  };

  Map<SensorType, bool> connectionErrors = {
    SensorType.powerMeter: false,
    SensorType.heartRate: false,
    SensorType.cadence: false,
    SensorType.speed: false,
  };

  @override
  void initState() {
    super.initState();
    _powerService = PowerMeterService();
    controller = CycleScreenController(
      rideService: _rideService,
      storageService: _storage,
      preferencesService: _prefsService,
    );
    _initPowerService();
    _initializeController();
    _requestLocationPermission();
    _setupSensorListeners();
  }

  Future<void> _initPowerService() async {
    if (widget.device != null) {
      // For initial device connection
      await _connectSensor(SensorType.powerMeter, widget.device!);
    }
  }

  void _setupSensorListeners() {
    // Power stream listener
    _powerService.powerStream.listen((power) {
      if (mounted) {
        setState(() {
          controller.rideData.currentPower = power;
          connectionStatus[SensorType.powerMeter] = "Connected";
          connectionErrors[SensorType.powerMeter] = false;

          controller.updateMetric('power', '${controller.rideData.currentPower}');
          controller.updateWattsPerKilo();

          if (controller.rideData.isRiding) {
            controller.powerSamples.add(power);
            if (power > controller.rideData.maxPower) {
              controller.rideData.maxPower = power;
            }
            controller.updateMetric(
              'max_power',
              '${controller.rideData.maxPower}',
            );
            controller.updateAveragePower();
            controller.updateKiloJoules();
            controller.updateCalories();
            controller.update3sPowerAvg(power);

            if (controller.lapTimer != null) {
              controller.lapPowerSamples.add(power);
              if (power > controller.rideData.lapMaxPower) {
                controller.rideData.lapMaxPower = power;
              }
              controller.updateMetric(
                'lap_max_power',
                '${controller.rideData.lapMaxPower}',
              );
            }
          }
        });
      }
    }, onError: (error) {
      print('Power stream error: $error');
    });

    // Heart rate stream listener
    _powerService.heartRateStream.listen((hr) {
      if (mounted) {
        setState(() {
          controller.updateHrMetrics(hr);
          connectionStatus[SensorType.heartRate] = "Connected";
          connectionErrors[SensorType.heartRate] = false;
        });
      }
    }, onError: (error) {
      print('Heart rate stream error: $error');
    });

    // Cadence stream listener
    _powerService.cadenceStream.listen((cadence) {
      if (mounted) {
        setState(() {
          controller.updateCadenceMetrics(cadence);
          connectionStatus[SensorType.cadence] = "Connected";
          connectionErrors[SensorType.cadence] = false;
        });
      }
    }, onError: (error) {
      print('Cadence stream error: $error');
    });

    // Speed stream listener
    _powerService.speedStream.listen((speedKmh) {
      if (mounted) {
        setState(() {
          // Now we receive calculated speed directly
          controller.updateSensorSpeed(speedKmh);
          connectionStatus[SensorType.speed] = "Connected";
          connectionErrors[SensorType.speed] = false;
        });
      }
    }, onError: (error) {
      print('Speed stream error: $error');
    });
  }

  Future<void> _initializeController() async {
    await controller.initializeMetrics();
  }

  Future<void> _requestLocationPermission() async {
    final granted = await requestLocationPermission();
    setState(() {
      controller.isLocationPermissionGranted = granted;
    });
  }

  @override
  void dispose() {
    controller.rideTimer?.cancel();
    controller.lapTimer?.cancel();

    // Stop GPS recording
    _rideService.dispose();

    // Disconnect Bluetooth
    _powerService.disconnectAll();
    _powerService.dispose();

    controller.dispose();
    super.dispose();
  }

  Future<void> _connectSensor(
      SensorType sensorType,
      BluetoothDevice device,
      ) async {
    setState(() {
      connectionStatus[sensorType] = "Connecting...";
      connectionErrors[sensorType] = false;
    });

    try {
      await _powerService.connect(sensorType, device);

      // Force UI update after connection
      setState(() {
        connectionStatus[sensorType] = "Connected";
        connectionErrors[sensorType] = false;
      });

      print('Successfully connected to ${device.name} for $sensorType');

    } catch (e) {
      print('Error connecting to device: $e');
      setState(() {
        connectionStatus[sensorType] = "Error: ${e.toString()}";
        connectionErrors[sensorType] = true;
      });
    }
  }


  void _startRide() {
    setState(() {
      controller.startRide();

      if (controller.isLocationPermissionGranted) {
        _rideService.startGpsRecording((position) {
          setState(() {
            controller.rideData.distance = _rideService.distance;
            controller.updateMetric(
              'distance',
              controller.rideData.distance.toStringAsFixed(2),
            );

            controller.rideData.currentSpeed = _rideService.currentSpeed;
            controller.updateMetric(
              'speed',
              controller.rideData.currentSpeed.toStringAsFixed(1),
            );

            if (controller.rideData.currentSpeed >
                controller.rideData.maxSpeed) {
              controller.rideData.maxSpeed = controller.rideData.currentSpeed;
              controller.updateMetric(
                'max_speed',
                controller.rideData.maxSpeed.toStringAsFixed(1),
              );
            }
            controller.updateAvgSpeed();
          });
        });
      }

      controller.rideTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        setState(() {
          controller.rideData.rideDuration += const Duration(seconds: 1);
          controller.updateMetric(
            'time',
            formatDuration(controller.rideData.rideDuration),
          );
          controller.updateMetric('local_time', formatTime(DateTime.now()));
          controller.updateMetric(
            'ride_time',
            formatDuration(controller.rideData.rideDuration),
          );
          controller.updateMetric(
            'trip_time',
            formatDuration(controller.rideData.rideDuration),
          );
        });
      });
    });
  }

  void _startLap() {
    setState(() {
      controller.startLap();

      controller.lapTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          controller.rideData.lapDuration += const Duration(seconds: 1);
          controller.updateMetric(
            'lap_time',
            formatDuration(controller.rideData.lapDuration),
          );
          controller.updateLapAvgSpeed();
        });
      });
    });
  }

  void _stopLap() {
    setState(() {
      controller.stopLap();
    });
  }

  void _stopRide() {
    setState(() {
      controller.rideData.isRiding = false;
      controller.rideTimer?.cancel();
      controller.lapTimer?.cancel();
      controller.updateAveragePower();
      _rideService.dispose();
      _saveRideSession();
    });
  }

  Future<bool> _onWillPop() async {
    // If no ride is in progress or no data to save, allow immediate exit
    if (!controller.rideData.isRiding && controller.rideData.rideDuration.inSeconds == 0) {
      return true;
    }

    // Show confirmation dialog for unsaved ride
    final shouldSave = await showDialog<bool?>(
      context: context,
      barrierDismissible: true, // Allow tapping outside to dismiss
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Save Ride?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Do you want to save this ride before exiting?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text(
              'CANCEL',
              style: TextStyle(color: Colors.white70),
            ),
            onPressed: () => Navigator.of(context).pop(null), // Returns null for cancel
          ),
          TextButton(
            child: Text(
              'DISCARD',
              style: TextStyle(color: Colors.red.shade300),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(
              'SAVE',
              style: TextStyle(color: Colors.green.shade300),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    // Handle the dialog result
    if (shouldSave == null) {
      // User tapped outside or pressed CANCEL - stay on screen
      return false;
    } else if (shouldSave == true) {
      // User chose SAVE - save and exit
      await _saveRideAndExit();
      return true;
    } else {
      // User chose DISCARD - show confirmation warning
      final confirmDiscard = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.blue.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Discard Ride?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to discard this ride? All data will be lost.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: Text(
                'CANCEL',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(
                'DISCARD',
                style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      // Handle discard confirmation
      if (confirmDiscard == true) {
        // User confirmed discard - exit without saving
        return true;
      } else {
        // User canceled discard - stay on screen
        return false;
      }
    }
  }

  Future<void> _saveRideAndExit() async {
    // Stop any active timers
    controller.rideTimer?.cancel();
    controller.lapTimer?.cancel();

    // Update final calculations
    controller.updateAveragePower();
    controller.updateAverageHeartRate();
    controller.updateAverageCadence();
    controller.updateNormalisedPower();

    // Save the ride session
    await controller.saveRideSession(widget.device);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ride saved successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openMetricEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade800,
                Colors.blue.shade700,
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: MetricEditor(
            allMetrics: controller.allMetrics,
            displayedMetrics: controller.displayedMetrics,
            onSave: (selectedMetrics) async {
              // FIX: Update state first THEN save
              setState(() {
                controller.displayedMetrics = selectedMetrics;
              });
              await controller.saveDisplayedMetrics();
            },
          ),
        );
      },
    );
  }

  void _handleDeviceSelection(SensorType sensorType) async {
    final device = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceScanScreen(sensorType: sensorType),
      ),
    );

    if (device != null && device is BluetoothDevice) {
      await _connectSensor(sensorType, device);
    }
  }


  void _showSensorSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade800,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connect Sensor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              _buildSensorButton(
                SensorType.powerMeter,
                'Power Meter',
                Icons.flash_on,
              ),
              SizedBox(height: 10),
              _buildSensorButton(
                SensorType.heartRate,
                'Heart Rate Monitor',
                Icons.favorite,
              ),
              SizedBox(height: 10),
              _buildSensorButton(
                SensorType.cadence,
                'Cadence Sensor',
                Icons.repeat,
              ),
              SizedBox(height: 10),
              _buildSensorButton(SensorType.speed, 'Speed Sensor', Icons.speed),
              SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorButton(SensorType type, String label, IconData icon) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () {
        Navigator.pop(context);
        _handleDeviceSelection(
            type); // Use the new method instead of direct navigation
      },
    );
  }

  Widget _buildSensorIcon(SensorType type, IconData icon) {
    final status = connectionStatus[type]!;
    final hasError = connectionErrors[type]!;
    final isConnected = status == "Connected" || status.contains("Connected");

    Color iconColor;
    if (hasError) {
      iconColor = Colors.red;
    } else if (isConnected) {
      iconColor = Colors.green;
    } else {
      iconColor = Colors.yellow;
    }

    return Tooltip(
      message: "${type.toString().split('.').last}: $status",
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }


  Future<void> _saveRideSession() async {
    try {
      await controller.saveRideSession(widget.device);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride saved to history'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save ride: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                  Colors.blue.shade500,
                ],
              ),
            ),
            child: Column(
              children: [
                // Custom App Bar
                Container(
                  padding: EdgeInsets.only(
                    top: 50,
                    left: 20,
                    right: 20,
                    bottom: 15,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () async {
                          final shouldExit = await _onWillPop();
                          if (shouldExit && mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      Spacer(),
                      // Sensor status icons
                      _buildSensorIcon(SensorType.powerMeter, Icons.flash_on),
                      _buildSensorIcon(SensorType.heartRate, Icons.favorite),
                      _buildSensorIcon(SensorType.cadence, Icons.repeat),
                      _buildSensorIcon(SensorType.speed, Icons.speed),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.grid_on, color: Colors.white, size: 28),
                        onPressed: _openMetricEditor,
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          Icons.bluetooth,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _showSensorSelection,
                      ),
                    ],
                  ),
                ),

                // Connection Status Summary
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [
                      for (var type in SensorType.values)
                        if (connectionErrors[type]! ||
                            connectionStatus[type]!.contains("Error") ||
                            connectionStatus[type]!.contains("Connected"))
                          Chip(
                            label: Text(
                              "${type.toString().split('.').last}: ${connectionStatus[type]}",
                              style: TextStyle(
                                color:
                                    connectionErrors[type]!
                                        ? Colors.red[300]
                                        : Colors.green[300],
                                fontSize: 14,
                              ),
                            ),
                            backgroundColor: Colors.black.withOpacity(0.2),
                          ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      MetricsGrid(displayedMetrics: controller.displayedMetrics),
                      RideControls(
                        isRiding: controller.rideData.isRiding,
                        isLapActive: controller.lapTimer != null,
                        onStartRide: _startRide,
                        onStopRide: _stopRide,
                        onStartLap: _startLap,
                        onStopLap: _stopLap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
