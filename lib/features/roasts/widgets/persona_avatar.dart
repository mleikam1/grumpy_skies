import 'package:flutter/material.dart';

import '../../../design/dm_shadows.dart';
import '../../../design/dm_theme.dart';
import '../../../models/daymaker_models.dart';
import '../../../shared/widgets/dm_asset_image.dart';
import '../models/roast_persona.dart';

/// Shared portrait treatment for every surface that renders a roast persona.
///
/// Approved transparent portrait; the surrounding surface belongs to the theme.
class PersonaAvatar extends StatelessWidget {
  const PersonaAvatar({
    super.key,
    required this.persona,
    required this.size,
    this.showShadow = true,
  });

  final Persona persona;
  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final config = RoastPersonas.byId(persona.id);

    return Semantics(
      image: true,
      label: '${persona.name} persona portrait',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('persona-avatar-${persona.id}'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.dmColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: showShadow ? DMShadows.soft : DMShadows.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: DmAssetImage(
            assetPath: persona.avatarAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
            placeholderGradient: config.fallbackGradient,
            placeholderIcon: Icons.person_rounded,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
