import 'package:flutter/material.dart';

import '../models/achievement.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final IconData icon;

  const AchievementBadge({
    super.key,
    required this.achievement,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor:
              unlocked ? colorScheme.primaryContainer : colorScheme.surfaceVariant,
          foregroundColor: unlocked ? colorScheme.primary : colorScheme.outline,
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          achievement.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: unlocked ? null : colorScheme.outline,
              ),
        ),
        Text(
          unlocked ? 'Unlocked' : 'Locked',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: unlocked ? colorScheme.primary : colorScheme.outline),
        ),
      ],
    );
  }
}
