import 'package:flutter/material.dart';

class StreakIndicator extends StatelessWidget {
  final int streakCount;

  const StreakIndicator({
    super.key,
    required this.streakCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.local_fire_department,
            color: colorScheme.error,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Streak',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '$streakCount days',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        )
      ],
    );
  }
}
