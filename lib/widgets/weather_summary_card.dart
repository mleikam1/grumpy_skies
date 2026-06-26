import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weather_models.dart';
import '../models/temperature_unit.dart';
import '../services/settings_controller.dart';
import '../shared/widgets/daymaker_weather_icon.dart';

class WeatherSummaryCard extends StatelessWidget {
  final WeatherBundle weather;

  const WeatherSummaryCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final current = weather.current;
    final unit = settings.temperatureUnit;
    final tempString = _formatTemp(
      unit == TemperatureUnit.fahrenheit
          ? current.temperatureF
          : current.temperatureC,
      unit,
    );
    final feelsLikeString = _formatTemp(
      unit == TemperatureUnit.fahrenheit
          ? current.feelsLikeF
          : current.feelsLikeC,
      unit,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DaymakerWeatherIcon(
                  conditionId: current.weatherId,
                  openWeatherIconCode: current.weatherIcon,
                  conditionMain: current.weatherMain,
                  conditionDescription: current.condition,
                  forecastTime: current.lastUpdated,
                  sunrise: current.sunrise,
                  sunset: current.sunset,
                  size: 54,
                  semanticLabel: current.condition,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tempString,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 4),
                    if (current.locationName.isNotEmpty) ...[
                      Text(
                        current.locationName,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      current.condition,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoTile('Feels like', feelsLikeString),
                _infoTile('Wind', current.windLabel),
                _infoTile('Humidity', '${current.humidity}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatTemp(double temp, TemperatureUnit unit) {
    return '${temp.toStringAsFixed(0)}°${unit.suffix}';
  }
}
