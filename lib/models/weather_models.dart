class CurrentWeather {
  final double temperatureC;
  final String condition;
  final double feelsLikeC;
  final double windKph;
  final int humidity;
  final DateTime lastUpdated;

  CurrentWeather({
    required this.temperatureC,
    required this.condition,
    required this.feelsLikeC,
    required this.windKph,
    required this.humidity,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'temperatureC': temperatureC,
    'condition': condition,
    'feelsLikeC': feelsLikeC,
    'windKph': windKph,
    'humidity': humidity,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  double get temperatureF => _cToF(temperatureC);

  double get feelsLikeF => _cToF(feelsLikeC);

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperatureC: (json['temperatureC'] as num).toDouble(),
      condition: json['condition'] as String,
      feelsLikeC: (json['feelsLikeC'] as num).toDouble(),
      windKph: (json['windKph'] as num).toDouble(),
      humidity: json['humidity'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperatureC;
  final String condition;

  HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.condition,
  });

  double get temperatureF => _cToF(temperatureC);

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temperatureC': temperatureC,
    'condition': condition,
  };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.parse(json['time'] as String),
      temperatureC: (json['temperatureC'] as num).toDouble(),
      condition: json['condition'] as String,
    );
  }
}

class DailyForecast {
  final DateTime date;
  final double minTempC;
  final double maxTempC;
  final String condition;

  DailyForecast({
    required this.date,
    required this.minTempC,
    required this.maxTempC,
    required this.condition,
  });

  double get minTempF => _cToF(minTempC);

  double get maxTempF => _cToF(maxTempC);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'minTempC': minTempC,
    'maxTempC': maxTempC,
    'condition': condition,
  };

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.parse(json['date'] as String),
      minTempC: (json['minTempC'] as num).toDouble(),
      maxTempC: (json['maxTempC'] as num).toDouble(),
      condition: json['condition'] as String,
    );
  }
}

/// Bundle for convenience
class WeatherBundle {
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  WeatherBundle({
    required this.current,
    required this.hourly,
    required this.daily,
  });

  Map<String, dynamic> toJson() => {
    'current': current.toJson(),
    'hourly': hourly.map((e) => e.toJson()).toList(),
    'daily': daily.map((e) => e.toJson()).toList(),
  };

  factory WeatherBundle.fromJson(Map<String, dynamic> json) {
    return WeatherBundle(
      current: CurrentWeather.fromJson(json['current']),
      hourly: (json['hourly'] as List)
          .map((e) => HourlyForecast.fromJson(e))
          .toList(),
      daily: (json['daily'] as List)
          .map((e) => DailyForecast.fromJson(e))
          .toList(),
    );
  }
}

double _cToF(double tempC) => tempC * 9 / 5 + 32;
