import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';

class CacheService {
  static const _weatherPrefix = 'weather_cache_';
  static const _weatherTsPrefix = 'weather_ts_';

  final SharedPreferences _prefs;

  CacheService._(this._prefs);

  static Future<CacheService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CacheService._(prefs);
  }

  String _weatherKeyForLocation(double lat, double lon) =>
      '$_weatherPrefix${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';

  String _tsKeyForLocation(double lat, double lon) =>
      '$_weatherTsPrefix${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';

  Future<void> saveWeatherBundle({
    required double lat,
    required double lon,
    required WeatherBundle bundle,
  }) async {
    final key = _weatherKeyForLocation(lat, lon);
    final tsKey = _tsKeyForLocation(lat, lon);

    await _prefs.setString(key, jsonEncode(bundle.toJson()));
    await _prefs.setString(tsKey, DateTime.now().toIso8601String());
  }

  WeatherBundle? getWeatherBundle(double lat, double lon) {
    final key = _weatherKeyForLocation(lat, lon);
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return WeatherBundle.fromJson(map);
  }

  DateTime? getLastFetchTime(double lat, double lon) {
    final tsKey = _tsKeyForLocation(lat, lon);
    final raw = _prefs.getString(tsKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
