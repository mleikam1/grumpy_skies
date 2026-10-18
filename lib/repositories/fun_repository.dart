import '../models/weather_models.dart';

/// Retained creative and achievement content, independent of weather delivery.
abstract class FunRepository {
  Future<List<Achievement>> getAchievements();
  Future<List<FunFeature>> getFunFeatures();
  Future<List<MemeTemplate>> getMemeTemplates();
}
