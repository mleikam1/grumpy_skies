import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/weather_models.dart';

class OpenWeatherBackendException implements Exception {
  final String message;
  final int? statusCode;

  const OpenWeatherBackendException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class OpenWeatherBackendClient {
  OpenWeatherBackendClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = _normalizeBaseUrl(baseUrl ?? resolvedDefaultBaseUrl);

  static const _configuredBaseUrl = String.fromEnvironment(
    'WEATHER_API_BASE_URL',
  );

  static String get resolvedDefaultBaseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return '${Uri.base.origin}/api';
    }

    return 'http://127.0.0.1:5001/grumpy-skies/us-central1/api';
  }

  final http.Client _httpClient;
  final String baseUrl;

  Future<List<LocationCandidate>> geocode({
    required String query,
    int limit = 5,
  }) async {
    final json = await _getJson(
      '/location/geocode',
      {
        'q': query,
        'limit': limit.toString(),
      },
    );
    return ((json['locations'] as List?) ?? const [])
        .map((item) => LocationCandidate.fromJson(
              (item as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  Future<LocationCandidate> zip({
    required String zip,
    String country = 'US',
  }) async {
    final json = await _getJson(
      '/location/zip',
      {
        'zip': zip,
        'country': country,
      },
    );
    return LocationCandidate.fromJson(
      (json['location'] as Map).cast<String, dynamic>(),
    );
  }

  Future<LocationCandidate> reverse({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _getJson(
      '/location/reverse',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    );
    return LocationCandidate.fromJson(
      (json['location'] as Map).cast<String, dynamic>(),
    );
  }

  Future<CurrentWeather> current({
    required double latitude,
    required double longitude,
    String units = 'imperial',
    String locationName = '',
  }) async {
    final json = await _getJson(
      '/weather/current',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'units': units,
      },
    );
    return _currentFromBackend(
      (json['current'] as Map).cast<String, dynamic>(),
      locationName: locationName,
      units: units,
    );
  }

  Future<List<MinutePrecipitation>> minute({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _getJson(
      '/weather/minute',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    );
    return ((json['minutes'] as List?) ?? const [])
        .map((item) => MinutePrecipitation.fromJson(
              (item as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  Future<List<TimelineWeatherPoint>> hourly({
    required double latitude,
    required double longitude,
    String units = 'imperial',
  }) async {
    final json = await _getJson(
      '/weather/hourly',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'units': units,
      },
    );
    return ((json['points'] as List?) ?? const [])
        .map((item) => TimelineWeatherPoint.fromJson(
              (item as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  Future<List<TimelineWeatherPoint>> timeline15({
    required double latitude,
    required double longitude,
    String units = 'imperial',
  }) async {
    final json = await _getJson(
      '/weather/timeline15',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'units': units,
      },
    );
    return ((json['points'] as List?) ?? const [])
        .map((item) => TimelineWeatherPoint.fromJson(
              (item as Map).cast<String, dynamic>(),
            ))
        .toList();
  }

  Future<WeatherAlert> alert(String alertId) async {
    final json = await _getJson('/weather/alert/$alertId', const {});
    return WeatherAlert.fromJson(
      (json['alert'] as Map).cast<String, dynamic>(),
    );
  }

  String radarTileUrlTemplate({
    required RadarMode mode,
    required int timestamp,
  }) {
    return '$baseUrl/radar/tile/${mode.pathSegment}/{z}/{x}/{y}.png?tm=$timestamp';
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final uri = _uri(path, query);
    _debugWeatherEndpoint(path, query);
    final response = await _httpClient.get(uri);
    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(decoded) ??
          'Weather data is unavailable right now. Try again soon.';
      throw OpenWeatherBackendException(
        message,
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Uri _uri(String path, Map<String, String> query) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(queryParameters: query);
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return const {};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  static String? _errorMessage(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    if (json['message'] is String) {
      return json['message'] as String;
    }
    return null;
  }

  static CurrentWeather _currentFromBackend(
    Map<String, dynamic> json, {
    required String locationName,
    required String units,
  }) {
    final weather = (json['weather'] as Map?)?.cast<String, dynamic>();
    final temp = (json['temp'] as num?)?.toDouble() ?? 0;
    final feelsLike = (json['feelsLike'] as num?)?.toDouble() ?? temp;
    final windSpeed = (json['windSpeed'] as num?)?.toDouble() ?? 0;
    final windGust = (json['windGust'] as num?)?.toDouble();
    final dewPoint = (json['dewPoint'] as num?)?.toDouble();
    final dt = (json['dt'] as num?)?.toInt();
    final sunrise = (json['sunrise'] as num?)?.toInt();
    final sunset = (json['sunset'] as num?)?.toInt();
    final now = DateTime.now();

    return CurrentWeather(
      locationName: locationName,
      temperatureC: units == 'metric' ? temp : _fToC(temp),
      condition: _titleCase(
        (weather?['description'] ?? 'Current conditions') as String,
      ),
      feelsLikeC: units == 'metric' ? feelsLike : _fToC(feelsLike),
      windKph: units == 'metric' ? windSpeed * 3.6 : windSpeed * 1.609344,
      windDirection: _windDirection((json['windDeg'] as num?)?.toDouble()),
      humidity: (json['humidity'] as num?)?.round() ?? 0,
      precipitationChance: 0,
      aqi: 0,
      aqiCategory: '',
      sunrise: _fromUnix(sunrise) ?? DateTime(now.year, now.month, now.day, 6),
      sunset: _fromUnix(sunset) ?? DateTime(now.year, now.month, now.day, 18),
      moonrise: DateTime(now.year, now.month, now.day, 21),
      moonset: DateTime(now.year, now.month, now.day + 1, 6),
      uvIndex: (json['uvi'] as num?)?.toDouble() ?? 0,
      uvCategory: _uvCategory((json['uvi'] as num?)?.toDouble() ?? 0),
      chaosMeterPercent: _chaosMeter(weather?['id'] as num?),
      lastUpdated: _fromUnix(dt) ?? now,
      dewPointC: dewPoint == null
          ? null
          : units == 'metric'
              ? dewPoint
              : _fToC(dewPoint),
      pressureHpa: (json['pressure'] as num?)?.round(),
      visibilityMeters: (json['visibility'] as num?)?.round(),
      windGustKph: windGust == null
          ? null
          : units == 'metric'
              ? windGust * 3.6
              : windGust * 1.609344,
      rainLastHour: (json['rain1h'] as num?)?.toDouble(),
      snowLastHour: (json['snow1h'] as num?)?.toDouble(),
      weatherIcon: weather?['icon'] as String?,
      weatherId: (weather?['id'] as num?)?.round(),
      alertIds: ((json['alertIds'] as List?) ?? const [])
          .map((id) => id.toString())
          .toList(),
      timezone: json['timezone'] as String?,
    );
  }

  static DateTime? _fromUnix(int? seconds) {
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
  }

  static double _fToC(double tempF) => (tempF - 32) * 5 / 9;

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _uvCategory(double uv) {
    if (uv >= 11) return 'Extreme';
    if (uv >= 8) return 'Very High';
    if (uv >= 6) return 'High';
    if (uv >= 3) return 'Moderate';
    return 'Low';
  }

  static int _chaosMeter(num? weatherId) {
    final id = weatherId?.round() ?? 800;
    if (id >= 200 && id < 300) return 92;
    if (id >= 500 && id < 600) return 74;
    if (id >= 600 && id < 700) return 68;
    if (id >= 700 && id < 800) return 58;
    if (id > 800) return 42;
    return 18;
  }

  static String _windDirection(double? degrees) {
    if (degrees == null) return '';
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % labels.length;
    return labels[index];
  }

  static void _debugWeatherEndpoint(
    String path,
    Map<String, String> query,
  ) {
    if (!kDebugMode || !path.startsWith('/weather/')) return;
    final lat = double.tryParse(query['lat'] ?? '');
    final lon = double.tryParse(query['lon'] ?? '');
    final coordinateLabel = lat == null || lon == null
        ? ''
        : ' lat=${lat.toStringAsFixed(3)} lon=${lon.toStringAsFixed(3)}';
    debugPrint('[GrumpySkies] weather endpoint $path$coordinateLabel');
  }
}
