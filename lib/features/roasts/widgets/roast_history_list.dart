import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../models/roast_persona.dart';
import 'persona_avatar.dart';

class RoastHistoryList extends StatelessWidget {
  const RoastHistoryList({
    super.key,
    required this.roasts,
    required this.personas,
    required this.onShareRoast,
  });

  final List<Roast> roasts;
  final List<Persona> personas;
  final ValueChanged<Roast> onShareRoast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DmSectionHeader(
          title: 'Roast history',
          subtitle: 'Recently served weather commentary.',
        ),
        const SizedBox(height: DMSpacing.sm),
        DmGlassCard(
          gradient: DMGradients.glassNavy,
          borderColor: DMColors.glassBorder,
          padding: EdgeInsets.zero,
          child: roasts.isEmpty
              ? const _EmptyHistory()
              : Column(
                  children: [
                    for (var index = 0; index < roasts.length; index++) ...[
                      _HistoryRow(
                        roast: roasts[index],
                        persona: _personaFor(roasts[index]),
                        onShare: () => onShareRoast(roasts[index]),
                      ),
                      if (index != roasts.length - 1)
                        const Divider(
                          height: 1,
                          color: DMColors.divider,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Persona _personaFor(Roast roast) {
    final normalizedRoastPersonaId =
        RoastPersonas.normalizeIdOrNull(roast.personaId);
    for (final persona in personas) {
      if (RoastPersonas.normalizeIdOrNull(persona.id) ==
          normalizedRoastPersonaId) {
        return persona;
      }
    }

    return const Persona(
      id: 'unknown',
      name: 'DayMaker',
      title: 'Weather Voice',
      avatarAsset: '',
      requiredXp: 0,
      unlocked: true,
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.roast,
    required this.persona,
    required this.onShare,
  });

  final Roast roast;
  final Persona persona;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DMSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonaAvatar(
            persona: persona,
            size: 48,
            showShadow: false,
          ),
          const SizedBox(width: DMSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatTimestamp(roast.createdAt)} - ${persona.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: DMColors.sunriseYellow,
                  ),
                ),
                const SizedBox(height: DMSpacing.xs),
                Text(
                  roast.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.body,
                ),
              ],
            ),
          ),
          const SizedBox(width: DMSpacing.xs),
          DmIconButton(
            icon: const Icon(Icons.ios_share_rounded),
            semanticLabel: 'Share roast from ${persona.name}',
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(DMSpacing.lg),
      child: Text(
        'No roast history yet.',
        style: DMTypography.body,
      ),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
  final minutes = timestamp.minute.toString().padLeft(2, '0');
  final suffix = timestamp.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minutes $suffix';
}
