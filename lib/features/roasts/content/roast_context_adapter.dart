import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../models/weather_safety.dart';
import 'weather_roast_models.dart';

bool _zonesReady = false;

/// IANA conversion honors DST at the target instant. An offset is valid only
/// for the current observation period; it cannot predict future DST transitions.
DateTime? roastLocalTime(DateTime instant, String? zone, int? offset,
    {bool forecast = false}) {
  if (zone != null && zone.isNotEmpty) {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
    try {
      return tz.TZDateTime.from(instant.toUtc(), tz.getLocation(zone));
    } on tz.LocationNotFoundException {
      // Unknown zones remain unknown instead of using the device's location.
    }
  }
  if (offset != null && !forecast) {
    return DateTime.fromMillisecondsSinceEpoch(
        instant.toUtc().millisecondsSinceEpoch + offset * 1000,
        isUtc: true);
  }
  return null;
}

WeatherRoastContext adaptRoastContext(
  WeatherBundle weather, {
  required DateTime now,
  TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
  RoastScope scope = RoastScope.current,
  DateTime? targetTime,
  DateTime? targetEnd,
  String locale = 'en-US',
  RoastActivity? activity,
  LocationCandidate? selectedLocation,
}) {
  final current = weather.current;
  final place = selectedLocation ?? weather.location;
  final city = place?.name ?? current.locationName.split(',').first.trim();
  final placeId = place != null
      ? '${place.lat},${place.lon}'
      : current.latitude != null && current.longitude != null
          ? '${current.latitude},${current.longitude}'
          : city;
  if (selectedLocation != null &&
      (weather.location?.lat ?? current.latitude) != null &&
      (weather.location?.lon ?? current.longitude) != null &&
      ((selectedLocation.lat - (weather.location?.lat ?? current.latitude!))
                  .abs() >
              0.00001 ||
          (selectedLocation.lon - (weather.location?.lon ?? current.longitude!))
                  .abs() >
              0.00001)) {
    return WeatherRoastContext.unavailable(
        now: now,
        city: city,
        placeId: placeId,
        country: place?.country,
        region: place?.state,
        locale: locale,
        scope: scope,
        temperatureUnit: temperatureUnit,
        activity: activity);
  }
  final observedAt = current.displayUpdatedAt;
  final localNow =
      roastLocalTime(now, current.timezone, current.timezoneOffset);
  final isCurrent = scope == RoastScope.current;
  var local = isCurrent
      ? localNow
      : roastLocalTime(
          targetTime ?? now, current.timezone, current.timezoneOffset,
          forecast: true);
  final freshness = weather.isOfflineCache
      ? WeatherFreshness.stale
      : weatherFreshness(observedAt, now,
          maxAge: isCurrent
              ? const Duration(minutes: 30)
              : const Duration(hours: 3));
  final safety = weatherSafetyStatus(weather, now);
  var temp = isCurrent && current.temperatureKnown
      ? _number(current.temperatureF)?.round()
      : null;
  var temperatureC = isCurrent && current.temperatureKnown
      ? _number(current.temperatureC)
      : null;
  final extraFacts = <String>{};
  var feels = isCurrent && current.feelsLikeKnown
      ? _number(current.feelsLikeF)?.round()
      : null;
  var humidity = isCurrent &&
          current.humidityKnown &&
          current.humidity >= 0 &&
          current.humidity <= 100
      ? current.humidity
      : null;
  var wind = isCurrent && current.windKnown && current.windMph >= 0
      ? _number(current.windMph)
      : null;
  var probability = isCurrent &&
          current.precipitationChanceKnown &&
          current.precipitationChance >= 0 &&
          current.precipitationChance <= 100
      ? current.precipitationChance
      : null;
  var condition = isCurrent ? current.condition : null;
  var code = isCurrent ? current.weatherId : null;
  var windowStart = isCurrent ? observedAt : targetTime;
  DateTime? windowEnd = isCurrent ? observedAt : targetEnd;
  final rainMm = isCurrent &&
          current.rainLastHour != null &&
          current.rainLastHour!.isFinite &&
          current.rainLastHour! >= 0 &&
          {'imperial', 'metric', 'standard'}.contains(current.units)
      ? current.rainLastHour! * (current.units == 'imperial' ? 25.4 : 1)
      : null;
  var tags = isCurrent
      ? roastWeatherTags(
          tempF: temp,
          humidity: humidity,
          windMph: wind,
          code: code,
          rainMm: rainMm,
          uv: current.uvKnown && current.uvIndex >= 0
              ? _number(current.uvIndex)
              : null,
          aqi: current.aqi,
          aqiScale: current.aqiScale,
          aqiCategory: current.aqiCategory)
      : <WeatherRoastTag>{};
  var complete = isCurrent;

  if (scope == RoastScope.hourly || scope == RoastScope.commute) {
    // Commute hours are explicit user-selected periods. There is no assumed
    // work schedule, morning route, or fabricated commute.
    final start = targetTime;
    final end = targetEnd ?? start?.add(const Duration(hours: 1));
    final samples = start == null || end == null
        ? <HourlyForecast>[]
        : weather.hourly
            .where((h) => !h.time.isBefore(start) && h.time.isBefore(end))
            .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (start != null &&
        end != null &&
        samples.isNotEmpty &&
        samples.first.time.isAtSameMomentAs(start) &&
        samples.last.time.add(const Duration(hours: 1)).isAtSameMomentAs(end) &&
        List.generate(
            samples.length - 1,
            (i) =>
                samples[i + 1].time.difference(samples[i].time) ==
                const Duration(hours: 1)).every((v) => v)) {
      complete = true;
      windowStart = start;
      windowEnd = end;
      final sampleTags = samples
          .map((h) => roastWeatherTags(
              tempF:
                  h.temperatureKnown ? _number(h.temperatureF)?.round() : null,
              code: h.weatherId))
          .toList();
      tags = sampleTags.reduce((a, b) => a.intersection(b));
      if (sampleTags.any((t) => t.contains(WeatherRoastTag.severe))) {
        tags.add(WeatherRoastTag.severe);
      }
      if (samples.length == 1) {
        final sample = samples.single;
        temperatureC =
            sample.temperatureKnown ? _number(sample.temperatureC) : null;
        temp = samples.single.temperatureKnown
            ? _number(samples.single.temperatureF)?.round()
            : null;
        // A trend refers only to the preceding absolute forecast hour. Missing
        // records, unknown values and DST clock labels never fabricate a trend.
        final previous = weather.hourly.where(
            (h) => sample.time.difference(h.time) == const Duration(hours: 1));
        if (temperatureC != null &&
            previous.length == 1 &&
            previous.single.temperatureKnown &&
            previous.single.temperatureC.isFinite) {
          final change = temperatureC - previous.single.temperatureC;
          if (change >= 2) extraFacts.add('forecast_warming');
          if (change <= -2) extraFacts.add('forecast_cooling');
        }
        condition = samples.single.condition;
        code = samples.single.weatherId;
        if ({
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
          520,
          521,
          522,
          531
        }.contains(code)) {
          extraFacts.add('forecast_rain_condition');
        }
        probability = samples.single.precipitationChanceKnown &&
                samples.single.precipitationChance >= 0 &&
                samples.single.precipitationChance <= 100
            ? samples.single.precipitationChance
            : null;
      }
    }
  } else if (scope == RoastScope.today || scope == RoastScope.weekend) {
    // Daily timestamps are provider calendar dates (not precise observations).
    // Require every requested date; Friday's observation is never a weekend.
    if (local != null) {
      DateTime day = DateTime.utc(local.year, local.month, local.day);
      if (scope == RoastScope.weekend && targetTime == null) {
        final days = day.weekday == DateTime.sunday
            ? -1
            : (DateTime.saturday - day.weekday + 7) % 7;
        day = day.add(Duration(days: days));
      }
      final dates = [
        day,
        if (scope == RoastScope.weekend) day.add(const Duration(days: 1))
      ];
      final samples = <DailyForecast>[];
      for (final date in dates) {
        for (final d in weather.daily) {
          // Backend daily dates use a calendar label, not an instant at UTC
          // midnight. Compare the provider's year/month/day verbatim.
          if (d.date.year == date.year &&
              d.date.month == date.month &&
              d.date.day == date.day) {
            samples.add(d);
            break;
          }
        }
      }
      if (samples.length == dates.length &&
          (scope != RoastScope.weekend || day.weekday == DateTime.saturday)) {
        complete = true;
        windowStart = _localMidnight(day, current.timezone!);
        windowEnd = _localMidnight(
            dates.last.add(const Duration(days: 1)), current.timezone!);
        local =
            roastLocalTime(windowStart, current.timezone, null, forecast: true);
        final dailyTags = samples.map((d) {
          final low = d.temperatureKnown ? _number(d.minTempF)?.round() : null;
          final high = d.temperatureKnown ? _number(d.maxTempF)?.round() : null;
          final atLow = roastWeatherTags(tempF: low, code: d.weatherId);
          final atHigh = roastWeatherTags(tempF: high, code: d.weatherId);
          final shared = atLow.intersection(atHigh);
          if (atLow.contains(WeatherRoastTag.severe) ||
              atHigh.contains(WeatherRoastTag.severe)) {
            shared.add(WeatherRoastTag.severe);
          }
          return shared;
        }).toList();
        tags = dailyTags.reduce((a, b) => a.intersection(b));
        if (dailyTags.any((t) => t.contains(WeatherRoastTag.severe))) {
          tags.add(WeatherRoastTag.severe);
        }
        if (samples.length == 1 &&
            samples.single.precipitationChanceKnown &&
            samples.single.precipitationChance >= 0 &&
            samples.single.precipitationChance <= 100) {
          probability = samples.single.precipitationChance;
        }
        // A day's low/high is not a current scalar temperature.
        if (samples.map((d) => d.weatherId).toSet().length == 1) {
          code = samples.first.weatherId;
        }
        if (samples.map((d) => d.condition).toSet().length == 1) {
          condition = samples.first.condition;
        }
        if (scope == RoastScope.weekend &&
            tags.contains(WeatherRoastTag.nice)) {
          tags.add(WeatherRoastTag.weekendGood);
        }
      }
    }
  }
  if (safety == WeatherSafetyStatus.activeAlert ||
      current.alertIds.isNotEmpty ||
      roastWeatherTags(
        tempF: current.temperatureKnown
            ? _number(current.temperatureF)?.round()
            : null,
        windMph: current.windKnown ? _number(current.windMph) : null,
        code: current.weatherId,
        aqi: current.aqi,
        aqiScale: current.aqiScale,
      ).contains(WeatherRoastTag.severe)) {
    tags.add(WeatherRoastTag.severe);
  }
  if (tags.isEmpty) tags.add(WeatherRoastTag.fallback);
  return WeatherRoastContext(
    city: city,
    placeId: placeId,
    country: place?.country,
    region: place?.state,
    timezone: current.timezone,
    localTime: local,
    evaluatedAt: now,
    observedAt: observedAt,
    windowStart: windowStart,
    windowEnd: windowEnd,
    scope: scope,
    locale: locale,
    activity: activity,
    temperatureUnit: temperatureUnit,
    tempF: temp,
    temperatureC: temperatureC,
    feelsLikeF: feels,
    humidity: humidity,
    windMph: wind,
    precipChance: probability,
    condition: condition,
    conditionCode: code,
    tags: Set.unmodifiable(tags),
    daypart: local == null ? Daypart.any : Daypart.fromDateTime(local),
    freshness: freshness,
    safetyStatus: safety,
    isOffline: weather.isOfflineCache,
    forecastComplete: complete,
    observedRainMm: rainMm,
    uvIndex: isCurrent && current.uvKnown && current.uvIndex >= 0
        ? _number(current.uvIndex)
        : null,
    aqi: isCurrent && current.aqi > 0 ? current.aqi : null,
    aqiScale: isCurrent ? current.aqiScale : null,
    aqiSource: isCurrent ? current.aqiSource : null,
    extraFacts: Set.unmodifiable(extraFacts),
  );
}

DateTime _localMidnight(DateTime calendar, String zone) => tz.TZDateTime(
        tz.getLocation(zone), calendar.year, calendar.month, calendar.day)
    .toUtc();
double? _number(num? value) =>
    value != null && value.isFinite ? value.toDouble() : null;

/// OpenWeather condition code semantics are authoritative. POP is deliberately
/// absent from this function: probability does not establish rain or intensity.
Set<WeatherRoastTag> roastWeatherTags(
    {int? tempF,
    int? humidity,
    double? windMph,
    int? code,
    double? rainMm,
    double? uv,
    int? aqi,
    String? aqiScale,
    String? aqiCategory}) {
  final tags = <WeatherRoastTag>{};
  if (tempF != null && tempF >= 90) tags.add(WeatherRoastTag.hot);
  if (tempF != null && tempF <= 32) tags.add(WeatherRoastTag.cold);
  if (humidity != null && humidity >= 65 && tempF != null && tempF >= 75) {
    tags.add(WeatherRoastTag.humid);
  }
  if (humidity != null && humidity <= 30) tags.add(WeatherRoastTag.dry);
  if (windMph != null && windMph >= 20) tags.add(WeatherRoastTag.windy);
  if (uv != null && uv >= 7) tags.add(WeatherRoastTag.highUv);
  final badAir =
      (aqiScale == 'openweather_1_5' && aqi != null && aqi >= 4 && aqi <= 5) ||
          (aqiScale == 'us_epa' && aqi != null && aqi >= 151);
  if (badAir) tags.add(WeatherRoastTag.badAir);
  if (code == 800) tags.add(WeatherRoastTag.clear);
  if (code == 801) tags.add(WeatherRoastTag.partlyCloudy);
  if (code != null && code >= 802 && code <= 804) {
    tags.add(WeatherRoastTag.cloudy);
  }
  if ({200, 201, 202, 210, 211, 212, 221, 230, 231, 232}.contains(code)) {
    tags.add(WeatherRoastTag.storm);
  }
  if ({600, 601, 602, 615, 616, 620, 621, 622}.contains(code)) {
    tags.add(WeatherRoastTag.snow);
  }
  if ({701, 741}.contains(code)) tags.add(WeatherRoastTag.fog);
  const light = {200, 230, 231, 232, 300, 301, 310, 311, 313, 321, 500, 520};
  const heavy = {202, 314, 502, 503, 504, 522};
  // 501/521/531 are moderate/unspecified shower rain, not heavy by code alone.
  if (light.contains(code)) tags.add(WeatherRoastTag.lightRain);
  if (heavy.contains(code)) tags.add(WeatherRoastTag.heavyRain);
  // Last-hour accumulation says what fell during that interval, not what is
  // falling at the observation instant. Only condition codes set rain intensity.
  // Application-owned caution, not a fabricated official weather warning.
  if ({511, 611, 612, 613, 711, 762, 771, 781}.contains(code) ||
      badAir ||
      tags.contains(WeatherRoastTag.storm) ||
      (windMph != null && windMph >= 40) ||
      (tempF != null && (tempF >= 105 || tempF <= -10))) {
    tags.add(WeatherRoastTag.severe);
  }
  if (tags.any({
    WeatherRoastTag.lightRain,
    WeatherRoastTag.heavyRain,
    WeatherRoastTag.storm,
    WeatherRoastTag.snow,
    WeatherRoastTag.fog,
    WeatherRoastTag.windy,
    WeatherRoastTag.severe
  }.contains)) {
    tags.add(WeatherRoastTag.commuteRisk);
  }
  if (tags.any({
    WeatherRoastTag.humid,
    WeatherRoastTag.heavyRain,
    WeatherRoastTag.badAir,
    WeatherRoastTag.fog
  }.contains)) {
    tags.add(WeatherRoastTag.gross);
  }
  if (tempF != null &&
      tempF >= 60 &&
      tempF <= 82 &&
      code != null &&
      code >= 800 &&
      code <= 802 &&
      !tags.contains(WeatherRoastTag.commuteRisk) &&
      !tags.contains(WeatherRoastTag.gross)) {
    tags.add(WeatherRoastTag.nice);
  }
  return tags;
}
