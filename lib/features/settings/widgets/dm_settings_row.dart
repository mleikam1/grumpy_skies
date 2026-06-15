import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DMSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: DMTypography.bodySmall,
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

    return DmDarkGlassCard(
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DMColors.opacity(color, 0.9),
            DMColors.opacity(DMColors.cloudWhite, 0.16),
          ],
        ),
        borderRadius: DMRadius.medium,
        border: Border.all(color: DMColors.opacity(DMColors.cloudWhite, 0.24)),
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(
          icon,
          color: DMColors.cloudWhite,
          size: DMSpacing.iconLg,
        ),
      ),
    );
  }
}
