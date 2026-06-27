import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastExtraMetrics extends StatelessWidget {
  const ForecastExtraMetrics({
    super.key,
    required this.weather,
  });

  final CurrentWeather weather;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricSpec(
        icon: Icons.wb_sunny_outlined,
        iconSlug: 'uv-index',
        label: 'UV',
        value: weather.uvLabel,
        color: DMColors.sunriseYellow,
      ),
      _MetricSpec(
        icon: Icons.opacity_rounded,
        iconSlug: 'humidity',
        label: 'Humidity',
        value: '${weather.humidity}%',
        color: DMColors.rainTeal,
      ),
      _MetricSpec(
        icon: Icons.compress_rounded,
        iconSlug: 'barometer',
        label: 'Pressure',
        value: weather.pressureLabel,
        color: DMColors.skyBlueSoft,
      ),
      _MetricSpec(
        icon: Icons.visibility_outlined,
        iconSlug: 'horizon',
        label: 'Visibility',
        value: weather.visibilityLabel,
        color: DMColors.frostCyan,
      ),
      _MetricSpec(
        icon: Icons.grain_rounded,
        iconSlug: 'raindrops',
        label: 'Last hour',
        value: weather.rainSnowLastHourLabel,
        color: DMColors.lavenderGlass,
      ),
      _MetricSpec(
        icon: Icons.wb_twilight_rounded,
        iconSlug: 'sunrise',
        label: 'Sunrise',
        value: _formatTime(weather.sunrise),
        color: DMColors.sunrisePeach,
      ),
      _MetricSpec(
        icon: Icons.nights_stay_outlined,
        iconSlug: 'sunset',
        label: 'Sunset',
        value: _formatTime(weather.sunset),
        color: DMColors.lavenderMist,
      ),
      _MetricSpec(
        icon: Icons.dark_mode_outlined,
        iconSlug: 'moonrise',
        label: 'Moonrise',
        value: _formatTime(weather.moonrise),
        color: DMColors.frostCyan,
      ),
      _MetricSpec(
        icon: Icons.bedtime_outlined,
        iconSlug: 'moonset',
        label: 'Moonset',
        value: _formatTime(weather.moonset),
        color: DMColors.skyBlueSoft,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: 'Details'),
        const SizedBox(height: DMSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = DMSpacing.sm;
            final width = constraints.maxWidth;
            final columns = width >= 760
                ? 3
                : width >= 480
                    ? 2
                    : 1;
            final itemWidth = (width - (gap * (columns - 1))) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: itemWidth,
                    child: DmMetricChip(
                      icon: metric.icon,
                      leading: DaymakerWeatherIcon(
                        iconSlug: metric.iconSlug,
                        size: DMSpacing.iconMd,
                        semanticLabel: metric.label,
                        color: metric.color,
                      ),
                      label: metric.label,
                      value: metric.value,
                      accentColor: metric.color,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _formatTime(DateTime time) {
    final hours = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minutes = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hours:$minutes $suffix';
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.icon,
    required this.iconSlug,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String iconSlug;
  final String label;
  final String value;
  final Color color;
}
