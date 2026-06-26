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
  });

  final List<HourlyForecast> hourly;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    final items = hourly.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: 'Hourly'),
        const SizedBox(height: DMSpacing.sm),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: DMSpacing.sm),
            itemBuilder: (context, index) {
              return _HourlyTile(
                hour: items[index],
                label: index == 0 ? 'Now' : _formatHour(items[index].time),
                sunrise: sunrise,
                sunset: sunset,
              );
            },
          ),
        ),
      ],
    );
  }

  static String _formatHour(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour $suffix';
  }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.label,
            ),
            const Spacer(),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.numeral,
            ),
            const SizedBox(height: DMSpacing.xxs),
            Text(
              '${hour.precipitationChance}% rain',
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
