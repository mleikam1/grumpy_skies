import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../features/roasts/models/roast_persona.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../../../shared/widgets/dm_roast_mood_badge.dart';
import '../../../shared/widgets/dm_roast_surface.dart';

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
    final colors = context.dmRoastColors;
    final mood = roast.resolvedMood;
    final title =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("${persona.name}'s take",
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary)),
      const SizedBox(height: 5),
      Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DmPersonaTitleBadge(
                label: RoastPersonas.byId(persona.id).badgeText,
                colors: colors),
            DmRoastMoodBadge(mood: mood, colors: colors),
          ]),
    ]);
    final quote = Text('“${roast.text}”',
        style: TextStyle(
            color: colors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -.4));
    final actions = LayoutBuilder(builder: (context, c) {
      final buttons = [
        DmApprovedAction(
            label: 'Another',
            icon: Icons.refresh,
            onPressed: onNewRoast,
            backgroundColor: colors.anotherSurface,
            foregroundColor: colors.anotherText,
            outlineColor: colors.anotherOutline),
        DmApprovedAction(
            label: 'Share',
            icon: Icons.ios_share_outlined,
            primary: true,
            backgroundColor: colors.shareSurface,
            foregroundColor: colors.shareText,
            onPressed: onShare),
      ];
      if (c.maxWidth < 200 || MediaQuery.textScalerOf(context).scale(13) > 18) {
        return Wrap(spacing: 6, runSpacing: 6, children: buttons);
      }
      return Row(children: [
        Expanded(child: buttons[0]),
        const SizedBox(width: 6),
        Expanded(child: buttons[1])
      ]);
    });
    final source = sourceLabel == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(sourceLabel!,
                style: TextStyle(fontSize: 10, color: colors.textSecondary)),
          );
    return DmRoastSurface(
      key: const ValueKey('today-persona-card'),
      colors: colors,
      padding: const EdgeInsets.fromLTRB(8, 14, 14, 12),
      child: LayoutBuilder(builder: (context, c) {
        final large =
            c.maxWidth < 285 || MediaQuery.textScalerOf(context).scale(14) > 19;
        if (large) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  DmPersonaPortrait(
                      personaId: persona.id,
                      mood: mood,
                      width: 96,
                      height: 126),
                  const SizedBox(width: 12),
                  Expanded(child: title),
                ]),
                const SizedBox(height: 10),
                source,
                quote,
                const SizedBox(height: 12),
                actions,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 30,
              child: DmPersonaPortrait(
                  personaId: persona.id, mood: mood, height: 175)),
          const SizedBox(width: 10),
          Expanded(
              flex: 70,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    source,
                    quote,
                    const SizedBox(height: 10),
                    actions,
                  ])),
        ]);
      }),
    );
  }
}
