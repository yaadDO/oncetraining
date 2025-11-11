// gpx_storage_service.dart
import 'dart:io';
import 'package:gpx/gpx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart' as xml;
import '../../cycle/domain/ride_session.dart';

class GpxStorageService {
  static const String _directoryName = 'rideSessions';

  Future<Directory> _getAppDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${appDir.path}/$_directoryName');

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> saveSession(RideSession session) async {
    final dir = await _getAppDirectory();
    final file = File('${dir.path}/${session.id}.gpx');

    // Create enhanced GPX with power data
    final gpxContent = _createEnhancedGpx(session);
    await file.writeAsString(gpxContent);
  }

  String _createEnhancedGpx(RideSession session) {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('gpx', nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'Power Meter App');
      builder.attribute('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance');
      builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');
      builder.attribute('xsi:schemaLocation',
          'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd');
      builder.attribute('xmlns:gpxtpx', 'http://www.garmin.com/xmlschemas/TrackPointExtension/v1');
      builder.attribute('xmlns:gpxx', 'http://www.garmin.com/xmlschemas/GpxExtensions/v3');

      // Metadata
      builder.element('metadata', nest: () {
        builder.element('name', nest: 'Cycling Activity - ${DateFormat('yyyy-MM-dd HH:mm').format(session.startTime)}');
        builder.element('time', nest: session.startTime.toUtc().toIso8601String());
        builder.element('desc', nest:
        'Power: ${session.avgPower}W avg, ${session.maxPower}W max | '
            'Distance: ${session.distance.toStringAsFixed(2)}km | '
            'Duration: ${_formatDuration(Duration(seconds: session.durationSeconds))}');
      });

      // Track
      builder.element('trk', nest: () {
        builder.element('name', nest: 'Cycling Activity');
        builder.element('type', nest: '9'); // Strava activity type for cycling

        // Track segment
        builder.element('trkseg', nest: () {
          // Use detailed data points if available, otherwise use GPS points
          if (session.dataPoints.isNotEmpty) {
            _buildTrackPointsFromDataPoints(builder, session);
          } else {
            _buildTrackPointsFromGpsPoints(builder, session);
          }
        });

        // Add extensions for session summary
        builder.element('extensions', nest: () {
          _buildSessionExtensions(builder, session);
        });
      });

      // Add extensions at root level for Strava compatibility
      builder.element('extensions', nest: () {
        _buildRootExtensions(builder, session);
      });
    });

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  void _buildTrackPointsFromDataPoints(xml.XmlBuilder builder, RideSession session) {
    for (final dataPoint in session.dataPoints) {
      builder.element('trkpt', nest: () {
        // Use actual GPS coordinates if available, otherwise use default
        final gpsPoint = _findGpsPointForTimestamp(session.gpsPoints, dataPoint.timestamp);

        builder.attribute('lat', gpsPoint?['lat'] ?? 0.0);
        builder.attribute('lon', gpsPoint?['lon'] ?? 0.0);

        builder.element('ele', nest: gpsPoint?['ele'] ?? dataPoint.altitude);
        builder.element('time', nest: dataPoint.timestamp.toUtc().toIso8601String());

        // Add sensor data as extensions (Strava compatible)
        builder.element('extensions', nest: () {
          builder.element('gpxtpx:TrackPointExtension', nest: () {
            builder.element('gpxtpx:hr', nest: dataPoint.heartRate);
            builder.element('gpxtpx:cad', nest: dataPoint.cadence);

            // Power data - Strava will recognize this
            if (dataPoint.power > 0) {
              builder.element('gpxtpx:power', nest: dataPoint.power);
            }

            // Speed and distance
            builder.element('gpxtpx:speed', nest: dataPoint.speed / 3.6); // Convert to m/s
            builder.element('gpxtpx:distance', nest: dataPoint.distance * 1000); // Convert to meters
          });
        });
      });
    }
  }

  void _buildTrackPointsFromGpsPoints(xml.XmlBuilder builder, RideSession session) {
    for (final point in session.gpsPoints) {
      builder.element('trkpt', nest: () {
        builder.attribute('lat', point['lat'] ?? 0.0);
        builder.attribute('lon', point['lon'] ?? 0.0);

        builder.element('ele', nest: point['ele'] ?? 0.0);

        final time = session.startTime.add(Duration(
            seconds: (point['timeOffset'] ?? 0).toInt()
        ));
        builder.element('time', nest: time.toUtc().toIso8601String());

        // Add extensions even for basic GPS points
        builder.element('extensions', nest: () {
          builder.element('gpxtpx:TrackPointExtension', nest: () {
            // Add average values for the session
            builder.element('gpxtpx:hr', nest: session.avgHeartRate);
            builder.element('gpxtpx:cad', nest: session.avgCadence);
            builder.element('gpxtpx:power', nest: session.avgPower);
          });
        });
      });
    }
  }

  Map<String, double>? _findGpsPointForTimestamp(List<Map<String, double>> gpsPoints, DateTime timestamp) {
    if (gpsPoints.isEmpty) return null;

    // Find the closest GPS point by time
    final sessionStart = timestamp;
    for (final point in gpsPoints) {
      final pointTime = sessionStart.add(Duration(seconds: (point['timeOffset'] ?? 0).toInt()));
      if ((pointTime.difference(timestamp).inSeconds).abs() < 10) {
        return point;
      }
    }

    return gpsPoints.first;
  }

  void _buildSessionExtensions(xml.XmlBuilder builder, RideSession session) {
    builder.element('gpxx:TrackExtension', nest: () {
      builder.element('gpxx:DisplayColor', nest: 'Red'); // Strava color
    });
  }

  void _buildRootExtensions(xml.XmlBuilder builder, RideSession session) {
    builder.element('power', nest: session.avgPower);
    builder.element('total_elevation_gain', nest: session.altitudeGain.toStringAsFixed(1));
    builder.element('elevation_gain', nest: session.altitudeGain.toStringAsFixed(1));
    builder.element('max_elevation', nest: session.maxAltitude.toStringAsFixed(1));

    // Device info
    if (session.deviceName != null) {
      builder.element('device', nest: session.deviceName!);
    }

    // Power metrics
    builder.element('avg_power', nest: session.avgPower);
    builder.element('max_power', nest: session.maxPower);
    builder.element('normalized_power', nest: session.normalizedPower.toStringAsFixed(0));
    builder.element('intensity_factor', nest: (session.normalizedPower / (session.ftpPercentage > 0 ? session.ftpPercentage : 250)).toStringAsFixed(2));
    builder.element('training_stress_score', nest: _calculateTSS(session).toStringAsFixed(0));

    // Heart rate metrics
    builder.element('avg_heart_rate', nest: session.avgHeartRate);
    builder.element('max_heart_rate', nest: session.maxHeartRate);

    // Cadence metrics
    builder.element('avg_cadence', nest: session.avgCadence);
    builder.element('max_cadence', nest: session.maxCadence);

    // Speed metrics
    builder.element('avg_speed', nest: (session.avgSpeed / 3.6).toStringAsFixed(2)); // m/s
    builder.element('max_speed', nest: (session.maxSpeed / 3.6).toStringAsFixed(2)); // m/s

    // Energy metrics
    builder.element('calories', nest: session.calories.toStringAsFixed(0));
    builder.element('kilojoules', nest: session.kiloJoules);
  }

  double _calculateTSS(RideSession session) {
    if (session.durationSeconds == 0 || session.ftpPercentage == 0) return 0;

    final hours = session.durationSeconds / 3600;
    final intensity = session.normalizedPower / (session.ftpPercentage > 0 ? session.ftpPercentage : 250);

    return (session.durationSeconds * session.normalizedPower * intensity) / ((session.ftpPercentage > 0 ? session.ftpPercentage : 250) * 3600) * 100;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<File?> exportSessionToDownloads(String sessionId) async {
    try {
      final dir = await _getAppDirectory();
      final sourceFile = File('${dir.path}/$sessionId.gpx');

      if (!await sourceFile.exists()) {
        print('GPX file not found for session: $sessionId');
        return null;
      }

      // Use app's documents directory (scoped storage)
      final appDocDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${appDocDir.path}/exports');

      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

      // Copy file to exports directory
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final destFile = File('${exportsDir.path}/Ride_${sessionId}_$timestamp.gpx');

      await sourceFile.copy(destFile.path);
      print('GPX file exported to: ${destFile.path}');

      return destFile;
    } catch (e) {
      print('Error exporting GPX file: $e');
      return null;
    }
  }

  void _showDownloadNotification(String filePath) {
    // This would typically use flutter_local_notifications
    print('File downloaded to: $filePath');
  }

  // ADD THIS METHOD TO GET THE GPX FILE FOR SHARING
  Future<File?> getSessionGpxFile(String sessionId) async {
    try {
      final dir = await _getAppDirectory();
      final file = File('${dir.path}/$sessionId.gpx');

      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting GPX file: $e');
      return null;
    }
  }

  Future<List<RideSession>> getAllSessions() async {
    final dir = await _getAppDirectory();
    final files = await dir.list()
        .where((entity) => entity is File && entity.path.endsWith('.gpx'))
        .cast<File>()
        .toList();

    final sessions = <RideSession>[];
    final reader = GpxReader();

    for (final file in files) {
      try {
        final contents = await file.readAsString();
        final gpx = reader.fromString(contents);

        // Extract values from extensions map
        final deviceName = _getExtensionValue(gpx, 'deviceName');
        final durationSeconds = _getExtensionValue(gpx, 'durationSeconds');
        final avgPower = _getExtensionValue(gpx, 'avgPower');
        final maxPower = _getExtensionValue(gpx, 'maxPower');
        final distance = _getExtensionValue(gpx, 'distance');
        final calories = _getExtensionValue(gpx, 'calories');
        final kiloJoules = _getExtensionValue(gpx, 'kiloJoules');
        final normalizedPower = _getExtensionValue(gpx, 'normalizedPower');
        final avgSpeed = _getExtensionValue(gpx, 'avgSpeed');
        final maxSpeed = _getExtensionValue(gpx, 'maxSpeed');
        final wattsPerKilo = _getExtensionValue(gpx, 'wattsPerKilo');
        final power3sAvg = _getExtensionValue(gpx, 'power3sAvg');
        final ftpPercentage = _getExtensionValue(gpx, 'ftpPercentage');
        final hrZone = _getExtensionValue(gpx, 'hrZone');
        final avgHeartRate = _getExtensionValue(gpx, 'avgHeartRate');
        final maxHeartRate = _getExtensionValue(gpx, 'maxHeartRate');
        final avgCadence = _getExtensionValue(gpx, 'avgCadence');
        final maxCadence = _getExtensionValue(gpx, 'maxCadence');
        final power10sAvg = _getExtensionValue(gpx, 'power10sAvg');
        final power20sAvg = _getExtensionValue(gpx, 'power20sAvg');
        final ftpZone = _getExtensionValue(gpx, 'ftpZone');
        final altitude = _getExtensionValue(gpx, 'altitude');
        final altitudeGain = _getExtensionValue(gpx, 'altitudeGain');
        final maxAltitude = _getExtensionValue(gpx, 'maxAltitude');

        // Extract GPS points
        List<Map<String, double>> gpsPoints = [];
        if (gpx.trks != null) {
          for (Trk track in gpx.trks!) {
            for (Trkseg segment in track.trksegs) {
              for (Wpt point in segment.trkpts) {
                gpsPoints.add({
                  'lat': point.lat ?? 0.0,
                  'lon': point.lon ?? 0.0,
                  'ele': point.ele ?? 0.0,
                  'timeOffset': point.time != null
                      ? point.time!.difference(gpx.metadata?.time ?? DateTime.now()).inSeconds.toDouble()
                      : 0.0,
                });
              }
            }
          }
        }

        // Create empty data points list for now (we'll need to parse these from the enhanced GPX later)
        final dataPoints = <RideDataPoint>[];

        sessions.add(RideSession(
          id: file.path.split(Platform.pathSeparator).last.replaceAll('.gpx', ''),
          startTime: gpx.metadata?.time ?? DateTime.now(),
          durationSeconds: int.tryParse(durationSeconds ?? '0') ?? 0,
          avgPower: int.tryParse(avgPower ?? '0') ?? 0,
          maxPower: int.tryParse(maxPower ?? '0') ?? 0,
          deviceName: deviceName,
          gpsPoints: gpsPoints,
          dataPoints: dataPoints, // Add empty list for now
          avgHeartRate: int.tryParse(avgHeartRate ?? '0') ?? 0,
          maxHeartRate: int.tryParse(maxHeartRate ?? '0') ?? 0,
          avgCadence: int.tryParse(avgCadence ?? '0') ?? 0,
          maxCadence: int.tryParse(maxCadence ?? '0') ?? 0,
          distance: double.tryParse(distance ?? '0') ?? 0.0,
          calories: double.tryParse(calories ?? '0') ?? 0.0,
          kiloJoules: int.tryParse(kiloJoules ?? '0') ?? 0,
          normalizedPower: double.tryParse(normalizedPower ?? '0') ?? 0.0,
          avgSpeed: double.tryParse(avgSpeed ?? '0') ?? 0.0,
          maxSpeed: double.tryParse(maxSpeed ?? '0') ?? 0.0,
          wattsPerKilo: double.tryParse(wattsPerKilo ?? '0') ?? 0.0,
          power3sAvg: int.tryParse(power3sAvg ?? '0') ?? 0,
          ftpPercentage: double.tryParse(ftpPercentage ?? '0') ?? 0.0,
          hrZone: int.tryParse(hrZone ?? '0') ?? 0,
          power10sAvg: int.tryParse(power10sAvg ?? '0') ?? 0,
          power20sAvg: int.tryParse(power20sAvg ?? '0') ?? 0,
          ftpZone: int.tryParse(ftpZone ?? '0') ?? 0,
          altitude: double.tryParse(altitude ?? '0') ?? 0.0,
          altitudeGain: double.tryParse(altitudeGain ?? '0') ?? 0.0,
          maxAltitude: double.tryParse(maxAltitude ?? '0') ?? 0.0,
        ));
      } catch (e) {
        print('Error reading GPX file: ${file.path} - $e');
      }
    }

    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  String? _getExtensionValue(Gpx gpx, String key) {
    if (gpx.extensions == null) return null;

    // Handle the type conversion safely
    final value = gpx.extensions![key];
    if (value is String) {
      return value;
    }
    return value?.toString();
  }

  Future<void> deleteSession(String id) async {
    final dir = await _getAppDirectory();
    final file = File('${dir.path}/$id.gpx');
    if (await file.exists()) {
      await file.delete();
    }
  }
}