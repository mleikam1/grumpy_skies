import 'package:flutter/material.dart';

import '../../roasts/content/roast_context_adapter.dart';
import '../plancast_models.dart';

String planCastTimestamp(BuildContext context, DateTime time) {
  final local = time.toLocal();
  return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${TimeOfDay.fromDateTime(local).format(context)}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String planCastDate(BuildContext context, DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now().toLocal();
  if (_sameDay(day, today)) return 'Today';
  if (_sameDay(day, DateTime(today.year, today.month, today.day + 1))) {
    return 'Tomorrow';
  }
  return MaterialLocalizations.of(context).formatMediumDate(day);
}

/// Formats existing instants; location choices never change appointment times.
String planCastEventTime(BuildContext context, CalendarEvent event,
    {DateTime? now, String? timeZone, bool deviceTime = false}) {
  final reference = now ?? DateTime.now();
  if (event.isAllDay) {
    final first = event.allDayStart!;
    final last = event.allDayEnd!.subtract(const Duration(days: 1));
    final start = planCastDate(context, first, now: reference.toLocal());
    return '$start${_sameDay(first, last) ? '' : ' – ${MaterialLocalizations.of(context).formatMediumDate(last)}'} · All day';
  }
  final zone = timeZone ?? event.timeZone;
  DateTime local(DateTime instant) => deviceTime
      ? instant.toLocal()
      : roastLocalTime(instant, zone, null) ?? instant.toLocal();
  final start = local(event.startUtc);
  final end = local(event.endUtc);
  String clock(DateTime value) => TimeOfDay.fromDateTime(value).format(context);
  final endDate = _sameDay(start, end)
      ? ''
      : '${planCastDate(context, end, now: local(reference))} · ';
  final range = event.hasDuration ? '–$endDate${clock(end)}' : '';
  return '${planCastDate(context, start, now: local(reference))} · ${clock(start)}$range';
}

bool planCastCalendarTimeDiffers(CalendarEvent event) {
  if (event.isAllDay) return false;
  final source = roastLocalTime(event.startUtc, event.timeZone, null);
  if (source == null) return false;
  final device = event.startUtc.toLocal();
  return !_sameDay(source, device) ||
      source.hour != device.hour ||
      source.minute != device.minute;
}
