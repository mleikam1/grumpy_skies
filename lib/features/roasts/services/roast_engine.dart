import '../content/roast_selector.dart';
import '../content/weather_roast_models.dart';
import '../models/persona.dart';
import '../models/roast.dart';

class RoastEngine {
  const RoastEngine();

  Roast _legacy(Persona persona, RoastType type) {
    final selection = const RoastSelector().applicationSelection(
      WeatherRoastContext.unavailable(),
      normalizeRoastPersonaId(persona.id),
      type,
      reason: 'legacy_without_weather',
    );
    return Roast(
        id: selection.id,
        personaId: selection.persona,
        text: selection.renderedText,
        timestamp: selection.selectedAt ?? DateTime.now(),
        type: type.name);
  }

  Roast generateDailyRoast(Persona p) => _legacy(p, RoastType.today);
  Roast generateMorningRoast(Persona p) => _legacy(p, RoastType.mood);
  Roast generateAfternoonRoast(Persona p) => _legacy(p, RoastType.mood);
  Roast generateNightRoast(Persona p) => _legacy(p, RoastType.mood);
  Roast generateMoodRoast(Persona p) => _legacy(p, RoastType.mood);
  Roast generateCommuteRoast(Persona p) => _legacy(p, RoastType.commute);
  Roast generateWeekendRoast(Persona p) => _legacy(p, RoastType.weekend);
  List<Roast> generateHourlyRoasts(Persona p) => [_legacy(p, RoastType.hourly)];
}
