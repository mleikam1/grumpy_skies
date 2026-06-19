import '../models/weather_models.dart';

abstract class WeatherRepository {
  const WeatherRepository();

  Future<List<LocationCandidate>> searchLocations({
    required String query,
    int limit = 5,
  }) async {
    return const [];
  }

  Future<LocationCandidate?> lookupZip({
    required String zip,
    String country = 'US',
  }) async {
    return null;
  }

  Future<LocationCandidate?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return null;
  }

  Future<WeatherSnapshot> getSnapshot({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  });

  Future<List<RadarAlert>> getRadarAlerts({
    required double latitude,
    required double longitude,
  });

  Future<List<WeatherAlert>> getWeatherAlerts({
    required List<String> alertIds,
  }) async {
    return const [];
  }

  Future<WeatherBundle> getWeather({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
    LocationCandidate? location,
  }) async {
    final snapshot = await getSnapshot(
      latitude: latitude,
      longitude: longitude,
      forceRefresh: forceRefresh,
    );

    return WeatherBundle.fromSnapshot(snapshot);
  }
}
