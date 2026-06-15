import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_asset_image.dart';

class AdvancedRoastPersona {
  const AdvancedRoastPersona({
    required this.name,
    required this.unlocked,
    this.avatarAsset,
    this.lockLabel,
    this.placeholderGradient = DMGradients.twilight,
    this.placeholderIcon = Icons.person_rounded,
  });

  final String name;
  final bool unlocked;
  final String? avatarAsset;
  final String? lockLabel;
  final Gradient placeholderGradient;
  final IconData placeholderIcon;
}

class AdvancedRoastPersonasRow extends StatelessWidget {
  const AdvancedRoastPersonasRow({
    super.key,
    required this.personas,
  });

  final List<AdvancedRoastPersona> personas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: DMSpacing.xs),
        itemCount: personas.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DMSpacing.sm),
        itemBuilder: (context, index) {
          return _AdvancedRoastPersonaTile(persona: personas[index]);
        },
      ),
    );
  }
}

class _AdvancedRoastPersonaTile extends StatelessWidget {
  const _AdvancedRoastPersonaTile({required this.persona});

  final AdvancedRoastPersona persona;

  @override
  Widget build(BuildContext context) {
    final foreground =
        persona.unlocked ? DMColors.textPrimary : DMColors.textMuted;
    final status =
        persona.unlocked ? 'Unlocked' : persona.lockLabel ?? 'Locked';

    return Semantics(
      container: true,
      label: '${persona.name}, $status',
      child: ExcludeSemantics(
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(DMSpacing.sm),
          decoration: BoxDecoration(
            gradient:
                persona.unlocked ? DMGradients.glass : DMGradients.glassNavy,
            borderRadius: DMRadius.card,
            border: Border.all(
              color: persona.unlocked
                  ? DMColors.glassBorderStrong
                  : DMColors.outlineVariant,
            ),
            boxShadow: persona.unlocked ? DMShadows.soft : DMShadows.none,
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          persona.unlocked ? DMGradients.primaryAction : null,
                      color: persona.unlocked ? null : DMColors.glass,
                    ),
                    child: DmAssetImage(
                      assetPath: persona.avatarAsset,
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                      borderRadius: DMRadius.full,
                      semanticLabel: '${persona.name} avatar',
                      placeholderGradient: persona.placeholderGradient,
                      placeholderIcon: persona.placeholderIcon,
                      color: persona.unlocked ? null : DMColors.textMuted,
                      colorBlendMode:
                          persona.unlocked ? null : BlendMode.modulate,
                    ),
                  ),
                  if (persona.unlocked)
                    const Positioned(
                      right: -4,
                      bottom: -2,
                      child: _StatusDot(
                        color: DMColors.mintGreen,
                        icon: Icons.check_rounded,
                      ),
                    )
                  else
                    const Positioned(
                      right: -4,
                      bottom: -2,
                      child: _StatusDot(
                        color: DMColors.surfaceRaised,
                        icon: Icons.lock_rounded,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DMSpacing.sm),
              Text(
                persona.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: DMTypography.labelLarge.copyWith(color: foreground),
              ),
              const SizedBox(height: DMSpacing.xxs),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: DMTypography.labelSmall.copyWith(
                  color: persona.unlocked
                      ? DMColors.mintSoft
                      : DMColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: DMColors.deepNavy, width: 2),
      ),
      child: Icon(
        icon,
        color: color == DMColors.mintGreen
            ? DMColors.deepNavy
            : DMColors.textMuted,
        size: 15,
      ),
    );
  }
}
