import 'dart:async';
import 'package:geolocator/geolocator.dart';

class RideService {
  StreamSubscription<Position>? _gpsSubscription;
  Position? _lastPosition;
  double _distance = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _lapDistance = 0.0;
  Position? _lapStartPosition;

  // Store all GPS positions for Strava export
  List<Position> _gpsPositions = [];
  List<Position> _lapGpsPositions = [];

  double get distance => _distance;
  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get lapDistance => _lapDistance;
  List<Position> get gpsPositions => _gpsPositions;
  List<Position> get lapGpsPositions => _lapGpsPositions;

  void startGpsRecording(Function(Position) onPositionUpdate) {
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Record point every 5 meters (increase frequency)
      ),
    ).listen((Position position) {
      _updateDistance(position);
      _currentSpeed = position.speed * 3.6; // Convert m/s to km/h

      // Store GPS position with timestamp
      _gpsPositions.add(position);
      _lapGpsPositions.add(position);

      // Update max speed
      if (_currentSpeed > _maxSpeed) {
        _maxSpeed = _currentSpeed;
      }

      onPositionUpdate(position);
    });
  }

  void _updateDistance(Position newPosition) {
    if (_lastPosition != null) {
      final double distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      // Update total distance
      _distance += distanceInMeters / 1000; // Convert to km

      // Update lap distance
      _lapDistance += distanceInMeters / 1000; // Convert to km
    }
    _lastPosition = newPosition;
  }

  void resetLap() {
    _lapDistance = 0.0;
    _lapStartPosition = _lastPosition;
    _lapGpsPositions.clear();
  }

  void reset() {
    _distance = 0.0;
    _currentSpeed = 0.0;
    _lastPosition = null;
    _maxSpeed = 0.0;
    _lapDistance = 0.0;
    _lapStartPosition = null;
    _gpsPositions.clear();
    _lapGpsPositions.clear();
  }

  void dispose() {
    _gpsSubscription?.cancel();
  }
}