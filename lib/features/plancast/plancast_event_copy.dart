import 'package:intl/intl.dart';

import '../roasts/content/roast_context_adapter.dart';
import 'plancast_models.dart';

/// Shared factual context for the briefing and opt-in detailed reminders.
/// Calendar instants remain unchanged when an assumed weather area moves.
class PlanCastEventCopy {
  const PlanCastEventCopy._();

  static String interval(PlanCastEventWeather item) {
    final event = item.event;
    if (event.isAllDay) return 'All day';
    DateTime calendarTime(DateTime value) =>
        roastLocalTime(value, event.timeZone, null) ?? value.toLocal();
    final start = calendarTime(event.startUtc);
    final end = calendarTime(event.endUtc);
    final first = DateFormat.jm().format(start);
    if (!event.hasDuration) return '$first calendar time';
    final acrossDay = start.year != end.year ||
        start.month != end.month ||
        start.day != end.day;
    final last =
        '${acrossDay ? '${DateFormat.MMMd().format(end)} ' : ''}${DateFormat.jm().format(end)}';
    return '$first–$last calendar time';
  }

  /// Called only for in-app briefings or explicit detailed-notification opt-in.
  static String location(PlanCastEventWeather item,
      {bool privateLabels = false}) {
    final resolved = item.resolvedLocation;
    if (resolved == null || !resolved.hasWeatherBasis) return '';
    // Exact venues, addresses and raw calendar labels can reveal private event
    // details even when its title is hidden. Broad area context remains useful.
    if (privateLabels &&
        !{LocationPrecision.city, LocationPrecision.area}
            .contains(resolved.precision)) {
      return 'Using the event’s weather location${resolved.provisional ? '; provisional for this plan' : ''}.';
    }
    final name = resolved.displayLabel;
    String area(String prefix) =>
        name == 'Your area' ? prefix : '$prefix: $name';
    final text = resolved.areaAssumed
        ? switch (resolved.source) {
            LocationSource.currentArea => area('Using your area'),
            LocationSource.lastKnownArea => area('Using last known area'),
            LocationSource.defaultArea => area('Using your default area'),
            LocationSource.confirmedTrip => area('Using trip area'),
            _ => area('Using an assumed area'),
          }
        : '${resolved.sourceLabel}: $name${resolved.precision == LocationPrecision.city || resolved.precision == LocationPrecision.area ? ' area' : ''}';
    return '$text${resolved.provisional ? '; provisional for this plan' : ''}.';
  }

  static String weather(EventWeatherAssessment assessment) {
    if (assessment.segments.isNotEmpty) {
      final parts =
          assessment.segments.where((s) => s.assessment.usable).toList();
      return [
        assessment.explanation,
        for (final segment in parts.take(3))
          '${segment.label}: ${_weather(segment.assessment)}',
      ].join(' ');
    }
    return _weather(assessment);
  }

  static String _weather(EventWeatherAssessment assessment) {
    final condition = assessment.condition.trim();
    final hasCondition =
        condition.isNotEmpty && condition.toLowerCase() != 'unknown';
    final context = assessment.isDaily
        ? 'Broad day outlook; event-hour weather is unavailable.'
        : assessment.coverage == ForecastCoverage.partial
            ? 'Partial coverage of this event window.'
            : 'For this event window.';
    return [
      if (hasCondition) '$condition.',
      context,
      assessment.explanation,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }
}
