import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';

class RoastsBrandHeader extends StatelessWidget {
  const RoastsBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: DMSpacing.tapTarget,
              height: DMSpacing.tapTarget,
              decoration: const BoxDecoration(
                gradient: DMGradients.primaryAction,
                shape: BoxShape.circle,
                boxShadow: DMShadows.sunGlow,
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: DMColors.deepNavy,
              ),
            ),
            const SizedBox(width: DMSpacing.sm),
            Expanded(
              child: Text(
                'DayMaker',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelLarge.copyWith(
                  color: DMColors.sunriseYellow,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DMSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: DMRadius.large,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                DMColors.opacity(DMColors.playfulPink, 0.28),
                Colors.transparent,
              ],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(
              DMSpacing.md,
              DMSpacing.sm,
              DMSpacing.md,
              DMSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roasts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.brandDisplay,
                ),
                SizedBox(height: DMSpacing.xs),
                Text(
                  'Pick your weather personality.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
