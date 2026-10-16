import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/forecast/models/forecast_view_models.dart';
import 'package:grumpy_skies/models/weather_models.dart';

DailyForecast day(DateTime date) =>
    DailyForecast(date: date, minTempC: 10, maxTempC: 20, condition: 'Cloudy');

void main() {
  test('seven civil dates use the selected IANA location across DST', () {
    final now = DateTime.utc(2026, 11, 1, 4, 30); // October 31 in Chicago.
    final supplied = [
      for (var i = -1; i < 10; i++) day(DateTime(2026, 10, 31 + i)),
      day(DateTime(2026, 10, 31)),
    ].reversed.toList();
    final window = DailyForecastWindow.fromForecast(supplied,
        now: now, timezone: 'America/Chicago', timezoneOffset: -21600);
    expect(window.today, DateTime.utc(2026, 10, 31));
    expect(window.items, hasLength(7));
    expect(window.items.map((item) => item.date),
        List.generate(7, (i) => DateTime.utc(2026, 10, 31 + i)));
    expect(window.complete, isTrue);
    expect(window.items.first.noonInstant('America/Chicago', -21600),
        DateTime.utc(2026, 10, 31, 17));
    expect(window.items[1].noonInstant('America/Chicago', -18000),
        DateTime.utc(2026, 11, 1, 18));
    final details = DailyForecastWindow.fromForecast(supplied,
        now: now, timezone: 'America/Chicago', horizonDays: null);
    expect(details.items, hasLength(10));
    expect(details.coveredDays, 7);
  });

  test('missing dates stay missing rather than filling from day eight onward',
      () {
    final now = DateTime.utc(2026, 10, 15);
    final window = DailyForecastWindow.fromForecast([
      day(DateTime(2026, 10, 14)),
      day(DateTime(2026, 10, 15)),
      day(DateTime(2026, 10, 15)),
      day(DateTime(2026, 10, 17)),
      day(DateTime(2026, 10, 22)),
    ], now: now, timezone: 'UTC');
    expect(window.items.map((item) => item.date.day), [15, 17]);
    expect(window.coveredDays, 2);
    expect(window.complete, isFalse);
  });

  test(
      'hourly preview reuses absolute timeline sorting and preserves DST hours',
      () {
    final first = DateTime.utc(2026, 11, 1, 6);
    final hours = [
      for (var i = -1; i < 30; i++)
        HourlyForecast(
            time: first.add(Duration(hours: i)),
            temperatureC: 15,
            condition: 'Cloudy'),
      HourlyForecast(time: first, temperatureC: 15, condition: 'Cloudy'),
    ].reversed.toList();
    final items = HourlyForecastItem.fromForecast(hours,
        now: first.add(const Duration(minutes: 30)),
        timezone: 'America/Chicago');
    expect(items, hasLength(12));
    expect(items.first.isCurrentHour, isTrue);
    expect(items[1].isCurrentHour, isFalse);
    expect(items.first.localTime.hour, 1);
    expect(items[1].localTime.hour, 1);
    expect(items.map((item) => item.id).toSet(), hasLength(12));
    expect(items.last.forecast.time, first.add(const Duration(hours: 11)));
  });
}
