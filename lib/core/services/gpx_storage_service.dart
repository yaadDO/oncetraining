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

      // Metadata with ALL session data
      builder.element('metadata', nest: () {
        builder.element('name', nest: 'Cycling Activity - ${DateFormat('yyyy-MM-dd HH:mm').format(session.startTime)}');
        builder.element('time', nest: session.startTime.toUtc().toIso8601String());

        // Store ALL session data as extensions in metadata
        builder.element('extensions', nest: () {
          _buildSessionMetadataExtensions(builder, session);
        });
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
      });
    });

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  void _buildSessionMetadataExtensions(xml.XmlBuilder builder, RideSession session) {
    // Store all session data as simple key-value pairs
    builder.element('session_id', nest: session.id);
    builder.element('start_time', nest: session.startTime.toIso8601String());
    builder.element('duration_seconds', nest: session.durationSeconds);
    builder.element('avg_power', nest: session.avgPower);
    builder.element('max_power', nest: session.maxPower);
    builder.element('avg_heart_rate', nest: session.avgHeartRate);
    builder.element('max_heart_rate', nest: session.maxHeartRate);
    builder.element('avg_cadence', nest: session.avgCadence);
    builder.element('max_cadence', nest: session.maxCadence);
    builder.element('distance', nest: session.distance);
    builder.element('calories', nest: session.calories);
    builder.element('kilo_joules', nest: session.kiloJoules);
    builder.element('normalized_power', nest: session.normalizedPower);
    builder.element('avg_speed', nest: session.avgSpeed);
    builder.element('max_speed', nest: session.maxSpeed);
    builder.element('watts_per_kilo', nest: session.wattsPerKilo);
    builder.element('power_3s_avg', nest: session.power3sAvg);
    builder.element('ftp_percentage', nest: session.ftpPercentage);
    builder.element('hr_zone', nest: session.hrZone);
    builder.element('power_10s_avg', nest: session.power10sAvg);
    builder.element('power_20s_avg', nest: session.power20sAvg);
    builder.element('ftp_zone', nest: session.ftpZone);
    builder.element('altitude', nest: session.altitude);
    builder.element('altitude_gain', nest: session.altitudeGain);
    builder.element('max_altitude', nest: session.maxAltitude);

    if (session.deviceName != null) {
      builder.element('device_name', nest: session.deviceName!);
    }

    // Save lap data
    if (session.laps.isNotEmpty) {
      builder.element('laps', nest: () {
        for (final lap in session.laps) {
          builder.element('lap', nest: () {
            builder.element('lap_number', nest: lap.lapNumber);
            builder.element('lap_duration', nest: lap.duration.inSeconds);
            builder.element('lap_distance', nest: lap.distance);
            builder.element('lap_avg_power', nest: lap.avgPower);
            builder.element('lap_max_power', nest: lap.maxPower);
            builder.element('lap_avg_speed', nest: lap.avgSpeed);
            builder.element('lap_max_speed', nest: lap.maxSpeed);
            builder.element('lap_avg_hr', nest: lap.avgHeartRate);
            builder.element('lap_avg_cadence', nest: lap.avgCadence);
            builder.element('lap_normalized_power', nest: lap.normalizedPower);
          });
        }
      });
    }
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

        // Add sensor data as extensions
        builder.element('extensions', nest: () {
          builder.element('gpxtpx:TrackPointExtension', nest: () {
            builder.element('gpxtpx:hr', nest: dataPoint.heartRate);
            builder.element('gpxtpx:cad', nest: dataPoint.cadence);
            if (dataPoint.power > 0) {
              builder.element('gpxtpx:power', nest: dataPoint.power);
            }
            builder.element('gpxtpx:speed', nest: dataPoint.speed / 3.6);
            builder.element('gpxtpx:distance', nest: dataPoint.distance * 1000);
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
      });
    }
  }

  Map<String, double>? _findGpsPointForTimestamp(List<Map<String, double>> gpsPoints, DateTime timestamp) {
    if (gpsPoints.isEmpty) return null;

    final sessionStart = timestamp;
    for (final point in gpsPoints) {
      final pointTime = sessionStart.add(Duration(seconds: (point['timeOffset'] ?? 0).toInt()));
      if ((pointTime.difference(timestamp).inSeconds).abs() < 10) {
        return point;
      }
    }

    return gpsPoints.first;
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

      final appDocDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${appDocDir.path}/exports');

      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

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

    for (final file in files) {
      try {
        final contents = await file.readAsString();
        final document = xml.XmlDocument.parse(contents);

        // Extract data from metadata extensions
        final metadata = _parseMetadataExtensions(document);

        // Create RideSession from parsed data
        final session = _createSessionFromMetadata(metadata, file.path);
        sessions.add(session);

      } catch (e) {
        print('Error reading GPX file: ${file.path} - $e');
        // Create a basic session with file info as fallback
        sessions.add(_createFallbackSession(file.path));
      }
    }

    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  Map<String, dynamic> _parseMetadataExtensions(xml.XmlDocument document) {
    final Map<String, dynamic> data = {};

    try {
      // Get metadata element
      final metadata = document.findAllElements('metadata').firstOrNull;
      if (metadata == null) return data;

      // Get extensions within metadata
      final extensions = metadata.findElements('extensions').firstOrNull;
      if (extensions == null) return data;

      // Parse all extension elements
      for (final element in extensions.childElements) {
        final tag = element.name.local;
        final text = element.text;

        // Convert to appropriate types
        if (text.isNotEmpty) {
          switch (tag) {
            case 'session_id':
            case 'device_name':
              data[tag] = text;
              break;
            case 'start_time':
              data[tag] = DateTime.parse(text);
              break;
            case 'duration_seconds':
            case 'avg_power':
            case 'max_power':
            case 'avg_heart_rate':
            case 'max_heart_rate':
            case 'avg_cadence':
            case 'max_cadence':
            case 'kilo_joules':
            case 'power_3s_avg':
            case 'hr_zone':
            case 'power_10s_avg':
            case 'power_20s_avg':
            case 'ftp_zone':
              data[tag] = int.tryParse(text) ?? 0;
              break;
            case 'distance':
            case 'calories':
            case 'normalized_power':
            case 'avg_speed':
            case 'max_speed':
            case 'watts_per_kilo':
            case 'ftp_percentage':
            case 'altitude':
            case 'altitude_gain':
            case 'max_altitude':
              data[tag] = double.tryParse(text) ?? 0.0;
              break;
            case 'laps':
            // Parse lap data
              final laps = _parseLapsData(element);
              data['laps'] = laps;
              break;
          }
        }
      }
    } catch (e) {
      print('Error parsing metadata extensions: $e');
    }

    return data;
  }

  List<LapData> _parseLapsData(xml.XmlElement lapsElement) {
    final laps = <LapData>[];

    try {
      for (final lapElement in lapsElement.findElements('lap')) {
        final lapData = <String, dynamic>{};

        for (final element in lapElement.childElements) {
          final tag = element.name.local;
          final text = element.text;

          if (text.isNotEmpty) {
            switch (tag) {
              case 'lap_number':
              case 'lap_avg_power':
              case 'lap_max_power':
              case 'lap_avg_hr':
              case 'lap_avg_cadence':
                lapData[tag] = int.tryParse(text) ?? 0;
                break;
              case 'lap_duration':
                lapData[tag] = int.tryParse(text) ?? 0;
                break;
              case 'lap_distance':
              case 'lap_avg_speed':
              case 'lap_max_speed':
              case 'lap_normalized_power':
                lapData[tag] = double.tryParse(text) ?? 0.0;
                break;
            }
          }
        }

        // Create LapData object from parsed data
        if (lapData.isNotEmpty) {
          laps.add(LapData(
            lapNumber: lapData['lap_number'] ?? 0,
            duration: Duration(seconds: lapData['lap_duration'] ?? 0),
            distance: lapData['lap_distance']?.toDouble() ?? 0.0,
            avgPower: lapData['lap_avg_power'] ?? 0,
            maxPower: lapData['lap_max_power'] ?? 0,
            avgSpeed: lapData['lap_avg_speed']?.toDouble() ?? 0.0,
            maxSpeed: lapData['lap_max_speed']?.toDouble() ?? 0.0,
            avgHeartRate: lapData['lap_avg_hr'] ?? 0,
            avgCadence: lapData['lap_avg_cadence'] ?? 0,
            normalizedPower: lapData['lap_normalized_power']?.toDouble() ?? 0.0,
          ));
        }
      }
    } catch (e) {
      print('Error parsing laps data: $e');
    }

    return laps;
  }

  RideSession _createSessionFromMetadata(Map<String, dynamic> data, String filePath) {
    final id = data['session_id'] ?? filePath.split('/').last.replaceAll('.gpx', '');
    final startTime = data['start_time'] as DateTime? ?? DateTime.now();

    // Parse laps from data
    final laps = data['laps'] as List<LapData>? ?? [];

    return RideSession(
      id: id,
      startTime: startTime,
      durationSeconds: data['duration_seconds'] ?? 0,
      avgPower: data['avg_power'] ?? 0,
      maxPower: data['max_power'] ?? 0,
      deviceName: data['device_name']?.toString(),
      gpsPoints: [], // We don't need GPS points for history list
      dataPoints: [], // We don't need data points for history list
      avgHeartRate: data['avg_heart_rate'] ?? 0,
      maxHeartRate: data['max_heart_rate'] ?? 0,
      avgCadence: data['avg_cadence'] ?? 0,
      maxCadence: data['max_cadence'] ?? 0,
      distance: data['distance']?.toDouble() ?? 0.0,
      calories: data['calories']?.toDouble() ?? 0.0,
      kiloJoules: data['kilo_joules'] ?? 0,
      normalizedPower: data['normalized_power']?.toDouble() ?? 0.0,
      avgSpeed: data['avg_speed']?.toDouble() ?? 0.0,
      maxSpeed: data['max_speed']?.toDouble() ?? 0.0,
      wattsPerKilo: data['watts_per_kilo']?.toDouble() ?? 0.0,
      power3sAvg: data['power_3s_avg'] ?? 0,
      ftpPercentage: data['ftp_percentage']?.toDouble() ?? 0.0,
      hrZone: data['hr_zone'] ?? 0,
      power10sAvg: data['power_10s_avg'] ?? 0,
      power20sAvg: data['power_20s_avg'] ?? 0,
      ftpZone: data['ftp_zone'] ?? 0,
      altitude: data['altitude']?.toDouble() ?? 0.0,
      altitudeGain: data['altitude_gain']?.toDouble() ?? 0.0,
      maxAltitude: data['max_altitude']?.toDouble() ?? 0.0,
      laps: laps, // Add the parsed laps
    );
  }

  RideSession _createFallbackSession(String filePath) {
    final id = filePath.split('/').last.replaceAll('.gpx', '');
    return RideSession(
      id: id,
      startTime: DateTime.now(),
      durationSeconds: 0,
      avgPower: 0,
      maxPower: 0,
      deviceName: null,
      gpsPoints: [],
      dataPoints: [],
      avgHeartRate: 0,
      maxHeartRate: 0,
      avgCadence: 0,
      maxCadence: 0,
      distance: 0.0,
      calories: 0.0,
      kiloJoules: 0,
      normalizedPower: 0.0,
      avgSpeed: 0.0,
      maxSpeed: 0.0,
      wattsPerKilo: 0.0,
      power3sAvg: 0,
      ftpPercentage: 0.0,
      hrZone: 0,
      power10sAvg: 0,
      power20sAvg: 0,
      ftpZone: 0,
      altitude: 0.0,
      altitudeGain: 0.0,
      maxAltitude: 0.0,
      laps: [], // Empty laps for fallback
    );
  }

  Future<void> deleteSession(String id) async {
    final dir = await _getAppDirectory();
    final file = File('${dir.path}/$id.gpx');
    if (await file.exists()) {
      await file.delete();
    }
  }
}