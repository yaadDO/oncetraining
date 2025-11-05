import 'package:flutter/material.dart';

class RideControls extends StatelessWidget {
  final bool isRiding;
  final bool isLapActive;
  final VoidCallback onStartRide;
  final VoidCallback onStopRide;
  final VoidCallback onLapPressed; // Single callback for lap

  const RideControls({
    super.key,
    required this.isRiding,
    required this.isLapActive,
    required this.onStartRide,
    required this.onStopRide,
    required this.onLapPressed,
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
              // Single Lap button that toggles between LAP and STOP LAP
              if (isRiding)
                _buildActionButton(
                    isLapActive ? "STOP LAP" : "LAP",
                    Icons.flag,
                    isLapActive ? [Colors.orange, Colors.orange.shade700] : [Colors.blueAccent, Colors.blue],
                    onLapPressed
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