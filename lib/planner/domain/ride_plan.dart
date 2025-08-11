// ride_plan.dart
import 'dart:convert';

class RidePlan {
  final String id;
  final String title;
  final String description;
  final List<RidePlanInterval> intervals;

  RidePlan({
    required this.id,
    required this.title,
    this.description = '',
    required this.intervals,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'intervals': intervals.map((x) => x.toMap()).toList(),
    };
  }

  factory RidePlan.fromMap(Map<String, dynamic> map) {
    return RidePlan(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      intervals: List<RidePlanInterval>.from(
          map['intervals']?.map((x) => RidePlanInterval.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory RidePlan.fromJson(String source) =>
      RidePlan.fromMap(json.decode(source));
}

class RidePlanInterval {
  final String title;
  final int duration; // in seconds
  final int? targetPower; // watts
  final int? targetHeartRate; // bpm
  final double? targetSpeed; // km/h
  final int? targetCadence; // rpm

  RidePlanInterval({
    required this.title,
    required this.duration,
    this.targetPower,
    this.targetHeartRate,
    this.targetSpeed,
    this.targetCadence,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'duration': duration,
      'targetPower': targetPower,
      'targetHeartRate': targetHeartRate,
      'targetSpeed': targetSpeed,
      'targetCadence': targetCadence,
    };
  }

  factory RidePlanInterval.fromMap(Map<String, dynamic> map) {
    return RidePlanInterval(
      title: map['title'],
      duration: map['duration'],
      targetPower: map['targetPower'],
      targetHeartRate: map['targetHeartRate'],
      targetSpeed: map['targetSpeed']?.toDouble(),
      targetCadence: map['targetCadence'],
    );
  }
}