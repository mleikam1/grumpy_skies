import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/daymaker_components.dart';

class RoastCooldownCard extends StatelessWidget {
  const RoastCooldownCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.opacity(DMColors.frostCyan, 0.42),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final icon = Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DMColors.opacity(DMColors.frostCyan, 0.14),
              borderRadius: DMRadius.large,
              border: Border.all(color: DMColors.glassBorder),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: DMColors.frostCyan,
            ),
          );
          const copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New roast coming soon',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.headingSmall,
              ),
              SizedBox(height: DMSpacing.xs),
              Text(
                'The forecast is cooling its jets.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.body,
              ),
            ],
          );
          const button = DmPillButton(
            label: 'Cooling down',
            leading: Icon(Icons.ac_unit_rounded),
            variant: DmPillButtonVariant.glass,
            onPressed: null,
          );

          if (wide) {
            return Row(
              children: [
                icon,
                const SizedBox(width: DMSpacing.md),
                const Expanded(child: copy),
                const SizedBox(width: DMSpacing.md),
                button,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(height: DMSpacing.md),
              copy,
              const SizedBox(height: DMSpacing.md),
              button,
            ],
          );
        },
      ),
    );
  }
}
