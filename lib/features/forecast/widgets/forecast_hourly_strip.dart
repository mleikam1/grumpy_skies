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

class ForecastHourlyStrip extends StatelessWidget {
  const ForecastHourlyStrip({
    super.key,
    required this.hourly,
    this.sunrise,
    this.sunset,
    this.referenceTime,
    this.timezoneOffset,
    this.errorMessage,
  });

  final List<HourlyForecast> hourly;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? referenceTime;
  final int? timezoneOffset;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems(
      hourly,
      referenceTime ?? DateTime.now(),
      timezoneOffset,
    );
    final child = items.isEmpty
        ? _EmptyHourlyState(message: errorMessage)
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              return _HourlyTile(
                width:
                    ((MediaQuery.sizeOf(context).width - 56) / 5).clamp(60, 90),
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
        DmApprovedSectionHeader(
            title: 'Hourly forecast',
            onAction: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                        child: ListView(children: [
                      for (final item in items)
                        ListTile(
                            title: Text(item.label),
                            subtitle: Text(item.hour.condition),
                            trailing: Text(forecastTemperature(
                                item.hour.temperatureC,
                                forecastTemperatureUnit(context))))
                    ])))),
        SizedBox(
          height: 98 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
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
  const _EmptyHourlyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Center(
        child: Text(
          message ?? 'Hourly forecast unavailable',
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
    this.width = 66,
    this.sunrise,
    this.sunset,
  });

  final HourlyForecast hour;
  final String label;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DmGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
              style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: context.dmColors.textSecondary),
            ),
            const SizedBox(height: 6),
            DaymakerWeatherIcon(
              style: WeatherIconStyle.line,
              color:
                  hour.weatherId == 800 ? null : context.dmColors.textSecondary,
              conditionId: hour.weatherId,
              openWeatherIconCode: hour.weatherIcon,
              conditionMain: hour.weatherMain,
              conditionDescription: hour.condition,
              forecastTime: hour.time,
              sunrise: sunrise,
              sunset: sunset,
              size: 25,
              semanticLabel: hour.condition,
            ),
            const SizedBox(height: 4),
            Text(
              forecastTemperature(
                  hour.temperatureC, forecastTemperatureUnit(context)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18, height: 1.1, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: DMSpacing.xxs),
            Text(
              hour.precipitationChanceKnown && hour.precipitationChance > 0
                  ? '${hour.precipitationChance}%'
                  : '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: context.dmColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
