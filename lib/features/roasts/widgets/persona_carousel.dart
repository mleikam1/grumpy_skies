import 'package:flutter/material.dart';

import '../../../shared/widgets/dm_asset_image.dart';
import '../models/persona.dart';

class PersonaCarousel extends StatelessWidget {
  final List<Persona> personas;
  final ValueChanged<Persona>? onPersonaSelected;

  const PersonaCarousel({
    super.key,
    required this.personas,
    this.onPersonaSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (context, index) {
          final persona = personas[index];
          final isLocked = persona.requiredXp > 0;
          return GestureDetector(
            onTap: isLocked ? null : () => onPersonaSelected?.call(persona),
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 64,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // TODO(assets): Add persona portraits at the
                            // DmAssets.personas paths used by this model.
                            DmAssetImage(
                              assetPath: persona.avatar,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(999),
                              semanticLabel: '${persona.name} avatar',
                              placeholderIcon: Icons.person_rounded,
                            ),
                            if (isLocked)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        persona.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (isLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Locked',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: personas.length,
      ),
    );
  }
}
