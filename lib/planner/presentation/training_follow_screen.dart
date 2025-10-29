import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../domain/ride_plan.dart';
import '../../bluetooth/services/bluetooth_service.dart';
import '../../cycle/domain/ride_data.dart';
import '../../cycle/domain/metric_model.dart';
import '../../bluetooth/presentation/device_scan_screen.dart';

class TrainingFollowScreen extends StatefulWidget {
  final RidePlan plan;

  const TrainingFollowScreen({Key? key, required this.plan}) : super(key: key);

  @override
  _TrainingFollowScreenState createState() => _TrainingFollowScreenState();
}

class _TrainingFollowScreenState extends State<TrainingFollowScreen> {
  final PowerMeterService _bluetoothService = PowerMeterService();
  final RideData _rideData = RideData();

  int _currentIntervalIndex = 0;
  int _intervalTimeElapsed = 0;
  Timer? _intervalTimer;
  bool _isRiding = false;

  // Current sensor values
  int _currentPower = 0;
  int _currentHeartRate = 0;
  int _currentCadence = 0;
  double _currentSpeed = 0.0;

  // Connection status
  bool _isPowerConnected = false;
  bool _isHeartRateConnected = false;
  bool _isCadenceConnected = false;

  @override
  void initState() {
    super.initState();
    _setupBluetoothListeners();
  }

  void _setupBluetoothListeners() {
    _bluetoothService.powerStream.listen((power) {
      if (mounted) {
        setState(() {
          _currentPower = power;
          _isPowerConnected = true;
        });
      }
    });

    _bluetoothService.heartRateStream.listen((hr) {
      if (mounted) {
        setState(() {
          _currentHeartRate = hr;
          _isHeartRateConnected = true;
        });
      }
    });

    _bluetoothService.cadenceStream.listen((cadence) {
      if (mounted) {
        setState(() {
          _currentCadence = cadence;
          _isCadenceConnected = true;
        });
      }
    });

    _bluetoothService.speedStream.listen((speed) {
      if (mounted) {
        setState(() {
          _currentSpeed = speed;
        });
      }
    });
  }

  void _startTraining() {
    setState(() {
      _isRiding = true;
      _currentIntervalIndex = 0;
      _intervalTimeElapsed = 0;
    });

    _startIntervalTimer();
  }

  void _startIntervalTimer() {
    _intervalTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _intervalTimeElapsed++;

          // Check if current interval is completed
          final currentInterval = widget.plan.intervals[_currentIntervalIndex];
          if (_intervalTimeElapsed >= currentInterval.duration) {
            _nextInterval();
          }
        });
      }
    });
  }

  void _nextInterval() {
    setState(() {
      _intervalTimeElapsed = 0;
      if (_currentIntervalIndex < widget.plan.intervals.length - 1) {
        _currentIntervalIndex++;
      } else {
        // Training completed
        _stopTraining();
      }
    });
  }

  void _stopTraining() {
    _intervalTimer?.cancel();
    setState(() {
      _isRiding = false;
      _currentIntervalIndex = 0;
      _intervalTimeElapsed = 0;
    });
  }

  void _pauseResumeTraining() {
    if (_isRiding) {
      _intervalTimer?.cancel();
    } else {
      _startIntervalTimer();
    }

    setState(() {
      _isRiding = !_isRiding;
    });
  }

  Color _getTargetColor(int? target, int current, {bool isHigherBetter = true}) {
    if (target == null) return Colors.grey;

    final difference = current - target;
    final percentageDiff = (difference / target * 100).abs();

    if (percentageDiff <= 5) return Colors.green;
    if (percentageDiff <= 15) return Colors.orange;
    return Colors.red;
  }

  Color _getTimeColor() {
    final currentInterval = widget.plan.intervals[_currentIntervalIndex];
    final progress = _intervalTimeElapsed / currentInterval.duration;

    if (progress < 0.8) return Colors.green;
    if (progress < 0.95) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTargetIndicator(String label, int? target, int current, String unit, {bool isHigherBetter = true}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getTargetColor(target, current, isHigherBetter: isHigherBetter),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 4),
          Text(
            target != null ? '$target $unit' : 'No Target',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            '$current $unit',
            style: TextStyle(
              color: _getTargetColor(target, current, isHigherBetter: isHigherBetter),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalProgress() {
    final currentInterval = widget.plan.intervals[_currentIntervalIndex];
    final progress = _intervalTimeElapsed / currentInterval.duration;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interval ${_currentIntervalIndex + 1}/${widget.plan.intervals.length}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                currentInterval.title,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.blue.shade600,
            valueColor: AlwaysStoppedAnimation<Color>(_getTimeColor()),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatSeconds(_intervalTimeElapsed)} / ${_formatSeconds(currentInterval.duration)}',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildConnectionChip('Power', _isPowerConnected, Icons.flash_on),
          _buildConnectionChip('HR', _isHeartRateConnected, Icons.favorite),
          _buildConnectionChip('Cadence', _isCadenceConnected, Icons.repeat),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(String label, bool connected, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: connected ? Colors.green : Colors.red, size: 20),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
        Text(
          connected ? 'Connected' : 'Disconnected',
          style: TextStyle(
            color: connected ? Colors.green : Colors.red,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  void _connectSensor(SensorType sensorType) async {
    final device = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceScanScreen(sensorType: sensorType),
      ),
    );

    if (device != null && device is BluetoothDevice) {
      await _bluetoothService.connect(sensorType, device);
    }
  }

  @override
  void dispose() {
    _intervalTimer?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentInterval = _currentIntervalIndex < widget.plan.intervals.length
        ? widget.plan.intervals[_currentIntervalIndex]
        : widget.plan.intervals.last;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
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
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.plan.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Following Training Plan',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.bluetooth, color: Colors.white),
                        onPressed: () => _showSensorSelection(),
                      ),
                    ],
                  ),
                ),

                // Connection Status
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _buildConnectionStatus(),
                ),

                SizedBox(height: 16),

                // Interval Progress
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _buildIntervalProgress(),
                ),

                SizedBox(height: 16),

                // Target Indicators
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _buildTargetIndicator(
                        'Power Target',
                        currentInterval.targetPower,
                        _currentPower,
                        'W',
                      ),
                      _buildTargetIndicator(
                        'Heart Rate Target',
                        currentInterval.targetHeartRate,
                        _currentHeartRate,
                        'bpm',
                      ),
                      _buildTargetIndicator(
                        'Cadence Target',
                        currentInterval.targetCadence,
                        _currentCadence,
                        'rpm',
                      ),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Speed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            SizedBox(height: 4),
                            Text(
                              currentInterval.targetSpeed != null
                                  ? '${currentInterval.targetSpeed} km/h'
                                  : 'No Target',
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${_currentSpeed.toStringAsFixed(1)} km/h',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Spacer(),

                // Controls
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!_isRiding && _currentIntervalIndex == 0)
                        ElevatedButton.icon(
                          icon: Icon(Icons.play_arrow, color: Colors.white),
                          label: Text('START', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _startTraining,
                        )
                      else if (_isRiding)
                        ElevatedButton.icon(
                          icon: Icon(Icons.pause, color: Colors.white),
                          label: Text('PAUSE', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _pauseResumeTraining,
                        )
                      else if (!_isRiding && _currentIntervalIndex > 0)
                          ElevatedButton.icon(
                            icon: Icon(Icons.play_arrow, color: Colors.white),
                            label: Text('RESUME', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _pauseResumeTraining,
                          ),

                      ElevatedButton.icon(
                        icon: Icon(Icons.stop, color: Colors.white),
                        label: Text('STOP', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _stopTraining,
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
              _buildSensorButton(SensorType.powerMeter, 'Power Meter', Icons.flash_on),
              SizedBox(height: 10),
              _buildSensorButton(SensorType.heartRate, 'Heart Rate Monitor', Icons.favorite),
              SizedBox(height: 10),
              _buildSensorButton(SensorType.cadence, 'Cadence Sensor', Icons.repeat),
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
        _connectSensor(type);
      },
    );
  }
}