import '../../features/roasts/models/roast_mood.dart';
import '../../features/roasts/models/roast_persona.dart';

/// All paths are bundled assets, never remote URLs or user-controlled paths.
abstract final class PersonaEmotionAssets {
  static String path(String personaId, RoastMood mood) =>
      'assets/personas/${RoastPersonas.normalizeId(personaId)}/${mood.name}.png';

  static String legacyPortrait(String personaId) =>
      'assets/approved_v1/personas/${RoastPersonas.normalizeId(personaId)}_portrait.png';

  static List<String> fallbacks(String personaId, RoastMood? mood) => [
        if (mood != null) path(personaId, mood),
        if (mood != null && mood != RoastMood.neutral)
          path(personaId, RoastMood.neutral),
        legacyPortrait(personaId),
      ];
}
