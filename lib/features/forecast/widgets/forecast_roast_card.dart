import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../features/roasts/models/roast_persona.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';

class ForecastRoastCard extends StatelessWidget {
  const ForecastRoastCard(
      {super.key,
      required this.persona,
      required this.roast,
      required this.onNewRoast,
      required this.onShare,
      this.onShareToMeme,
      this.sourceLabel});
  final Persona persona;
  final Roast roast;
  final VoidCallback onNewRoast;
  final VoidCallback onShare;
  final VoidCallback? onShareToMeme;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.dmColors;
    return Container(
        key: const ValueKey('today-persona-card'),
        padding: const EdgeInsets.fromLTRB(0, 14, 12, 10),
        decoration: BoxDecoration(
            gradient: colors.karenGradient,
            borderRadius: BorderRadius.circular(22)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 30,
              child: DmPersonaPortrait(personaId: persona.id, height: 175)),
          const SizedBox(width: 10),
          Expanded(
              flex: 70,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text("${persona.name}'s take",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(RoastPersonas.byId(persona.id).badgeText,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: colors.textSecondary))
                              ])),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: colors.karenBorder)),
                              child: Text('FOR FUN',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textSecondary))),
                        ]),
                    const SizedBox(height: 16),
                    if (sourceLabel != null)
                      Text(sourceLabel!,
                          style: TextStyle(
                              fontSize: 10, color: colors.textSecondary)),
                    Text('“${roast.text}”',
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -.5)),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (context, c) {
                      final actions = [
                        DmApprovedAction(
                            label: 'Another',
                            icon: Icons.refresh,
                            onPressed: onNewRoast),
                        DmApprovedAction(
                            label: 'Share',
                            icon: Icons.ios_share_outlined,
                            primary: true,
                            onPressed: onShare)
                      ];
                      if (c.maxWidth < 200 ||
                          MediaQuery.textScalerOf(context).scale(13) > 18) {
                        return Wrap(
                            spacing: 6, runSpacing: 6, children: actions);
                      }
                      return Row(children: [
                        Expanded(child: actions[0]),
                        const SizedBox(width: 6),
                        Expanded(child: actions[1])
                      ]);
                    }),
                  ])),
        ]));
  }
}
