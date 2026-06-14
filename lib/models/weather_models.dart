import 'daymaker_models.dart';

export 'daymaker_models.dart';

class CurrentWeather {
  final String locationName;
  final double temperatureC;
  final String condition;
  final double feelsLikeC;
  final double windKph;
  final String windDirection;
  final int humidity;
  final int precipitationChance;
  final int aqi;
  final String aqiCategory;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime moonrise;
  final DateTime moonset;
  final double uvIndex;
  final String uvCategory;
  final int chaosMeterPercent;
  final DateTime lastUpdated;

  const CurrentWeather({
    this.locationName = '',
    required this.temperatureC,
    required this.condition,
    required this.feelsLikeC,
    required this.windKph,
    this.windDirection = '',
    required this.humidity,
    required this.precipitationChance,
    required this.aqi,
    this.aqiCategory = '',
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.moonset,
    required this.uvIndex,
    this.uvCategory = '',
    this.chaosMeterPercent = 0,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'locationName': locationName,
        'temperatureC': temperatureC,
        'condition': condition,
        'feelsLikeC': feelsLikeC,
        'windKph': windKph,
        'windDirection': windDirection,
        'humidity': humidity,
        'precipitationChance': precipitationChance,
        'aqi': aqi,
        'aqiCategory': aqiCategory,
        'sunrise': sunrise.toIso8601String(),
        'sunset': sunset.toIso8601String(),
        'moonrise': moonrise.toIso8601String(),
        'moonset': moonset.toIso8601String(),
        'uvIndex': uvIndex,
        'uvCategory': uvCategory,
        'chaosMeterPercent': chaosMeterPercent,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  double get temperatureF => _cToF(temperatureC);

  double get feelsLikeF => _cToF(feelsLikeC);

  double get temp => temperatureC;

  double get feelsLike => feelsLikeC;

  double get windMph => windKph / 1.609344;

  String get windLabel {
    final direction = windDirection.isEmpty ? '' : ' $windDirection';
    return '${windMph.toStringAsFixed(0)} mph$direction';
  }

  String get aqiLabel =>
      aqiCategory.isEmpty ? aqi.toString() : '$aqi $aqiCategory';

  String get uvLabel => uvCategory.isEmpty
      ? uvIndex.toStringAsFixed(0)
      : '${uvIndex.toStringAsFixed(0)} $uvCategory';

  factory CurrentWeather.fromSnapshot(WeatherSnapshot snapshot) {
    final observedAt = snapshot.observedAt;

    return CurrentWeather(
      locationName: snapshot.locationName,
      temperatureC: snapshot.temperatureC,
      condition: snapshot.condition,
      feelsLikeC: snapshot.feelsLikeC,
      windKph: snapshot.windKph,
      windDirection: snapshot.windDirection,
      humidity: snapshot.humidityPercent,
      precipitationChance: snapshot.rainChancePercent,
      aqi: snapshot.aqi,
      aqiCategory: snapshot.aqiCategory,
      sunrise: DateTime(
        observedAt.year,
        observedAt.month,
        observedAt.day,
        5,
        48,
      ),
      sunset: DateTime(
        observedAt.year,
        observedAt.month,
        observedAt.day,
        18,
        45,
      ),
      moonrise: DateTime(
        observedAt.year,
        observedAt.month,
        observedAt.day,
        22,
        10,
      ),
      moonset: DateTime(
        observedAt.year,
        observedAt.month,
        observedAt.day,
        4,
        35,
      ),
      uvIndex: snapshot.uvIndex,
      uvCategory: snapshot.uvCategory,
      chaosMeterPercent: snapshot.chaosMeterPercent,
      lastUpdated: snapshot.observedAt,
    );
  }

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      locationName: (json['locationName'] ?? '') as String,
      temperatureC: (json['temperatureC'] as num).toDouble(),
      condition: json['condition'] as String,
      feelsLikeC: (json['feelsLikeC'] as num).toDouble(),
      windKph: (json['windKph'] as num).toDouble(),
      windDirection: (json['windDirection'] ?? '') as String,
      humidity: (json['humidity'] as num).toInt(),
      precipitationChance: ((json['precipitationChance'] ?? 0) as num).toInt(),
      aqi: ((json['aqi'] ?? 50) as num).toInt(),
      aqiCategory: (json['aqiCategory'] ?? '') as String,
      sunrise: _safeParseDate(json['sunrise']) ?? DateTime.now(),
      sunset: _safeParseDate(json['sunset']) ?? DateTime.now(),
      moonrise: _safeParseDate(json['moonrise']) ?? DateTime.now(),
      moonset: _safeParseDate(json['moonset']) ?? DateTime.now(),
      uvIndex: ((json['uvIndex'] ?? 5) as num).toDouble(),
      uvCategory: (json['uvCategory'] ?? '') as String,
      chaosMeterPercent: ((json['chaosMeterPercent'] ?? 0) as num).toInt(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperatureC;
  final String condition;
  final int precipitationChance;

  const HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.condition,
    this.precipitationChance = 0,
  });

  double get temperatureF => _cToF(temperatureC);

  factory HourlyForecast.fromForecastHour(ForecastHour hour) {
    return HourlyForecast(
      time: hour.time,
      temperatureC: hour.temperatureC,
      condition: hour.condition,
      precipitationChance: hour.rainChancePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperatureC': temperatureC,
        'condition': condition,
        'precipitationChance': precipitationChance,
      };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.parse(json['time'] as String),
      temperatureC: (json['temperatureC'] as num).toDouble(),
      condition: json['condition'] as String,
      precipitationChance: ((json['precipitationChance'] ?? 0) as num).toInt(),
    );
  }
}

class DailyForecast {
  final DateTime date;
  final double minTempC;
  final double maxTempC;
  final String condition;
  final int precipitationChance;

  const DailyForecast({
    required this.date,
    required this.minTempC,
    required this.maxTempC,
    required this.condition,
    this.precipitationChance = 0,
  });

  double get minTempF => _cToF(minTempC);

  double get maxTempF => _cToF(maxTempC);

  factory DailyForecast.fromForecastDay(ForecastDay day) {
    return DailyForecast(
      date: day.date,
      minTempC: day.lowC,
      maxTempC: day.highC,
      condition: day.condition,
      precipitationChance: day.rainChancePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minTempC': minTempC,
        'maxTempC': maxTempC,
        'condition': condition,
        'precipitationChance': precipitationChance,
      };

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.parse(json['date'] as String),
      minTempC: (json['minTempC'] as num).toDouble(),
      maxTempC: (json['maxTempC'] as num).toDouble(),
      condition: json['condition'] as String,
      precipitationChance: ((json['precipitationChance'] ?? 0) as num).toInt(),
    );
  }
}

/// Bundle for convenience
class WeatherBundle {
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final WeatherSnapshot? snapshot;

  const WeatherBundle({
    required this.current,
    required this.hourly,
    required this.daily,
    this.snapshot,
  });

  Map<String, dynamic> toJson() => {
        'current': current.toJson(),
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'daily': daily.map((e) => e.toJson()).toList(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
      };

  factory WeatherBundle.fromSnapshot(WeatherSnapshot snapshot) {
    return WeatherBundle(
      current: CurrentWeather.fromSnapshot(snapshot),
      hourly: snapshot.hourly
          .map((hour) => HourlyForecast.fromForecastHour(hour))
          .toList(),
      daily: snapshot.daily
          .map((day) => DailyForecast.fromForecastDay(day))
          .toList(),
      snapshot: snapshot,
    );
  }

  factory WeatherBundle.fromJson(Map<String, dynamic> json) {
    return WeatherBundle(
      current: CurrentWeather.fromJson(json['current']),
      hourly: (json['hourly'] as List)
          .map((e) => HourlyForecast.fromJson(e))
          .toList(),
      daily: (json['daily'] as List)
          .map((e) => DailyForecast.fromJson(e))
          .toList(),
      snapshot: json['snapshot'] == null
          ? null
          : WeatherSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
    );
  }
}

double _cToF(double tempC) => tempC * 9 / 5 + 32;

DateTime? _safeParseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
