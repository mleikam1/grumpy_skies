import 'dart:math';

import '../models/persona.dart';
import '../models/weather_models.dart';

class PersonaRoastService {
  final _random = Random();

  // TODO: Replace with JSON from cloud storage later.
  static const _karenHot = [
    "It's so hot even my complaints are sweating.",
    "Who approved this temperature? I want a refund."
  ];

  static const _fratBroCold = [
    "Bro, it's colder than my last DM.",
    "Bulk up, it's cutting season out there."
  ];

  String getRoast({
    required PersonaType persona,
    required WeatherBundle weather,
  }) {
    final temp = weather.current.temperatureC;
    final isHot = temp >= 27;
    final isCold = temp <= 5;

    List<String> candidates;

    switch (persona) {
      case PersonaType.karen:
        candidates = isHot
            ? _karenHot
            : ["Ugh, this weather is not what I ordered."];
        break;
      case PersonaType.fratBro:
        candidates = isCold
            ? _fratBroCold
            : ["Weather's mid, but we still vibin'."];
        break;
      case PersonaType.grandpa:
        candidates = [
          "Back in my day, weather respected us.",
          "I've seen worse, but this still stinks."
        ];
        break;
      case PersonaType.politician:
        candidates = [
          "We must address this forecast with decisive layers.",
          "I promise a brighter day... eventually."
        ];
        break;
      case PersonaType.toddler:
        candidates = [
          "Sky mad. Wear coat.",
          "Hot. No like. Juice please."
        ];
        break;
    }

    return candidates[_random.nextInt(candidates.length)];
  }
}
