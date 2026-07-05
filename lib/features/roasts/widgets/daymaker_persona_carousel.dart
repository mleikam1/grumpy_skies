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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 900
            ? ((width - (DMSpacing.sm * 4)) / 5).clamp(176.0, 220.0)
            : width >= 600
                ? 264.0
                : 244.0;

        return SizedBox(
          height: 224,
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
                width: cardWidth,
                selected: persona.id == selectedPersonaId,
                onTap: () => onPersonaSelected(persona),
              );
            },
          ),
        );
      },
    );
  }
}

class _PersonaCarouselCard extends StatelessWidget {
  const _PersonaCarouselCard({
    required this.persona,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final double width;
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
      label: '${persona.name}, ${persona.title} persona',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DMRadius.card,
            onTap: onTap,
            child: AnimatedContainer(
              duration: motion,
              curve: DMMotion.easeOut,
              width: width,
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
                      _PersonaArtwork(persona: persona),
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

class _PersonaArtwork extends StatelessWidget {
  const _PersonaArtwork({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1774 / 887,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: DMRadius.medium,
          boxShadow: DMShadows.soft,
        ),
        child: DmAssetImage(
          assetPath: persona.avatarAsset,
          fit: BoxFit.cover,
          borderRadius: DMRadius.medium,
          semanticLabel: '${persona.name} persona card',
          placeholderGradient: _personaGradient(persona.id),
          placeholderIcon: Icons.person_rounded,
          placeholderBuilder: (context) => _PersonaArtworkFallback(
            persona: persona,
          ),
        ),
      ),
    );
  }
}

class _PersonaArtworkFallback extends StatelessWidget {
  const _PersonaArtworkFallback({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _personaGradient(persona.id),
        borderRadius: DMRadius.medium,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DMSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              persona.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DMTypography.labelLarge.copyWith(
                color: DMColors.deepNavy,
              ),
            ),
            const SizedBox(height: DMSpacing.xs),
            Text(
              persona.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DMTypography.labelSmall.copyWith(
                color: DMColors.deepNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Gradient _personaGradient(String personaId) {
  return switch (personaId) {
    'frat_bro' || 'frat-bro' => DMGradients.clearSky,
    'grandpa' => DMGradients.rain,
    'politician' => DMGradients.storm,
    'two_year_old' || 'two-year-old' || 'toddler' => DMGradients.heat,
    _ => DMGradients.sunrise,
  };
}
