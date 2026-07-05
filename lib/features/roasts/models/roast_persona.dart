import '../../../models/daymaker_models.dart' as daymaker;
import '../../../shared/assets/dm_assets.dart';

enum RoastPersonaId {
  karen,
  fratBro,
  twoYearOld,
  politician,
  grandpa;

  String get storageId => switch (this) {
        RoastPersonaId.karen => 'karen',
        RoastPersonaId.fratBro => 'frat_bro',
        RoastPersonaId.twoYearOld => 'two_year_old',
        RoastPersonaId.politician => 'politician',
        RoastPersonaId.grandpa => 'grandpa',
      };
}

class RoastPersona {
  const RoastPersona({
    required this.key,
    required this.displayName,
    required this.badgeText,
    required this.assetPath,
    required this.toneDescription,
    this.enabled = true,
  });

  final RoastPersonaId key;
  final String displayName;
  final String badgeText;
  final String assetPath;
  final String toneDescription;
  final bool enabled;

  String get id => key.storageId;

  daymaker.Persona toDayMakerPersona() {
    return daymaker.Persona(
      id: id,
      name: displayName,
      title: _titleCaseBadge(badgeText),
      avatarAsset: assetPath,
      requiredXp: 0,
      unlocked: enabled,
      toneDescription: toneDescription,
      enabled: enabled,
    );
  }
}

abstract final class RoastPersonas {
  static const defaultId = RoastPersonaId.karen;

  static final List<RoastPersona> all = List.unmodifiable([
    RoastPersona(
      key: RoastPersonaId.karen,
      displayName: 'Karen',
      badgeText: 'ROAST QUEEN',
      assetPath: DmAssets.personas.karenRoastQueen,
      toneDescription:
          'Smug, sassy, suburban, brutally observant, funny but not hateful.',
    ),
    RoastPersona(
      key: RoastPersonaId.fratBro,
      displayName: 'Frat Bro',
      badgeText: 'BAROMETER BRO',
      assetPath: DmAssets.personas.fratBroBarometerBro,
      toneDescription:
          'Overly confident hype-man energy with weather-as-party-report logic.',
    ),
    RoastPersona(
      key: RoastPersonaId.twoYearOld,
      displayName: '2-Year-Old',
      badgeText: 'TINY THUNDER',
      assetPath: DmAssets.personas.twoYearOldTinyThunder,
      toneDescription:
          'Chaotic toddler logic that stays adorable, impulsive, and non-cruel.',
    ),
    RoastPersona(
      key: RoastPersonaId.politician,
      displayName: 'Politician',
      badgeText: 'SPIN DOCTOR',
      assetPath: DmAssets.personas.politicianSpinDoctor,
      toneDescription:
          'Evasive, over-polished public-relations spin with absurd optimism.',
    ),
    RoastPersona(
      key: RoastPersonaId.grandpa,
      displayName: 'Grandpa',
      badgeText: 'CLOUD HISTORIAN',
      assetPath: DmAssets.personas.grandpaCloudHistorian,
      toneDescription:
          'Folksy, nostalgic old-school weather wisdom with gentle ribbing.',
    ),
  ]);

  static RoastPersona get defaultPersona => byId(defaultId.storageId);

  static List<String> get supportedIds =>
      all.map((persona) => persona.id).toList(growable: false);

  static List<daymaker.Persona> toDayMakerPersonas() {
    return all
        .where((persona) => persona.enabled)
        .map((persona) => persona.toDayMakerPersona())
        .toList(growable: false);
  }

  static RoastPersona byId(String? id) {
    return maybeById(id) ?? all.first;
  }

  static RoastPersona? maybeById(String? id) {
    final normalized = normalizeIdOrNull(id);
    if (normalized == null) return null;

    for (final persona in all) {
      if (persona.id == normalized) return persona;
    }

    return null;
  }

  static String normalizeId(String? id) {
    return normalizeIdOrNull(id) ?? defaultId.storageId;
  }

  static String? normalizeIdOrNull(String? id) {
    final raw = id?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw.replaceAll(RegExp(r'[\s-]+'), '_');
    return switch (normalized) {
      'karen' => RoastPersonaId.karen.storageId,
      'frat_bro' => RoastPersonaId.fratBro.storageId,
      'two_year_old' || 'toddler' => RoastPersonaId.twoYearOld.storageId,
      'politician' => RoastPersonaId.politician.storageId,
      'grandpa' || 'old_grandpa' => RoastPersonaId.grandpa.storageId,
      _ => null,
    };
  }
}

String _titleCaseBadge(String value) {
  return value
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
