import '../data/daymaker_sample_data.dart';
import '../features/roasts/models/roast_persona.dart';
import '../models/weather_models.dart';
import 'roast_repository.dart';

class FakeRoastRepository implements RoastRepository {
  const FakeRoastRepository();

  @override
  Future<List<Persona>> getPersonas() async {
    // TODO(integration): Keep generated persona artwork local, but source
    // persona availability, XP gates, and live roast copy from the app backend.
    return DayMakerSampleData.personas;
  }

  @override
  Future<Persona> getPersona(String id) async {
    final normalizedId = RoastPersonas.normalizeId(id);
    return DayMakerSampleData.personas.firstWhere(
      (persona) => persona.id == normalizedId,
      orElse: () => DayMakerSampleData.persona,
    );
  }

  @override
  Future<Roast> getDailyRoast({
    required String personaId,
    required String weatherSnapshotId,
  }) async {
    final normalizedPersonaId = RoastPersonas.normalizeId(personaId);
    return DayMakerSampleData.dailyRoasts.firstWhere(
      (roast) =>
          RoastPersonas.normalizeId(roast.personaId) == normalizedPersonaId &&
          roast.weatherSnapshotId == weatherSnapshotId,
      orElse: () => DayMakerSampleData.roast,
    );
  }

  @override
  Future<List<Roast>> getRoastHistory({String? personaId}) async {
    if (personaId == null) {
      return DayMakerSampleData.roastHistory;
    }

    final normalizedPersonaId = RoastPersonas.normalizeId(personaId);
    return DayMakerSampleData.roastHistory
        .where(
          (roast) =>
              RoastPersonas.normalizeId(roast.personaId) == normalizedPersonaId,
        )
        .toList(growable: false);
  }

  @override
  Future<List<Achievement>> getAchievements() async {
    return DayMakerSampleData.achievements;
  }

  @override
  Future<List<FunFeature>> getFunFeatures() async {
    return DayMakerSampleData.funFeatures;
  }

  @override
  Future<List<MemeTemplate>> getMemeTemplates() async {
    // TODO(integration): Replace sample templates with backend-managed
    // share/export templates once the meme pipeline is connected.
    return DayMakerSampleData.memeTemplates;
  }
}
