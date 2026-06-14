import '../models/weather_models.dart';

abstract class RoastRepository {
  Future<List<Persona>> getPersonas();

  Future<Persona> getPersona(String id);

  Future<Roast> getDailyRoast({
    required String personaId,
    required String weatherSnapshotId,
  });

  Future<List<Roast>> getRoastHistory({String? personaId});

  Future<List<Achievement>> getAchievements();

  Future<List<FunFeature>> getFunFeatures();

  Future<List<MemeTemplate>> getMemeTemplates();
}
