import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

import '../models/weather_models.dart';

class WeatherSummaryCard extends StatelessWidget {
  final WeatherBundle weather;

  const WeatherSummaryCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final current = weather.current;
    final iconData = _iconForCondition(current.condition);

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
                BoxedIcon(
                  iconData,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.temperatureC.toStringAsFixed(1)}°C',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 4),
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
                _infoTile('Feels like',
                    '${current.feelsLikeC.toStringAsFixed(1)}°C'),
                _infoTile('Wind', '${current.windKph.toStringAsFixed(1)} km/h'),
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

  IconData _iconForCondition(String condition) {
    final description = condition.toLowerCase();

    if (description.contains('storm') || description.contains('thunder')) {
      return WeatherIcons.thunderstorm;
    }
    if (description.contains('rain') || description.contains('drizzle')) {
      return WeatherIcons.rain;
    }
    if (description.contains('snow') || description.contains('sleet')) {
      return WeatherIcons.snow;
    }
    if (description.contains('fog') || description.contains('mist')) {
      return WeatherIcons.fog;
    }
    if (description.contains('cloud')) {
      return WeatherIcons.cloudy;
    }
    if (description.contains('sun') || description.contains('clear')) {
      return WeatherIcons.day_sunny;
    }

    return WeatherIcons.cloud;
  }
}
