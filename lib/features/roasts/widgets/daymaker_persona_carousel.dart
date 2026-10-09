import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';

class DaymakerPersonaCarousel extends StatelessWidget {
  const DaymakerPersonaCarousel(
      {super.key,
      required this.personas,
      required this.selectedPersonaId,
      required this.onPersonaSelected});
  final List<Persona> personas;
  final String selectedPersonaId;
  final ValueChanged<Persona> onPersonaSelected;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
        final width = math.max(
            ((constraints.maxWidth - 24) / 5).clamp(60.0, 100.0), 60 * scale);
        final labelHeight = personas.map((persona) {
          final painter = TextPainter(
              text: TextSpan(
                  text: persona.name,
                  style: const TextStyle(
                      fontSize: 10, height: 1.2, fontFamily: 'DaymakerSans')),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context))
            ..layout(maxWidth: width);
          final height = painter.height;
          painter.dispose();
          return height;
        }).fold<double>(12, math.max);
        return SizedBox(
          height: 84 + labelHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: personas.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final persona = personas[index];
              final selected = persona.id == selectedPersonaId;
              return Semantics(
                button: true,
                selected: selected,
                label: '${persona.name}, ${persona.title} persona',
                child: ExcludeSemantics(
                    child: SizedBox(
                  key: ValueKey('persona-card-${persona.id}'),
                  width: width,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onPersonaSelected(persona),
                    child: Column(children: [
                      Container(
                        height: 74,
                        width: width,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: index == 0
                              ? context.dmColors.karenSurface
                              : context.dmColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: selected
                                  ? context.dmColors.focusRing
                                  : context.dmColors.border,
                              width: selected ? 2 : 1),
                        ),
                        child: DmPersonaPortrait(personaId: persona.id),
                      ),
                      const SizedBox(height: 6),
                      Text(persona.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w500,
                              color: selected
                                  ? context.dmColors.textPrimary
                                  : context.dmColors.textSecondary)),
                    ]),
                  ),
                )),
              );
            },
          ),
        );
      });
}
