import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastMetricChips extends StatelessWidget {
  const ForecastMetricChips({
    super.key,
    required this.weather,
  });

  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = DMSpacing.sm;
        final width = constraints.maxWidth;
        final columns = width >= 700
            ? 3
            : width >= 520
                ? 2
                : 1;
        final itemWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: itemWidth,
              child: DmMetricChip(
                icon: Icons.water_drop_outlined,
                label: 'Rain',
                value: '${weather.rainChancePercent}% rain',
                accentColor: DMColors.rainTeal,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: DmMetricChip(
                icon: Icons.air_rounded,
                label: 'AQI',
                value: weather.aqiLabel,
                accentColor: DMColors.mintGreen,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: DmMetricChip(
                icon: Icons.thermostat_outlined,
                label: 'Feels',
                value: '${weather.feelsLikeF}° Comfortable',
                accentColor: DMColors.sunriseYellow,
              ),
            ),
          ],
        );
      },
    );
  }
}
