import 'plancast_models.dart';

/// Builds one bounded, replaceable local queue. Native adapters persist it;
/// no Dart timer is responsible for delivering a notice.
class PlanCastNotificationPlanner {
  const PlanCastNotificationPlanner();
  List<Map<String, dynamic>> plan(
      {required DateTime now,
      required DateTime calendarSyncedAt,
      required List<PlanCastEventWeather> events,
      required PlanCastPreferences preferences,
      Map<String, Set<String>> routineReservations = const {},
      Map<String, DateTime> forecastChanges = const {},
      int pendingBudget = 32}) {
    if (!preferences.notifications) return const [];
    final notices = <Map<String, dynamic>>[];
    final local = now.toLocal();
    final horizon = now.add(const Duration(days: 7));
    final routine = {
      for (final entry in routineReservations.entries)
        entry.key: {...entry.value}
    };
    final bundledAt = <DateTime>[];
    String dayKey(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    DateTime outsideQuiet(DateTime delivery) {
      final start = preferences.quietStartMinute;
      final end = preferences.quietEndMinute;
      final minute = delivery.hour * 60 + delivery.minute;
      if (start == end) return delivery;
      final quiet = start < end
          ? minute >= start && minute < end
          : minute >= start || minute < end;
      if (!quiet) return delivery;
      final nextDay = start > end && minute >= start ? 1 : 0;
      return DateTime(delivery.year, delivery.month, delivery.day + nextDay,
          end ~/ 60, end % 60);
    }

    DateTime expiryFor(DateTime at, PlanCastEventWeather? item, bool detailed) {
      final expiry = detailed
          ? item!.assessment.validUntil!
          : at.add(const Duration(hours: 2));
      return item != null && item.event.startUtc.isBefore(expiry)
          ? item.event.startUtc
          : expiry;
    }

    Map<String, dynamic> notice(
            String id, DateTime at, String body, String route,
            {PlanCastEventWeather? item, bool detailed = false}) =>
        {
          'id': id,
          'fireAtMs': at.toUtc().millisecondsSinceEpoch,
          'title': 'PlanCast',
          'body': body,
          'route': route,
          'detailed': detailed,
          'quietStartMinute': preferences.quietStartMinute,
          'quietEndMinute': preferences.quietEndMinute,
          'generatedAtMs': now.toUtc().millisecondsSinceEpoch,
          'calendarSyncedAtMs': calendarSyncedAt.toUtc().millisecondsSinceEpoch,
          'expiresAtMs':
              expiryFor(at, item, detailed).toUtc().millisecondsSinceEpoch,
          if (item?.assessment.forecastUpdatedAt != null)
            'forecastUpdatedAtMs': item!.assessment.forecastUpdatedAt!
                .toUtc()
                .millisecondsSinceEpoch,
          if (item != null) ...{
            'nativeCalendarId': item.event.calendarId,
            'nativeEventId': item.event.nativeId,
            if (item.event.nativeFingerprint != null)
              'nativeFingerprint': item.event.nativeFingerprint,
            'nativeStartMs': item.event.startUtc.millisecondsSinceEpoch
          },
        };
    // Fresh briefing text is never repeated tomorrow. A generic invitation is
    // useful without implying an unguaranteed delivery-time weather refresh.
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(local.year, local.month, local.day + offset);
      final morning = outsideQuiet(DateTime(day.year, day.month, day.day,
          preferences.morningMinute ~/ 60, preferences.morningMinute % 60));
      if (morning.isAfter(now) && morning.isBefore(horizon)) {
        notices.add(notice(
            planCastId('morning|${dayKey(day)}'),
            morning,
            'Your plans. The sky’s opinion. Open PlanCast to refresh your day.',
            '/plancast?day=${dayKey(day)}'));
      }
    }
    final sorted = [...events]
      ..sort((a, b) => a.event.startUtc.compareTo(b.event.startUtc));
    for (final item in sorted) {
      if (!item.remindersEnabled ||
          item.environment == EventEnvironment.online ||
          item.event.isAllDay ||
          !item.assessment.materiallyAffected ||
          !item.assessment.usable) {
        continue;
      }
      final candidates = <({String kind, DateTime at})>[
        if (forecastChanges[item.event.id] != null)
          (kind: 'change', at: forecastChanges[item.event.id]!.toLocal()),
        if (preferences.eventHeadsUp)
          (
            kind: 'event',
            at: item.event.startUtc
                .toLocal()
                .subtract(Duration(minutes: preferences.eventLeadMinutes))
          ),
        if (preferences.dayBefore)
          (
            kind: 'before',
            at: DateTime(
                item.event.startUtc.toLocal().year,
                item.event.startUtc.toLocal().month,
                item.event.startUtc.toLocal().day - 1,
                preferences.eveningMinute ~/ 60,
                preferences.eveningMinute % 60)
          ),
      ];
      for (final candidate in candidates) {
        final at = outsideQuiet(candidate.at);
        if (!at.isAfter(now) ||
            !at.isBefore(horizon) ||
            !at.isBefore(item.event.startUtc)) {
          continue;
        }
        final key = dayKey(at);
        final id = planCastId(
            '${candidate.kind}|${item.event.id}|${at.toUtc().millisecondsSinceEpoch}');
        final reserved = routine.putIfAbsent(key, () => <String>{});
        if (reserved.length >= 2 && !reserved.contains(id)) continue;
        if (bundledAt.any(
            (other) => other.difference(at).abs() < const Duration(hours: 1))) {
          continue;
        }
        reserved.add(id);
        bundledAt.add(at);
        final expiry = item.assessment.validUntil;
        final updated = item.assessment.forecastUpdatedAt;
        final detailed = preferences.detailedNotificationPreviews &&
            expiry != null &&
            updated != null &&
            !at.toUtc().isAfter(expiry) &&
            at.difference(calendarSyncedAt) <= const Duration(hours: 6) &&
            at.difference(now) <= const Duration(hours: 6) &&
            item.assessment.coverage == ForecastCoverage.hourly;
        final checked = updated?.toLocal();
        final body = detailed
            ? '${item.event.displayTitle}: ${item.assessment.impact.label}. ${item.assessment.advice} Last checked ${checked!.hour.toString().padLeft(2, '0')}:${checked.minute.toString().padLeft(2, '0')}.'
            : 'You have upcoming plans. Open PlanCast for the latest venue weather and calendar changes.';
        notices.add(notice(id, at, body, '/plancast?event=${item.event.id}',
            item: item, detailed: detailed));
      }
    }
    if (preferences.evening) {
      for (var offset = 0; offset < 7; offset++) {
        final day = DateTime(local.year, local.month, local.day + offset);
        final at = outsideQuiet(DateTime(day.year, day.month, day.day,
            preferences.eveningMinute ~/ 60, preferences.eveningMinute % 60));
        final key = dayKey(at);
        final id = planCastId('evening|$key');
        final reserved = routine.putIfAbsent(key, () => <String>{});
        if (!at.isAfter(now) ||
            !at.isBefore(horizon) ||
            (reserved.length >= 2 && !reserved.contains(id))) {
          continue;
        }
        reserved.add(id);
        notices.add(notice(
            id,
            at,
            'Take a look at tomorrow’s plans. Open PlanCast for a fresh outlook.',
            '/plancast?day=${dayKey(DateTime(day.year, day.month, day.day + 1))}'));
      }
    }
    // Quiet-hour shifts may put two morning invitations at the same instant.
    final deduped = <String, Map<String, dynamic>>{};
    for (final item in notices) {
      deduped['${item['fireAtMs']}|${item['body']}'] = item;
    }
    return (deduped.values.toList()
          ..sort(
              (a, b) => (a['fireAtMs'] as int).compareTo(b['fireAtMs'] as int)))
        .take(pendingBudget.clamp(0, 32))
        .toList();
  }
}
