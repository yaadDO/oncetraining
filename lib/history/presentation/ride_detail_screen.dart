// ride_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../cycle/domain/ride_session.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle

class RideDetailScreen extends StatelessWidget {
  final RideSession session;

  const RideDetailScreen({Key? key, required this.session}) : super(key: key);

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
              // Custom App Bar
              Container(
                padding: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 15),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 15),
                    Text(
                      'Ride Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildSection('Power Metrics', [
                        _buildMetricItem('Average Power', '${session.avgPower} W'),
                        _buildMetricItem('Max Power', '${session.maxPower} W'),
                        _buildMetricItem('Normalized Power', '${session.normalizedPower.toStringAsFixed(0)} W'),
                        _buildMetricItem('3s Avg Power', '${session.power3sAvg} W'),
                        _buildMetricItem('Watts per Kg', session.wattsPerKilo.toStringAsFixed(1)),
                        _buildMetricItem('% FTP', session.ftpPercentage.toStringAsFixed(0)),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Speed & Distance', [
                        _buildMetricItem('Distance', '${session.distance.toStringAsFixed(2)} km'),
                        _buildMetricItem('Average Speed', '${session.avgSpeed.toStringAsFixed(1)} km/h'),
                        _buildMetricItem('Max Speed', '${session.maxSpeed.toStringAsFixed(1)} km/h'),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Energy', [
                        _buildMetricItem('Calories', session.calories.toStringAsFixed(0)),
                        _buildMetricItem('KiloJoules', '${session.kiloJoules} kJ'),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Heart Rate', [
                        _buildMetricItem('Average HR', '${session.avgHeartRate} bpm'),
                        _buildMetricItem('Max HR', '${session.maxHeartRate} bpm'),
                        _buildMetricItem('HR Zone', '${session.hrZone}'),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Cadence', [
                        _buildMetricItem('Average Cadence', '${session.avgCadence} rpm'),
                        _buildMetricItem('Max Cadence', '${session.maxCadence} rpm'),
                      ]),

                      if (session.deviceName != null) ...[
                        const SizedBox(height: 20),
                        _buildSection('Device', [
                          _buildMetricItem('Connected Device', session.deviceName!),
                        ]),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.15),
      ),
      child: Column(
        children: [
          Text(
            DateFormat.yMMMMd().format(session.startTime),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${session.distance.toStringAsFixed(2)} km • ${_formatDuration(Duration(seconds: session.durationSeconds))}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}