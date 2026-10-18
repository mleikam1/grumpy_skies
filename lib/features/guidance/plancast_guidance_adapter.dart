import 'package:timezone/timezone.dart' as tz;

import '../../models/weather_models.dart';
import '../../models/weather_time.dart';
import '../plancast/plancast_models.dart';
import 'domain/guidance.dart';

/// Immutable engine inputs derived from an already evaluated PlanCast event.
/// Calendar titles and addresses are not sent to selection or local history.
class PlanCastGuidanceInput {
  const PlanCastGuidanceInput({
    required this.eventId,
    required this.weather,
    required this.context,
    required this.signature,
  });

  final String eventId, signature;
  final WeatherEvidence weather;
  final GuidanceContext context;
}

/// No service boundary is available here. The caller supplies the event's
/// existing cache entry after checking its current resolved-venue key.
abstract final class PlanCastGuidanceAdapter {
  static PlanCastGuidanceInput? fromEventSnapshot({
    required PlanCastEventWeather item,
    required WeatherBundle? bundle,
    required DateTime now,
    DateTime? day,
    GuidanceSurface surface = GuidanceSurface.eventDetail,
  }) {
    final event = item.event;
    final resolved = item.resolvedLocation;
    final venue = item.venue;
    final assessment = item.assessment;
    if (item.isOnline ||
        item.environment == EventEnvironment.indoor ||
        // A daily probability/maximum cannot establish the weather during a
        // narrower appointment. The existing day-level assessment remains.
        (!event.isAllDay && assessment.isDaily) ||
        !assessment.usable ||
        bundle == null ||
        bundle.isOfflineCache ||
        resolved == null ||
        !resolved.hasWeatherBasis ||
        resolved.precision == LocationPrecision.unknown ||
        venue?.hasValidCoordinates != true ||
        resolved.candidate == null ||
        !_samePlace(venue!, resolved.candidate!) ||
        resolved.validUntil?.isAfter(now) == false ||
        assessment.validUntil?.isAfter(now) == false) {
      return null;
    }

    // The existing resolver permits an explicitly selected default area. An
    // observed-area assumption additionally needs actual non-expired evidence;
    // resolvedAt is not a new observation and cannot refresh that evidence.
    final observedArea = {
      LocationSource.currentArea,
      LocationSource.lastKnownArea,
    }.contains(resolved.source);
    if (observedArea &&
        (resolved.observedAt == null ||
            resolved.validUntil == null ||
            resolved.observedAt!.isAfter(now))) {
      return null;
    }

    final timeZone = item.venueTimeZone ?? bundle.current.timezone;
    DateTime start, end;
    if (event.isAllDay) {
      final first = event.allDayStart;
      final last = event.allDayEnd;
      if (first == null || last == null || !last.isAfter(first)) return null;
      final localNow = weatherLocalTime(now, timeZone, null, forecast: true);
      if (localNow is! tz.TZDateTime) return null;
      final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
      final selected = day ?? (today.isAfter(first) ? today : first);
      final civil = DateTime.utc(selected.year, selected.month, selected.day);
      if (civil.isBefore(first) || !civil.isBefore(last)) return null;
      // These are coverage bounds for a floating date, never appointment times.
      // IANA construction preserves 23/25-hour days across DST transitions.
      start =
          tz.TZDateTime(localNow.location, civil.year, civil.month, civil.day)
              .toUtc();
      end = tz.TZDateTime(
              localNow.location, civil.year, civil.month, civil.day + 1)
          .toUtc();
    } else {
      if (!event.hasDuration) return null;
      start = event.startUtc.toUtc();
      end = event.endUtc.toUtc();
      if (day != null &&
          event.startUtc.difference(event.endUtc).inHours.abs() > 24) {
        final local = weatherLocalTime(start, timeZone, null, forecast: true);
        if (local is! tz.TZDateTime) return null;
        final dayStart =
            tz.TZDateTime(local.location, day.year, day.month, day.day).toUtc();
        final dayEnd =
            tz.TZDateTime(local.location, day.year, day.month, day.day + 1)
                .toUtc();
        if (dayStart.isAfter(start)) start = dayStart;
        if (dayEnd.isBefore(end)) end = dayEnd;
      }
    }
    if (!end.isAfter(start) || !end.isAfter(now)) return null;

    final signature = planCastId([
      event.id,
      event.startUtc.toUtc(),
      event.endUtc.toUtc(),
      event.timeZone,
      event.isAllDay,
      start,
      end,
      item.environment.name,
      resolved.signature,
    ].join('|'));
    final location = GuidanceLocation(
      key:
          'point:${venue.lat.toStringAsFixed(5)},${venue.lon.toStringAsFixed(5)}',
      label: _locationLabel(resolved),
      latitude: venue.lat,
      longitude: venue.lon,
      precision: resolved.precision.name,
      assumed: resolved.areaAssumed,
      observedAt: resolved.observedAt,
      validUntil: resolved.validUntil,
      timezone: timeZone,
    );
    final context = GuidanceContext(
      surface: surface,
      location: location,
      activity: item.environment == EventEnvironment.outdoor
          ? GuidanceActivity.outdoorEvent
          : GuidanceActivity.outdoor,
      knownActivity: item.environment == EventEnvironment.outdoor,
      allDay: event.isAllDay,
      window: GuidanceInterval(start, end),
    );
    return PlanCastGuidanceInput(
      eventId: event.id,
      weather: GuidanceWeatherAdapter.fromBundle(bundle, location: location),
      context: context,
      signature: signature,
    );
  }

  static bool _samePlace(LocationCandidate a, LocationCandidate b) =>
      a.lat.toStringAsFixed(5) == b.lat.toStringAsFixed(5) &&
      a.lon.toStringAsFixed(5) == b.lon.toStringAsFixed(5);

  static String _locationLabel(ResolvedLocation resolved) {
    final label = switch (resolved.source) {
      LocationSource.currentArea => 'your current area',
      LocationSource.lastKnownArea => 'your last-known area',
      LocationSource.defaultArea => 'your selected PlanCast area',
      LocationSource.confirmedTrip => 'your confirmed trip area',
      _ => resolved.areaAssumed ? 'the event area' : 'the event location',
    };
    return label;
  }
}
