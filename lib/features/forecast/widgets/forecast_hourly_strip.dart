import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastHourlyStrip extends StatelessWidget {
  const ForecastHourlyStrip({
    super.key,
    required this.hourly,
  });

  final List<HourlyForecast> hourly;

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
  });

  final HourlyForecast hour;
  final String label;

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
            Icon(
              _iconForCondition(hour.condition),
              color: DMColors.sunriseYellow,
              size: 30,
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

  static IconData _iconForCondition(String condition) {
    final normalized = condition.toLowerCase();
    if (normalized.contains('drizzle') || normalized.contains('rain')) {
      return Icons.grain_rounded;
    }
    if (normalized.contains('sun')) {
      return Icons.wb_sunny_rounded;
    }
    if (normalized.contains('cloud')) {
      return Icons.wb_cloudy_rounded;
    }
    return Icons.wb_twilight_rounded;
  }
}
