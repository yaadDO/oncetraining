import 'package:flutter/material.dart';
import '../domain/ride_plan.dart';

class PlanMakerScreen extends StatefulWidget {
  final RidePlan? existingPlan;

  const PlanMakerScreen({this.existingPlan});

  @override
  _PlanMakerScreenState createState() => _PlanMakerScreenState();
}

class _PlanMakerScreenState extends State<PlanMakerScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late List<RidePlanInterval> _intervals;
  final _formKey = GlobalKey<FormState>();
  final _durationRegex = RegExp(r'^[0-9]{1,2}:[0-5][0-9]$');

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingPlan?.title ?? '',
    );
    _descController = TextEditingController(
      text: widget.existingPlan?.description ?? '',
    );
    _intervals = widget.existingPlan?.intervals.toList() ?? [
      RidePlanInterval(title: 'Warmup', duration: 600),
    ];
  }

  void _addInterval() {
    setState(() {
      _intervals.add(RidePlanInterval(
        title: 'New Interval',
        duration: 300,
      ));
    });
  }

  void _savePlan() {
    if (_formKey.currentState!.validate()) {
      final newPlan = RidePlan(
        id: widget.existingPlan?.id ?? DateTime.now().toIso8601String(),
        title: _titleController.text,
        description: _descController.text,
        intervals: _intervals,
      );

      Navigator.pop(context, newPlan);
    }
  }

  void _updateInterval(int index, RidePlanInterval newInterval) {
    setState(() {
      _intervals[index] = newInterval;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.existingPlan != null ? 'Edit Plan' : 'Create Plan',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(Icons.save, color: Colors.white),
                onPressed: _savePlan,
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  _buildInputField(
                    controller: _titleController,
                    label: 'Plan Title',
                    icon: Icons.title,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildInputField(
                    controller: _descController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 3,
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.repeat, color: Colors.white70, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Intervals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ..._intervals.asMap().entries.map((entry) =>
                      IntervalEditor(
                        interval: entry.value,
                        index: entry.key,
                        onChanged: (newInterval) =>
                            _updateInterval(entry.key, newInterval),
                        onDelete: () => setState(() =>
                            _intervals.removeAt(entry.key)),
                        durationRegex: _durationRegex,
                      )
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addInterval,
                    icon: Icon(Icons.add, color: Colors.white),
                    label: Text('Add Interval', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int? maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          errorStyle: TextStyle(color: Colors.red[300]),
        ),
        validator: validator,
        maxLines: maxLines,
      ),
    );
  }
}

class IntervalEditor extends StatefulWidget {
  final RidePlanInterval interval;
  final int index;
  final Function(RidePlanInterval) onChanged;
  final VoidCallback onDelete;
  final RegExp durationRegex;

  const IntervalEditor({
    required this.interval,
    required this.index,
    required this.onChanged,
    required this.onDelete,
    required this.durationRegex,
  });

  @override
  _IntervalEditorState createState() => _IntervalEditorState();
}

class _IntervalEditorState extends State<IntervalEditor> {
  late TextEditingController _titleController;
  late TextEditingController _durationController;
  late TextEditingController _powerController;
  late TextEditingController _hrController;
  late TextEditingController _speedController;
  late TextEditingController _cadenceController;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.interval.title);
    _durationController = TextEditingController(
      text: _formatDuration(widget.interval.duration),
    );
    _powerController = TextEditingController(
      text: widget.interval.targetPower?.toString() ?? '',
    );
    _hrController = TextEditingController(
      text: widget.interval.targetHeartRate?.toString() ?? '',
    );
    _speedController = TextEditingController(
      text: widget.interval.targetSpeed?.toString() ?? '',
    );
    _cadenceController = TextEditingController(
      text: widget.interval.targetCadence?.toString() ?? '',
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int _parseDuration(String input) {
    final parts = input.split(':');
    if (parts.length != 2) return 0;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;

    return (minutes * 60) + seconds;
  }

  void _validateDuration(String value) {
    if (value.isEmpty) {
      _durationError = 'Duration is required';
    } else if (!widget.durationRegex.hasMatch(value)) {
      _durationError = 'Invalid format (use MM:SS)';
    } else {
      _durationError = null;
    }
    _updateInterval();
  }

  void _updateInterval() {
    widget.onChanged(RidePlanInterval(
      title: _titleController.text,
      duration: _parseDuration(_durationController.text),
      targetPower: int.tryParse(_powerController.text),
      targetHeartRate: int.tryParse(_hrController.text),
      targetSpeed: double.tryParse(_speedController.text),
      targetCadence: int.tryParse(_cadenceController.text),
    ));
  }

  Widget _buildIntervalInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          errorText: label == 'Duration (MM:SS)' ? _durationError : null,
          errorStyle: TextStyle(color: Colors.red[300]),
        ),
        keyboardType: keyboardType,
        onChanged: (_) => _updateInterval(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade800.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade600, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Interval ${widget.index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildIntervalInputField(
              controller: _titleController,
              label: 'Title',
              icon: Icons.title,
            ),
            SizedBox(height: 12),
            _buildIntervalInputField(
              controller: _durationController,
              label: 'Duration (MM:SS)',
              icon: Icons.timer,
            ),
            SizedBox(height: 16),
            Text(
              'Target Metrics (optional)',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildIntervalInputField(
                    controller: _powerController,
                    label: 'Power (W)',
                    icon: Icons.flash_on,
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildIntervalInputField(
                    controller: _hrController,
                    label: 'Heart Rate',
                    icon: Icons.favorite,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildIntervalInputField(
                    controller: _speedController,
                    label: 'Speed (km/h)',
                    icon: Icons.speed,
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildIntervalInputField(
                    controller: _cadenceController,
                    label: 'Cadence (rpm)',
                    icon: Icons.repeat,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}