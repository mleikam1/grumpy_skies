import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_motion.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class DaymakerPersonaCarousel extends StatelessWidget {
  const DaymakerPersonaCarousel({
    super.key,
    required this.personas,
    required this.selectedPersonaId,
    required this.onPersonaSelected,
  });

  final List<Persona> personas;
  final String selectedPersonaId;
  final ValueChanged<Persona> onPersonaSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: DMSpacing.xs),
        itemCount: personas.length,
        separatorBuilder: (context, index) => const SizedBox(
          width: DMSpacing.sm,
        ),
        itemBuilder: (context, index) {
          final persona = personas[index];
          return _PersonaCarouselCard(
            persona: persona,
            selected: persona.id == selectedPersonaId,
            onTap: () => onPersonaSelected(persona),
          );
        },
      ),
    );
  }
}

class _PersonaCarouselCard extends StatelessWidget {
  const _PersonaCarouselCard({
    required this.persona,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = DMMotion.resolve(context, DMMotion.standard);
    final borderColor =
        selected ? DMColors.sunriseYellow : DMColors.glassBorder;
    final foreground = selected ? DMColors.deepNavy : DMColors.textPrimary;
    final titleColor = selected ? DMColors.sunriseYellow : DMColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: '${persona.name}, ${persona.title}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DMRadius.card,
            onTap: onTap,
            child: AnimatedContainer(
              duration: motion,
              curve: DMMotion.easeOut,
              width: 156,
              padding: const EdgeInsets.all(DMSpacing.sm),
              decoration: BoxDecoration(
                gradient: selected ? DMGradients.glass : DMGradients.glassNavy,
                borderRadius: DMRadius.card,
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
                boxShadow: selected ? DMShadows.sunGlow : DMShadows.soft,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _PersonaAvatar(persona: persona, selected: selected),
                      const SizedBox(height: DMSpacing.sm),
                      Text(
                        persona.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: DMTypography.labelLarge.copyWith(
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: DMSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DMSpacing.xs,
                          vertical: DMSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? DMColors.sunriseYellow
                              : DMColors.opacity(DMColors.cloudWhite, 0.12),
                          borderRadius: DMRadius.full,
                          border: selected
                              ? null
                              : Border.all(color: DMColors.glassBorder),
                        ),
                        child: Text(
                          persona.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DMTypography.labelSmall.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: DMColors.sunriseYellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: DMColors.deepNavy,
                          size: DMSpacing.iconMd,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonaAvatar extends StatelessWidget {
  const _PersonaAvatar({
    required this.persona,
    required this.selected,
  });

  final Persona persona;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? DMGradients.primaryAction : null,
        color: selected ? null : DMColors.glass,
      ),
      child: DmAssetImage(
        assetPath: persona.avatarAsset,
        width: 74,
        height: 74,
        fit: BoxFit.cover,
        borderRadius: DMRadius.full,
        semanticLabel: '${persona.name} avatar',
        placeholderGradient: _personaGradient(persona.id),
        placeholderIcon: Icons.person_rounded,
      ),
    );
  }
}

Gradient _personaGradient(String personaId) {
  return switch (personaId) {
    'frat-bro' => DMGradients.clearSky,
    'grandpa' => DMGradients.rain,
    'politician' => DMGradients.storm,
    'two-year-old' => DMGradients.heat,
    _ => DMGradients.sunrise,
  };
}
