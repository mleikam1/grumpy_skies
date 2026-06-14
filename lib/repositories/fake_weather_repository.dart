import '../data/daymaker_sample_data.dart';
import '../models/weather_models.dart';
import 'weather_repository.dart';

class FakeWeatherRepository extends WeatherRepository {
  const FakeWeatherRepository();

  @override
  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    return DayMakerSampleData.weatherSnapshot;
  }

  @override
  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  }) async {
    return DayMakerSampleData.radarAlerts;
  }
}
