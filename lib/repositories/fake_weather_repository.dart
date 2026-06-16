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
    // TODO(integration): Replace this sample snapshot with normalized
    // WeatherKit or AccuWeather data while keeping this fake for tests/previews.
    return DayMakerSampleData.weatherSnapshot;
  }

  @override
  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  }) async {
    // TODO(integration): Feed provider alert polygons/copy into RadarAlert
    // models when the live radar/weather backend is connected.
    return DayMakerSampleData.radarAlerts;
  }
}
