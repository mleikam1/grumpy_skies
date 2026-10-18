import 'dart:convert';

import 'plancast_models.dart';

/// View scope is independent from the calendars imported by PlanCast.
enum PlanCastDayState {
  ready,
  loading,
  disconnected,
  noCalendars,
  empty,
  filteredEmpty,
  completed
}

/// A single immutable snapshot drives rows, counts, and the weather readout.
class PlanCastDaySummary {
  PlanCastDaySummary._({
    required this.day,
    required this.events,
    required this.state,
    required this.completedCount,
    required this.refreshing,
    required this.calendarIds,
    required this.signature,
  });

  factory PlanCastDaySummary.build({
    required DateTime day,
    required DateTime now,
    required Iterable<PlanCastEventWeather> events,
    required bool connected,
    required Set<String> selectedCalendarIds,
    bool loading = false,
    Set<String>? calendarFilter,
    Iterable<CalendarEvent> completedEvents = const [],
  }) {
    final date = DateTime(day.year, day.month, day.day);
    final selected = Set<String>.of(selectedCalendarIds);
    final scope = calendarFilter == null
        ? selected
        : selected.intersection(calendarFilter);
    final onDay = events
        .where((item) =>
            selected.contains(item.event.calendarId) &&
            occursOnDay(item.event, date))
        .toList();
    final remaining = onDay.where((item) => !_ended(item.event, now)).toList();
    final visible = remaining
        .where((item) => scope.contains(item.event.calendarId))
        .map((item) => _forDay(item, date))
        .toList()
      ..sort((a, b) {
        final time = a.event.startUtc.compareTo(b.event.startUtc);
        return time != 0 ? time : a.event.id.compareTo(b.event.id);
      });
    final completed = <String>{
      for (final item in onDay)
        if (scope.contains(item.event.calendarId) && _ended(item.event, now))
          item.event.id,
      for (final event in completedEvents)
        if (scope.contains(event.calendarId) &&
            occursOnDay(event, date) &&
            _ended(event, now))
          event.id,
    };
    final state = !connected
        ? PlanCastDayState.disconnected
        : selected.isEmpty
            ? PlanCastDayState.noCalendars
            : loading && visible.isEmpty && completed.isEmpty
                ? PlanCastDayState.loading
                : visible.isNotEmpty
                    ? PlanCastDayState.ready
                    : remaining.isNotEmpty || scope.isEmpty
                        ? PlanCastDayState.filteredEmpty
                        : completed.isNotEmpty
                            ? PlanCastDayState.completed
                            : PlanCastDayState.empty;
    final ids = scope.toList()..sort();
    return PlanCastDaySummary._(
        day: date,
        events: List.unmodifiable(visible),
        state: state,
        completedCount: completed.length,
        refreshing: loading,
        calendarIds: Set.unmodifiable(scope),
        signature: planCastId(jsonEncode([
          date.toIso8601String(),
          ids,
          state.name,
          completed.toList()..sort(),
          for (final item in visible) _eventSignature(item),
        ])));
  }

  final DateTime day;
  final List<PlanCastEventWeather> events;
  final PlanCastDayState state;
  final bool refreshing;
  final int completedCount;
  final Set<String> calendarIds;
  final String signature;
  int get planCount => events.length;
  int get weatherCount =>
      events.where((e) => !e.isOnline && e.assessment.usable).length;
  int get onlineCount => events.where((e) => e.isOnline).length;
  int get automaticCount =>
      events.where((e) => !e.isOnline && e.automaticLocation).length;
  int get needsLocationCount => events.where((e) => e.needsLocation).length;
  int get loadingCount => events
      .where((e) => e.assessment.coverage == ForecastCoverage.loading)
      .length;
  bool get hasSeriousWeather =>
      events.any((e) => !e.isOnline && e.assessment.serious);

  static bool occursOnDay(CalendarEvent event, DateTime day) {
    if (event.isAllDay) {
      final civil = DateTime.utc(day.year, day.month, day.day);
      return !civil.isBefore(event.allDayStart!) &&
          civil.isBefore(event.allDayEnd!);
    }
    return event.startUtc
            .isBefore(DateTime(day.year, day.month, day.day + 1).toUtc()) &&
        event.endUtc.isAfter(DateTime(day.year, day.month, day.day).toUtc());
  }

  static bool _ended(CalendarEvent event, DateTime now) {
    final local = now.toLocal();
    return event.isAllDay
        ? !event.allDayEnd!
            .isAfter(DateTime.utc(local.year, local.month, local.day))
        : !event.endUtc.isAfter(now);
  }

  /// Stay rows use the selected day's outlook, never the worst arrival weather
  /// carried over to every day. Detail views retain the original full snapshot.
  static PlanCastEventWeather _forDay(PlanCastEventWeather item, DateTime day) {
    if (item.assessment.segments.isEmpty) return item;
    final start = DateTime(day.year, day.month, day.day).toUtc();
    final end = DateTime(day.year, day.month, day.day + 1).toUtc();
    final segments = item.assessment.segments
        .where((s) => item.event.isAllDay
            ? s.startUtc.year == day.year &&
                s.startUtc.month == day.month &&
                s.startUtc.day == day.day
            : s.startUtc.isBefore(end) && s.endUtc.isAfter(start))
        .toList();
    final EventWeatherAssessment assessment;
    if (segments.isEmpty) {
      assessment = const EventWeatherAssessment(
          coverage: ForecastCoverage.unavailable,
          impact: WeatherImpact.unavailable,
          explanation:
              'No dated outlook is available for this part of the stay.');
    } else {
      final facts = segments.map((s) => s.assessment).toList();
      final usable = facts.where((a) => a.usable).toList();
      final base = facts.first;
      final sameCondition = facts.every((a) => a.condition == base.condition);
      final allUsable = usable.length == facts.length;
      final impact = usable.isEmpty
          ? WeatherImpact.unavailable
          : usable
              .map((a) => a.impact)
              .reduce((a, b) => a.index > b.index ? a : b);
      double? extreme(Iterable<double?> values, bool maximum) {
        final known =
            values.whereType<double>().where((v) => v.isFinite).toList();
        return known.isEmpty
            ? null
            : known
                .reduce((a, b) => maximum ? (a > b ? a : b) : (a < b ? a : b));
      }

      final pops = usable
          .map((a) => a.peakPrecipitationChance)
          .whereType<int>()
          .toList();
      assessment = EventWeatherAssessment(
          coverage:
              facts.length == 1 ? base.coverage : ForecastCoverage.partial,
          impact: impact,
          explanation: facts.length == 1
              ? base.explanation
              : 'Dated outlooks for this day; coverage can differ between stay segments.',
          advice:
              usable.where((a) => a.materiallyAffected).firstOrNull?.advice ??
                  base.advice,
          condition: sameCondition ? base.condition : 'Mixed conditions',
          weatherIcon: sameCondition ? base.weatherIcon : null,
          peakPrecipitationChance:
              pops.isEmpty ? null : pops.reduce((a, b) => a > b ? a : b),
          minTemperatureC: extreme(usable.map((a) => a.minTemperatureC), false),
          maxTemperatureC: extreme(usable.map((a) => a.maxTemperatureC), true),
          maxWindKph: extreme(usable.map((a) => a.maxWindKph), true),
          maxGustKph: extreme(usable.map((a) => a.maxGustKph), true),
          forecastUpdatedAt: base.forecastUpdatedAt,
          validUntil: base.validUntil,
          alerts: [for (final a in facts) ...a.alerts],
          uncertainties: [
            for (final a in facts) ...a.uncertainties,
            if (!allUsable) 'Some stay segments have no forecast.'
          ],
          dailyOnly: facts.every((a) => a.isDaily || !a.usable),
          segments: segments);
    }
    return PlanCastEventWeather(
        event: item.event,
        assessment: assessment,
        venue: item.venue,
        resolvedLocation: item.resolvedLocation,
        participation: item.participation,
        venueTimeZone: item.venueTimeZone,
        venueTimeZoneOffset: item.venueTimeZoneOffset,
        environment: item.environment,
        remindersEnabled: item.remindersEnabled);
  }

  static Object _eventSignature(PlanCastEventWeather e) => [
        e.event.id,
        e.event.nativeFingerprint,
        e.event.title,
        e.event.startUtc.toIso8601String(),
        e.event.endUtc.toIso8601String(),
        e.event.timeZone,
        e.event.allDayStart?.toIso8601String(),
        e.event.allDayEnd?.toIso8601String(),
        e.resolvedLocation?.signature,
        e.venue?.lat,
        e.venue?.lon,
        e.venue?.name,
        e.participation.name,
        e.environment.name,
        _assessmentSignature(e.assessment),
      ];
  static Object _assessmentSignature(EventWeatherAssessment a) => [
        a.coverage.name,
        a.impact.name,
        a.condition,
        a.weatherIcon,
        a.minTemperatureC,
        a.maxTemperatureC,
        a.peakPrecipitationChance,
        a.maxWindKph,
        a.maxGustKph,
        a.forecastUpdatedAt?.toIso8601String(),
        a.validUntil?.toIso8601String(),
        a.dailyOnly,
        a.explanation,
        a.advice,
        a.uncertainties,
        for (final alert in a.alerts)
          [
            alert.event,
            alert.start?.toIso8601String(),
            alert.end?.toIso8601String()
          ],
        for (final s in a.segments)
          [
            s.label,
            s.startUtc.toIso8601String(),
            s.endUtc.toIso8601String(),
            _assessmentSignature(s.assessment)
          ],
      ];
}

class PlanCastAgendaSummary {
  PlanCastAgendaSummary(
      {required this.start, required List<PlanCastDaySummary> days})
      : days = List.unmodifiable(days),
        endExclusive =
            DateTime(start.year, start.month, start.day + days.length),
        events = List.unmodifiable(_uniqueEvents(days));
  static List<PlanCastEventWeather> _uniqueEvents(
      List<PlanCastDaySummary> days) {
    final unique = <String, PlanCastEventWeather>{};
    for (final day in days) {
      for (final item in day.events) {
        final prior = unique[item.event.id];
        // Aggregate tiles must reflect any available outlook in the range.
        // Dated agenda rows keep their own daily projections separately.
        if (prior == null ||
            (!prior.assessment.usable && item.assessment.usable)) {
          unique[item.event.id] = item;
        }
      }
    }
    return unique.values.toList()
      ..sort((a, b) => a.event.startUtc.compareTo(b.event.startUtc));
  }

  final DateTime start, endExclusive;
  final List<PlanCastDaySummary> days;

  /// Existing opaque occurrence identity only: similar titles and calendar copies
  /// remain separate. A stay appearing on several days counts once in the range.
  final List<PlanCastEventWeather> events;
  int get planCount => events.length;
  int get weatherCount => events
      .where((e) =>
          !e.isOnline &&
          days.any((d) => d.events
              .any((v) => v.event.id == e.event.id && v.assessment.usable)))
      .length;
  int get onlineCount => events.where((e) => e.isOnline).length;
  int get automaticCount =>
      events.where((e) => !e.isOnline && e.automaticLocation).length;
  int get needsLocationCount => events.where((e) => e.needsLocation).length;
  int get loadingCount => events
      .where((e) => e.assessment.coverage == ForecastCoverage.loading)
      .length;
  int get completedCount =>
      days.fold(0, (count, d) => count + d.completedCount);
  bool get hasSeriousWeather => days.any((d) => d.hasSeriousWeather);
}
