import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_glass_card.dart';

class MemeToolCard extends StatelessWidget {
  const MemeToolCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      borderColor: DMColors.glassBorderStrong,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 116),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: DMColors.opacity(color, 0.2),
                borderRadius: DMRadius.medium,
                border: Border.all(color: DMColors.opacity(color, 0.44)),
              ),
              child: SizedBox.square(
                dimension: DMSpacing.tapTarget,
                child: Icon(
                  icon,
                  color: color,
                  size: DMSpacing.iconLg,
                ),
              ),
            ),
            const SizedBox(height: DMSpacing.sm),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
