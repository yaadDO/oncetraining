// metric_block.dart
import 'package:flutter/material.dart';
import '../../domain/metric_model.dart';

class MetricBlockWidget extends StatelessWidget {
  final MetricBlock metric;

  const MetricBlockWidget({Key? key, required this.metric}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700.withOpacity(0.4),
            Colors.blue.shade700.withOpacity(0.2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(metric.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(metric.value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )),
            if (metric.unit.isNotEmpty)
              Text(metric.unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  )),
          ],
        ),
      ),
    );
  }
}