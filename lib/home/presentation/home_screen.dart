import 'package:flutter/material.dart';
import '../../bluetooth/presentation/device_scan_screen.dart';
import '../../bluetooth/services/bluetooth_service.dart';
import '../../cycle/presentation/pages/cycle_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../planner/presentation/training_plans_screen.dart';
import '../../settings/presentation/user_settings_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient
          Container(
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
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Title
                    _buildAppHeader(),
                    const SizedBox(height: 40),

                    // Main Action Buttons
                    _buildActionButton(
                      context,
                      icon: Icons.directions_bike,
                      label: 'START RIDE',
                      color: Colors.green,
                      onPressed: () => _navigateTo(context, PowerDisplayScreen(device: null)),
                    ),
                    const SizedBox(height: 25),

                    _buildActionButton(
                      context,
                      icon: Icons.bluetooth,
                      label: 'CONNECT DEVICE',
                      color: Colors.blueAccent,
                      onPressed: () => _showSensorSelection(context),
                    ),
                    const SizedBox(height: 25),

                    _buildActionButton(
                      context,
                      icon: Icons.history,
                      label: 'RIDE HISTORY',
                      color: Colors.amber,
                      onPressed: () => _navigateTo(context, HistoryScreen()),
                    ),
                    const SizedBox(height: 25),

                    _buildActionButton(
                      context,
                      icon: Icons.fitness_center,
                      label: 'TRAINING PLANS',
                      color: Colors.deepPurple,
                      onPressed: () => _navigateTo(context, TrainingPlansScreen()),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Settings button in top-right corner
          Positioned(
            top: 50,
            right: 25,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.settings, size: 28, color: Colors.white),
                onPressed: () => _navigateTo(context, UserSettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _showSensorSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade800,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with spacing
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Select Sensor Type',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Sensor buttons with enhanced spacing
              _buildSensorButton(context, SensorType.powerMeter, 'Power Meter', Icons.flash_on),
              SizedBox(height: 15),
              _buildSensorButton(context, SensorType.heartRate, 'Heart Rate Monitor', Icons.favorite),
              SizedBox(height: 15),
              _buildSensorButton(context, SensorType.cadence, 'Cadence Sensor', Icons.repeat),
              SizedBox(height: 15),
              _buildSensorButton(context, SensorType.speed, 'Speed Sensor', Icons.speed),

              // Spacer and cancel button
              SizedBox(height: 25),
              Container(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorButton(BuildContext context, SensorType type, String label, IconData icon) {
    return ElevatedButton.icon(
      icon: Container(
        padding: EdgeInsets.all(10), // Space behind icon
        decoration: BoxDecoration(
          color: Colors.blue.shade900.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
      label: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(right: 10), // Space at end of label
            child: Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 3,
        alignment: Alignment.centerLeft,
      ),
      onPressed: () {
        Navigator.pop(context);
        _navigateTo(context, DeviceScanScreen(sensorType: type));
      },
    );
  }

  Widget _buildAppHeader() {
    return Column(
      children: [
        Icon(Icons.directions_bike, size: 64, color: Colors.white),
        const SizedBox(height: 15),
        Text('ONCETRAINING',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  blurRadius: 10.0,
                  color: Colors.black45,
                  offset: Offset(2.0, 2.0),
                ),
              ],
            )),
        const SizedBox(height: 5),
        Text('PERFORMANCE TRACKING',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              letterSpacing: 3.0,
            )),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: Colors.white),
                  const SizedBox(width: 15),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
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