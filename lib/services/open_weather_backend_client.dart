import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config/weather_api_config.dart';
import '../models/weather_models.dart';
import 'network_counters.dart';

class RadarHealth {
  const RadarHealth({
    required this.ok,
    required this.source,
    required this.humanReadableMessage,
    this.upstreamStatus,
    this.upstreamContentType,
    this.upstreamContentLength,
    this.firstBytesHex,
    this.isImage = false,
    this.latestFrameTimestamp,
    this.availableFrameCount,
    this.statusCode,
    this.fallbackCode,
  });

  final bool ok;
  final String source;
  final String humanReadableMessage;
  final int? upstreamStatus;
  final String? upstreamContentType;
  final int? upstreamContentLength;
  final String? firstBytesHex;
  final bool isImage;
  final int? latestFrameTimestamp;
  final int? availableFrameCount;
  final int? statusCode;
  final String? fallbackCode;

  bool get available => ok;

  factory RadarHealth.fromJson(Map<String, dynamic> json) {
    return RadarHealth(
      ok: json['ok'] == true,
      source: (json['source'] as String?) ?? 'unknown',
      humanReadableMessage: (json['humanReadableMessage'] as String?) ??
          'Radar temporarily unavailable.',
      upstreamStatus: (json['upstreamStatus'] as num?)?.round(),
      upstreamContentType: json['upstreamContentType'] as String?,
      upstreamContentLength: (json['upstreamContentLength'] as num?)?.round(),
      firstBytesHex: json['firstBytesHex'] as String?,
      isImage: json['isImage'] == true,
      latestFrameTimestamp: (json['latestFrameTimestamp'] as num?)?.round(),
      availableFrameCount: (json['availableFrameCount'] as num?)?.round(),
      statusCode: (json['upstreamStatus'] as num?)?.round(),
      fallbackCode: json['fallbackCode'] as String?,
    );
  }
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
    NetworkCounters? counters,
  })  : counters = counters ?? NetworkCounters.instance,
        _httpClient = httpClient ?? http.Client(),
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

  final NetworkCounters counters;
  final Map<String, Future<Map<String, dynamic>>> _inflight = {};
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

  Future<WeatherBundle> forecast({
    required double latitude,
    required double longitude,
    String units = 'imperial',
    String locationName = '',
  }) async {
    final json = await _getJson(
      '/weather/forecast',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'units': units,
      },
    );
    return _forecastBundleFromBackend(
      json,
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
    return _recordsFromList(json['points'])
        .where((item) => _forecastTimestamp(item['time'] ?? item['dt']) != null)
        .map(TimelineWeatherPoint.fromJson)
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
    return _recordsFromList(json['points'])
        .where((item) => _forecastTimestamp(item['time'] ?? item['dt']) != null)
        .map(TimelineWeatherPoint.fromJson)
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
    String? source,
  }) {
    final radarSource = source ?? mode.sourceParam;
    return '$baseUrl/radar/tile?source=$radarSource'
        '&z={z}&x={x}&y={y}&time=$timestamp';
  }

  Future<RadarFrameSet> radarFrames({
    required RadarMode mode,
    required double latitude,
    required double longitude,
    int hours = 6,
  }) async {
    final path = switch (mode) {
      RadarMode.usForecast => '/radar/noaaFrames',
      RadarMode.futureCast => '/radar/futureFrames',
      RadarMode.global => '/radarFrames',
    };
    final query = <String, String>{
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      if (mode == RadarMode.futureCast) 'hours': hours.toString(),
      if (mode == RadarMode.global) 'product': 'global',
    };
    final json = await _getJson(path, query);
    return RadarFrameSet.fromJson(json);
  }

  Future<RadarHealth> radarHealth({
    required RadarMode mode,
    required int timestamp,
    required double latitude,
    required double longitude,
    String? source,
  }) async {
    try {
      final json = await _getJson(
        '/radarHealth',
        {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'source': source ?? mode.sourceParam,
          'time': timestamp.toString(),
        },
      );
      return RadarHealth.fromJson(json);
    } catch (error) {
      return RadarHealth(
        ok: false,
        source: source ?? mode.sourceParam,
        humanReadableMessage:
            "Couldn't reach the radar service. The base map is still usable.",
        fallbackCode: 'weather_backend_unreachable',
      );
    }
  }

  Future<RadarHealth> radarTileHealth({
    required RadarMode mode,
    required int timestamp,
    required double latitude,
    required double longitude,
    String? source,
  }) {
    return radarHealth(
      mode: mode,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      source: source,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) {
    final uri = _uri(path, query);
    final key = uri.toString();
    final pending = _inflight[key];
    if (pending != null) {
      counters.increment('backendDeduplicated');
      return pending;
    }
    return _inflight[key] = _requestJson(path, query, uri).whenComplete(() {
      _inflight.remove(key);
    });
  }

  Future<Map<String, dynamic>> _requestJson(
    String path,
    Map<String, String> query,
    Uri uri,
  ) async {
    counters.increment(path.startsWith('/location/')
        ? 'geocodingBackendRequests'
        : path.startsWith('/weather/')
            ? 'weatherBackendRequests'
            : 'radarBackendRequests');
    _debugWeatherEndpoint(path, query);
    final http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(_requestTimeout);
    } catch (error) {
      _debugWeatherFailure(uri, error);
      throw OpenWeatherBackendException(_connectionFailureMessage(uri));
    }

    counters.increment('backendResponseBytes', response.bodyBytes.length);
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
    final weather = _primaryWeatherCondition(json['weather']);
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
      temperatureKnown: json['temp'] is num,
      feelsLikeKnown: json['feelsLike'] is num,
      windKnown: json['windSpeed'] is num,
      humidityKnown: json['humidity'] is num,
      uvKnown: json['uvi'] is num,
      sunriseKnown: sunrise != null,
      sunsetKnown: sunset != null,
      temperatureC: _temperatureToC(temp, dtoUnits),
      condition: _titleCase(
        weatherDescription ?? weatherMain ?? 'Current conditions',
      ),
      feelsLikeC: _temperatureToC(feelsLike, dtoUnits),
      windKph: _speedToKph(windSpeed, dtoUnits),
      windDirection: _windDirection((json['windDeg'] as num?)?.toDouble()),
      humidity: (json['humidity'] as num?)?.round() ?? 0,
      precipitationChance: 0,
      precipitationChanceKnown: false,
      aqi: (json['aqi'] as num?)?.round() ?? 0,
      aqiCategory: json['aqiCategory'] as String? ?? '',
      aqiScale: json['aqiScale'] as String?,
      aqiSource: json['aqiSource'] as String?,
      sunrise: sunrise ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sunset: sunset ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      moonrise: _dateFromJson(json['moonrise']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      moonset: _dateFromJson(json['moonset']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      uvIndex: (json['uvi'] as num?)?.toDouble() ?? -1,
      uvCategory: json['uvi'] is num
          ? _uvCategory((json['uvi'] as num).toDouble())
          : '',
      chaosMeterPercent: _chaosMeter(weatherId),
      lastUpdated: observedAt ??
          sourceUpdatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dewPointC: dewPoint == null ? null : _temperatureToC(dewPoint, dtoUnits),
      pressureHpa: (json['pressure'] as num?)?.round(),
      visibilityMeters: (json['visibility'] as num?)?.round(),
      windGustKph: windGust == null ? null : _speedToKph(windGust, dtoUnits),
      rainLastHour: _precipitationToDisplayUnits(rainLastHour, dtoUnits),
      snowLastHour: _precipitationToDisplayUnits(snowLastHour, dtoUnits),
      weatherIcon: weatherIcon,
      weatherMain: weatherMain,
      weatherId: weatherId?.round(),
      alertIds: ((json['alertIds'] as List?) ?? const [])
          .map((id) => id.toString())
          .toList(),
      timezone: json['timezone'] as String?,
    );
  }

  static WeatherBundle _forecastBundleFromBackend(
    Map<String, dynamic> json, {
    required String locationName,
    required String units,
  }) {
    final dtoUnits = (json['units'] as String?) ?? units;
    final currentJson =
        ((json['current'] as Map?) ?? json).cast<String, dynamic>();
    final hourlyMetadata = json['hourlyTimeline'] is Map
        ? json['hourlyTimeline'] as Map
        : const {};
    final dailyMetadata =
        json['dailyTimeline'] is Map ? json['dailyTimeline'] as Map : const {};
    final current = _currentFromBackend(
      {
        ...currentJson,
        'timezone': currentJson['timezone'] ??
            json['timezone'] ??
            hourlyMetadata['timezone'] ??
            dailyMetadata['timezone'],
        'timezoneOffset': currentJson['timezoneOffset'] ??
            json['timezoneOffset'] ??
            hourlyMetadata['timezoneOffset'] ??
            dailyMetadata['timezoneOffset'],
      },
      locationName: locationName,
      units: dtoUnits,
    );
    final timezoneOffset =
        current.timezoneOffset ?? (json['timezoneOffset'] as num?)?.round();
    final hourlyRecords = _forecastRecords(
      json['hourly'],
      json['hourlyTimeline'],
    )
        .where((item) => _forecastTimestamp(item['time'] ?? item['dt']) != null)
        .toList(growable: false);
    final dailyRecords = _forecastRecords(
      json['daily'],
      json['dailyTimeline'],
    )
        .where((item) =>
            _forecastDate(
                item['date'], item['dt'], timezoneOffset, current.timezone) !=
            null)
        .toList(growable: false);
    final hourly = hourlyRecords
        .map(
          (item) => _hourlyForecastFromBackend(
            item,
            units: dtoUnits,
          ),
        )
        .toList(growable: false);
    final daily = dailyRecords
        .map(
          (item) => _dailyForecastFromBackend(
            item,
            current: current,
            units: dtoUnits,
            timezoneOffset: timezoneOffset,
          ),
        )
        .toList(growable: false);
    final minutes = _recordsFromList(json['minutes'])
        .map((item) => MinutePrecipitation.fromJson(
              item,
            ))
        .toList(growable: false);
    final timeline = hourlyRecords
        .map((item) => TimelineWeatherPoint.fromJson(
              item,
            ))
        .toList(growable: false);
    final alerts = _recordsFromList(json['alerts'])
        .map((item) => WeatherAlert.fromJson(
              item,
            ))
        .toList(growable: false);
    final forecastErrors =
        (json['forecastErrors'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hourlyForecastMessage =
        hourly.isEmpty ? _forecastIssueMessage(forecastErrors['hourly']) : null;
    final dailyForecastMessage =
        daily.isEmpty ? _forecastIssueMessage(forecastErrors['daily']) : null;

    return WeatherBundle(
      current: current,
      hourly: hourly,
      daily: daily,
      minutePrecipitation: minutes,
      timeline: timeline,
      alerts: alerts,
      alertCoverageVerified: json['alertCoverageVerified'] == true,
      alertsCheckedAt: _dateFromJson(json['alertsCheckedAt']),
      hourlyForecastMessage: hourlyForecastMessage,
      dailyForecastMessage: dailyForecastMessage,
    );
  }

  static String? _forecastIssueMessage(Object? value) {
    if (value is! Map) return null;
    final record = value.cast<String, dynamic>();
    final code = record['code'] as String?;
    final message = record['message'] as String?;
    return switch (code) {
      'openweather_one_call_access_denied' =>
        'Forecast timeline needs OpenWeather One Call API 4.0 access.',
      'openweather_key_rejected' =>
        'Forecast timeline credentials need attention.',
      'openweather_not_found' => 'Forecast timeline data was not found.',
      'openweather_timeout' => 'Forecast timeline timed out. Try again soon.',
      'openweather_unavailable' =>
        'Forecast timeline is temporarily unavailable.',
      _ => message,
    };
  }

  static List<Map<String, dynamic>> _forecastRecords(
    Object? records,
    Object? timeline,
  ) {
    final direct = _recordsFromList(records).toList(growable: false);
    if (direct.isNotEmpty) return direct;
    final timelineRecord =
        timeline is Map ? timeline.cast<String, dynamic>() : null;
    return _recordsFromList(timelineRecord?['data']).toList(growable: false);
  }

  static Iterable<Map<String, dynamic>> _recordsFromList(Object? value) sync* {
    if (value is! List) return;
    for (final item in value) {
      if (item is Map) {
        yield item.cast<String, dynamic>();
      }
    }
  }

  static HourlyForecast _hourlyForecastFromBackend(
    Map<String, dynamic> json, {
    required String units,
  }) {
    final weather = _primaryWeatherCondition(json['weather']);
    final rawTemp = json['temp'] ?? json['temperature'] ?? json['temperatureF'];
    final rawTime = _forecastTimestamp(json['time'] ?? json['dt']);
    return HourlyForecast(
      time: rawTime!,
      temperatureKnown: rawTemp is num && rawTemp.isFinite,
      temperatureC: rawTemp is num && rawTemp.isFinite
          ? _temperatureToC(rawTemp.toDouble(), units)
          : 0,
      condition: _titleCase(
        (json['condition'] ??
                json['weatherDescription'] ??
                weather?['description'] ??
                weather?['main'] ??
                'Unknown')
            .toString(),
      ),
      precipitationChanceKnown: (json['precipitationProbability'] ??
          json['pop'] ??
          json['precipitationChance']) is num,
      precipitationChance: _precipitationChance(
        json['precipitationProbability'] ??
            json['pop'] ??
            json['precipitationChance'],
      ),
      weatherIcon:
          (json['weatherIcon'] ?? json['icon'] ?? weather?['icon']) as String?,
      weatherMain: (json['weatherMain'] ?? weather?['main']) as String?,
      weatherId: (json['weatherId'] ?? weather?['id'] as num?)?.round(),
    );
  }

  static DailyForecast _dailyForecastFromBackend(
    Map<String, dynamic> json, {
    required CurrentWeather current,
    required String units,
    required int? timezoneOffset,
  }) {
    final weather = _primaryWeatherCondition(json['weather']);
    final temp = (json['temp'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawMin = json['minTemp'] ?? json['minTempF'] ?? temp['min'];
    final rawMax = json['maxTemp'] ?? json['maxTempF'] ?? temp['max'];
    return DailyForecast(
      date: _forecastDate(
        json['date'],
        json['dt'],
        timezoneOffset,
        current.timezone,
      )!,
      temperatureKnown:
          rawMin is num && rawMin.isFinite && rawMax is num && rawMax.isFinite,
      minTempC: rawMin is num && rawMin.isFinite
          ? _temperatureToC(rawMin.toDouble(), units)
          : 0,
      maxTempC: rawMax is num && rawMax.isFinite
          ? _temperatureToC(rawMax.toDouble(), units)
          : 0,
      condition: _titleCase(
        (json['condition'] ??
                json['weatherDescription'] ??
                weather?['description'] ??
                weather?['main'] ??
                'Unknown')
            .toString(),
      ),
      precipitationChanceKnown: (json['precipitationProbability'] ??
          json['pop'] ??
          json['precipitationChance']) is num,
      precipitationChance: _precipitationChance(
        json['precipitationProbability'] ??
            json['pop'] ??
            json['precipitationChance'],
      ),
      weatherIcon:
          (json['weatherIcon'] ?? json['icon'] ?? weather?['icon']) as String?,
      weatherMain: (json['weatherMain'] ?? weather?['main']) as String?,
      weatherId: (json['weatherId'] ?? weather?['id'] as num?)?.round(),
    );
  }

  static int _precipitationChance(Object? value, {int fallback = 0}) {
    if (value is! num) return fallback;
    final probability = value.toDouble();
    return probability <= 1 ? (probability * 100).round() : probability.round();
  }

  static bool _forecastTimeZonesLoaded = false;

  static DateTime? _forecastDate(
    Object? date,
    Object? dt,
    int? timezoneOffset,
    String? timezone,
  ) {
    if (date is String) {
      final civil = _validCivilPrefix(date);
      if (civil != null && DateTime.tryParse(date) != null) return civil;
    }
    final instant = _forecastTimestamp(dt);
    if (instant == null) return null;
    if (timezone != null && timezone.isNotEmpty) {
      if (!_forecastTimeZonesLoaded) {
        tzdata.initializeTimeZones();
        _forecastTimeZonesLoaded = true;
      }
      try {
        final local = tz.TZDateTime.from(instant, tz.getLocation(timezone));
        return DateTime(local.year, local.month, local.day);
      } on tz.LocationNotFoundException {
        // A provider offset is the honest fallback for an unknown zone name.
      }
    }
    final local = instant.toUtc().add(Duration(seconds: timezoneOffset ?? 0));
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? _validCivilPrefix(String value) {
    final match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|T|\s)').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final civil = DateTime(year, month, day);
    return civil.year == year && civil.month == month && civil.day == day
        ? civil
        : null;
  }

  static DateTime? _forecastTimestamp(Object? value) {
    if (value is String && _validCivilPrefix(value) == null) return null;
    if (value is num && !value.isFinite) return null;
    try {
      return _dateFromJson(value);
    } on ArgumentError {
      return null;
    }
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

  static Map<String, dynamic>? _primaryWeatherCondition(Object? value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first as Map).cast<String, dynamic>();
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
    debugPrint('[GrumpySkies] weather endpoint $path');
  }

  static void _debugWeatherFailure(Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather request failed '
      'host=${uri.host} path=${uri.path}: ${error.runtimeType}',
    );
  }

  static void _debugNonJsonResponse(Uri uri, http.Response response) {
    if (!kDebugMode) return;
    debugPrint(
      '[GrumpySkies] weather backend returned non-JSON '
      'host=${uri.host} path=${uri.path} status=${response.statusCode} '
      'contentType=${response.headers['content-type'] ?? 'unknown'} '
      'responseBytes=${response.bodyBytes.length}',
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
      'host=${uri.host} path=${uri.path} status=${response.statusCode} '
      'contentType=${response.headers['content-type'] ?? 'unknown'} '
      'responseBytes=${response.bodyBytes.length} error=${error.runtimeType}',
    );
  }
}
