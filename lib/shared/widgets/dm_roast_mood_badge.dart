import 'package:flutter/material.dart';

import '../../design/dm_theme.dart';
import '../../features/roasts/models/roast_mood.dart';

class DmPersonaTitleBadge extends StatelessWidget {
  const DmPersonaTitleBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: context.dmColors.outlineVariant),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
                color: context.dmColors.textSecondary)),
      );
}

class DmRoastMoodBadge extends StatelessWidget {
  const DmRoastMoodBadge({super.key, required this.mood});
  final RoastMood mood;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Mood: ${mood.label}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: context.dmColors.surface.withValues(alpha: .7),
            border: Border.all(color: context.dmColors.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(mood.name.toUpperCase(),
              style: TextStyle(
                  color: context.dmColors.textPrimary,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4)),
        ),
      );
}
