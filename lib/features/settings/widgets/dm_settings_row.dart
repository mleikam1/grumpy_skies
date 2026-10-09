import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../design/dm_theme.dart';
import '../../../shared/widgets/dm_glass_card.dart';

class DmSettingsRow extends StatelessWidget {
  const DmSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.child,
    this.onTap,
    this.accentColor = DMColors.skyBlue,
    this.semanticLabel,
  }) : assert(icon != null || leading != null);

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;
  final Color accentColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading ??
                  _SettingsIcon(
                    icon: icon!,
                    color: accentColor,
                  ),
              const SizedBox(width: DMSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DMTypography.title
                          .copyWith(color: context.dmColors.textPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DMSpacing.xxs),
                      Text(
                        subtitle!,
                        style: DMTypography.bodySmall
                            .copyWith(color: context.dmColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: DMSpacing.md),
                trailing!,
              ],
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: DMSpacing.md),
            child!,
          ],
        ],
      ),
    );

    return DmGlassCard(
      gradient: null,
      color: context.dmColors.surface,
      borderColor: context.dmColors.border,
      shadows: context.dmColors.cardShadows,
      blurSigma: 0,
      onTap: onTap,
      semanticLabel: semanticLabel ?? title,
      padding: const EdgeInsets.all(DMSpacing.md),
      child: row,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.dmColors.surfaceSecondary,
        borderRadius: DMRadius.medium,
        border: Border.all(color: context.dmColors.border),
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(
          icon,
          color: context.dmColors.link,
          size: DMSpacing.iconLg,
        ),
      ),
    );
  }
}
