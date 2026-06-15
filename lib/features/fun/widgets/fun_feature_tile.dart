import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/daymaker_components.dart';

class FunFeatureTile extends StatelessWidget {
  const FunFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionSemanticLabel,
    this.onAction,
    this.body,
    this.accentColor = DMColors.skyBlue,
    this.gradient,
    this.featured = false,
    this.minHeight,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final String? actionSemanticLabel;
  final VoidCallback? onAction;
  final Widget? body;
  final Color accentColor;
  final Gradient? gradient;
  final bool featured;
  final double? minHeight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        featured ? DMTypography.headingMedium : DMTypography.title;
    final tileMinHeight = minHeight ?? (featured ? 276.0 : 184.0);

    return DmGlassCard(
      padding: EdgeInsets.all(featured ? DMSpacing.xl : DMSpacing.lg),
      borderColor: DMColors.glassBorderStrong,
      gradient: gradient ?? DMGradients.glassNavy,
      semanticLabel: semanticLabel ?? title,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tileMinHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FunIconBadge(
              icon: icon,
              color: accentColor,
              featured: featured,
            ),
            const SizedBox(height: DMSpacing.md),
            Text(
              title,
              maxLines: featured ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: DMSpacing.xs),
              Text(
                subtitle!,
                maxLines: featured ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: featured ? DMTypography.bodyLarge : DMTypography.body,
              ),
            ],
            if (body != null) ...[
              SizedBox(height: featured ? DMSpacing.xl : DMSpacing.md),
              body!,
            ],
            if (actionLabel != null) ...[
              SizedBox(height: featured ? DMSpacing.xl : DMSpacing.lg),
              DmPillButton(
                label: actionLabel!,
                semanticLabel: actionSemanticLabel ?? actionLabel,
                onPressed: onAction,
                leading: Icon(_actionIconFor(icon)),
                variant: featured
                    ? DmPillButtonVariant.secondary
                    : DmPillButtonVariant.primary,
                expand: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _actionIconFor(IconData icon) {
    if (icon == Icons.poll_outlined) return Icons.how_to_vote_outlined;
    if (icon == Icons.cyclone_outlined) return Icons.rotate_right_rounded;
    if (icon == Icons.person_search_outlined) return Icons.badge_outlined;
    if (icon == Icons.image_outlined) return Icons.add_photo_alternate_outlined;
    return Icons.auto_awesome_rounded;
  }
}

class _FunIconBadge extends StatelessWidget {
  const _FunIconBadge({
    required this.icon,
    required this.color,
    required this.featured,
  });

  final IconData icon;
  final Color color;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final size = featured ? 64.0 : 50.0;
    final iconSize = featured ? 34.0 : 26.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(color, 0.92),
        borderRadius: featured ? DMRadius.large : DMRadius.medium,
        boxShadow: [
          BoxShadow(
            color: DMColors.opacity(color, 0.36),
            blurRadius: featured ? 32 : 22,
            spreadRadius: featured ? 2 : 1,
          ),
          ...DMShadows.soft,
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          icon,
          color: DMColors.deepNavy,
          size: iconSize,
        ),
      ),
    );
  }
}
