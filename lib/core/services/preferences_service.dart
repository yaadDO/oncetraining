import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _displayedMetricsKey = 'displayed_metrics';

  Future<void> saveDisplayedMetrics(List<String> metricKeys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_displayedMetricsKey, metricKeys);
  }

  Future<List<String>> getDisplayedMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_displayedMetricsKey) ?? [];
  }
}