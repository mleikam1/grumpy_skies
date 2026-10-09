import 'forecast_temperature.dart';
import 'package:flutter/material.dart';
import '../../../design/dm_metric_colors.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastMetricChips extends StatelessWidget {
  const ForecastMetricChips(
      {super.key, required this.weather, this.rainAvailable = true});
  final WeatherSnapshot weather;
  final bool rainAvailable;

  @override
  Widget build(BuildContext context) {
    final category = weather.aqiCategory.trim();
    final aqiAvailable = weather.aqi > 0 ||
        (weather.aqi == 0 &&
            category.isNotEmpty &&
            !['live', 'not supplied', 'unavailable']
                .contains(category.toLowerCase()));
    final tiles = [
      DmMetricChip(
          icon: Icons.water_drop_outlined,
          label: 'Rain',
          value:
              rainAvailable ? '${weather.rainChancePercent}%' : 'Unavailable',
          available: rainAvailable,
          tone: DMMetricTone.water),
      DmMetricChip(
          icon: Icons.air_rounded,
          label: 'AQI',
          value: aqiAvailable ? '${weather.aqi}' : 'Unavailable',
          status: aqiAvailable ? category : null,
          available: aqiAvailable,
          tone: DMMetricTone.air),
      DmMetricChip(
          icon: Icons.thermostat_outlined,
          label: 'Feels like',
          value: forecastTemperature(
              weather.feelsLikeC, forecastTemperatureUnit(context)),
          tone: DMMetricTone.warm),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 330 * scale ? 3 : 1;
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final tile in tiles) SizedBox(width: width, child: tile),
      ]);
    });
  }
}
