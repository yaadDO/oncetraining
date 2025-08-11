import 'dart:io';
import 'package:gpx/gpx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

    // Create GPX object
    final gpx = Gpx();
    gpx.creator = 'Power Meter App';

    // Add metadata
    gpx.metadata = Metadata()
      ..name = 'Ride Session'
      ..time = session.startTime
      ..desc = 'Power: ${session.avgPower}W avg, ${session.maxPower}W max';

    // Add track with GPS points
    if (session.gpsPoints.isNotEmpty) {
      final track = Trk()
        ..name = 'Cycling Activity'
        ..type = 'Biking';

      final segment = Trkseg();

      for (final point in session.gpsPoints) {
        segment.trkpts.add(Wpt()
          ..lat = point['lat'] ?? 0.0
          ..lon = point['lon'] ?? 0.0
          ..ele = point['ele'] ?? 0.0
          ..time = session.startTime.add(Duration(
              seconds: (point['timeOffset'] ?? 0).toInt()
          )));
        }

            track.trksegs.add(segment);
        gpx.trks.add(track);
      }

      // Add all metrics as extensions
      gpx.extensions = {
        'deviceName': session.deviceName ?? '',
        'durationSeconds': session.durationSeconds.toString(),
        'avgPower': session.avgPower.toString(),
        'maxPower': session.maxPower.toString(),
        'distance': session.distance.toString(),
        'calories': session.calories.toString(),
        'kiloJoules': session.kiloJoules.toString(),
        'normalizedPower': session.normalizedPower.toString(),
        'avgSpeed': session.avgSpeed.toString(),
        'maxSpeed': session.maxSpeed.toString(),
        'wattsPerKilo': session.wattsPerKilo.toString(),
        'power3sAvg': session.power3sAvg.toString(),
        'ftpPercentage': session.ftpPercentage.toString(),
        'hrZone': session.hrZone.toString(),
        'avgHeartRate': session.avgHeartRate.toString(),
        'maxHeartRate': session.maxHeartRate.toString(),
        'avgCadence': session.avgCadence.toString(),
        'maxCadence': session.maxCadence.toString(),
      };

      // Write to file
      final writer = GpxWriter();
      await file.writeAsString(writer.asString(gpx));
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

        sessions.add(RideSession(
          id: file.path.split(Platform.pathSeparator).last.replaceAll('.gpx', ''),
          startTime: gpx.metadata?.time ?? DateTime.now(),
          durationSeconds: int.tryParse(durationSeconds ?? '0') ?? 0,
          avgPower: int.tryParse(avgPower ?? '0') ?? 0,
          maxPower: int.tryParse(maxPower ?? '0') ?? 0,
          deviceName: deviceName,
          gpsPoints: gpsPoints,
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
    return gpx.extensions![key]?.toString();
  }

  Future<void> deleteSession(String id) async {
    final dir = await _getAppDirectory();
    final file = File('${dir.path}/$id.gpx');
    if (await file.exists()) {
      await file.delete();
    }
  }
}