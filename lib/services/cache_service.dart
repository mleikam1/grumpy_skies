import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_models.dart';

class CacheService {
  static const _weatherPrefix = 'weather_cache_exact_v2_';
  static const _weatherTsPrefix = 'weather_ts_exact_v2_';

  final SharedPreferences _prefs;

  final DateTime Function() _clock;

  CacheService._(this._prefs, this._clock);

  static Future<CacheService> create({DateTime Function()? clock}) async {
    final prefs = await SharedPreferences.getInstance();
    return CacheService._(prefs, clock ?? DateTime.now);
  }

  String _weatherKeyForLocation(double lat, double lon) =>
      '$_weatherPrefix${lat}_$lon';

  String _tsKeyForLocation(double lat, double lon) =>
      '$_weatherTsPrefix${lat}_$lon';

  Future<void> saveWeatherBundle({
    required double lat,
    required double lon,
    required WeatherBundle bundle,
  }) async {
    final key = _weatherKeyForLocation(lat, lon);
    final tsKey = _tsKeyForLocation(lat, lon);

    await _prefs.setString(key, jsonEncode(bundle.toJson()));
    await _prefs.setString(tsKey, _clock().toIso8601String());
  }

  WeatherBundle? getWeatherBundle(double lat, double lon) {
    final key = _weatherKeyForLocation(lat, lon);
    final raw = _prefs.getString(key);
    if (raw != null) {
      try {
        return WeatherBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      } // A corrupt optional cache cannot block refresh.
    }
    // Read legacy rounded entries only when the payload proves the exact place.
    // Keep all old entries/settings intact; an ambiguous cache is not weather.
    return _legacyExactBundle(lat, lon);
  }

  WeatherBundle? _legacyExactBundle(double lat, double lon) {
    final key =
        'weather_cache_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}';
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final bundle =
          WeatherBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final location = bundle.location;
      final cachedLat = location?.lat ?? bundle.current.latitude;
      final cachedLon = location?.lon ?? bundle.current.longitude;
      return cachedLat == lat && cachedLon == lon ? bundle : null;
    } catch (_) {
      return null;
    }
  }

  DateTime? getLastFetchTime(double lat, double lon) {
    final tsKey = _tsKeyForLocation(lat, lon);
    var raw = _prefs.getString(tsKey);
    if (raw == null && _legacyExactBundle(lat, lon) != null) {
      raw = _prefs.getString(
          'weather_ts_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}');
    }
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
