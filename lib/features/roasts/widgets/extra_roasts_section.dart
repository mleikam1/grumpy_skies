import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../models/roast.dart';
import '../services/roast_engine.dart';

class ExtraRoastsSection extends StatelessWidget {
  final Persona persona;
  final RoastEngine roastEngine;

  const ExtraRoastsSection({
    super.key,
    required this.persona,
    required this.roastEngine,
  });

  @override
  Widget build(BuildContext context) {
    final moodRoast = roastEngine.generateMoodRoast(persona);
    final commuteRoast = roastEngine.generateCommuteRoast(persona);
    final weekendRoast = roastEngine.generateWeekendRoast(persona);
    final hourlyRoasts = roastEngine.generateHourlyRoasts(persona);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra Roasts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _RoastTile(title: 'Mood roast', roast: moodRoast),
          const SizedBox(height: 8),
          _RoastTile(title: 'Commute roast', roast: commuteRoast),
          const SizedBox(height: 8),
          _RoastTile(title: 'Weekend roast', roast: weekendRoast),
          const SizedBox(height: 12),
          Text(
            'Hourly roasts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...hourlyRoasts
              .map(
                (roast) => Card(
                  child: ListTile(
                    title: Text(roast.text),
                    subtitle: Text('Hourly'),
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

class _RoastTile extends StatelessWidget {
  final String title;
  final Roast roast;

  const _RoastTile({
    required this.title,
    required this.roast,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(roast.text),
      ),
    );
  }
}
