class Roast {
  final String id;
  final String personaId;
  final String text;
  final DateTime timestamp;
  final String type;

  const Roast({
    required this.id,
    required this.personaId,
    required this.text,
    required this.timestamp,
    required this.type,
  });
}

/// Generates a simple placeholder roast list for a persona.
List<Roast> placeholderRoastsForPersona(String personaId) {
  final now = DateTime.now();
  return [
    Roast(
      id: 'r1',
      personaId: personaId,
      text: "You're somehow managing to annoy the weather today.",
      timestamp: now,
      type: 'daily',
    ),
    Roast(
      id: 'r2',
      personaId: personaId,
      text: 'Even the clouds are rolling their eyes at you.',
      timestamp: now.add(const Duration(hours: 1)),
      type: 'hourly',
    ),
  ];
}
