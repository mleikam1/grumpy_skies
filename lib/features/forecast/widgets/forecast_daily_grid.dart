import 'package:flutter/material.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
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
  });

  final List<DailyForecast> daily;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? referenceTime;
  final int? timezoneOffset;

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays(
      daily,
      referenceTime ?? DateTime.now(),
      timezoneOffset,
    );
    final child = days.isEmpty
        ? const _EmptyDailyState()
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: DMSpacing.xs),
            clipBehavior: Clip.none,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: DMSpacing.sm),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 128,
                child: _DailyTile(
                  day: days[index],
                  label: _dayLabel(
                    days[index].date,
                    referenceTime ?? DateTime.now(),
                    timezoneOffset,
                  ),
                  sunrise: sunrise,
                  sunset: sunset,
                ),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: '7-day forecast'),
        const SizedBox(height: DMSpacing.sm),
        SizedBox(
          height: 184,
          child: child,
        ),
      ],
    );
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
    if (dayOffset == 1) return 'Tomorrow';
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
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return labels[date.weekday - 1];
  }
}

class _EmptyDailyState extends StatelessWidget {
  const _EmptyDailyState();

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Center(
        child: Text(
          '7-day forecast unavailable',
          textAlign: TextAlign.center,
          style: DMTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({
    required this.day,
    required this.label,
    this.sunrise,
    this.sunset,
  });

  final DailyForecast day;
  final String label;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.sm),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.labelLarge,
          ),
          const SizedBox(height: DMSpacing.sm),
          DaymakerWeatherIcon(
            conditionId: day.weatherId,
            openWeatherIconCode: day.weatherIcon,
            conditionMain: day.weatherMain,
            conditionDescription: day.condition,
            forecastTime:
                DateTime(day.date.year, day.date.month, day.date.day, 12),
            sunrise: sunrise,
            sunset: sunset,
            size: 30,
            semanticLabel: day.condition,
          ),
          const SizedBox(height: DMSpacing.xs),
          Text(
            '${day.maxTempF.round()}° / ${day.minTempF.round()}°',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.labelLarge,
          ),
          const SizedBox(height: DMSpacing.xxs),
          Text(
            day.condition,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
