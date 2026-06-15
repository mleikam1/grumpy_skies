import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/assets/dm_assets.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastRoastCard extends StatelessWidget {
  const ForecastRoastCard({
    super.key,
    required this.persona,
    required this.roast,
    required this.onNewRoast,
    required this.onShare,
  });

  final Persona persona;
  final Roast roast;
  final VoidCallback onNewRoast;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      gradient: DMGradients.premiumCard,
      borderColor: DMColors.opacity(DMColors.playfulPinkSoft, 0.48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DmAssetImage(
                assetPath: DmAssets.personas.karen,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                borderRadius: DMRadius.full,
                semanticLabel: 'Karen avatar',
                placeholderGradient: DMGradients.sunrise,
                placeholderIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(width: DMSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.headingSmall,
                    ),
                    const SizedBox(height: DMSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _RoastBadge(label: persona.title.toUpperCase()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.lg),
          Text(
            roast.text,
            style: DMTypography.headingMedium.copyWith(height: 1.18),
          ),
          const SizedBox(height: DMSpacing.lg),
          Wrap(
            spacing: DMSpacing.sm,
            runSpacing: DMSpacing.sm,
            children: [
              DmPillButton(
                label: 'New Roast',
                semanticLabel: 'Show a new weather roast',
                leading: const Icon(Icons.refresh_rounded),
                onPressed: onNewRoast,
              ),
              DmPillButton(
                label: 'Share',
                semanticLabel: 'Share current weather roast',
                leading: const Icon(Icons.ios_share_rounded),
                variant: DmPillButtonVariant.glass,
                onPressed: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoastBadge extends StatelessWidget {
  const _RoastBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.sm,
        vertical: DMSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: DMColors.playfulPink,
        borderRadius: DMRadius.full,
        boxShadow: [
          BoxShadow(
            color: DMColors.opacity(DMColors.playfulPink, 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DMTypography.labelSmall.copyWith(color: DMColors.deepNavy),
      ),
    );
  }
}
