import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';

class DmAchievementBadge extends StatelessWidget {
  const DmAchievementBadge({
    super.key,
    required this.label,
    required this.icon,
    this.unlocked = true,
    this.progressLabel,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final bool unlocked;
  final String? progressLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = unlocked ? DMColors.sunriseYellow : DMColors.slate;
    final foreground = unlocked ? DMColors.textPrimary : DMColors.textMuted;
    final status = progressLabel ?? (unlocked ? 'Unlocked' : 'Locked');

    return Semantics(
      container: true,
      label: semanticLabel ?? '$label achievement, $status',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 112,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked ? DMGradients.primaryAction : null,
                  color: unlocked ? null : DMColors.glass,
                  border: Border.all(
                    color: unlocked
                        ? DMColors.opacity(DMColors.sunriseYellow, 0.82)
                        : DMColors.glassBorder,
                  ),
                  boxShadow: unlocked ? DMShadows.sunGlow : DMShadows.none,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      color: unlocked ? DMColors.deepNavy : accent,
                      size: 28,
                    ),
                    if (!unlocked)
                      Positioned(
                        right: 7,
                        bottom: 7,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: DMColors.glassNavy,
                            shape: BoxShape.circle,
                            border: Border.all(color: DMColors.glassBorder),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: DMColors.textMuted,
                            size: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DMSpacing.xs),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: DMTypography.label.copyWith(color: foreground),
              ),
              const SizedBox(height: DMSpacing.xxs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DMSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: unlocked
                      ? DMColors.opacity(DMColors.mintGreen, 0.18)
                      : DMColors.opacity(DMColors.cloudWhite, 0.08),
                  borderRadius: DMRadius.full,
                  border: Border.all(
                    color: unlocked
                        ? DMColors.opacity(DMColors.mintGreen, 0.42)
                        : DMColors.outlineVariant,
                  ),
                ),
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: unlocked ? DMColors.mintSoft : DMColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
