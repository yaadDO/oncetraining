import 'package:flutter/material.dart';
import '../../domain/metric_model.dart';
import '../widgets/metric_block.dart';

class MetricsGrid extends StatelessWidget {
  final List<MetricBlock> displayedMetrics;

  const MetricsGrid({super.key, required this.displayedMetrics});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => MetricBlockWidget(metric: displayedMetrics[index]),
                childCount: displayedMetrics.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}