// training_plans_screen.dart
import 'package:flutter/material.dart';
import '../domain/ride_plan.dart';
import '../services/plan_storage_service.dart';
import 'plan_maker_screen.dart';

class TrainingPlansScreen extends StatefulWidget {
  @override
  _TrainingPlansScreenState createState() => _TrainingPlansScreenState();
}

class _TrainingPlansScreenState extends State<TrainingPlansScreen> {
  final PlanStorageService _storage = PlanStorageService();
  late Future<List<RidePlan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _plansFuture = _storage.getPlans();
    });
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Plan?', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade800,
        content: Text('Are you sure you want to delete this training plan?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: Colors.red[300])),
            onPressed: () {
              _storage.deletePlan(id).then((_) {
                Navigator.pop(context);
                _refresh();
              });
            },
          ),
        ],
      ),
    );
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
            title: Text('Training Plans', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _refresh,
                color: Colors.white,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.add, size: 32),
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            onPressed: () => _navigateToPlanMaker(null),
            elevation: 8,
          ),
          body: FutureBuilder<List<RidePlan>>(
            future: _plansFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, size: 64, color: Colors.white.withOpacity(0.5)),
                      SizedBox(height: 20),
                      Text(
                        'No training plans yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Create your first plan to get started',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Create Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () => _navigateToPlanMaker(null),
                      ),
                    ],
                  ),
                );
              }

              final plans = snapshot.data!;
              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return _buildPlanCard(plan, context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(RidePlan plan, BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade600,
          ],
        ),
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
          onTap: () => Navigator.pop(context, plan),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white70),
                      color: Colors.blue.shade800,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white70),
                              SizedBox(width: 10),
                              Text('Edit', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red[300]),
                              SizedBox(width: 10),
                              Text('Delete', style: TextStyle(color: Colors.red[300])),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _navigateToPlanMaker(plan);
                        } else if (value == 'delete') {
                          _showDeleteDialog(plan.id);
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  plan.description,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 18, color: Colors.white70),
                        SizedBox(width: 5),
                        Text(
                          '${plan.intervals.length} intervals',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 18, color: Colors.white70),
                        SizedBox(width: 5),
                        Text(
                          _totalDuration(plan),
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _totalDuration(RidePlan plan) {
    final totalSeconds = plan.intervals.fold(
        0, (sum, interval) => sum + interval.duration);
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _navigateToPlanMaker(RidePlan? plan) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanMakerScreen(existingPlan: plan),
      ),
    );

    if (result != null && result is RidePlan) {
      await _storage.savePlan(result);
      _refresh();
    }
  }
}