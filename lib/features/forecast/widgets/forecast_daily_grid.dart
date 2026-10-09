import 'forecast_temperature.dart';
import 'forecast_sheet.dart';
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
              : () => showForecastSheet(context,
                      title: '${days.length}-day forecast',
                      subtitle: 'Daily conditions · High / Low',
                      children: [
                        for (var index = 0; index < days.length; index++) ...[
                          if (index > 0)
                            Divider(height: 1, color: context.dmColors.divider),
                          _DailyDetailRow(
                              day: days[index],
                              label: _dayLabel(
                                  days[index].date,
                                  referenceTime ?? DateTime.now(),
                                  timezoneOffset)),
                        ],
                      ])),
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
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text(
                              _dayLabel(
                                  days[i].date,
                                  referenceTime ?? DateTime.now(),
                                  timezoneOffset),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600))),
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
          style: DMTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DailyDetailRow extends StatelessWidget {
  const _DailyDetailRow({required this.day, required this.label});
  final DailyForecast day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final unit = forecastTemperatureUnit(context);
    final high = forecastTemperature(day.maxTempC, unit);
    final low = forecastTemperature(day.minTempC, unit);
    final colors = context.dmColors;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary))),
            const SizedBox(width: 12),
            Semantics(
                label: 'High $high, low $low',
                child: ExcludeSemantics(
                    child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: high,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary)),
                          TextSpan(
                              text: '  /  $low',
                              style: TextStyle(color: colors.textSecondary)),
                        ]),
                        style: const TextStyle(fontSize: 17, height: 1.2)))),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DaymakerWeatherIcon(
                style: WeatherIconStyle.line,
                color: day.weatherId == 800 ? null : colors.textSecondary,
                conditionId: day.weatherId,
                openWeatherIconCode: day.weatherIcon,
                conditionMain: day.weatherMain,
                conditionDescription: day.condition,
                forecastTime:
                    DateTime(day.date.year, day.date.month, day.date.day, 12),
                size: 28,
                semanticLabel: day.condition),
            const SizedBox(width: 12),
            Expanded(
                child: Text(day.condition,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colors.textSecondary))),
          ]),
          if (day.precipitationChanceKnown) ...[
            const SizedBox(height: 7),
            Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text('${day.precipitationChance}% precipitation',
                    style: TextStyle(
                        fontSize: 12, height: 1.3, color: colors.link))),
          ],
        ]));
  }
}
