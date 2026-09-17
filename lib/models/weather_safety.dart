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
