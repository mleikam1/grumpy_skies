import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_glass_card.dart';

class RadarHeaderCard extends StatelessWidget {
  const RadarHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.lg),
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      semanticLabel:
          'Live Radar, San Francisco California, moderate storm moving in',
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
                  'Live Radar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.headingSmall,
                ),
                const SizedBox(height: DMSpacing.xxs),
                Text(
                  'San Francisco, CA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.body.copyWith(
                    color: DMColors.skyBlueSoft,
                  ),
                ),
                const SizedBox(height: DMSpacing.xs),
                Text(
                  'Moderate storm moving in',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelLarge.copyWith(
                    color: DMColors.sunriseYellow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
