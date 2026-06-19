import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_glass_card.dart';

class RadarHeaderCard extends StatelessWidget {
  const RadarHeaderCard({
    super.key,
    required this.locationName,
    required this.modeLabel,
    required this.timeLabel,
    required this.lastUpdatedLabel,
  });

  final String locationName;
  final String modeLabel;
  final String timeLabel;
  final String lastUpdatedLabel;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.lg),
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      semanticLabel: 'Radar, $locationName, $modeLabel, $timeLabel',
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: DMColors.skyBlue,
              borderRadius: DMRadius.large,
              boxShadow: [
                BoxShadow(
                  color: DMColors.opacity(DMColors.skyBlue, 0.34),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const SizedBox.square(
              dimension: 54,
              child: Icon(
                Icons.radar,
                color: DMColors.deepNavy,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: DMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Radar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.headingSmall,
                ),
                const SizedBox(height: DMSpacing.xxs),
                Text(
                  locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.body.copyWith(
                    color: DMColors.skyBlueSoft,
                  ),
                ),
                const SizedBox(height: DMSpacing.xs),
                Text(
                  timeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelLarge.copyWith(
                    color: DMColors.sunriseYellow,
                  ),
                ),
                const SizedBox(height: DMSpacing.xs),
                Wrap(
                  spacing: DMSpacing.xs,
                  runSpacing: DMSpacing.xxs,
                  children: [
                    _RadarBadge(label: modeLabel),
                    _RadarBadge(label: lastUpdatedLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarBadge extends StatelessWidget {
  const _RadarBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.cloudWhite, 0.08),
        borderRadius: DMRadius.full,
        border: Border.all(color: DMColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.sm,
          vertical: DMSpacing.xxs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
