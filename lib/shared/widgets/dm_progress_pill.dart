import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_motion.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';

class DmProgressPill extends StatelessWidget {
  const DmProgressPill({
    super.key,
    required this.value,
    required this.label,
    this.valueLabel,
    this.color = DMColors.mintGreen,
    this.semanticLabel,
  });

  final double value;
  final String label;
  final String? valueLabel;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0).toDouble();
    final visibleValue = valueLabel ?? '${(clampedValue * 100).round()}%';
    final duration = DMMotion.resolve(context, DMMotion.standard);

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
      child: ClipRRect(
        borderRadius: DMRadius.full,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DMColors.glass,
            borderRadius: DMRadius.full,
            border: Border.all(color: DMColors.glassBorder),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: duration,
                    curve: DMMotion.easeOut,
                    widthFactor: clampedValue,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DMColors.opacity(color, 0.72),
                        borderRadius: DMRadius.full,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DMSpacing.md,
                  vertical: DMSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DMTypography.labelLarge,
                      ),
                    ),
                    const SizedBox(width: DMSpacing.sm),
                    Text(
                      visibleValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.label.copyWith(
                        color: DMColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel ?? label,
      value: visibleValue,
      child: ExcludeSemantics(child: content),
    );
  }
}
