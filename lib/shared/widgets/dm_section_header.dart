import 'package:flutter/material.dart';

import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import 'dm_buttons.dart';

class DmSectionHeader extends StatelessWidget {
  const DmSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.actionSemanticLabel,
  }) : assert(
          trailing == null || actionLabel == null,
          'Use either trailing or actionLabel, not both.',
        );

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? actionSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final action = trailing ??
        (actionLabel == null
            ? null
            : DmPillButton(
                label: actionLabel!,
                semanticLabel: actionSemanticLabel ?? actionLabel,
                variant: DmPillButtonVariant.glass,
                onPressed: onAction,
                padding: const EdgeInsets.symmetric(
                  horizontal: DMSpacing.md,
                  vertical: DMSpacing.xs,
                ),
              ));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.headingSmall,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: DMSpacing.xxs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: DMSpacing.md),
          action,
        ],
      ],
    );
  }
}
