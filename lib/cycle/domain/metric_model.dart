class MetricBlock {
  final String title;
  String value;
  final String unit;
  final String key;
  final String category;

  MetricBlock({
    required this.title,
    required this.value,
    required this.unit,
    required this.key,
    required this.category,
  });

  MetricBlock copyWith({String? title, String? value, String? unit, String? category}) {
    return MetricBlock(
      title: title ?? this.title,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      key: key,
      category: category ?? this.category,
    );
  }

  factory MetricBlock.fromKey(String key) {
    return MetricBlock(
      title: _getTitleFromKey(key),
      value: '0',
      unit: _getUnitFromKey(key),
      key: key,
      category: _getCategoryFromKey(key),
    );
  }

  static String _getCategoryFromKey(String key) {
    if (['speed', 'avg_speed', 'lap_max_speed', 'last_lap_avg_speed',
      'lap_avg_speed', 'max_speed'].contains(key)) {
      return 'speed';
    }
    if (['local_time', 'last_lap_time', 'lap_count', 'lap_time',
      'trip_time', 'ride_time', 'time'].contains(key)) {
      return 'time';
    }
    if (['distance', 'lap_distance', 'last_lap_distance'].contains(key)) {
      return 'distance';
    }
    if (['kj', 'calories'].contains(key)) {
      return 'energy';
    }
    if (['hr', 'avg_hr', 'max_hr', 'hr_percentage_max', 'hr_zone',
      'lap_avg_hr', 'last_lap_avg_hr'].contains(key)) {
      return 'heart_rate';
    }
    if (['cadence', 'avg_cadence', 'max_cadence', 'lap_avg_cadence',
      'last_lap_avg_cadence'].contains(key)) {
      return 'cadence';
    }
    if (['power_10s_avg', 'power_20s_avg', 'ftp_zone'].contains(key)) {
      return 'power';
    }
    if (['altitude', 'alt_gain', 'max_alt'].contains(key)) {
      return 'altitude';
    }
    if (['power', 'avg_power', 'max_power', 'lap_avg_power', 'lap_max_power',
      'power_3s_avg', 'normalised_power', 'watts_kg', 'ftp_percentage',
      'last_lap_avg_power', 'last_lap_max_power', 'lap_normalised'].contains(key)) {
      return 'power';
    }
    return 'other';
  }

  static String _getTitleFromKey(String key) {
    switch (key) {
      case 'power': return 'Current Power';
      case 'speed': return 'Speed';
      case 'distance': return 'Distance';
      case 'watts_kg': return 'Watts/Kg';
      case 'cadence': return 'Cadence';
      case 'hr': return 'Heart Rate';
      case 'time': return 'Time';
      case 'kj': return 'KiloJoules';
      case 'lap_time': return 'Lap Time';
      case 'lap_avg_speed': return 'Lap Avg Speed';
      case 'lap_avg_power': return 'Lap Avg Power';
      case 'calories': return 'Calories';
      case 'lap_avg_hr': return 'Lap Avg HR';
      case 'avg_cadence': return 'Avg Cadence';
      case 'avg_hr': return 'Avg Heart Rate';
      case 'avg_speed': return 'Avg Speed';

    // Speed category
      case 'lap_max_speed': return 'Lap Max Speed';
      case 'last_lap_avg_speed': return 'Last Lap Avg Speed';
      case 'max_speed': return 'Max Speed';

    // Time category
      case 'local_time': return 'Local Time';
      case 'last_lap_time': return 'Last Lap Time';
      case 'lap_count': return 'Lap Count';
      case 'trip_time': return 'Trip Time';
      case 'ride_time': return 'Ride Time';

    // Distance category
      case 'lap_distance': return 'Lap Distance';
      case 'last_lap_distance': return 'Last Lap Distance';

    // Heart Rate category
      case 'max_hr': return 'Max Heart Rate';
      case 'hr_percentage_max': return '% Max HR';
      case 'hr_zone': return 'HR Zone';
      case 'last_lap_avg_hr': return 'Last Lap Avg HR';

    // Cadence category
      case 'max_cadence': return 'Max Cadence';
      case 'lap_avg_cadence': return 'Lap Avg Cadence';
      case 'last_lap_avg_cadence': return 'Last Lap Avg Cadence';

    // Power category
      case 'avg_power': return 'Avg Power';
      case 'max_power': return 'Max Power';
      case 'lap_max_power': return 'Lap Max Power';
      case 'power_3s_avg': return '3s Avg Power';
      case 'normalised_power': return 'Normalised Power';
      case 'ftp_percentage': return '% FTP';
      case 'last_lap_avg_power': return 'Last Lap Avg Power';
      case 'last_lap_max_power': return 'Last Lap Max Power';
      case 'lap_normalised': return 'Lap Normalised Power';
      case 'power_10s_avg': return '10s Avg Power';
      case 'power_20s_avg': return '20s Avg Power';
      case 'ftp_zone': return 'FTP Zone';

      case 'heart_rate': return 'Heart Rate';
      case 'cadence': return 'Cadence';
      case 'sensor_speed': return 'Speed (Sensor)';

      case 'altitude': return 'Altitude';
      case 'alt_gain': return 'Elevation Gain';
      case 'max_alt': return 'Max Altitude';

      case 'normalised_power': return 'Normalised Power';
      case 'ftp_percentage': return '% FTP';
      case 'avg_power': return 'Avg Power';
      case 'max_power': return 'Max Power';
      case 'last_lap_avg_power': return 'Last Lap Avg Power';
      case 'last_lap_max_power': return 'Last Lap Max Power';
      case 'avg_cadence': return 'Avg Cadence';
      case 'max_cadence': return 'Max Cadence';
      case 'lap_avg_cadence': return 'Lap Avg Cadence';
      case 'last_lap_avg_cadence': return 'Last Lap Avg Cadence';
      case 'avg_hr': return 'Avg Heart Rate';
      case 'max_hr': return 'Max Heart Rate';
      case 'hr_percentage_max': return '% Max HR';
      case 'hr_zone': return 'HR Zone';
      case 'lap_avg_hr': return 'Lap Avg HR';
      case 'last_lap_avg_hr': return 'Last Lap Avg HR';
      case 'kj': return 'KiloJoules';
      case 'calories': return 'Calories';
      case 'distance': return 'Distance';
      case 'lap_distance': return 'Lap Distance';
      case 'last_lap_distance': return 'Last Lap Distance';
      case 'speed': return 'Speed';
      case 'avg_speed': return 'Avg Speed';
      case 'max_speed': return 'Max Speed';
      case 'lap_avg_speed': return 'Lap Avg Speed';
      case 'lap_max_speed': return 'Lap Max Speed';
      case 'lap_time': return 'Lap Time';
      case 'lap_count': return 'Lap Count';


      default: return key;
    }
  }

  static String _getUnitFromKey(String key) {
    switch (key) {
      case 'power': return 'W';
      case 'speed': return 'km/h';
      case 'distance': return 'km';
      case 'watts_kg': return 'w/kg';
      case 'cadence': return 'rpm';
      case 'hr': return 'bpm';
      case 'time': return '';
      case 'kj': return 'kJ';
      case 'lap_time': return '';
      case 'lap_avg_speed': return 'km/h';
      case 'lap_avg_power': return 'W';
      case 'calories': return 'cal';
      case 'lap_avg_hr': return 'bpm';
      case 'avg_cadence': return 'rpm';
      case 'avg_hr': return 'bpm';
      case 'avg_speed': return 'km/h';

    // Speed category
      case 'lap_max_speed': return 'km/h';
      case 'last_lap_avg_speed': return 'km/h';
      case 'max_speed': return 'km/h';

    // Time category
      case 'local_time': return '';
      case 'last_lap_time': return '';
      case 'lap_count': return '';
      case 'trip_time': return '';
      case 'ride_time': return '';

    // Distance category
      case 'lap_distance': return 'km';
      case 'last_lap_distance': return 'km';

    // Heart Rate category
      case 'max_hr': return 'bpm';
      case 'hr_percentage_max': return '%';
      case 'hr_zone': return '';
      case 'last_lap_avg_hr': return 'bpm';

    // Cadence category
      case 'max_cadence': return 'rpm';
      case 'lap_avg_cadence': return 'rpm';
      case 'last_lap_avg_cadence': return 'rpm';

    // Power category
      case 'avg_power': return 'W';
      case 'max_power': return 'W';
      case 'lap_max_power': return 'W';
      case 'power_3s_avg': return 'W';
      case 'normalised_power': return 'W';
      case 'ftp_percentage': return '%';
      case 'last_lap_avg_power': return 'W';
      case 'last_lap_max_power': return 'W';
      case 'lap_normalised': return 'W';
      case 'heart_rate': return 'bpm';
      case 'cadence': return 'rpm';
      case 'sensor_speed': return 'km/h';

      case 'power_10s_avg': return 'W';
      case 'power_20s_avg': return 'W';
      case 'ftp_zone': return '';

    // New altitude metrics
      case 'altitude': return 'm';
      case 'alt_gain': return 'm';
      case 'max_alt': return 'm';

    // Existing units
      case 'normalised_power': return 'W';
      case 'ftp_percentage': return '%';
      case 'avg_power': return 'W';
      case 'max_power': return 'W';
      case 'last_lap_avg_power': return 'W';
      case 'last_lap_max_power': return 'W';
      case 'avg_cadence': return 'rpm';
      case 'max_cadence': return 'rpm';
      case 'lap_avg_cadence': return 'rpm';
      case 'last_lap_avg_cadence': return 'rpm';
      case 'avg_hr': return 'bpm';
      case 'max_hr': return 'bpm';
      case 'hr_percentage_max': return '%';
      case 'hr_zone': return '';
      case 'lap_avg_hr': return 'bpm';
      case 'last_lap_avg_hr': return 'bpm';
      case 'kj': return 'kJ';
      case 'calories': return 'cal';
      case 'distance': return 'km';
      case 'lap_distance': return 'km';
      case 'last_lap_distance': return 'km';
      case 'speed': return 'km/h';
      case 'avg_speed': return 'km/h';
      case 'max_speed': return 'km/h';
      case 'lap_avg_speed': return 'km/h';
      case 'lap_max_speed': return 'km/h';
      case 'lap_time': return '';
      case 'lap_count': return '';

      default: return '';
    }
  }
}