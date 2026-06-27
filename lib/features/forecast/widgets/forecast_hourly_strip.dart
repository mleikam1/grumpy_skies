import 'package:flutter/material.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastHourlyStrip extends StatelessWidget {
  const ForecastHourlyStrip({
    super.key,
    required this.hourly,
    this.sunrise,
    this.sunset,
    this.referenceTime,
    this.timezoneOffset,
  });

  final List<HourlyForecast> hourly;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? referenceTime;
  final int? timezoneOffset;

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems(
      hourly,
      referenceTime ?? DateTime.now(),
      timezoneOffset,
    );
    final child = items.isEmpty
        ? const _EmptyHourlyState()
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: DMSpacing.xs),
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: DMSpacing.sm),
            itemBuilder: (context, index) {
              return _HourlyTile(
                hour: items[index].hour,
                label: items[index].label,
                sunrise: sunrise,
                sunset: sunset,
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: 'Hourly'),
        const SizedBox(height: DMSpacing.sm),
        SizedBox(
          height: 168,
          child: child,
        ),
      ],
    );
  }

  static List<_HourlyForecastItem> _visibleItems(
    List<HourlyForecast> hourly,
    DateTime referenceTime,
    int? timezoneOffset,
  ) {
    final sorted = hourly.toList()
      ..sort((left, right) => left.time.compareTo(right.time));
    final thresholdUtc =
        referenceTime.toUtc().subtract(const Duration(minutes: 30));
    final visible = sorted
        .where((hour) => !hour.time.toUtc().isBefore(thresholdUtc))
        .take(12)
        .toList(growable: false);

    return [
      for (var index = 0; index < visible.length; index++)
        _HourlyForecastItem(
          hour: visible[index],
          label: index == 0 &&
                  _isSameLocalHour(
                    visible[index].time,
                    referenceTime,
                    timezoneOffset,
                  )
              ? 'Now'
              : _formatHour(visible[index].time, timezoneOffset),
        ),
    ];
  }

  static bool _isSameLocalHour(
    DateTime left,
    DateTime right,
    int? timezoneOffset,
  ) {
    final localLeft = _forecastClockTime(left, timezoneOffset);
    final localRight = _forecastClockTime(right, timezoneOffset);
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day &&
        localLeft.hour == localRight.hour;
  }

  static String _formatHour(DateTime time, int? timezoneOffset) {
    final local = _forecastClockTime(time, timezoneOffset);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour $suffix';
  }

  static DateTime _forecastClockTime(DateTime time, int? timezoneOffset) {
    if (timezoneOffset == null) return time.toLocal();
    return DateTime.fromMillisecondsSinceEpoch(
      time.toUtc().millisecondsSinceEpoch + timezoneOffset * 1000,
      isUtc: true,
    );
  }
}

class _EmptyHourlyState extends StatelessWidget {
  const _EmptyHourlyState();

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Center(
        child: Text(
          'Hourly forecast unavailable',
          textAlign: TextAlign.center,
          style: DMTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _HourlyForecastItem {
  const _HourlyForecastItem({
    required this.hour,
    required this.label,
  });

  final HourlyForecast hour;
  final String label;
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({
    required this.hour,
    required this.label,
    this.sunrise,
    this.sunset,
  });

  final HourlyForecast hour;
  final String label;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: DmGlassCard(
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
              style: DMTypography.label,
            ),
            const SizedBox(height: DMSpacing.sm),
            DaymakerWeatherIcon(
              conditionId: hour.weatherId,
              openWeatherIconCode: hour.weatherIcon,
              conditionMain: hour.weatherMain,
              conditionDescription: hour.condition,
              forecastTime: hour.time,
              sunrise: sunrise,
              sunset: sunset,
              size: 32,
              semanticLabel: hour.condition,
            ),
            const SizedBox(height: DMSpacing.xs),
            Text(
              '${hour.temperatureF.round()}°',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.numeral,
            ),
            const SizedBox(height: DMSpacing.xxs),
            Text(
              '${hour.precipitationChance}% rain',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
