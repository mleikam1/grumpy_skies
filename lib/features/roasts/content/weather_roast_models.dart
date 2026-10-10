import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../models/weather_safety.dart';
import 'roast_content_models.dart';
import 'roast_context_adapter.dart';
export '../models/roast_mood.dart';
export 'roast_content_models.dart';

extension RoastLineWeatherConstraints on RoastLine {
  bool matchesStaticWeatherConstraints(WeatherRoastContext context) {
    if (conditionCodes.isNotEmpty &&
        (context.conditionCode == null ||
            !conditionCodes.contains(context.conditionCode))) {
      return false;
    }
    if (tempMinF != null &&
        (context.tempF == null || context.tempF! < tempMinF!)) {
      return false;
    }
    if (tempMaxF != null &&
        (context.tempF == null || context.tempF! > tempMaxF!)) {
      return false;
    }
    if (humidityMin != null &&
        (context.humidity == null || context.humidity! < humidityMin!)) {
      return false;
    }
    if (windMinMph != null &&
        (context.windMph == null || context.windMph! < windMinMph!)) {
      return false;
    }
    if (precipMinPercent != null &&
        (context.precipChance == null ||
            context.precipChance! < precipMinPercent!)) {
      return false;
    }
    return true;
  }
}

/// Immutable adapter output. Nullable fields are unknown, never fictional zeroes.
class WeatherRoastContext {
  const WeatherRoastContext({
    required this.city,
    this.tempF,
    this.feelsLikeF,
    this.condition,
    this.humidity,
    this.windMph,
    this.precipChance,
    this.daypart = Daypart.any,
    this.tags = const {},
    this.conditionCode,
    this.temperatureUnit = TemperatureUnit.fahrenheit,
    this.placeId,
    this.country,
    this.region,
    this.timezone,
    this.localTime,
    this.evaluatedAt,
    this.observedAt,
    this.windowStart,
    this.windowEnd,
    this.scope = RoastScope.current,
    this.locale = 'en-US',
    this.freshness = WeatherFreshness.fresh,
    this.safetyStatus = WeatherSafetyStatus.unknown,
    this.isOffline = false,
    this.forecastComplete = false,
    this.observedRainMm,
    this.uvIndex,
    this.aqi,
    this.aqiScale,
    this.aqiSource,
    this.activity,
    this.extraFacts = const {},
  });
  final TemperatureUnit temperatureUnit;
  final String city;
  final int? tempF;
  final int? feelsLikeF;
  final String? condition;
  final int? humidity;
  final double? windMph;
  final int? precipChance;
  final Daypart daypart;
  final Set<WeatherRoastTag> tags;
  final int? conditionCode;
  final String? placeId;
  final String? country;
  final String? region;
  final String? timezone;
  final DateTime? localTime;
  final DateTime? evaluatedAt;
  final DateTime? observedAt;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final RoastScope scope;
  final String locale;
  final WeatherFreshness freshness;
  final WeatherSafetyStatus safetyStatus;
  final bool isOffline;
  final bool forecastComplete;
  final double? observedRainMm;
  final double? uvIndex;
  final int? aqi;
  final String? aqiScale;
  final String? aqiSource;
  final RoastActivity? activity;
  final Set<String> extraFacts;

  bool get requiresSafetyMessage =>
      safetyStatus == WeatherSafetyStatus.activeAlert ||
      tags.contains(WeatherRoastTag.severe);
  bool get hasFreshWeather => freshness == WeatherFreshness.fresh;
  Set<String> get facts => {
        ...tags.map((tag) => tag.wireValue),
        ...extraFacts,
        if (scope == RoastScope.current &&
            ((observedRainMm != null && observedRainMm! > 0) ||
                {
                  200,
                  201,
                  202,
                  230,
                  231,
                  232,
                  300,
                  301,
                  302,
                  310,
                  311,
                  312,
                  313,
                  314,
                  321,
                  500,
                  501,
                  502,
                  503,
                  504,
                  511,
                  520,
                  521,
                  522,
                  531,
                  615,
                  616
                }.contains(conditionCode)))
          'observed_rain',
        if (precipChance != null) 'forecast_rain_probability',
        if (activity != null) activity!.fact,
      };

  /// Three-state evidence: absence of an input is never evidence of absence.
  bool? factValue(String fact) {
    if (facts.contains(fact)) return true;
    if (fact.startsWith('activity_')) return activity == null ? null : false;
    if (fact == 'forecast_rain_probability') {
      return precipChance == null ? null : true;
    }
    if ({'hot', 'cold'}.contains(fact)) return tempF == null ? null : false;
    if (fact == 'dry') return humidity == null ? null : false;
    if (fact == 'humid') {
      return tempF == null || humidity == null ? null : false;
    }
    if (fact == 'windy') return windMph == null ? null : false;
    if (fact == 'high_uv') return uvIndex == null ? null : false;
    if (fact == 'bad_air') {
      return aqi == null || !{'us_epa', 'openweather_1_5'}.contains(aqiScale)
          ? null
          : false;
    }
    if ({
      'clear',
      'partly_cloudy',
      'cloudy',
      'light_rain',
      'heavy_rain',
      'storm',
      'snow',
      'fog',
      'observed_rain'
    }.contains(fact)) {
      return knownRoastConditionCodes.contains(conditionCode) ? false : null;
    }
    // Composite/region/calendar facts require affirmative evidence supplied by
    // the adapter. Unsupported or partially observed combinations stay unknown.
    return null;
  }

  Map<String, Map<String, Object?>> get inputProvenance => {
        for (final entry in <String, bool>{
          'temperature': tempF != null,
          'feels_like': feelsLikeF != null,
          'humidity': humidity != null,
          'wind': windMph != null,
          'condition_code': knownRoastConditionCodes.contains(conditionCode),
          'forecast_probability': precipChance != null,
          'observed_rain': observedRainMm != null,
          'uv_index': uvIndex != null,
          'air_quality': aqi != null && aqiScale != null,
          'local_calendar': localTime != null,
          'alerts': safetyStatus == WeatherSafetyStatus.clear ||
              safetyStatus == WeatherSafetyStatus.activeAlert,
        }.entries)
          entry.key: {
            'known': entry.value,
            'source': entry.key == 'local_calendar'
                ? 'selected_location_timezone'
                : scope == RoastScope.current
                    ? 'weather_bundle_current'
                    : 'weather_bundle_forecast',
            'observed_at': observedAt?.toUtc().toIso8601String(),
            'freshness': freshness.name,
          },
      };

  factory WeatherRoastContext.fromWeatherBundle(
    WeatherBundle weather, {
    DateTime? now,
    TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
    RoastScope scope = RoastScope.current,
    DateTime? targetTime,
    DateTime? targetEnd,
    String locale = 'en-US',
    RoastActivity? activity,
    LocationCandidate? selectedLocation,
  }) =>
      adaptRoastContext(weather,
          now: now ?? DateTime.now(),
          temperatureUnit: temperatureUnit,
          scope: scope,
          targetTime: targetTime,
          targetEnd: targetEnd,
          locale: locale,
          activity: activity,
          selectedLocation: selectedLocation);

  String? _displayTemperature(int? fahrenheit) => fahrenheit == null
      ? null
      : temperatureUnit == TemperatureUnit.celsius
          ? ((fahrenheit - 32) * 5 / 9).round().toString()
          : fahrenheit.toString();

  Map<String, String> get placeholderValues => {
        if (city.trim().isNotEmpty) 'city': city,
        if (tempF != null) 'temp': _displayTemperature(tempF)!,
        'temp_unit': '°${temperatureUnit.suffix}',
        if (feelsLikeF != null) 'feels_like': _displayTemperature(feelsLikeF)!,
        if (condition != null &&
            condition!.trim().isNotEmpty &&
            condition != 'Unknown')
          'condition': condition!,
        if (humidity != null) 'humidity': humidity.toString(),
        if (windMph != null) 'wind_mph': windMph!.round().toString(),
        if (precipChance != null) 'precip_chance': precipChance.toString(),
        if (daypart != Daypart.any) 'daypart': daypart.name,
      };

  bool canRender(String template) =>
      RegExp(r'\{([^{}]+)\}')
          .allMatches(template)
          .every((m) => placeholderValues.containsKey(m.group(1))) &&
      !template
          .replaceAll(RegExp(r'\{([^{}]+)\}'), '')
          .contains(RegExp(r'[{}]'));

  String render(String template) {
    if (!canRender(template)) {
      throw FormatException(
          'Unknown or unavailable roast placeholder', template);
    }
    final values = placeholderValues;
    return _cleanRenderedText(template.replaceAllMapped(
        RegExp(r'\{([^{}]+)\}'), (m) => values[m.group(1)]!));
  }

  /// Broad weather buckets keep display slots stable across tiny value changes.
  String stableSlot(String persona, RoastType type) => [
        normalizeRoastPersonaId(persona),
        sha256.convert(utf8.encode(placeId ?? city)).toString(),
        scope.name,
        type.name,
        localTime == null
            ? 'unknown-date'
            : '${localTime!.year}-${localTime!.month}-${localTime!.day}',
        daypart.name,
        if (scope != RoastScope.current)
          windowStart?.toUtc().toIso8601String() ?? 'unknown-window',
        ...(tags.map((tag) => tag.wireValue).toList()..sort()),
        precipChance == null
            ? 'unknown-pop'
            : precipChance! < 30
                ? 'low-pop'
                : precipChance! < 60
                    ? 'moderate-pop'
                    : 'high-pop',
        freshness.name,
        safetyStatus.name,
        locale,
        activity?.name ?? '',
      ].join('|');

  Map<String, Object?> get diagnostics => {
        'scope': scope.name,
        'timezone': timezone,
        'local_time': localTime?.toIso8601String(),
        'observed_at': observedAt?.toUtc().toIso8601String(),
        'window_start': windowStart?.toUtc().toIso8601String(),
        'window_end': windowEnd?.toUtc().toIso8601String(),
        'freshness': freshness.name,
        'alert_status': safetyStatus.name,
        'offline': isOffline,
        'forecast_complete': forecastComplete,
        'facts': facts.toList()..sort(),
        'inputs': inputProvenance,
        'aqi_scale': aqiScale,
        'aqi_source': aqiSource,
      };

  static WeatherRoastContext unavailable(
          {DateTime? now,
          String city = '',
          String? placeId,
          String? country,
          String? region,
          String? timezone,
          RoastScope scope = RoastScope.current,
          String locale = 'en-US',
          TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
          RoastActivity? activity}) =>
      WeatherRoastContext(
          city: city,
          placeId: placeId,
          country: country,
          region: region,
          timezone: timezone,
          evaluatedAt: now ?? DateTime.now(),
          scope: scope,
          locale: locale,
          temperatureUnit: temperatureUnit,
          activity: activity,
          freshness: WeatherFreshness.unavailable,
          tags: const {WeatherRoastTag.fallback});

  static WeatherRoastContext fallback(
          {String city = 'your area', Daypart daypart = Daypart.any}) =>
      WeatherRoastContext(
          city: city,
          daypart: daypart,
          freshness: WeatherFreshness.unavailable,
          tags: const {WeatherRoastTag.fallback});
}

String _cleanRenderedText(String text) {
  var cleaned = text
      .replaceAllMapped(
        RegExp(r'\s+([,.!?;:])'),
        (match) => match.group(1)!,
      )
      .replaceAllMapped(
        RegExp(r'[,;:]\s*([.!?])'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  return cleaned;
}

/// Only documented OpenWeather codes establish positive or negative facts.
const knownRoastConditionCodes = <int>{
  200,
  201,
  202,
  210,
  211,
  212,
  221,
  230,
  231,
  232,
  300,
  301,
  302,
  310,
  311,
  312,
  313,
  314,
  321,
  500,
  501,
  502,
  503,
  504,
  511,
  520,
  521,
  522,
  531,
  600,
  601,
  602,
  611,
  612,
  613,
  615,
  616,
  620,
  621,
  622,
  701,
  711,
  721,
  731,
  741,
  751,
  761,
  762,
  771,
  781,
  800,
  801,
  802,
  803,
  804,
};
