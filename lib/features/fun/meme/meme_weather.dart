import 'package:flutter/foundation.dart';

import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../services/cache_service.dart';
import '../../../services/weather_location_controller.dart';
import '../../roasts/models/roast_persona.dart';

enum MemeWindUnit { mph, kph }

/// A read-only adapter. This module deliberately has no weather repository or
/// roast-generation dependency: using the studio cannot start a weather request.
abstract final class MemeWeather {
  static const staleAfter = Duration(hours: 1);

  static Map<String, dynamic>? fromCache(
    CacheService cache,
    WeatherLocationController locations, {
    TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
    MemeWindUnit windUnit = MemeWindUnit.mph,
    bool includeCity = false,
    DateTime? now,
  }) {
    final location = locations.selectedLocation;
    if (location == null) return null;
    try {
      final bundle = cache.getWeatherBundle(location.lat, location.lon);
      if (bundle == null) return null;
      return freeze(
        bundle,
        temperatureUnit: temperatureUnit,
        windUnit: windUnit,
        includeCity: includeCity,
        now: now,
      );
    } catch (_) {
      // A damaged or absent weather cache must not block manual meme creation.
      return null;
    }
  }

  static Map<String, dynamic> freeze(
    WeatherBundle bundle, {
    TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
    MemeWindUnit windUnit = MemeWindUnit.mph,
    bool includeCity = false,
    bool isSample = false,
    DateTime? now,
  }) {
    final weather = bundle.current;
    final frozenAt = (now ?? DateTime.now()).toUtc();
    // fetchedAt measures retrieval, not the age of the actual observation.
    final observedAt = (weather.sourceUpdatedAt ?? weather.lastUpdated).toUtc();
    final age = frozenAt.difference(observedAt);
    final offset = weather.timezoneOffset;
    final local =
        offset == null ? null : observedAt.add(Duration(seconds: offset));
    final city = weather.locationName.split(',').first.trim();
    final metric = temperatureUnit == TemperatureUnit.celsius;
    final temperature = metric ? weather.temperatureC : weather.temperatureF;
    final feelsLike = metric ? weather.feelsLikeC : weather.feelsLikeF;
    final wind =
        windUnit == MemeWindUnit.mph ? weather.windMph : weather.windKph;
    return Map.unmodifiable({
      'schemaVersion': 1,
      'source': isSample ? 'sample' : 'cached',
      'observedAt': observedAt.toIso8601String(),
      'frozenAt': frozenAt.toIso8601String(),
      'stale': age > staleAfter || age < const Duration(minutes: -5),
      if (weather.timezone?.isNotEmpty == true) 'timezone': weather.timezone,
      if (offset != null) 'timezoneOffsetSeconds': offset,
      'temperatureUnit': temperatureUnit.name,
      'windUnit': windUnit.name,
      if (temperature.isFinite) 'temperature': temperature,
      if (feelsLike.isFinite) 'feelsLike': feelsLike,
      if (weather.condition.trim().isNotEmpty) 'condition': weather.condition,
      if (weather.humidity >= 0 && weather.humidity <= 100)
        'humidity': weather.humidity,
      if (wind.isFinite && wind >= 0) 'wind': wind,
      if (local != null) 'day': _dayName(local.weekday),
      if (includeCity && city.isNotEmpty) 'city': city,
      'tags': List.unmodifiable(_tags(weather)),
      if (!isSample) 'attribution': 'Weather data: OpenWeather',
    });
  }

  /// Values suitable for editable chips/tokens. Missing values stay absent.
  static Map<String, String> tokens(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return const {};
    final unit = snapshot['temperatureUnit'] == 'celsius' ? '°C' : '°F';
    String? number(String key) {
      final value = snapshot[key];
      return value is num && value.isFinite ? value.round().toString() : null;
    }

    final temperature = number('temperature');
    final feelsLike = number('feelsLike');
    final humidity = number('humidity');
    final wind = number('wind');
    return {
      for (final key in ['city', 'condition', 'day'])
        if (snapshot[key] is String && (snapshot[key] as String).isNotEmpty)
          key: snapshot[key] as String,
      if (temperature != null) 'temperature': '$temperature$unit',
      if (feelsLike != null) 'feelsLike': '$feelsLike$unit',
      if (humidity != null) 'humidity': '$humidity%',
      if (wind != null)
        'wind': '$wind ${snapshot['windUnit'] == 'kph' ? 'km/h' : 'mph'}',
    };
  }

  static String renderTokens(String text, Map<String, dynamic>? snapshot) {
    final values = tokens(snapshot);
    return text.replaceAllMapped(
      RegExp(r'\{([a-zA-Z_]+)\}'),
      (match) => values[match.group(1)] ?? '',
    );
  }

  static String statusLabel(Map<String, dynamic>? snapshot, {DateTime? now}) {
    if (snapshot == null) return 'No cached weather — choose any template';
    if (snapshot['source'] == 'sample') return 'Sample weather';
    if (snapshot['source'] == 'custom') return 'Custom weather';
    final observedAt =
        DateTime.tryParse(snapshot['observedAt']?.toString() ?? '');
    final age = observedAt == null
        ? null
        : (now ?? DateTime.now()).toUtc().difference(observedAt.toUtc());
    final stale = snapshot['stale'] == true ||
        (age != null &&
            (age > staleAfter || age < const Duration(minutes: -5)));
    return stale ? 'Stale cached weather' : 'Frozen cached weather';
  }

  static Set<String> _tags(CurrentWeather weather) {
    final code = weather.weatherId;
    final condition =
        '${weather.condition} ${weather.weatherMain ?? ''}'.toLowerCase();
    final tags = <String>{};
    bool mentions(String word) => condition.contains(word);
    if ((code != null && code >= 200 && code < 300) || mentions('thunder')) {
      tags.add('thunderstorm');
      tags.add('rain');
    }
    if ((code != null && code >= 300 && code < 400) || mentions('drizzle')) {
      tags.addAll(['drizzle', 'rain']);
    }
    if ((code != null && code >= 500 && code < 600) || mentions('rain')) {
      tags.add('rain');
    }
    if ((code != null && code >= 600 && code < 700) || mentions('snow')) {
      tags.add('snow');
    }
    if (code == 701 || code == 741 || mentions('fog') || mentions('mist')) {
      tags.addAll(['fog', 'mist']);
    }
    if (code == 800 || mentions('clear') || mentions('sunny')) {
      tags.add('clear_day');
    }
    if ((code != null && code >= 801 && code <= 804) || mentions('cloud')) {
      tags.add('cloudy');
    }
    if (code == 804 || mentions('overcast')) tags.add('overcast');
    if (weather.temperatureF >= 90) tags.add('hot');
    if (weather.temperatureF <= 32) tags.add('cold');
    if (weather.humidity >= 70) tags.add('humid');
    if (weather.windMph >= 20) tags.add('wind');
    // Pollen, rainbows, and temperature swings require observations that the
    // current weather model does not supply. Never guess them from the season,
    // rain probability, or a daily forecast high/low.
    return tags;
  }

  static String _dayName(int weekday) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][weekday - 1];
}

/// The text is copied from the displayed widget state, never regenerated.
@immutable
class DisplayedRoastSnapshot {
  DisplayedRoastSnapshot({
    required this.id,
    required this.text,
    required String personaId,
    required this.sourceKey,
    required this.sourceLabel,
    required this.isSample,
    Map<String, dynamic>? weatherSnapshot,
    DateTime? capturedAt,
  })  : personaId = RoastPersonas.normalizeId(personaId),
        weatherSnapshot =
            weatherSnapshot == null ? null : Map.unmodifiable(weatherSnapshot),
        capturedAt = capturedAt ?? DateTime.now();

  final String id;
  final String text;
  final String personaId;
  final String sourceKey;
  final String sourceLabel;
  final bool isSample;
  final Map<String, dynamic>? weatherSnapshot;
  final DateTime capturedAt;

  String get chooserLabel =>
      '$sourceLabel · ${RoastPersonas.byId(personaId).displayName}'
      '${isSample ? ' · Sample roast' : ''}';
}

/// Retains one exact, most recently displayed choice per source across routes.
/// This in-memory registry intentionally never persists captions or locations.
class DisplayedRoastRegistry extends ChangeNotifier {
  final Map<String, DisplayedRoastSnapshot> _choices = {};
  WeatherBundle? _cachedWeather;

  List<DisplayedRoastSnapshot> get choices =>
      List.unmodifiable(_choices.values.toList().reversed);
  DisplayedRoastSnapshot? get latestForecast => _choices['forecast'];
  WeatherBundle? get cachedWeather => _cachedWeather;

  void publish(DisplayedRoastSnapshot snapshot, {WeatherBundle? weather}) {
    if (weather != null) _cachedWeather = weather;
    final old = _choices[snapshot.sourceKey];
    if (old != null &&
        old.id == snapshot.id &&
        old.text == snapshot.text &&
        old.personaId == snapshot.personaId &&
        old.isSample == snapshot.isSample &&
        old.weatherSnapshot?['observedAt'] ==
            snapshot.weatherSnapshot?['observedAt'] &&
        old.weatherSnapshot?['temperatureUnit'] ==
            snapshot.weatherSnapshot?['temperatureUnit'] &&
        old.weatherSnapshot?['stale'] == snapshot.weatherSnapshot?['stale']) {
      return;
    }
    _choices.remove(snapshot.sourceKey);
    _choices[snapshot.sourceKey] = snapshot;
    notifyListeners();
  }

  void clearSource(String sourceKey) {
    if (sourceKey == 'forecast') _cachedWeather = null;
    if (_choices.remove(sourceKey) != null) notifyListeners();
  }
}
