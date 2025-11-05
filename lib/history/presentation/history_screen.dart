// [file name]: history_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oncetraining/history/presentation/ride_detail_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../cycle/domain/ride_session.dart';
import '../../core/services/gpx_storage_service.dart';
import 'package:flutter/services.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GpxStorageService _storage = GpxStorageService();
  late Future<List<RideSession>> _sessionsFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _sessionsFuture = _storage.getAllSessions();
    });
  }

  // ADD THIS METHOD FOR EXPORTING GPX FILES
  Future<void> _exportGpxFile(RideSession session) async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Request storage permission on Android
      if (await _requestStoragePermission()) {
        final exportedFile = await _storage.exportSessionToDownloads(session.id);

        if (exportedFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPX file downloaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () {
                  // You could add functionality to open the file location
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download GPX file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission required to download files'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      // For iOS, no permission needed for app directories
      if (!Platform.isAndroid) return true;

      // On Android 10+, we use scoped storage - no permissions needed for app directories
      // We only need permission if we want to access shared storage
      final sdkVersion = await Platform.version;
      print('Android SDK version: $sdkVersion');

      // For Android 10+ (API 29+), scoped storage is used by default
      // No permissions needed for app's private directory
      return true;

    } catch (e) {
      print('Storage permission check error: $e');
      return true; // Continue anyway with scoped storage
    }
  }

  Future<void> _showDeleteDialog(String id) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.blue.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Confirm Delete',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete this ride?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteSession(id); // Then delete
              },
            ),
          ],
        );
      },
    );
  }

  // Update the _buildSessionCard method to include download button
  Widget _buildSessionCard(RideSession session) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RideDetailScreen(session: session),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.directions_bike, color: Colors.white70, size: 32),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(session.startTime),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${session.distance.toStringAsFixed(1)} km • ${_formatDuration(Duration(seconds: session.durationSeconds))}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${session.avgPower}W • ${session.avgSpeed.toStringAsFixed(1)} km/h',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${session.avgPower} W',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _isExporting
                            ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                            ),
                          ),
                        )
                            : IconButton(
                          icon: _isExporting
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                            ),
                          )
                              : Icon(Icons.download, color: Colors.blue.shade300),
                          onPressed: _isExporting ? null : () => _exportGpxFile(session),
                          tooltip: 'Download/Share GPX for Strava',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red.shade300),
                          onPressed: () => _showDeleteDialog(session.id),
                          tooltip: 'Delete ride',
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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> _deleteSession(String id) async {
    await _storage.deleteSession(id);
    _refresh();
  }

  // ADD THE MISSING BUILD METHOD
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
                      'Ride History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white, size: 28),
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: RefreshIndicator(
                  color: Colors.blueAccent,
                  onRefresh: () async => _refresh(),
                  child: FutureBuilder<List<RideSession>>(
                    future: _sessionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading history',
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        );
                      }

                      final sessions = snapshot.data ?? [];

                      if (sessions.isEmpty) {
                        return Center(
                          child: Text(
                            'No ride history yet',
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return _buildSessionCard(session);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}