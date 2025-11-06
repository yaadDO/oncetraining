import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import '../services/bluetooth_service.dart';
import '../../core/domain/sensor_type.dart'; // ADD THIS IMPORT
import '../../cycle/presentation/pages/cycle_screen.dart';

class DeviceScanScreen extends StatefulWidget {
  final SensorType sensorType;

  const DeviceScanScreen({super.key, required this.sensorType});

  @override
  DeviceScanScreenState createState() => DeviceScanScreenState();
}

class DeviceScanScreenState extends State<DeviceScanScreen>
    with TickerProviderStateMixin {
  final PowerMeterService _bluetoothService = PowerMeterService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  String _status = "Tap the scan button to start";
  String? _error;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize wave animation
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _startScan();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bluetoothService.stopScan();
    _bluetoothService.dispose();
    super.dispose();
  }

  String _getSensorName() {
    switch (widget.sensorType) {
      case SensorType.powerMeter:
        return "Power Meter";
      case SensorType.heartRate:
        return "Heart Rate Monitor";
      case SensorType.cadence:
        return "Cadence Sensor";
      case SensorType.speed:
        return "Speed Sensor";
      default:
        return "Sensor";
    }
  }

  IconData _getSensorIcon() {
    switch (widget.sensorType) {
      case SensorType.powerMeter:
        return Icons.flash_on;
      case SensorType.heartRate:
        return Icons.favorite;
      case SensorType.cadence:
        return Icons.repeat;
      case SensorType.speed:
        return Icons.speed;
      default:
        return Icons.device_unknown;
    }
  }

  Color _getSensorColor() {
    switch (widget.sensorType) {
      case SensorType.powerMeter:
        return Colors.amber;
      case SensorType.heartRate:
        return Colors.red;
      case SensorType.cadence:
        return Colors.green;
      case SensorType.speed:
        return Colors.blueAccent;
      default:
        return Colors.blue;
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _status = "Scanning for ${_getSensorName()}...";
      _error = null;
      _devices.clear();
    });

    try {
      _bluetoothService.startScan(widget.sensorType);
      _bluetoothService.scanResults.listen((devices) {
        setState(() {
          _devices = devices;
          _status = _devices.isEmpty
              ? "No devices found"
              : "Found ${_devices.length} ${_getSensorName()} devices";
        });
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = "Scan failed";
        _isScanning = false;
      });
    }
  }

  void _stopScan() {
    _bluetoothService.stopScan();
    setState(() {
      _isScanning = false;
      _status = "Scan stopped";
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    // Stop scanning when connecting
    _stopScan();

    // Show connecting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Connecting...', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Connecting to ${device.name ?? 'device'}...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );

    try {
      // Wait a moment for the dialog to show
      await Future.delayed(Duration(milliseconds: 500));

      // Return the device to the previous screen
      Navigator.pop(context); // Close the dialog
      Navigator.pop(context, device); // Return to cycle screen with device
    } catch (e) {
      Navigator.pop(context); // Close the dialog
      Navigator.pop(context, device); // Still return the device
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // Custom App Bar with improved spacing
              Container(
                padding: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 15),
                child: Row(
                  children: [
                    // Back button with spacing
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Space between back button and sensor info
                    Spacer(),

                    // Sensor Icon with background and spacing
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getSensorColor().withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getSensorColor(),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getSensorIcon(),
                        color: _getSensorColor(),
                        size: 28,
                      ),
                    ),

                    // Space between icon and text
                    SizedBox(width: 15),

                    // Sensor name with padding
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getSensorName(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Space at the end
                    SizedBox(width: 10),
                  ],
                ),
              ),

              // Scanning Status with Animation
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _waveAnimation.value,
                          child: Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bluetooth,
                              color: _isScanning ? Colors.cyan : Colors.white70,
                              size: 50,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 15),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _status,
                            style: TextStyle(
                              color: _error != null ? Colors.red[300] : Colors.white,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red[200], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scan Button with spacing
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                child: ElevatedButton.icon(
                  icon: Icon(_isScanning ? Icons.stop : Icons.search, size: 24),
                  label: Text(
                    _isScanning ? 'STOP SCAN' : 'START SCAN',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? Colors.red : Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  onPressed: _isScanning ? _stopScan : _startScan,
                ),
              ),

              // Devices List with improved empty state
              Expanded(
                child: _devices.isEmpty && !_isScanning
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.device_unknown,
                          size: 60,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      SizedBox(height: 25),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'No devices found',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Make sure your device is turned on and nearby',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return _buildDeviceCard(device, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _connectToDevice(device),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Device Icon with background
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  // Space between icon and text
                  SizedBox(width: 20),

                  // Device Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name ?? "Unknown Device",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6),
                        Text(
                          device.id.toString(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Space between text and button
                  SizedBox(width: 15),

                  // Connect Button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Connect',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}