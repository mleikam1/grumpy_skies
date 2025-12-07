import '../models/persona.dart';
import '../models/roast.dart';

class RoastEngine {
  const RoastEngine();

  Roast _buildRoast(String type, Persona persona, String text) {
    return Roast(
      id: '${persona.id}-$type-${DateTime.now().millisecondsSinceEpoch}',
      personaId: persona.id,
      text: text,
      timestamp: DateTime.now(),
      type: type,
    );
  }

  Roast generateDailyRoast(Persona p) {
    return _buildRoast('daily', p, "You're somehow managing to annoy the weather today.");
  }

  Roast generateMorningRoast(Persona p) {
    return _buildRoast('morning', p, 'Rise and shine, or at least try to.');
  }

  Roast generateAfternoonRoast(Persona p) {
    return _buildRoast('afternoon', p, 'Afternoon check-in: still chaotic, still you.');
  }

  Roast generateNightRoast(Persona p) {
    return _buildRoast('night', p, 'The stars are judging you quietly.');
  }

  Roast generateMoodRoast(Persona p) {
    return _buildRoast('mood', p, 'Your mood is as predictable as a surprise drizzle.');
  }

  Roast generateCommuteRoast(Persona p) {
    return _buildRoast('commute', p, 'Traffic and your playlist both need help.');
  }

  Roast generateWeekendRoast(Persona p) {
    return _buildRoast('weekend', p, 'Weekend plans? The weather rolls its eyes.');
  }

  List<Roast> generateHourlyRoasts(Persona p) {
    return List.generate(3, (index) {
      return _buildRoast(
        'hourly',
        p,
        'Hourly update #${index + 1}: you and the clouds are in a mood.',
      );
    });
  }
}
