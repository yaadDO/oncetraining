import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../cycle/domain/ride_session.dart';
import 'package:flutter/services.dart';

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

                      // NEW: Lap Data Section
                      if (session.laps.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildLapSection(),
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
          if (session.laps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${session.laps.length} Laps',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ],
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

  // NEW: Lap Section Widget
  Widget _buildLapSection() {
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
            Row(
              children: [
                Icon(Icons.flag, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  'Lap Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                Spacer(),
                Text(
                  '${session.laps.length} Laps',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...session.laps.map((lap) => _buildLapCard(lap)).toList(),
          ],
        ),
      ),
    );
  }

  // NEW: Individual Lap Card
  Widget _buildLapCard(LapData lap) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lap Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lap ${lap.lapNumber}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDuration(lap.duration),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Lap Metrics - First Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLapMetric('Distance', '${lap.distance.toStringAsFixed(2)} km'),
              _buildLapMetric('Avg Power', '${lap.avgPower} W'),
              _buildLapMetric('Max Power', '${lap.maxPower} W'),
            ],
          ),
          SizedBox(height: 10),

          // Lap Metrics - Second Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLapMetric('Avg Speed', '${lap.avgSpeed.toStringAsFixed(1)} km/h'),
              _buildLapMetric('Max Speed', '${lap.maxSpeed.toStringAsFixed(1)} km/h'),
              _buildLapMetric('NP', '${lap.normalizedPower.toStringAsFixed(0)} W'),
            ],
          ),
          SizedBox(height: 10),

          // Lap Metrics - Third Row (if HR or Cadence data exists)
          if (lap.avgHeartRate > 0 || lap.avgCadence > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (lap.avgHeartRate > 0)
                  _buildLapMetric('Avg HR', '${lap.avgHeartRate} bpm'),
                if (lap.avgCadence > 0)
                  _buildLapMetric('Avg Cadence', '${lap.avgCadence} rpm'),
                Spacer(),
              ],
            ),
        ],
      ),
    );
  }

  // NEW: Helper for lap metrics
  Widget _buildLapMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));

    if (d.inHours > 0) {
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }
}