import 'package:flutter/material.dart';

import '../models/weather_models.dart';

class WeatherSummaryCard extends StatelessWidget {
  final WeatherBundle weather;

  const WeatherSummaryCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final current = weather.current;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
}
