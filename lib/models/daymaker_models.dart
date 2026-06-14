import 'temperature_unit.dart';

class WeatherSnapshot {
  final String id;
  final String locationName;
  final String condition;
  final int temperatureF;
  final int feelsLikeF;
  final double windMph;
  final String windDirection;
  final int humidityPercent;
  final int rainChancePercent;
  final int aqi;
  final String aqiCategory;
  final double uvIndex;
  final String uvCategory;
  final int chaosMeterPercent;
  final DateTime observedAt;
  final List<ForecastHour> hourly;
  final List<ForecastDay> daily;
  final List<WeatherMetric> metrics;

  WeatherSnapshot({
    required this.id,
    required this.locationName,
    required this.condition,
    required this.temperatureF,
    required this.feelsLikeF,
    required this.windMph,
    required this.windDirection,
    required this.humidityPercent,
    required this.rainChancePercent,
    required this.aqi,
    required this.aqiCategory,
    required this.uvIndex,
    required this.uvCategory,
    required this.chaosMeterPercent,
    required this.observedAt,
    List<ForecastHour> hourly = const [],
    List<ForecastDay> daily = const [],
    List<WeatherMetric> metrics = const [],
  })  : hourly = List.unmodifiable(hourly),
        daily = List.unmodifiable(daily),
        metrics = List.unmodifiable(metrics);

  double get temperatureC => _fToC(temperatureF);

  double get feelsLikeC => _fToC(feelsLikeF);

  double get windKph => windMph * 1.609344;

  String get windLabel => '${windMph.toStringAsFixed(0)} mph $windDirection';

  String get aqiLabel => '$aqi $aqiCategory';

  String get uvLabel => '${uvIndex.toStringAsFixed(0)} $uvCategory';

  Map<String, dynamic> toJson() => {
        'id': id,
        'locationName': locationName,
        'condition': condition,
        'temperatureF': temperatureF,
        'feelsLikeF': feelsLikeF,
        'windMph': windMph,
        'windDirection': windDirection,
        'humidityPercent': humidityPercent,
        'rainChancePercent': rainChancePercent,
        'aqi': aqi,
        'aqiCategory': aqiCategory,
        'uvIndex': uvIndex,
        'uvCategory': uvCategory,
        'chaosMeterPercent': chaosMeterPercent,
        'observedAt': observedAt.toIso8601String(),
        'hourly': hourly.map((hour) => hour.toJson()).toList(),
        'daily': daily.map((day) => day.toJson()).toList(),
        'metrics': metrics.map((metric) => metric.toJson()).toList(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      id: json['id'] as String,
      locationName: json['locationName'] as String,
      condition: json['condition'] as String,
      temperatureF: (json['temperatureF'] as num).round(),
      feelsLikeF: (json['feelsLikeF'] as num).round(),
      windMph: (json['windMph'] as num).toDouble(),
      windDirection: json['windDirection'] as String,
      humidityPercent: (json['humidityPercent'] as num).round(),
      rainChancePercent: (json['rainChancePercent'] as num).round(),
      aqi: (json['aqi'] as num).round(),
      aqiCategory: json['aqiCategory'] as String,
      uvIndex: (json['uvIndex'] as num).toDouble(),
      uvCategory: json['uvCategory'] as String,
      chaosMeterPercent: (json['chaosMeterPercent'] as num).round(),
      observedAt: DateTime.parse(json['observedAt'] as String),
      hourly: ((json['hourly'] as List?) ?? const [])
          .map((hour) => ForecastHour.fromJson(hour as Map<String, dynamic>))
          .toList(),
      daily: ((json['daily'] as List?) ?? const [])
          .map((day) => ForecastDay.fromJson(day as Map<String, dynamic>))
          .toList(),
      metrics: ((json['metrics'] as List?) ?? const [])
          .map((metric) =>
              WeatherMetric.fromJson(metric as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ForecastHour {
  final DateTime time;
  final int temperatureF;
  final String condition;
  final int rainChancePercent;

  const ForecastHour({
    required this.time,
    required this.temperatureF,
    required this.condition,
    required this.rainChancePercent,
  });

  double get temperatureC => _fToC(temperatureF);

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperatureF': temperatureF,
        'condition': condition,
        'rainChancePercent': rainChancePercent,
      };

  factory ForecastHour.fromJson(Map<String, dynamic> json) {
    return ForecastHour(
      time: DateTime.parse(json['time'] as String),
      temperatureF: (json['temperatureF'] as num).round(),
      condition: json['condition'] as String,
      rainChancePercent: (json['rainChancePercent'] as num).round(),
    );
  }
}

class ForecastDay {
  final DateTime date;
  final int lowF;
  final int highF;
  final String condition;
  final int rainChancePercent;

  const ForecastDay({
    required this.date,
    required this.lowF,
    required this.highF,
    required this.condition,
    required this.rainChancePercent,
  });

  double get lowC => _fToC(lowF);

  double get highC => _fToC(highF);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'lowF': lowF,
        'highF': highF,
        'condition': condition,
        'rainChancePercent': rainChancePercent,
      };

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: DateTime.parse(json['date'] as String),
      lowF: (json['lowF'] as num).round(),
      highF: (json['highF'] as num).round(),
      condition: json['condition'] as String,
      rainChancePercent: (json['rainChancePercent'] as num).round(),
    );
  }
}

class WeatherMetric {
  final String id;
  final String label;
  final String value;
  final String? detail;

  const WeatherMetric({
    required this.id,
    required this.label,
    required this.value,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'detail': detail,
      };

  factory WeatherMetric.fromJson(Map<String, dynamic> json) {
    return WeatherMetric(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
      detail: json['detail'] as String?,
    );
  }
}

class Persona {
  final String id;
  final String name;
  final String title;
  final String avatarAsset;
  final int requiredXp;
  final bool unlocked;

  const Persona({
    required this.id,
    required this.name,
    required this.title,
    required this.avatarAsset,
    required this.requiredXp,
    required this.unlocked,
  });

  String get displayName => '$name, $title';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'avatarAsset': avatarAsset,
        'requiredXp': requiredXp,
        'unlocked': unlocked,
      };
}

class Roast {
  final String id;
  final String personaId;
  final String weatherSnapshotId;
  final String text;
  final String category;
  final DateTime createdAt;
  final int xpReward;

  const Roast({
    required this.id,
    required this.personaId,
    required this.weatherSnapshotId,
    required this.text,
    required this.category,
    required this.createdAt,
    required this.xpReward,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'personaId': personaId,
        'weatherSnapshotId': weatherSnapshotId,
        'text': text,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'xpReward': xpReward,
      };
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final int xpReward;
  final bool unlocked;
  final int progress;
  final int target;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.xpReward,
    required this.unlocked,
    required this.progress,
    required this.target,
  });

  bool get complete => progress >= target;

  Achievement copyWith({
    bool? unlocked,
    int? progress,
  }) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      xpReward: xpReward,
      unlocked: unlocked ?? this.unlocked,
      progress: progress ?? this.progress,
      target: target,
    );
  }
}

class FunFeature {
  final String id;
  final String name;
  final String prompt;
  final String value;
  final bool enabled;

  const FunFeature({
    required this.id,
    required this.name,
    required this.prompt,
    required this.value,
    required this.enabled,
  });
}

class MemeTemplate {
  final String id;
  final String name;
  final String imageAsset;
  final String topText;
  final String bottomText;

  const MemeTemplate({
    required this.id,
    required this.name,
    required this.imageAsset,
    required this.topText,
    required this.bottomText,
  });
}

class RadarAlert {
  final String id;
  final String locationName;
  final String title;
  final String message;
  final String severity;
  final DateTime startsAt;
  final DateTime expiresAt;

  const RadarAlert({
    required this.id,
    required this.locationName,
    required this.title,
    required this.message,
    required this.severity,
    required this.startsAt,
    required this.expiresAt,
  });
}

class UserSettings {
  final TemperatureUnit temperatureUnit;
  final String selectedPersonaId;
  final bool notificationsEnabled;
  final bool adsEnabled;
  final int xp;
  final int level;
  final int streakDays;

  const UserSettings({
    required this.temperatureUnit,
    required this.selectedPersonaId,
    required this.notificationsEnabled,
    required this.adsEnabled,
    required this.xp,
    required this.level,
    required this.streakDays,
  });

  UserSettings copyWith({
    TemperatureUnit? temperatureUnit,
    String? selectedPersonaId,
    bool? notificationsEnabled,
    bool? adsEnabled,
    int? xp,
    int? level,
    int? streakDays,
  }) {
    return UserSettings(
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      selectedPersonaId: selectedPersonaId ?? this.selectedPersonaId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      adsEnabled: adsEnabled ?? this.adsEnabled,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

double _fToC(num tempF) => (tempF - 32) * 5 / 9;
