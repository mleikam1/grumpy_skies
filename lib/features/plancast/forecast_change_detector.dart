import 'plancast_models.dart';

/// Only two comparable, fresh event forecasts can establish a change.
class ForecastChangeDetector {
  const ForecastChangeDetector();
  bool materiallyChanged(
      PlanCastEventWeather? prior, PlanCastEventWeather current, DateTime now) {
    if (prior == null ||
        prior.event.id != current.event.id ||
        prior.event.startUtc != current.event.startUtc ||
        prior.event.endUtc != current.event.endUtc ||
        prior.event.timeZone != current.event.timeZone ||
        prior.event.isAllDay != current.event.isAllDay ||
        prior.event.allDayStart != current.event.allDayStart ||
        prior.event.allDayEnd != current.event.allDayEnd ||
        prior.venueTimeZone != current.venueTimeZone ||
        prior.venueTimeZoneOffset != current.venueTimeZoneOffset ||
        prior.participation != current.participation ||
        !_sameLocationEvidence(prior, current) ||
        prior.environment != current.environment ||
        !current.remindersEnabled ||
        current.isOnline ||
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

  bool _sameLocationEvidence(
      PlanCastEventWeather prior, PlanCastEventWeather current) {
    final before = prior.resolvedLocation;
    final after = current.resolvedLocation;
    final oldVenue = before?.candidate ?? prior.venue;
    final newVenue = after?.candidate ?? current.venue;
    if (newVenue == null ||
        oldVenue == null ||
        oldVenue.lat != newVenue.lat ||
        oldVenue.lon != newVenue.lon) {
      return false;
    }
    if (before == null || after == null) return before == null && after == null;
    // The full resolution signature includes observation freshness. A new
    // timestamp alone must not hide a genuine change in comparable weather.
    final observedArea = before.source == LocationSource.currentArea ||
        before.source == LocationSource.lastKnownArea;
    return before.hasWeatherBasis &&
        after.hasWeatherBasis &&
        before.source == after.source &&
        before.precision == after.precision &&
        before.evidenceQuality == after.evidenceQuality &&
        before.provider == after.provider &&
        before.provisional == after.provisional &&
        before.validFrom == after.validFrom &&
        (observedArea || before.validUntil == after.validUntil);
  }
}
