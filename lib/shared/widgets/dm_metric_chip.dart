import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';

class DmMetricChip extends StatelessWidget {
  const DmMetricChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.leading,
    this.accentColor = DMColors.skyBlue,
    this.onTap,
    this.semanticLabel,
  }) : assert(icon != null || leading != null);

  final String label;
  final String value;
  final IconData? icon;
  final Widget? leading;
  final Color accentColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: DMGradients.glassNavy,
          borderRadius: DMRadius.large,
          border: Border.all(color: DMColors.glassBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DMSpacing.md,
            vertical: DMSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(color: accentColor, size: DMSpacing.iconMd),
                child: leading ?? Icon(icon),
              ),
              const SizedBox(width: DMSpacing.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.labelSmall,
                    ),
                    const SizedBox(height: DMSpacing.xxs),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget chip = content;
    if (onTap != null) {
      chip = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DMRadius.large,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticLabel ?? '$label, $value',
      child: ExcludeSemantics(child: chip),
    );
  }
}
