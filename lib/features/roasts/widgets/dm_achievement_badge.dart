import '../../../design/dm_theme.dart';
import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_asset_image.dart';

class DmAchievementBadge extends StatelessWidget {
  const DmAchievementBadge({
    super.key,
    required this.label,
    required this.icon,
    this.unlocked = true,
    this.assetPath,
    this.progressLabel,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final bool unlocked;
  final String? assetPath;
  final String? progressLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = unlocked ? DMColors.sunriseYellow : DMColors.slate;
    final foreground =
        unlocked ? context.dmColors.textPrimary : context.dmColors.textMuted;
    final status = progressLabel ?? (unlocked ? 'Unlocked' : 'Locked');

    return Semantics(
      container: true,
      label: semanticLabel ?? '$label achievement, $status',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 124,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked ? DMGradients.primaryAction : null,
                  color: unlocked ? null : context.dmColors.glass,
                  border: Border.all(
                    color: unlocked
                        ? DMColors.opacity(DMColors.sunriseYellow, 0.82)
                        : context.dmColors.glassBorder,
                  ),
                  boxShadow: unlocked ? DMShadows.sunGlow : DMShadows.none,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // TODO(assets): Generated badge art should land at the
                    // DmAssets.badges paths passed into this widget.
                    Padding(
                      padding: const EdgeInsets.all(DMSpacing.xs),
                      child: DmAssetImage(
                        assetPath: assetPath,
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        placeholderBuilder: (_) => Icon(
                          icon,
                          color: unlocked ? DMColors.deepNavy : accent,
                          size: 28,
                        ),
                      ),
                    ),
                    if (!unlocked)
                      Positioned(
                        right: 7,
                        bottom: 7,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: context.dmColors.glassNavy,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: context.dmColors.glassBorder),
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            color: context.dmColors.textMuted,
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
                        : context.dmColors.outlineVariant,
                  ),
                ),
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: unlocked
                        ? DMColors.mintSoft
                        : context.dmColors.textMuted,
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
