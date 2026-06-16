import '../../../shared/assets/dm_assets.dart';

class Persona {
  final String id;
  final String name;
  final String avatar;
  final int requiredXp;
  final List<String> roastTemplates;

  const Persona({
    required this.id,
    required this.name,
    required this.avatar,
    required this.requiredXp,
    required this.roastTemplates,
  });
}

/// Placeholder list of personas that can be expanded later.
final List<Persona> samplePersonas = [
  Persona(
    id: 'p1',
    name: 'Snarky Storm',
    avatar: DmAssets.personas.snarkyStorm,
    requiredXp: 0,
    roastTemplates: [
      "You're somehow managing to annoy the weather today.",
      'A drizzle of sarcasm is heading your way.',
    ],
  ),
  Persona(
    id: 'p2',
    name: 'Cloudy Cynic',
    avatar: DmAssets.personas.cloudyCynic,
    requiredXp: 100,
    roastTemplates: [
      'Even the clouds are rolling their eyes at you.',
      'Forecast says 90% chance of roasted ego.',
    ],
  ),
  Persona(
    id: 'p3',
    name: 'Sunny Sass',
    avatar: DmAssets.personas.sunnySass,
    requiredXp: 250,
    roastTemplates: [
      'So bright you might blind us with bad decisions.',
      'Sun is out, but your vibes are partly questionable.',
    ],
  ),
];
