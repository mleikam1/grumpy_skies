import 'package:flutter/material.dart';

import '../../../shared/widgets/dm_asset_image.dart';
import '../models/achievement.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final IconData icon;
  final String? assetPath;

  const AchievementBadge({
    super.key,
    required this.achievement,
    required this.icon,
    this.assetPath,
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
          backgroundColor: unlocked
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          foregroundColor: unlocked ? colorScheme.primary : colorScheme.outline,
          child: DmAssetImage(
            // TODO(assets): Generated badge art should land at the
            // DmAssets.badges paths passed into this widget.
            assetPath: assetPath,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            placeholderBuilder: (_) => Icon(icon, size: 28),
          ),
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: unlocked ? colorScheme.primary : colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
