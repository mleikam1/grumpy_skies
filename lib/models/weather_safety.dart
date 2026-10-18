import 'weather_models.dart';

typedef WeatherClock = DateTime Function();

enum WeatherSafetyStatus { unknown, stale, clear, activeAlert }

enum WeatherFreshness { fresh, stale, future, unavailable }

WeatherFreshness weatherFreshness(DateTime observedAt, DateTime now,
    {Duration maxAge = const Duration(minutes: 30)}) {
  if (observedAt.millisecondsSinceEpoch <= 0) {
    return WeatherFreshness.unavailable;
  }
  final age = now.difference(observedAt);
  if (age.isNegative) return WeatherFreshness.future;
  return age > maxAge ? WeatherFreshness.stale : WeatherFreshness.fresh;
}

/// A cleared alert list is trustworthy only with explicit, fresh provider
/// coverage for the selected location. Absence and fallback data are unknown.
WeatherSafetyStatus weatherSafetyStatus(WeatherBundle? weather, DateTime now) {
  if (weather == null) return WeatherSafetyStatus.unknown;
  if (weather.alerts.any((alert) => alert.isRelevantAt(now))) {
    return WeatherSafetyStatus.activeAlert;
  }
  if (weather.current.alertIds.isNotEmpty || !weather.alertCoverageVerified) {
    return WeatherSafetyStatus.unknown;
  }
  if (weather.isOfflineCache ||
      weather.alertsCheckedAt == null ||
      weatherFreshness(weather.current.displayUpdatedAt, now) !=
          WeatherFreshness.fresh ||
      weatherFreshness(weather.alertsCheckedAt!, now,
              maxAge: const Duration(minutes: 10)) !=
          WeatherFreshness.fresh) {
    return WeatherSafetyStatus.stale;
  }
  return WeatherSafetyStatus.clear;
}

/// Application-owned caution from provider facts; this is not an official alert.
bool weatherConditionsNeedAttention({
  int? code,
  int? tempF,
  double? windMph,
  int? aqi,
  String? aqiScale,
}) {
  final badAir =
      (aqiScale == 'openweather_1_5' && aqi != null && aqi >= 4 && aqi <= 5) ||
          (aqiScale == 'us_epa' && aqi != null && aqi >= 151);
  return {
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
        511,
        611,
        612,
        613,
        711,
        762,
        771,
        781
      }.contains(code) ||
      badAir ||
      (windMph != null && windMph.isFinite && windMph >= 40) ||
      (tempF != null && (tempF >= 105 || tempF <= -10));
}

bool weatherNeedsAttention(WeatherBundle weather, DateTime now) {
  final current = weather.current;
  return weatherSafetyStatus(weather, now) == WeatherSafetyStatus.activeAlert ||
      weatherConditionsNeedAttention(
        code: current.weatherId,
        tempF: current.temperatureKnown && current.temperatureF.isFinite
            ? current.temperatureF.round()
            : null,
        windMph: current.windKnown ? current.windMph : null,
        aqi: current.aqi,
        aqiScale: current.aqiScale,
      );
}
