import 'forecast_temperature.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../design/dm_theme.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastDailyGrid extends StatelessWidget {
  const ForecastDailyGrid({
    super.key,
    required this.daily,
    this.sunrise,
    this.sunset,
    this.referenceTime,
    this.timezoneOffset,
    this.errorMessage,
  });

  final List<DailyForecast> daily;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? referenceTime;
  final int? timezoneOffset;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays(
      daily,
      referenceTime ?? DateTime.now(),
      timezoneOffset,
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DmApprovedSectionHeader(
          title:
              days.isEmpty ? 'Daily forecast' : '${days.length}-day forecast',
          onAction: days.isEmpty
              ? null
              : () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                          child: ListView(children: [
                        for (final day in days)
                          ListTile(
                              title: Text(_dayLabel(
                                  day.date,
                                  referenceTime ?? DateTime.now(),
                                  timezoneOffset)),
                              subtitle: Text(day.condition),
                              trailing: Text(
                                  '${forecastTemperature(day.maxTempC, forecastTemperatureUnit(context))} / ${forecastTemperature(day.minTempC, forecastTemperatureUnit(context))}'))
                      ])))),
      if (days.isEmpty)
        _EmptyDailyState(message: errorMessage)
      else
        Container(
            decoration: BoxDecoration(
                color: context.dmColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.dmColors.border)),
            child: Column(children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.dmColors.divider),
                Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text(
                              _dayLabel(
                                  days[i].date,
                                  referenceTime ?? DateTime.now(),
                                  timezoneOffset),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600))),
                      Expanded(
                          flex: 3,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: DaymakerWeatherIcon(
                                  style: WeatherIconStyle.line,
                                  color: days[i].weatherId == 800
                                      ? null
                                      : context.dmColors.textSecondary,
                                  conditionId: days[i].weatherId,
                                  openWeatherIconCode: days[i].weatherIcon,
                                  conditionMain: days[i].weatherMain,
                                  conditionDescription: days[i].condition,
                                  forecastTime: DateTime(days[i].date.year,
                                      days[i].date.month, days[i].date.day, 12),
                                  size: 23,
                                  semanticLabel: days[i].condition))),
                      Expanded(
                          flex: 2,
                          child: Text(
                              forecastTemperature(days[i].maxTempC,
                                  forecastTemperatureUnit(context)),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800))),
                      Expanded(
                          flex: 2,
                          child: Text(
                              forecastTemperature(days[i].minTempC,
                                  forecastTemperatureUnit(context)),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.dmColors.textSecondary))),
                    ])),
              ],
            ])),
    ]);
  }

  static List<DailyForecast> _visibleDays(
    List<DailyForecast> daily,
    DateTime referenceTime,
    int? timezoneOffset,
  ) {
    final today = _forecastDate(referenceTime, timezoneOffset);
    final sorted = daily.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    return sorted
        .where((day) => !_calendarDate(day.date).isBefore(today))
        .take(7)
        .toList(growable: false);
  }

  static String _dayLabel(
    DateTime date,
    DateTime referenceTime,
    int? timezoneOffset,
  ) {
    final today = _forecastDate(referenceTime, timezoneOffset);
    final forecastDate = _calendarDate(date);
    final dayOffset = forecastDate.difference(today).inDays;
    if (dayOffset == 0) return 'Today';
    return _weekday(forecastDate);
  }

  static DateTime _forecastDate(DateTime time, int? timezoneOffset) {
    final local = timezoneOffset == null
        ? time.toLocal()
        : DateTime.fromMillisecondsSinceEpoch(
            time.toUtc().millisecondsSinceEpoch + timezoneOffset * 1000,
            isUtc: true,
          );
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _calendarDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _weekday(DateTime date) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return labels[date.weekday - 1];
  }
}

class _EmptyDailyState extends StatelessWidget {
  const _EmptyDailyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Center(
        child: Text(
          message ?? '7-day forecast unavailable',
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
