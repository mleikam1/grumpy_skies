import 'plancast_models.dart';

/// Only two comparable, fresh venue forecasts can establish a change.
class ForecastChangeDetector {
  const ForecastChangeDetector();
  bool materiallyChanged(
      PlanCastEventWeather? prior, PlanCastEventWeather current, DateTime now) {
    if (prior == null ||
        prior.event.id != current.event.id ||
        prior.event.startUtc != current.event.startUtc ||
        prior.event.endUtc != current.event.endUtc ||
        prior.venue?.lat != current.venue?.lat ||
        prior.venue?.lon != current.venue?.lon ||
        current.venue == null ||
        prior.environment != current.environment ||
        !current.remindersEnabled ||
        current.environment == EventEnvironment.online ||
        !current.event.startUtc.isAfter(now) ||
        !current.assessment.materiallyAffected) {
      return false;
    }
    final before = prior.assessment;
    final after = current.assessment;
    if (before.coverage != ForecastCoverage.hourly ||
        after.coverage != ForecastCoverage.hourly ||
        before.forecastUpdatedAt == null ||
        after.forecastUpdatedAt == null ||
        !after.forecastUpdatedAt!.isAfter(before.forecastUpdatedAt!) ||
        before.validUntil == null ||
        after.validUntil == null ||
        now.isAfter(before.validUntil!) ||
        now.isAfter(after.validUntil!)) {
      return false;
    }
    if (after.impact.index > before.impact.index &&
        after.impact != WeatherImpact.unavailable) {
      return true;
    }
    final priorRain = before.peakPrecipitationChance;
    final nextRain = after.peakPrecipitationChance;
    if (priorRain != null && nextRain != null && nextRain - priorRain >= 30) {
      return true;
    }
    final priorWind = before.maxWindKph;
    final nextWind = after.maxWindKph;
    return priorWind != null &&
        nextWind != null &&
        nextWind >= 30 &&
        nextWind - priorWind >= 20;
  }
}
