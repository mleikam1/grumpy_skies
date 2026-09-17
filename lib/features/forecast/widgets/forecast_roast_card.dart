import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../features/roasts/models/roast_persona.dart';
import '../../../features/roasts/widgets/persona_avatar.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastRoastCard extends StatelessWidget {
  const ForecastRoastCard({
    super.key,
    required this.persona,
    required this.roast,
    required this.onNewRoast,
    required this.onShare,
    this.onShareToMeme,
    this.sourceLabel,
  });

  final Persona persona;
  final Roast roast;
  final VoidCallback onNewRoast;
  final VoidCallback onShare;
  final VoidCallback? onShareToMeme;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final personaConfig = RoastPersonas.byId(persona.id);

    return DmGlassCard(
      gradient: DMGradients.premiumCard,
      borderColor: DMColors.opacity(personaConfig.accentColor, 0.48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PersonaAvatar(
                persona: persona,
                size: 88,
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
                      child: _RoastBadge(
                        label: persona.title.toUpperCase(),
                        accentColor: personaConfig.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.lg),
          if (sourceLabel != null) ...[
            Text(sourceLabel!, style: DMTypography.labelSmall),
            const SizedBox(height: DMSpacing.xs),
          ],
          Text(
            roast.text,
            style: DMTypography.headingMedium.copyWith(height: 1.18),
          ),
          const SizedBox(height: DMSpacing.lg),
          Wrap(
            spacing: DMSpacing.sm,
            runSpacing: DMSpacing.sm,
            children: [
              if (onShareToMeme != null)
                DmPillButton(
                  label: 'Share to Meme',
                  semanticLabel: 'Make a meme with this exact displayed roast',
                  leading: const Icon(Icons.add_photo_alternate_outlined),
                  variant: DmPillButtonVariant.glass,
                  onPressed: onShareToMeme!,
                ),
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
  const _RoastBadge({
    required this.label,
    required this.accentColor,
  });

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.sm,
        vertical: DMSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: DMRadius.full,
        boxShadow: [
          BoxShadow(
            color: DMColors.opacity(accentColor, 0.26),
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
