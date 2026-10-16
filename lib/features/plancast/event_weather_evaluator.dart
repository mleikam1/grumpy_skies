import 'dart:math' as math;

import '../../models/weather_models.dart';
import '../roasts/content/roast_context_adapter.dart';
import 'plancast_models.dart';

/// Pure, deterministic evaluation. No geocoding, GPS, source-event mutations,
/// invented duration, current-observation substitution or probability averaging.
class EventWeatherEvaluator {
  const EventWeatherEvaluator({this.maximumAge = const Duration(hours: 6)});
  final Duration maximumAge;

  EventWeatherAssessment evaluate(
      {required CalendarEvent event,
      required WeatherBundle? weather,
      required DateTime now,
      EventEnvironment environment = EventEnvironment.unknown,
      int bufferMinutes = 30,
      bool hasLocation = true}) {
    if (environment == EventEnvironment.online) {
      return const EventWeatherAssessment(
          coverage: ForecastCoverage.online,
          impact: WeatherImpact.low,
          explanation: 'Online plan. No venue or travel weather lookup.',
          advice: 'Weather guidance is off for this online plan.');
    }
    if (!hasLocation) {
      return const EventWeatherAssessment(
          coverage: ForecastCoverage.needsLocation,
          impact: WeatherImpact.unavailable,
          explanation:
              'Choose or confirm a physical location to see weather for this plan.',
          advice: 'Add a venue, or mark this plan Online.');
    }
    if (weather == null) {
      return const EventWeatherAssessment(
          coverage: ForecastCoverage.unavailable,
          impact: WeatherImpact.unavailable,
          explanation:
              'Venue forecast unavailable. Try refreshing when connected.');
    }
    final updated =
        (weather.current.sourceUpdatedAt ?? weather.current.lastUpdated)
            .toUtc();
    final expiry = updated.add(maximumAge);
    if (weather.isOfflineCache ||
        now.isAfter(expiry) ||
        updated.isAfter(now.add(const Duration(minutes: 5)))) {
      return EventWeatherAssessment(
          coverage: ForecastCoverage.stale,
          impact: WeatherImpact.unavailable,
          explanation:
              'The venue forecast is stale or offline. Refresh before relying on it.',
          forecastUpdatedAt: updated,
          validUntil: expiry,
          uncertainties: const [
            'Weather may have changed since the last check.'
          ]);
    }
    if (!event.isAllDay && !event.hasDuration) {
      return EventWeatherAssessment(
          coverage: ForecastCoverage.unavailable,
          impact: WeatherImpact.unavailable,
          explanation:
              'This event has no usable duration. Its weather interval cannot be evaluated.',
          forecastUpdatedAt: updated,
          validUntil: expiry);
    }
    final result = event.isAllDay
        ? _daily(event, weather, updated, expiry)
        : _interval(event.startUtc, event.endUtc, weather, updated, expiry,
            environment);
    if (event.isAllDay || bufferMinutes <= 0 || !result.usable) return result;
    final buffer = Duration(minutes: bufferMinutes.clamp(0, 180));
    final arrival = _interval(event.startUtc.subtract(buffer), event.startUtc,
        weather, updated, expiry, EventEnvironment.outdoor,
        dailyFallback: false);
    final leaving = _interval(event.endUtc, event.endUtc.add(buffer), weather,
        updated, expiry, EventEnvironment.outdoor,
        dailyFallback: false);
    final indoor = environment == EventEnvironment.indoor;
    final bufferAssessments = [arrival, leaving].where((a) => a.usable).toList()
      ..sort((a, b) => b.impact.index.compareTo(a.impact.index));
    // An indoor activity is not classified as rained on because a shower falls
    // in the middle. Its guidance refers to the labeled arrival/leaving buffers.
    final guidance =
        indoor && result.alerts.isEmpty && bufferAssessments.isNotEmpty
            ? bufferAssessments.first
            : result;
    return EventWeatherAssessment(
        coverage: result.coverage,
        impact: guidance.impact,
        explanation: indoor
            ? 'Indoor activity. Arrival planning buffer: ${arrival.explanation} Leaving planning buffer: ${leaving.explanation}'
            : result.explanation,
        advice: guidance.advice,
        condition: result.condition,
        weatherIcon: result.weatherIcon,
        peakPrecipitationChance: result.peakPrecipitationChance,
        minTemperatureC: result.minTemperatureC,
        maxTemperatureC: result.maxTemperatureC,
        maxWindKph: result.maxWindKph,
        maxGustKph: result.maxGustKph,
        forecastUpdatedAt: updated,
        validUntil: expiry,
        alerts: result.alerts,
        uncertainties: result.uncertainties,
        arrival: arrival,
        leaving: leaving);
  }

  EventWeatherAssessment _interval(
      DateTime start,
      DateTime end,
      WeatherBundle weather,
      DateTime updated,
      DateTime expiry,
      EventEnvironment environment,
      {bool dailyFallback = true}) {
    final byInstant = <int, HourlyForecast>{};
    for (final hour in weather.hourly) {
      if (hour.time.isBefore(end) &&
          hour.time.add(const Duration(hours: 1)).isAfter(start)) {
        byInstant[hour.time.millisecondsSinceEpoch] = hour;
      }
    }
    final hours = byInstant.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (hours.isEmpty) {
      if (!dailyFallback) {
        return EventWeatherAssessment(
            coverage: ForecastCoverage.unavailable,
            impact: WeatherImpact.unavailable,
            explanation: 'No hourly forecast for this planning buffer.',
            forecastUpdatedAt: updated,
            validUntil: expiry);
      }
      return _daily(
          CalendarEvent(
              id: '',
              nativeId: '',
              calendarId: '',
              title: '',
              startUtc: start,
              endUtc: end,
              timeZone: weather.current.timezone ?? 'UTC'),
          weather,
          updated,
          expiry);
    }
    var coveredUntil = start;
    var complete = true;
    for (final hour in hours) {
      if (hour.time.isAfter(coveredUntil)) complete = false;
      final hourEnd = hour.time.add(const Duration(hours: 1));
      if (hourEnd.isAfter(coveredUntil)) coveredUntil = hourEnd;
    }
    complete = complete && !coveredUntil.isBefore(end);
    final probabilities = hours
        .where((h) => h.precipitationChanceKnown)
        .map((h) => h.precipitationChance)
        .toList();
    final temps = hours
        .where((h) => h.temperatureKnown && h.temperatureC.isFinite)
        .map((h) => h.temperatureC)
        .toList();
    // Timeline fields are optional. Never reuse current wind/feels-like for a future event.
    final points = weather.timeline
        .where((p) =>
            p.time.isBefore(end) &&
            p.time.add(const Duration(hours: 1)).isAfter(start))
        .toList();
    final wind = points
        .map((p) => p.windMph)
        .whereType<double>()
        .where((v) => v.isFinite)
        .map((v) => v * 1.609344)
        .toList();
    final feels = points
        .map((p) => p.feelsLikeF)
        .whereType<double>()
        .where((v) => v.isFinite)
        .map((v) => (v - 32) * 5 / 9)
        .toList();
    final peak = probabilities.isEmpty ? null : probabilities.reduce(math.max);
    final high = temps.isEmpty ? null : temps.reduce(math.max);
    final low = temps.isEmpty ? null : temps.reduce(math.min);
    final windPeak = wind.isEmpty ? null : wind.reduce(math.max);
    final effectiveHigh = feels.isEmpty ? high : feels.reduce(math.max);
    final effectiveLow = feels.isEmpty ? low : feels.reduce(math.min);
    final hazardous =
        hours.any((h) => _disruptiveCondition(h.condition, h.weatherId));
    final alerts = _alerts(weather, start, end);
    var impact = WeatherImpact.low;
    final reasons = <String>[];
    final actions = <String>[];
    if (peak != null && peak >= 40) {
      impact = WeatherImpact.watch;
      reasons.add('Peak hourly precipitation chance is $peak%.');
      actions.add('Bring an umbrella for arrival and leaving.');
    }
    if (windPeak != null && windPeak >= 30) {
      impact = WeatherImpact.watch;
      reasons.add('Wind could affect time outside.');
      actions.add('Secure loose items outside.');
    }
    if (effectiveHigh != null && effectiveHigh >= 32) {
      impact = WeatherImpact.watch;
      reasons.add('Hot conditions are forecast.');
      actions.add('Plan breaks from the heat.');
    }
    if (effectiveLow != null && effectiveLow <= 0) {
      impact = WeatherImpact.watch;
      reasons.add('Freezing conditions are forecast.');
      actions.add('Allow extra care on exposed surfaces.');
    }
    if (hazardous || (windPeak ?? 0) >= 55 || alerts.isNotEmpty) {
      impact = WeatherImpact.disruption;
      reasons.add(alerts.isNotEmpty
          ? 'An official alert overlaps this venue and event interval.'
          : 'Storms, icy weather or strong wind may disrupt outdoor plans.');
      actions.add(
          'Check the latest venue forecast and official guidance before leaving.');
    }
    if (environment == EventEnvironment.outdoor &&
        hours.any((h) => h.weatherIcon?.endsWith('n') == true)) {
      reasons.add('The provider places part of this event after dark.');
      actions.add('Check lighting for time outdoors.');
    }
    final uncertainty = <String>[
      if (hours.every((h) =>
          h.weatherIcon?.endsWith('d') != true &&
          h.weatherIcon?.endsWith('n') != true))
        'Daylight context is unavailable for this event; current-day sunrise is not reused for future dates.',
      if (!complete) 'Hourly coverage does not span the whole event.',
      if (probabilities.length < hours.length)
        'Some precipitation probabilities are unavailable.',
      if (temps.length < hours.length) 'Some temperatures are unavailable.',
      if (wind.length < hours.length)
        'Wind is not available for the full interval.',
      if (!weather.alertCoverageVerified)
        'Official alert coverage is not verified.',
      'Hourly data cannot give exact minute-by-minute precipitation timing.',
    ];
    if (temps.isEmpty &&
        probabilities.isEmpty &&
        hours.every((h) => _unknownCondition(h.condition)) &&
        wind.isEmpty) {
      impact = WeatherImpact.unavailable;
    }
    final conditionHour = hours
        .reduce((a, b) => _conditionWeight(b) > _conditionWeight(a) ? b : a);
    return EventWeatherAssessment(
        coverage: complete ? ForecastCoverage.hourly : ForecastCoverage.partial,
        impact: impact,
        explanation: [
          if (environment == EventEnvironment.indoor)
            'Indoor activity: this outlook concerns arrival and leaving, not rain inside.',
          if (reasons.isEmpty)
            (impact == WeatherImpact.unavailable
                ? 'Forecast values are unavailable for this interval.'
                : 'No material weather issue in the available hourly forecast.'),
          ...reasons,
          if (!complete) 'Only part of this event has hourly coverage.',
        ].join(' '),
        advice: actions.isEmpty
            ? 'Check again before leaving; forecasts can change.'
            : actions.toSet().join(' '),
        condition: conditionHour.condition,
        weatherIcon: conditionHour.weatherIcon,
        peakPrecipitationChance: peak,
        minTemperatureC: low,
        maxTemperatureC: high,
        maxWindKph: windPeak,
        forecastUpdatedAt: updated,
        validUntil: expiry,
        alerts: alerts,
        uncertainties: uncertainty);
  }

  EventWeatherAssessment _daily(CalendarEvent event, WeatherBundle weather,
      DateTime updated, DateTime expiry) {
    final zone = weather.current.timezone;
    final localStart = event.isAllDay
        ? event.allDayStart
        : roastLocalTime(event.startUtc, zone, null, forecast: true);
    final localEnd = event.isAllDay
        ? event.allDayEnd!.subtract(const Duration(days: 1))
        : roastLocalTime(
            event.endUtc.subtract(const Duration(microseconds: 1)), zone, null,
            forecast: true);
    if (localStart == null || localEnd == null) {
      return EventWeatherAssessment(
          coverage: ForecastCoverage.unavailable,
          impact: WeatherImpact.unavailable,
          explanation:
              'Venue time zone is unavailable; a day-level outlook cannot be matched reliably.',
          forecastUpdatedAt: updated,
          validUntil: expiry);
    }
    final first =
        DateTime.utc(localStart.year, localStart.month, localStart.day);
    final last = DateTime.utc(localEnd.year, localEnd.month, localEnd.day);
    // Backend daily dates are normalized civil dates, not UTC appointments.
    final dates = <DateTime, DailyForecast>{};
    for (final day in weather.daily) {
      final date = DateTime.utc(day.date.year, day.date.month, day.date.day);
      if (!date.isBefore(first) && !date.isAfter(last)) dates[date] = day;
    }
    if (dates.isEmpty) {
      final horizon = weather.daily
          .map((d) => DateTime.utc(d.date.year, d.date.month, d.date.day))
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      return EventWeatherAssessment(
          coverage: horizon != null && first.isAfter(horizon)
              ? ForecastCoverage.tooEarly
              : ForecastCoverage.unavailable,
          impact: WeatherImpact.unavailable,
          explanation: horizon != null && first.isAfter(horizon)
              ? 'Too early for a forecast.'
              : 'Forecast unavailable for this event date.',
          forecastUpdatedAt: updated,
          validUntil: expiry);
    }
    final days = dates.values.toList();
    final probabilities = days
        .where((d) => d.precipitationChanceKnown)
        .map((d) => d.precipitationChance)
        .toList();
    final temps = days
        .where((d) =>
            d.temperatureKnown && d.minTempC.isFinite && d.maxTempC.isFinite)
        .toList();
    final noValues = temps.isEmpty &&
        probabilities.isEmpty &&
        days.every((d) => _unknownCondition(d.condition));
    final peak = probabilities.isEmpty ? null : probabilities.reduce(math.max);
    final storm =
        days.any((d) => _disruptiveCondition(d.condition, d.weatherId));
    return EventWeatherAssessment(
        coverage: ForecastCoverage.daily,
        impact: noValues
            ? WeatherImpact.unavailable
            : storm
                ? WeatherImpact.disruption
                : (peak ?? 0) >= 40
                    ? WeatherImpact.watch
                    : WeatherImpact.low,
        explanation:
            'Day-level outlook only; event-hour weather is not available.${peak == null ? '' : ' Peak daily precipitation chance is $peak%.'}',
        advice: storm
            ? 'Check official guidance and the hourly forecast closer to the event.'
            : (peak ?? 0) >= 40
                ? 'Keep an umbrella available; check timing closer to the event.'
                : 'Check the hourly forecast closer to the event.',
        condition: days.first.condition,
        weatherIcon: days.first.weatherIcon,
        peakPrecipitationChance: peak,
        minTemperatureC: temps.isEmpty
            ? null
            : temps.map((d) => d.minTempC).reduce(math.min),
        maxTemperatureC: temps.isEmpty
            ? null
            : temps.map((d) => d.maxTempC).reduce(math.max),
        forecastUpdatedAt: updated,
        validUntil: expiry,
        uncertainties: [
          'A daily probability does not predict the probability during this event.',
          if (dates.length < last.difference(first).inDays + 1)
            'Some event dates are outside daily forecast coverage.',
          if (probabilities.length < days.length)
            'Some precipitation probabilities are unavailable.',
        ]);
  }

  static bool _disruptiveCondition(String condition, int? id) =>
      (id != null && (id >= 200 && id < 300 || id == 511)) ||
      RegExp(r'thunder|freezing rain|blizzard|tornado', caseSensitive: false)
          .hasMatch(condition);
  static bool _unknownCondition(String value) => [
        '',
        'unknown',
        'unavailable',
        'n/a'
      ].contains(value.trim().toLowerCase());
  static int _conditionWeight(HourlyForecast hour) =>
      _disruptiveCondition(hour.condition, hour.weatherId)
          ? 1000
          : hour.precipitationChanceKnown
              ? hour.precipitationChance
              : 0;
  static List<WeatherAlert> _alerts(
      WeatherBundle weather, DateTime start, DateTime end) {
    // The existing repository returns point-filtered venue alerts. Only verified
    // coverage and complete validity intervals can become official event alerts.
    if (!weather.alertCoverageVerified) return const [];
    return weather.alerts
        .where((a) =>
            a.start != null &&
            a.end != null &&
            a.start!.isBefore(end) &&
            a.end!.isAfter(start))
        .toList();
  }
}
