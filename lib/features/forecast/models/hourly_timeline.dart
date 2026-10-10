import '../../../models/weather_models.dart';
import '../../roasts/content/roast_context_adapter.dart';

/// Provider instants are the identity. Repeated DST clock labels are not duplicates.
List<HourlyForecast> forecastTimelineHours(
    List<HourlyForecast> hours, DateTime now) {
  final unique = <int, HourlyForecast>{};
  for (final hour in hours) {
    if (hour.time.add(const Duration(hours: 1)).isAfter(now)) {
      unique.putIfAbsent(hour.time.toUtc().millisecondsSinceEpoch, () => hour);
    }
  }
  return unique.values.toList()..sort((a, b) => a.time.compareTo(b.time));
}

DateTime forecastLocalTime(DateTime time, String? timezone, int? offset) =>
    roastLocalTime(time, timezone, offset) ?? time.toUtc();

bool forecastIsCurrentHour(DateTime time, DateTime now) =>
    !now.isBefore(time) && now.isBefore(time.add(const Duration(hours: 1)));

String forecastHourLabel(DateTime time, String? timezone, int? offset) {
  final local = forecastLocalTime(time, timezone, offset);
  final minute =
      local.minute == 0 ? '' : ':${local.minute.toString().padLeft(2, '0')}';
  return '${local.hour % 12 == 0 ? 12 : local.hour % 12}$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}

String forecastDateKey(DateTime time, String? timezone, int? offset) {
  final local = forecastLocalTime(time, timezone, offset);
  return '${local.year}-${local.month}-${local.day}';
}

String forecastDateLabel(DateTime time, String? timezone, int? offset) {
  final local = forecastLocalTime(time, timezone, offset);
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${days[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}';
}

String forecastUtcOffset(DateTime time, String? timezone, int? offset) {
  final local = forecastLocalTime(time, timezone, offset);
  final wall = DateTime.utc(
      local.year, local.month, local.day, local.hour, local.minute);
  final minutes = wall.difference(time.toUtc()).inMinutes;
  final sign = minutes < 0 ? '−' : '+';
  final absolute = minutes.abs();
  return 'UTC$sign${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
}
