import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../services/roast_engine.dart';

class TimeOfDayRoasts extends StatelessWidget {
  final Persona persona;
  final RoastEngine roastEngine;

  const TimeOfDayRoasts({
    super.key,
    required this.persona,
    required this.roastEngine,
  });

  @override
  Widget build(BuildContext context) {
    final morning = roastEngine.generateMorningRoast(persona);
    final afternoon = roastEngine.generateAfternoonRoast(persona);
    final night = roastEngine.generateNightRoast(persona);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time of Day Roasts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _TimeRoastCard(title: 'Morning roast', text: morning.text),
          _TimeRoastCard(title: 'Afternoon roast', text: afternoon.text),
          _TimeRoastCard(title: 'Night roast', text: night.text),
        ],
      ),
    );
  }
}

class _TimeRoastCard extends StatelessWidget {
  final String title;
  final String text;

  const _TimeRoastCard({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}
