import 'dart:async';
import 'package:geolocator/geolocator.dart';

class RideService {
  StreamSubscription<Position>? _gpsSubscription;
  Position? _lastPosition;
  double _distance = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _lapDistance = 0.0;

  double get distance => _distance;
  double get currentSpeed => _currentSpeed;
  double get maxSpeed => _maxSpeed;
  double get lapDistance => _lapDistance;

  void startGpsRecording(Function(Position) onPositionUpdate) {
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _updateDistance(position);
      _currentSpeed = position.speed * 3.6; // Convert m/s to km/h

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
    }
    _lastPosition = newPosition;
  }

  void reset() {
    _distance = 0.0;
    _currentSpeed = 0.0;
    _lastPosition = null;
    _maxSpeed = 0.0;
  }

  void dispose() {
    _gpsSubscription?.cancel();
  }
}