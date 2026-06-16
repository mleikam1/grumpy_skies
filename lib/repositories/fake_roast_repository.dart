import '../data/daymaker_sample_data.dart';
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
    return DayMakerSampleData.personas.firstWhere(
      (persona) => persona.id == id,
      orElse: () => DayMakerSampleData.persona,
    );
  }

  @override
  Future<Roast> getDailyRoast({
    required String personaId,
    required String weatherSnapshotId,
  }) async {
    return DayMakerSampleData.dailyRoasts.firstWhere(
      (roast) =>
          roast.personaId == personaId &&
          roast.weatherSnapshotId == weatherSnapshotId,
      orElse: () => DayMakerSampleData.roast,
    );
  }

  @override
  Future<List<Roast>> getRoastHistory({String? personaId}) async {
    if (personaId == null) {
      return DayMakerSampleData.roastHistory;
    }

    return DayMakerSampleData.roastHistory
        .where((roast) => roast.personaId == personaId)
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
