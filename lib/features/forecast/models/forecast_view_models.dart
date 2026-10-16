import 'package:timezone/timezone.dart' as tz;

import '../../../models/weather_models.dart';
import 'hourly_timeline.dart';

/// A civil date, independent of the phone's time zone and DST-length days.
DateTime forecastCalendarDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class DailyForecastItem {
  const DailyForecastItem({required this.forecast, required this.date});

  final DailyForecast forecast;
  final DateTime date;
  String get id => 'daily-${date.toIso8601String()}';

  /// Daily outlooks use the target location's noon, never today's solar times.
  DateTime noonInstant(String? timezone, int? timezoneOffset) {
    final local = forecastLocalTime(date, timezone, timezoneOffset);
    if (local is tz.TZDateTime) {
      return tz.TZDateTime(local.location, date.year, date.month, date.day, 12)
          .toUtc();
    }
    return date
        .add(const Duration(hours: 12))
        .subtract(Duration(seconds: timezoneOffset ?? 0));
  }
}

class DailyForecastWindow {
  const DailyForecastWindow({required this.items, required this.today});

  final List<DailyForecastItem> items;
  final DateTime today;

  int get coveredDays => items
      .where((item) => item.date.isBefore(today.add(const Duration(days: 7))))
      .length;
  bool get complete => coveredDays == 7;

  factory DailyForecastWindow.fromForecast(
    List<DailyForecast> daily, {
    required DateTime now,
    String? timezone,
    int? timezoneOffset,
    // Null keeps every returned future day in the expanded daily experience.
    int? horizonDays = 7,
  }) {
    final today =
        forecastCalendarDate(forecastLocalTime(now, timezone, timezoneOffset));
    final end =
        horizonDays == null ? null : today.add(Duration(days: horizonDays));
    final byDate = <DateTime, DailyForecastItem>{};
    for (final day in daily) {
      final date = forecastCalendarDate(day.date);
      if (date.isBefore(today) || (end != null && !date.isBefore(end))) {
        continue;
      }
      byDate.putIfAbsent(
          date, () => DailyForecastItem(forecast: day, date: date));
    }
    final items = byDate.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return DailyForecastWindow(items: List.unmodifiable(items), today: today);
  }
}

class HourlyForecastItem {
  const HourlyForecastItem({
    required this.forecast,
    required this.localTime,
    required this.isCurrentHour,
  });

  final HourlyForecast forecast;
  final DateTime localTime;
  final bool isCurrentHour;
  String get id => 'hourly-${forecast.time.toUtc().millisecondsSinceEpoch}';

  static List<HourlyForecastItem> fromForecast(
    List<HourlyForecast> hourly, {
    required DateTime now,
    String? timezone,
    int? timezoneOffset,
    int limit = 12,
  }) =>
      List.unmodifiable(forecastTimelineHours(hourly, now).take(limit).map(
            (hour) => HourlyForecastItem(
              forecast: hour,
              localTime: forecastLocalTime(hour.time, timezone, timezoneOffset),
              isCurrentHour: forecastIsCurrentHour(hour.time, now),
            ),
          ));
}
