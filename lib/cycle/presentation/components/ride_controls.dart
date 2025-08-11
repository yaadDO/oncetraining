// ride_controls.dart
import 'package:flutter/material.dart';

class RideControls extends StatelessWidget {
  final bool isRiding;
  final bool isLapActive;
  final VoidCallback onStartRide;
  final VoidCallback onStopRide;
  final VoidCallback onStartLap;
  final VoidCallback onStopLap;

  const RideControls({
    super.key,
    required this.isRiding,
    required this.isLapActive,
    required this.onStartRide,
    required this.onStopRide,
    required this.onStartLap,
    required this.onStopLap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              if (!isRiding)
                _buildActionButton(
                    "START RIDE",
                    Icons.play_arrow,
                    [Colors.green, Colors.green.shade700],
                    onStartRide
                ),
              if (isRiding)
                _buildActionButton(
                    "STOP RIDE",
                    Icons.stop,
                    [Colors.red, Colors.red.shade700],
                    onStopRide
                ),
              if (isRiding && !isLapActive)
                _buildActionButton(
                    "START LAP",
                    Icons.flag,
                    [Colors.blueAccent, Colors.blue],
                    onStartLap
                ),
              if (isRiding && isLapActive)
                _buildActionButton(
                    "STOP LAP",
                    Icons.flag,
                    [Colors.orange, Colors.orange.shade700],
                    onStopLap
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, List<Color> colors, VoidCallback onPressed) {
    return Container(
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
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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