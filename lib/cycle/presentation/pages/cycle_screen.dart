import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oncetraining/bluetooth/services/bluetooth_service.dart' show PowerMeterService;
import '../../../bluetooth/presentation/device_scan_screen.dart';
import '../../../core/domain/sensor_type.dart';
import '../../../core/services/gpx_storage_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/permissions.dart';
import '../../services/ride_service.dart';
import '../../services/sensor_listener_service.dart';
import '../components/metrics_grid.dart';
import '../components/ride_controls.dart';
import '../widgets/metric_editor.dart';
import '../widgets/sensor_status_widget.dart';
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
  late SensorListenerService _sensorListener;

  @override
  void initState() {
    super.initState();
    _powerService = PowerMeterService();
    controller = CycleScreenController(
      rideService: _rideService,
      storageService: _storage,
      preferencesService: _prefsService,
    );

    _setupSensorListeners();
    _initPowerService();
    _initializeController();
    _requestLocationPermission();
  }

  Future<void> _initPowerService() async {
    if (widget.device != null) {
      await _connectSensor(SensorType.powerMeter, widget.device!);
    }
  }

  void _setupSensorListeners() {
    _sensorListener = SensorListenerService(
      onPowerUpdate: (power) {
        if (mounted) {
          setState(() => controller.updatePowerData(power));
        }
      },
      onHeartRateUpdate: (hr) {
        if (mounted) {
          setState(() => controller.updateHrMetrics(hr));
        }
      },
      onCadenceUpdate: (cadence) {
        if (mounted) {
          setState(() => controller.updateCadenceMetrics(cadence));
        }
      },
      onSpeedUpdate: (speed) {
        if (mounted) {
          setState(() => controller.updateSensorSpeed(speed));
        }
      },
      onConnectionUpdate: (type, status, error) {
        if (mounted) {
          setState(() {
            controller.sensorManager.updateConnectionStatus(type as SensorType, status, error: error);
          });
        }
      },
    );

    _sensorListener.setupPowerListener(_powerService.powerStream);
    _sensorListener.setupHeartRateListener(_powerService.heartRateStream);
    _sensorListener.setupCadenceListener(_powerService.cadenceStream);
    _sensorListener.setupSpeedListener(_powerService.speedStream);
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
    controller.timerManager.dispose();
    _rideService.dispose();
    _powerService.disconnectAll();
    _powerService.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _connectSensor(SensorType sensorType, BluetoothDevice device) async {
    setState(() {
      controller.sensorManager.updateConnectionStatus(sensorType, "Connecting...", error: false);
    });

    try {
      await _powerService.connect(sensorType, device);
      setState(() {
        controller.sensorManager.updateConnectionStatus(sensorType, "Connected", error: false);
      });
      print('Successfully connected to ${device.name} for $sensorType');
    } catch (e) {
      print('Error connecting to device: $e');
      setState(() {
        controller.sensorManager.updateConnectionStatus(sensorType, "Error: ${e.toString()}", error: true);
      });
    }
  }

  void _startRide() {
    setState(() {
      controller.startRide();
      controller.startDataCollection();
      _startTimers();
      _startGpsRecording();
    });
  }

  void _startTimers() {
    controller.timerManager.startRideTimer((duration) {
      if (mounted) {
        setState(() {
          controller.rideData.rideDuration = duration;
          _updateTimeMetrics();
        });
      }
    });
  }

  void _startGpsRecording() {
    if (controller.isLocationPermissionGranted) {
      _rideService.startGpsRecording((position) {
        if (mounted) {
          setState(() {
            _updateGpsData(position);
          });
        }
      });
    } else {
      _requestLocationPermission();
    }
  }

  void _updateGpsData(Position position) {
    controller.rideData.distance = _rideService.distance;
    controller.updateMetric('distance', controller.rideData.distance.toStringAsFixed(2));

    controller.rideData.currentSpeed = _rideService.currentSpeed;
    controller.updateMetric('speed', controller.rideData.currentSpeed.toStringAsFixed(1));

    if (controller.rideData.currentSpeed > controller.rideData.maxSpeed) {
      controller.rideData.maxSpeed = controller.rideData.currentSpeed;
      controller.updateMetric('max_speed', controller.rideData.maxSpeed.toStringAsFixed(1));
    }

    if (controller.rideState.isLapActive) {
      controller.updateLapMaxSpeed(controller.rideData.currentSpeed);
    }

    controller.updateAvgSpeed();

    if (position.altitude > 0) {
      controller.updateAltitudeMetrics(position.altitude);
    }
  }

  void _updateTimeMetrics() {
    controller.updateMetric('time', formatDuration(controller.rideData.rideDuration));
    controller.updateMetric('local_time', formatTime(DateTime.now()));
    controller.updateMetric('ride_time', formatDuration(controller.rideData.rideDuration));
    controller.updateMetric('trip_time', formatDuration(controller.rideData.rideDuration));
  }

  void _startLap() {
    setState(() {
      controller.startLap();
      _startLapTimer();
    });
  }

  void _startLapTimer() {
    controller.timerManager.startLapTimer((duration) {
      if (mounted) {
        setState(() {
          controller.rideData.lapDuration = duration;
          _updateLapMetrics();
        });
      }
    });
  }

  void _updateLapMetrics() {
    controller.updateMetric('lap_time', formatDuration(controller.rideData.lapDuration));

    if (controller.isLocationPermissionGranted) {
      controller.rideData.lapDistance = _rideService.lapDistance;
      controller.updateMetric('lap_distance', controller.rideData.lapDistance.toStringAsFixed(2));
    }

    controller.updateLapAvgSpeed();

    if (controller.dataProcessor.lapPowerSamples.isNotEmpty) {
      final total = controller.dataProcessor.lapPowerSamples.reduce((a, b) => a + b);
      controller.rideData.lapAvgPower = total ~/ controller.dataProcessor.lapPowerSamples.length;
      controller.updateMetric('lap_avg_power', '${controller.rideData.lapAvgPower}');
    }

    if (controller.dataProcessor.lapHeartRateSamples.isNotEmpty) {
      final total = controller.dataProcessor.lapHeartRateSamples.reduce((a, b) => a + b);
      controller.rideData.lapAvgHeartRate = total ~/ controller.dataProcessor.lapHeartRateSamples.length;
      controller.updateMetric('lap_avg_hr', '${controller.rideData.lapAvgHeartRate}');
    }

    if (controller.dataProcessor.lapCadenceSamples.isNotEmpty) {
      final total = controller.dataProcessor.lapCadenceSamples.reduce((a, b) => a + b);
      controller.rideData.lapAvgCadence = total ~/ controller.dataProcessor.lapCadenceSamples.length;
      controller.updateMetric('lap_avg_cadence', '${controller.rideData.lapAvgCadence}');
    }
  }

  void _toggleLap() {
    setState(() {
      if (!controller.rideState.isLapActive) {
        _startLap();
      } else {
        controller.stopLap();
        controller.timerManager.stopLapTimer();
        controller.rideData.lapDuration = Duration.zero;
        controller.updateMetric('lap_time', formatDuration(controller.rideData.lapDuration));
      }
    });
  }

  void _stopRide() {
    setState(() {
      controller.rideState.stopRide();
      controller.rideData.isRiding = false;
      controller.timerManager.stopRideTimer();
      controller.timerManager.stopLapTimer();
      controller.updateAveragePower();
      _rideService.dispose();
      _saveRideSession();
    });
  }

  Future<bool> _onWillPop() async {
    if (!controller.rideData.isRiding && controller.rideData.rideDuration.inSeconds == 0) {
      return true;
    }

    final shouldSave = await showDialog<bool?>(
      context: context,
      barrierDismissible: true,
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
            onPressed: () => Navigator.of(context).pop(null),
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

    if (shouldSave == null) {
      return false;
    } else if (shouldSave == true) {
      await _saveRideAndExit();
      return true;
    } else {
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

      return confirmDiscard == true;
    }
  }

  Future<void> _saveRideAndExit() async {
    controller.timerManager.stopRideTimer();
    controller.timerManager.stopLapTimer();

    controller.updateAveragePower();
    controller.updateAverageHeartRate();
    controller.updateAverageCadence();
    controller.updateNormalisedPower();

    await controller.saveRideSession(widget.device);

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
        _handleDeviceSelection(type);
      },
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
                SensorAppBar(
                  controller: controller,
                  powerService: _powerService,
                  onBackPressed: () async {
                    final shouldExit = await _onWillPop();
                    if (shouldExit && mounted) Navigator.pop(context);
                  },
                  onMetricEditorPressed: _openMetricEditor,
                  onSensorSelectionPressed: _showSensorSelection,
                ),

                SensorConnectionStatus(controller: controller, powerService: _powerService),

                Expanded(
                  child: Column(
                    children: [
                      MetricsGrid(displayedMetrics: controller.displayedMetrics),
                      RideControls(
                        isRiding: controller.rideState.isRiding,
                        isLapActive: controller.rideState.isLapActive,
                        onStartRide: _startRide,
                        onStopRide: _stopRide,
                        onLapPressed: _toggleLap,
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