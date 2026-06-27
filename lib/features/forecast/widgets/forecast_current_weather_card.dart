import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastCurrentWeatherCard extends StatelessWidget {
  const ForecastCurrentWeatherCard({
    super.key,
    required this.weather,
    required this.now,
  });

  final CurrentWeather weather;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather.condition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.title,
                    ),
                    const SizedBox(height: DMSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${weather.temperatureF.round()}°F',
                        style: DMTypography.weatherNumeral(fontSize: 80),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DMSpacing.sm),
              Container(
                width: DMSpacing.tapTarget,
                height: DMSpacing.tapTarget,
                decoration: BoxDecoration(
                  color: DMColors.sunriseYellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DMColors.opacity(DMColors.sunriseYellow, 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: DaymakerWeatherIcon(
                    conditionId: weather.weatherId,
                    openWeatherIconCode: weather.weatherIcon,
                    conditionMain: weather.weatherMain,
                    conditionDescription: weather.condition,
                    forecastTime: weather.lastUpdated,
                    sunrise: weather.sunrise,
                    sunset: weather.sunset,
                    size: 42,
                    semanticLabel: weather.condition,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.md),
          Wrap(
            spacing: DMSpacing.sm,
            runSpacing: DMSpacing.sm,
            children: [
              _WeatherFact(
                icon: Icons.device_thermostat_outlined,
                iconSlug: 'thermometer',
                label: 'Feels like',
                value: '${weather.feelsLikeF.round()}°',
              ),
              _WeatherFact(
                icon: Icons.air_rounded,
                iconSlug: 'wind',
                label: 'Wind',
                value: weather.windLabel,
              ),
              _WeatherFact(
                icon: Icons.water_drop_outlined,
                iconSlug: 'humidity',
                label: 'Humidity',
                value: '${weather.humidity}%',
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: DMSpacing.iconSm,
                color: DMColors.textMuted,
              ),
              const SizedBox(width: DMSpacing.xs),
              Flexible(
                child: Text(
                  _formatUpdated(weather.displayUpdatedAt, now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatUpdated(DateTime updatedAt, DateTime now) {
    final elapsed = now.difference(updatedAt);
    if (elapsed.inMinutes < 1) {
      return 'Last updated just now';
    }

    if (elapsed.inHours < 1) {
      final minutes = elapsed.inMinutes;
      return 'Last updated $minutes min ago';
    }

    final hours = elapsed.inHours;
    final label = hours == 1 ? 'hour' : 'hours';
    return 'Last updated $hours $label ago';
  }
}

class _WeatherFact extends StatelessWidget {
  const _WeatherFact({
    required this.icon,
    this.iconSlug,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String? iconSlug;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.sm,
        vertical: DMSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.cloudWhite, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DMColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconSlug == null)
            Icon(icon, size: DMSpacing.iconSm, color: DMColors.skyBlueSoft)
          else
            DaymakerWeatherIcon(
              iconSlug: iconSlug,
              size: DMSpacing.iconSm,
              semanticLabel: label,
              color: DMColors.skyBlueSoft,
            ),
          const SizedBox(width: DMSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
