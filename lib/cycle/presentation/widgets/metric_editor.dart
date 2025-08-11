// metric_editor.dart
import 'package:flutter/material.dart';
import '../../domain/metric_model.dart';

class MetricEditor extends StatefulWidget {
  final List<MetricBlock> allMetrics;
  final List<MetricBlock> displayedMetrics;
  final Function(List<MetricBlock>) onSave;

  const MetricEditor({
    Key? key,
    required this.allMetrics,
    required this.displayedMetrics,
    required this.onSave,
  }) : super(key: key);

  @override
  _MetricEditorState createState() => _MetricEditorState();
}

class _MetricEditorState extends State<MetricEditor> {
  late List<MetricBlock> _selectedMetrics;
  final List<String> _categoryOrder = [
    'power',
    'speed',
    'time',
    'distance',
    'energy',
    'heart_rate',
    'cadence',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedMetrics = List.from(widget.displayedMetrics);
  }

  Map<String, List<MetricBlock>> _groupByCategory(List<MetricBlock> metrics) {
    final groups = <String, List<MetricBlock>>{};
    for (final metric in metrics) {
      groups.putIfAbsent(metric.category, () => []).add(metric);
    }
    return groups;
  }

  List<String> _getOrderedCategories(Set<String> categories) {
    final ordered = <String>[];

    // Add categories in predefined order
    for (final category in _categoryOrder) {
      if (categories.contains(category)) {
        ordered.add(category);
        categories.remove(category);
      }
    }

    // Add any remaining categories
    ordered.addAll(categories.toList());
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroups = _groupByCategory(_selectedMetrics);
    final selectedCategories = _getOrderedCategories(selectedGroups.keys.toSet());

    final availableMetrics = widget.allMetrics
        .where((metric) => !_selectedMetrics.any((m) => m.key == metric.key))
        .toList();
    final availableGroups = _groupByCategory(availableMetrics);
    final availableCategories = _getOrderedCategories(availableGroups.keys.toSet());

    return Container(
      padding: EdgeInsets.all(25),
      child: Column(
        children: [
          Text('Customize Metrics Display',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),
          SizedBox(height: 16),
          Text('Drag to reorder, tap ➕ to add, tap 🗑 to remove',
              style: TextStyle(color: Colors.white70)),
          SizedBox(height: 25),
          Expanded(
            child: ListView(
              children: [
                Text('Selected Metrics',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600
                    )
                ),
                SizedBox(height: 12),
                for (final category in selectedCategories)
                  _buildCategorySection(
                    category,
                    selectedGroups[category]!,
                    isSelected: true,
                  ),
              ],
            ),
          ),
          SizedBox(height: 25),
          Expanded(
            child: ListView(
              children: [
                Text('Available Metrics',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600
                    )
                ),
                SizedBox(height: 12),
                for (final category in availableCategories)
                  _buildCategorySection(
                    category,
                    availableGroups[category]!,
                    isSelected: false,
                  ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              Container(
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
                    onTap: () {
                      widget.onSave(_selectedMetrics);
                      Navigator.pop(context);
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green,
                            Colors.green.shade700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                        child: Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
      String category, List<MetricBlock> metrics, {required bool isSelected}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        _getCategoryTitle(category),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      children: [
        if (isSelected)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;

                // Find the global indices for these metrics
                final metric = metrics[oldIndex];
                final oldGlobalIndex = _selectedMetrics.indexOf(metric);
                final newGlobalIndex = _selectedMetrics.indexOf(metrics[newIndex]);

                // Adjust new index if moving down
                final adjustedNewIndex = newIndex > oldIndex ? newGlobalIndex : newGlobalIndex;

                // Reorder in global list
                final item = _selectedMetrics.removeAt(oldGlobalIndex);
                _selectedMetrics.insert(adjustedNewIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return Container(
                key: ValueKey(metric.key),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  title: Text(
                    metric.title,
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade300),
                    onPressed: () {
                      setState(() {
                        _selectedMetrics.removeWhere((m) => m.key == metric.key);
                      });
                    },
                  ),
                ),
              );
            },
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  title: Text(
                    metric.title,
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.add, color: Colors.green),
                  onTap: () {
                    setState(() {
                      _selectedMetrics.add(metric);
                    });
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'power': return 'Power Metrics';
      case 'speed': return 'Speed Metrics';
      case 'time': return 'Time Metrics';
      case 'distance': return 'Distance Metrics';
      case 'energy': return 'Energy Metrics';
      case 'heart_rate': return 'Heart Rate Metrics';
      case 'cadence': return 'Cadence Metrics';
      default: return 'Other Metrics';
    }
  }
}