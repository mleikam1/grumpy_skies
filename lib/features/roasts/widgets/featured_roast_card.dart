import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../models/roast_persona.dart';
import 'persona_avatar.dart';

class FeaturedRoastCard extends StatelessWidget {
  const FeaturedRoastCard({
    super.key,
    required this.persona,
    required this.roast,
    required this.weather,
    required this.onShare,
  });

  final Persona persona;
  final Roast roast;
  final WeatherSnapshot weather;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final personaConfig = RoastPersonas.byId(persona.id);

    return DmGlassCard(
      gradient: DMGradients.premiumCard,
      borderColor: DMColors.opacity(personaConfig.accentColor, 0.52),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 620;
          final avatarWidth = wide ? 248.0 : 136.0;
          final avatar = _FeaturedAvatar(
            persona: persona,
            width: avatarWidth,
          );
          final content = _FeaturedRoastContent(
            persona: persona,
            roast: roast,
            weather: weather,
            onShare: onShare,
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: DMSpacing.xl),
                Expanded(child: content),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(width: DMSpacing.md),
                  Expanded(
                    child: _PersonaTitle(persona: persona),
                  ),
                ],
              ),
              const SizedBox(height: DMSpacing.lg),
              _FeaturedRoastBody(
                roast: roast,
                weather: weather,
                onShare: onShare,
                shareSemanticLabel: 'Share featured roast from ${persona.name}',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeaturedAvatar extends StatelessWidget {
  const _FeaturedAvatar({
    required this.persona,
    required this.width,
  });

  final Persona persona;
  final double width;

  @override
  Widget build(BuildContext context) {
    return PersonaAvatar(
      persona: persona,
      size: width,
    );
  }
}

class _FeaturedRoastContent extends StatelessWidget {
  const _FeaturedRoastContent({
    required this.persona,
    required this.roast,
    required this.weather,
    required this.onShare,
  });

  final Persona persona;
  final Roast roast;
  final WeatherSnapshot weather;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PersonaTitle(persona: persona),
        const SizedBox(height: DMSpacing.lg),
        _FeaturedRoastBody(
          roast: roast,
          weather: weather,
          onShare: onShare,
          shareSemanticLabel: 'Share featured roast from ${persona.name}',
        ),
      ],
    );
  }
}

class _PersonaTitle extends StatelessWidget {
  const _PersonaTitle({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final personaConfig = RoastPersonas.byId(persona.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          persona.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.headingLarge,
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
    );
  }
}

class _FeaturedRoastBody extends StatelessWidget {
  const _FeaturedRoastBody({
    required this.roast,
    required this.weather,
    required this.onShare,
    required this.shareSemanticLabel,
  });

  final Roast roast;
  final WeatherSnapshot weather;
  final VoidCallback onShare;
  final String shareSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roast.text,
          style: DMTypography.headingMedium.copyWith(height: 1.18),
        ),
        const SizedBox(height: DMSpacing.lg),
        Wrap(
          spacing: DMSpacing.sm,
          runSpacing: DMSpacing.sm,
          children: [
            _MiniStat(
              icon: Icons.air_rounded,
              label: 'Wind',
              value: weather.windLabel,
              accentColor: DMColors.frostCyan,
            ),
            _MiniStat(
              icon: Icons.water_drop_outlined,
              label: 'Humidity',
              value: '${weather.humidityPercent}%',
              accentColor: DMColors.rainTeal,
            ),
          ],
        ),
        const SizedBox(height: DMSpacing.lg),
        DmPillButton(
          label: 'Share',
          semanticLabel: shareSemanticLabel,
          leading: const Icon(Icons.ios_share_rounded),
          variant: DmPillButtonVariant.secondary,
          onPressed: onShare,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.cloudWhite, 0.1),
        borderRadius: DMRadius.full,
        border: Border.all(color: DMColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.md,
          vertical: DMSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: DMSpacing.iconMd),
            const SizedBox(width: DMSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelSmall,
            ),
            const SizedBox(width: DMSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelLarge,
            ),
          ],
        ),
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
            color: DMColors.opacity(accentColor, 0.28),
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
