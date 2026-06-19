import 'daymaker_models.dart';

export 'daymaker_models.dart';

class LocationCandidate {
  final String name;
  final String? state;
  final String country;
  final double lat;
  final double lon;
  final String source;

  const LocationCandidate({
    required this.name,
    this.state,
    required this.country,
    required this.lat,
    required this.lon,
    required this.source,
  });

  double get latitude => lat;

  double get longitude => lon;

  String get displayName {
    final parts = [
      name,
      if (state != null && state!.trim().isNotEmpty) state!,
      if (country.trim().isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  bool get isUs => country.toUpperCase() == 'US';

  Map<String, dynamic> toJson() => {
        'name': name,
        if (state != null) 'state': state,
        'country': country,
        'lat': lat,
        'lon': lon,
        'source': source,
      };

  factory LocationCandidate.fromJson(Map<String, dynamic> json) {
    return LocationCandidate(
      name: (json['name'] ?? 'Selected location') as String,
      state: json['state'] as String?,
      country: (json['country'] ?? 'US') as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      source: (json['source'] ?? 'city') as String,
    );
  }
}

enum WeatherLocationSource {
  device,
  manual,
  fallback,
}

extension WeatherLocationSourceX on WeatherLocationSource {
  String get storageValue => switch (this) {
        WeatherLocationSource.device => 'device',
        WeatherLocationSource.manual => 'manual',
        WeatherLocationSource.fallback => 'fallback',
      };

  static WeatherLocationSource parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'device' || 'browser' => WeatherLocationSource.device,
      'fallback' => WeatherLocationSource.fallback,
      _ => WeatherLocationSource.manual,
    };
  }
}

class WeatherLocation extends LocationCandidate {
  const WeatherLocation({
    required super.name,
    super.state,
    required super.country,
    required double latitude,
    required double longitude,
    WeatherLocationSource source = WeatherLocationSource.manual,
    required this.updatedAt,
  })  : appSource = source,
        super(
          lat: latitude,
          lon: longitude,
          source: source == WeatherLocationSource.device
              ? 'device'
              : source == WeatherLocationSource.fallback
                  ? 'fallback'
                  : 'manual',
        );

  final WeatherLocationSource appSource;
  final DateTime updatedAt;

  WeatherLocation copyWith({
    String? name,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    WeatherLocationSource? source,
    DateTime? updatedAt,
  }) {
    return WeatherLocation(
      name: name ?? this.name,
      state: state ?? this.state,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? appSource,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WeatherLocation.fromCandidate(
    LocationCandidate candidate, {
    WeatherLocationSource? source,
    DateTime? updatedAt,
  }) {
    return WeatherLocation(
      name: candidate.name,
      state: candidate.state,
      country: candidate.country,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      source: source ?? WeatherLocationSourceX.parse(candidate.source),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'source': appSource.storageValue,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      name: (json['name'] ?? 'Selected location') as String,
      state: json['state'] as String?,
      country: (json['country'] ?? 'US') as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      source: WeatherLocationSourceX.parse(json['source']),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }
}

class MinutePrecipitation {
  final DateTime time;
  final double precipitation;

  const MinutePrecipitation({
    required this.time,
    required this.precipitation,
  });

  bool get isWet => precipitation > 0;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'precipitation': precipitation,
      };

  factory MinutePrecipitation.fromJson(Map<String, dynamic> json) {
    return MinutePrecipitation(
      time: _dateFromJson(json['time'] ?? json['dt']),
      precipitation: ((json['precipitation'] ?? 0) as num).toDouble(),
    );
  }
}

class TimelineWeatherPoint {
  final DateTime time;
  final double? temperatureF;
  final double? feelsLikeF;
  final int? humidity;
  final int precipitationChance;
  final double precipitation;
  final double? windMph;
  final int? windDeg;
  final String condition;
  final String? icon;
  final int? weatherId;
  final List<String> alertIds;

  const TimelineWeatherPoint({
    required this.time,
    this.temperatureF,
    this.feelsLikeF,
    this.humidity,
    this.precipitationChance = 0,
    this.precipitation = 0,
    this.windMph,
    this.windDeg,
    this.condition = 'Unknown',
    this.icon,
    this.weatherId,
    this.alertIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperatureF': temperatureF,
        'feelsLikeF': feelsLikeF,
        'humidity': humidity,
        'precipitationChance': precipitationChance,
        'precipitation': precipitation,
        'windMph': windMph,
        'windDeg': windDeg,
        'condition': condition,
        'icon': icon,
        'weatherId': weatherId,
        'alertIds': alertIds,
      };

  factory TimelineWeatherPoint.fromJson(Map<String, dynamic> json) {
    final weather = (json['weather'] as Map?)?.cast<String, dynamic>();
    final probability =
        ((json['precipitationProbability'] ?? 0) as num).toDouble();
    return TimelineWeatherPoint(
      time: _dateFromJson(json['time'] ?? json['dt']),
      temperatureF: (json['temperatureF'] ?? json['temp']) == null
          ? null
          : ((json['temperatureF'] ?? json['temp']) as num).toDouble(),
      feelsLikeF: (json['feelsLikeF'] ?? json['feelsLike']) == null
          ? null
          : ((json['feelsLikeF'] ?? json['feelsLike']) as num).toDouble(),
      humidity: (json['humidity'] as num?)?.round(),
      precipitationChance:
          probability <= 1 ? (probability * 100).round() : probability.round(),
      precipitation: ((json['precipitation'] ?? 0) as num).toDouble(),
      windMph: (json['windMph'] ?? json['windSpeed']) == null
          ? null
          : ((json['windMph'] ?? json['windSpeed']) as num).toDouble(),
      windDeg: (json['windDeg'] as num?)?.round(),
      condition:
          (json['condition'] ?? weather?['description'] ?? 'Unknown') as String,
      icon: (json['icon'] ?? weather?['icon']) as String?,
      weatherId: (json['weatherId'] ?? weather?['id'] as num?)?.round(),
      alertIds: ((json['alertIds'] as List?) ?? const [])
          .map((id) => id.toString())
          .toList(),
    );
  }
}

class WeatherAlert {
  final String senderName;
  final String event;
  final DateTime? start;
  final DateTime? end;
  final String description;

  const WeatherAlert({
    required this.senderName,
    required this.event,
    this.start,
    this.end,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'senderName': senderName,
        'event': event,
        'start': start?.toIso8601String(),
        'end': end?.toIso8601String(),
        'description': description,
      };

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      senderName: (json['senderName'] ??
          json['sender_name'] ??
          'Weather authority') as String,
      event: (json['event'] ?? 'Weather alert') as String,
      start: _nullableDateFromJson(json['start']),
      end: _nullableDateFromJson(json['end']),
      description: (json['description'] ?? '') as String,
    );
  }
}

enum RadarMode {
  usForecast,
  global,
}

extension RadarModeX on RadarMode {
  String get pathSegment => switch (this) {
        RadarMode.usForecast => 'us-forecast',
        RadarMode.global => 'global',
      };

  String get label => switch (this) {
        RadarMode.usForecast => 'US forecast radar',
        RadarMode.global => 'Global precipitation radar',
      };
}

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
  final double? dewPointC;
  final int? pressureHpa;
  final int? visibilityMeters;
  final double? windGustKph;
  final double? rainLastHour;
  final double? snowLastHour;
  final String? weatherIcon;
  final int? weatherId;
  final List<String> alertIds;
  final String? timezone;

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
    this.dewPointC,
    this.pressureHpa,
    this.visibilityMeters,
    this.windGustKph,
    this.rainLastHour,
    this.snowLastHour,
    this.weatherIcon,
    this.weatherId,
    this.alertIds = const [],
    this.timezone,
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
        'dewPointC': dewPointC,
        'pressureHpa': pressureHpa,
        'visibilityMeters': visibilityMeters,
        'windGustKph': windGustKph,
        'rainLastHour': rainLastHour,
        'snowLastHour': snowLastHour,
        'weatherIcon': weatherIcon,
        'weatherId': weatherId,
        'alertIds': alertIds,
        'timezone': timezone,
      };

  double get temperatureF => _cToF(temperatureC);

  double get feelsLikeF => _cToF(feelsLikeC);

  double get temp => temperatureC;

  double get feelsLike => feelsLikeC;

  double get windMph => windKph / 1.609344;

  double? get dewPointF => dewPointC == null ? null : _cToF(dewPointC!);

  double? get windGustMph =>
      windGustKph == null ? null : windGustKph! / 1.609344;

  double? get visibilityMiles =>
      visibilityMeters == null ? null : visibilityMeters! / 1609.344;

  String get windLabel {
    final direction = windDirection.isEmpty ? '' : ' $windDirection';
    return '${windMph.toStringAsFixed(0)} mph$direction';
  }

  String get aqiLabel =>
      aqiCategory.isEmpty ? aqi.toString() : '$aqi $aqiCategory';

  String get uvLabel => uvCategory.isEmpty
      ? uvIndex.toStringAsFixed(0)
      : '${uvIndex.toStringAsFixed(0)} $uvCategory';

  String get pressureLabel =>
      pressureHpa == null ? 'Unavailable' : '$pressureHpa hPa';

  String get visibilityLabel => visibilityMiles == null
      ? 'Unavailable'
      : '${visibilityMiles!.toStringAsFixed(1)} mi';

  String get rainSnowLastHourLabel {
    final values = <String>[];
    if ((rainLastHour ?? 0) > 0) {
      values.add('${rainLastHour!.toStringAsFixed(2)} in rain');
    }
    if ((snowLastHour ?? 0) > 0) {
      values.add('${snowLastHour!.toStringAsFixed(2)} in snow');
    }
    return values.isEmpty ? 'None' : values.join(' / ');
  }

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
      dewPointC: (json['dewPointC'] as num?)?.toDouble(),
      pressureHpa: (json['pressureHpa'] as num?)?.round(),
      visibilityMeters: (json['visibilityMeters'] as num?)?.round(),
      windGustKph: (json['windGustKph'] as num?)?.toDouble(),
      rainLastHour: (json['rainLastHour'] as num?)?.toDouble(),
      snowLastHour: (json['snowLastHour'] as num?)?.toDouble(),
      weatherIcon: json['weatherIcon'] as String?,
      weatherId: (json['weatherId'] as num?)?.round(),
      alertIds: ((json['alertIds'] as List?) ?? const [])
          .map((id) => id.toString())
          .toList(),
      timezone: json['timezone'] as String?,
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
  final LocationCandidate? location;
  final List<MinutePrecipitation> minutePrecipitation;
  final List<TimelineWeatherPoint> timeline;
  final List<WeatherAlert> alerts;

  const WeatherBundle({
    required this.current,
    required this.hourly,
    required this.daily,
    this.snapshot,
    this.location,
    this.minutePrecipitation = const [],
    this.timeline = const [],
    this.alerts = const [],
  });

  Map<String, dynamic> toJson() => {
        'current': current.toJson(),
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'daily': daily.map((e) => e.toJson()).toList(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (location != null) 'location': location!.toJson(),
        'minutePrecipitation':
            minutePrecipitation.map((e) => e.toJson()).toList(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'alerts': alerts.map((e) => e.toJson()).toList(),
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
      location: json['location'] == null
          ? null
          : LocationCandidate.fromJson(
              (json['location'] as Map).cast<String, dynamic>(),
            ),
      minutePrecipitation: ((json['minutePrecipitation'] as List?) ?? const [])
          .map((e) => MinutePrecipitation.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
      timeline: ((json['timeline'] as List?) ?? const [])
          .map((e) => TimelineWeatherPoint.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
      alerts: ((json['alerts'] as List?) ?? const [])
          .map((e) => WeatherAlert.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
    );
  }
}

double _cToF(double tempC) => tempC * 9 / 5 + 32;

DateTime _dateFromJson(dynamic value) {
  final parsed = _nullableDateFromJson(value);
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _nullableDateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
      isUtc: true,
    ).toLocal();
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _safeParseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
