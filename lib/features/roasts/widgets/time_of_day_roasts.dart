import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../progression/services/xp_service.dart';
import '../models/persona.dart';
import '../services/roast_engine.dart';

class TimeOfDayRoasts extends StatelessWidget {
  final Persona persona;
  final RoastEngine roastEngine;
  final ValueChanged<String>? onViewed;

  const TimeOfDayRoasts({
    super.key,
    required this.persona,
    required this.roastEngine,
    this.onViewed,
  });

  @override
  Widget build(BuildContext context) {
    final xpState = context.watch<XpService>().state;
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
          _TimeRoastCard(
            title: 'Morning roast',
            text: morning.text,
            viewed: xpState.viewedMorning,
            onTap: () => onViewed?.call('morning'),
          ),
          _TimeRoastCard(
            title: 'Afternoon roast',
            text: afternoon.text,
            viewed: xpState.viewedAfternoon,
            onTap: () => onViewed?.call('afternoon'),
          ),
          _TimeRoastCard(
            title: 'Night roast',
            text: night.text,
            viewed: xpState.viewedNight,
            onTap: () => onViewed?.call('night'),
          ),
        ],
      ),
    );
  }
}

class _TimeRoastCard extends StatelessWidget {
  final String title;
  final String text;
  final bool viewed;
  final VoidCallback? onTap;

  const _TimeRoastCard({
    required this.title,
    required this.text,
    required this.viewed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Icon(
                    viewed ? Icons.check_circle : Icons.visibility,
                    color: viewed ? colorScheme.primary : colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
