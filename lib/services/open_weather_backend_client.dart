import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/weather_api_config.dart';
import '../models/weather_models.dart';

class RadarTileHealth {
  const RadarTileHealth({
    required this.available,
    this.statusCode,
    this.contentType,
    this.fallbackCode,
  });

  final bool available;
  final int? statusCode;
  final String? contentType;
  final String? fallbackCode;
}

class OpenWeatherBackendException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const OpenWeatherBackendException(
    this.message, {
    this.statusCode,
    this.code,
  });

  bool get isProviderAuthorizationFailure {
    final safeCode = code ?? '';
    return safeCode == 'openweather_key_rejected' ||
        safeCode == 'openweather_one_call_access_denied' ||
        safeCode == 'openweather_radar_access_denied' ||
        safeCode == 'openweather_secret_missing' ||
        safeCode == 'openweather_secret_not_bound' ||
        safeCode == 'OPENWEATHER_API_KEY_MISSING' ||
        safeCode == 'OPENWEATHER_API_KEY_UNAVAILABLE' ||
        message.contains('OpenWeather rejected the server key') ||
        message.contains('One Call API 4.0');
  }

  @override
  String toString() => message;
}

class OpenWeatherBackendClient {
  OpenWeatherBackendClient({
    http.Client? httpClient,
    String? baseUrl,
    WeatherApiConfig? config,
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = _normalizeBaseUrl(
          baseUrl ?? (config ?? WeatherApiConfig.current).baseUrl,
        ) {
    if (baseUrl == null) {
      (config ?? WeatherApiConfig.current).debugLog();
    } else {
      WeatherApiConfig.debugLogOverride(baseUrl);
    }
  }

  static const _requestTimeout = Duration(seconds: 12);

  static String get resolvedDefaultBaseUrl {
    return WeatherApiConfig.current.baseUrl;
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
    String units = 'imperial',
  }) async {
    final json = await _getJson(
      '/weather/minute',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'units': units,
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
    return '$baseUrl/radar/tile/${mode.pathSegment}/{z}/{x}/{y}.png'
        '?tm=$timestamp';
  }

  Future<RadarTileHealth> radarTileHealth({
    required RadarMode mode,
    required int timestamp,
    required double latitude,
    required double longitude,
  }) async {
    const zoom = 3;
    final tile = _tileForLocation(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
    );
    final uri = _uri(
      '/radar/tile/${mode.pathSegment}/$zoom/${tile.x}/${tile.y}.png',
      {'tm': timestamp.toString()},
    );

    try {
      final response = await _httpClient.get(uri).timeout(_requestTimeout);
      final contentType = response.headers['content-type'];
      final fallbackCode = response.headers['x-grumpy-skies-tile-fallback'];
      return RadarTileHealth(
        available: response.statusCode >= 200 &&
            response.statusCode < 300 &&
            fallbackCode == null &&
            _isImageContentType(contentType ?? ''),
        statusCode: response.statusCode,
        contentType: contentType,
        fallbackCode: fallbackCode,
      );
    } catch (error) {
      _debugWeatherFailure(uri, error);
      return const RadarTileHealth(
        available: false,
        fallbackCode: 'weather_backend_unreachable',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final uri = _uri(path, query);
    _debugWeatherEndpoint(path, query);
    final http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(_requestTimeout);
    } catch (error) {
      _debugWeatherFailure(uri, error);
      throw OpenWeatherBackendException(_connectionFailureMessage(uri));
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!_isJsonContentType(contentType)) {
      _debugNonJsonResponse(uri, response);
      throw OpenWeatherBackendException(
        _nonJsonResponseMessage(uri),
        statusCode: response.statusCode,
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = _decodeBody(response.body);
    } catch (error) {
      _debugInvalidJsonResponse(uri, response, error);
      throw const OpenWeatherBackendException(
        'Weather service is unavailable. Try again soon.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(decoded) ??
          'Weather data is unavailable right now. Try again soon.';
      throw OpenWeatherBackendException(
        message,
        statusCode: response.statusCode,
        code: _errorCode(decoded),
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

  static String? _errorCode(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map && error['code'] is String) {
      return error['code'] as String;
    }
    if (json['code'] is String) {
      return json['code'] as String;
    }
    return null;
  }

  static String _connectionFailureMessage(Uri uri) {
    if (uri.port == 5001) {
      return 'Could not reach the local weather service. Make sure the Firebase emulator is running.';
    }
    return "Couldn't reach the forecast server. Check your connection and try again.";
  }

  static bool _isJsonContentType(String contentType) {
    final normalized = contentType.toLowerCase();
    return normalized.contains('application/json') ||
        normalized.contains('+json');
  }

  static bool _isImageContentType(String contentType) {
    final normalized = contentType.toLowerCase();
    return normalized.startsWith('image/png') ||
        normalized.startsWith('image/jpeg') ||
        normalized.startsWith('image/jpg') ||
        normalized.startsWith('image/webp');
  }

  static String _nonJsonResponseMessage(Uri uri) {
    if (uri.host.contains('cloudfunctions.net')) {
      return 'Weather backend returned an unexpected response. Check the configured Firebase Functions project and API route.';
    }
    return 'Weather service is unavailable. Try again soon.';
  }

  static CurrentWeather _currentFromBackend(
    Map<String, dynamic> json, {
    required String locationName,
    required String units,
  }) {
    final dtoUnits = (json['units'] as String?) ?? units;
    final weather = (json['weather'] as Map?)?.cast<String, dynamic>();
    final weatherDescription =
        (json['weatherDescription'] ?? weather?['description']) as String?;
    final weatherMain = (json['weatherMain'] ?? weather?['main']) as String?;
    final weatherIcon = (json['weatherIcon'] ?? weather?['icon']) as String?;
    final weatherId = (json['weatherId'] ?? weather?['id'] as num?) as num?;
    final temp = (json['temp'] as num?)?.toDouble() ?? 0;
    final feelsLike = (json['feelsLike'] as num?)?.toDouble() ?? temp;
    final windSpeed = (json['windSpeed'] as num?)?.toDouble() ?? 0;
    final windGust = (json['windGust'] as num?)?.toDouble();
    final dewPoint = (json['dewPoint'] as num?)?.toDouble();
    final now = DateTime.now();
    final observedAt = _dateFromJson(json['observedAt'] ?? json['dt']);
    final sourceUpdatedAt = _dateFromJson(json['sourceUpdatedAt']);
    final fetchedAt = _dateFromJson(json['fetchedAt']);
    final sunrise = _dateFromJson(json['sunrise']);
    final sunset = _dateFromJson(json['sunset']);
    final rainLastHour = (json['rain1h'] as num?)?.toDouble();
    final snowLastHour = (json['snow1h'] as num?)?.toDouble();

    return CurrentWeather(
      locationName: locationName,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezoneOffset: (json['timezoneOffset'] as num?)?.round(),
      sourceUpdatedAt: sourceUpdatedAt,
      fetchedAt: fetchedAt,
      units: dtoUnits,
      temperatureC: _temperatureToC(temp, dtoUnits),
      condition: _titleCase(
        weatherDescription ?? weatherMain ?? 'Current conditions',
      ),
      feelsLikeC: _temperatureToC(feelsLike, dtoUnits),
      windKph: _speedToKph(windSpeed, dtoUnits),
      windDirection: _windDirection((json['windDeg'] as num?)?.toDouble()),
      humidity: (json['humidity'] as num?)?.round() ?? 0,
      precipitationChance: 0,
      aqi: 0,
      aqiCategory: '',
      sunrise: sunrise ?? DateTime(now.year, now.month, now.day, 6),
      sunset: sunset ?? DateTime(now.year, now.month, now.day, 18),
      moonrise: DateTime(now.year, now.month, now.day, 21),
      moonset: DateTime(now.year, now.month, now.day + 1, 6),
      uvIndex: (json['uvi'] as num?)?.toDouble() ?? 0,
      uvCategory: _uvCategory((json['uvi'] as num?)?.toDouble() ?? 0),
      chaosMeterPercent: _chaosMeter(weatherId),
      lastUpdated: observedAt ?? sourceUpdatedAt ?? now,
      dewPointC: dewPoint == null ? null : _temperatureToC(dewPoint, dtoUnits),
      pressureHpa: (json['pressure'] as num?)?.round(),
      visibilityMeters: (json['visibility'] as num?)?.round(),
      windGustKph: windGust == null ? null : _speedToKph(windGust, dtoUnits),
      rainLastHour: _precipitationToDisplayUnits(rainLastHour, dtoUnits),
      snowLastHour: _precipitationToDisplayUnits(snowLastHour, dtoUnits),
      weatherIcon: weatherIcon,
      weatherId: weatherId?.round(),
      alertIds: ((json['alertIds'] as List?) ?? const [])
          .map((id) => id.toString())
          .toList(),
      timezone: json['timezone'] as String?,
    );
  }

  static DateTime? _dateFromJson(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  static double _fToC(double tempF) => (tempF - 32) * 5 / 9;

  static double _kToC(double tempK) => tempK - 273.15;

  static double _temperatureToC(double value, String units) {
    return switch (units) {
      'metric' => value,
      'standard' => _kToC(value),
      _ => _fToC(value),
    };
  }

  static double _speedToKph(double value, String units) {
    return units == 'imperial' ? value * 1.609344 : value * 3.6;
  }

  static double? _precipitationToDisplayUnits(double? value, String units) {
    if (value == null) return null;
    return units == 'imperial' ? value / 25.4 : value;
  }

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

  static void _debugWeatherFailure(Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather request failed '
      'host=${uri.host} path=${uri.path}: $error',
    );
  }

  static void _debugNonJsonResponse(Uri uri, http.Response response) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather backend returned non-JSON '
      'url=$uri status=${response.statusCode} '
      'contentType=${response.headers['content-type'] ?? 'unknown'} '
      'bodyPreview=${_safeBodyPreview(response.body)}',
    );
  }

  static void _debugInvalidJsonResponse(
    Uri uri,
    http.Response response,
    Object error,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather backend returned invalid JSON '
      'url=$uri status=${response.statusCode} '
      'contentType=${response.headers['content-type'] ?? 'unknown'} '
      'bodyPreview=${_safeBodyPreview(response.body)} error=$error',
    );
  }

  static String _safeBodyPreview(String body) {
    final compact = body
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .trim();
    return compact.length <= 240 ? compact : '${compact.substring(0, 240)}...';
  }

  static _TileCoordinate _tileForLocation({
    required double latitude,
    required double longitude,
    required int zoom,
  }) {
    final lat = latitude.clamp(-85.05112878, 85.05112878).toDouble();
    final lon = longitude.clamp(-180.0, 180.0).toDouble();
    final latRad = lat * math.pi / 180;
    final scale = 1 << zoom;
    final x = ((lon + 180) / 360 * scale).floor().clamp(0, scale - 1).toInt();
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                scale)
            .floor()
            .clamp(0, scale - 1)
            .toInt();
    return _TileCoordinate(x: x, y: y);
  }
}

class _TileCoordinate {
  const _TileCoordinate({required this.x, required this.y});

  final int x;
  final int y;
}
