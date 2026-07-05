import '../../../models/weather_models.dart';

const supportedWeatherRoastPersonas = <String>{
  'karen',
  'frat_bro',
  'two_year_old',
  'politician',
  'grandpa',
};

const legacyWeatherRoastPersonaAliases = <String, String>{
  'frat-bro': 'frat_bro',
  'old_grandpa': 'grandpa',
  'two-year-old': 'two_year_old',
  'toddler': 'two_year_old',
};

const supportedRoastPlaceholders = <String>{
  'city',
  'temp',
  'temp_unit',
  'feels_like',
  'condition',
  'humidity',
  'wind_mph',
  'precip_chance',
  'daypart',
};

enum RoastType {
  today,
  hourly,
  commute,
  weekend,
  mood;

  static RoastType parse(String value) {
    final normalized = value.trim().toLowerCase();
    return RoastType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => throw FormatException('Unknown roast type: $value'),
    );
  }
}

enum RoastLevel {
  mild,
  medium,
  spicy;

  static RoastLevel parse(String value) {
    final normalized = value.trim().toLowerCase();
    return RoastLevel.values.firstWhere(
      (level) => level.name == normalized,
      orElse: () => throw FormatException('Unknown roast level: $value'),
    );
  }

  bool allows(RoastLevel other) => other.index <= index;
}

enum Daypart {
  morning,
  afternoon,
  evening,
  night,
  any;

  static Daypart parse(String value) {
    final normalized = value.trim().toLowerCase();
    return Daypart.values.firstWhere(
      (daypart) => daypart.name == normalized,
      orElse: () => throw FormatException('Unknown daypart: $value'),
    );
  }

  static Daypart fromDateTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return Daypart.morning;
    if (hour >= 12 && hour < 17) return Daypart.afternoon;
    if (hour >= 17 && hour < 21) return Daypart.evening;
    return Daypart.night;
  }
}

enum WeatherRoastTag {
  clear('clear'),
  partlyCloudy('partly_cloudy'),
  cloudy('cloudy'),
  lightRain('light_rain'),
  heavyRain('heavy_rain'),
  storm('storm'),
  snow('snow'),
  fog('fog'),
  windy('windy'),
  hot('hot'),
  cold('cold'),
  humid('humid'),
  dry('dry'),
  badAir('bad_air'),
  highUv('high_uv'),
  nice('nice'),
  gross('gross'),
  commuteRisk('commute_risk'),
  weekendGood('weekend_good'),
  fallback('fallback'),
  severe('severe');

  const WeatherRoastTag(this.wireValue);

  final String wireValue;

  static WeatherRoastTag parse(String value) {
    final normalized = value.trim().toLowerCase();
    return WeatherRoastTag.values.firstWhere(
      (tag) => tag.wireValue == normalized,
      orElse: () => throw FormatException('Unknown weather tag: $value'),
    );
  }
}

class RoastPack {
  const RoastPack({
    required this.schemaVersion,
    required this.packVersion,
    required this.generatedAt,
    required this.personas,
    required this.roasts,
  });

  final int schemaVersion;
  final String packVersion;
  final DateTime generatedAt;
  final List<String> personas;
  final List<RoastLine> roasts;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'pack_version': packVersion,
        'generated_at': _iso8601Seconds(generatedAt.toUtc()),
        'personas': personas,
        'roasts': roasts.map((roast) => roast.toJson()).toList(),
      };

  factory RoastPack.fromJson(Map<String, dynamic> json) {
    return RoastPack(
      schemaVersion: (json['schema_version'] as num).round(),
      packVersion: json['pack_version'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      personas: ((json['personas'] as List?) ?? const [])
          .map((persona) => persona.toString())
          .toList(growable: false),
      roasts: ((json['roasts'] as List?) ?? const [])
          .map(
            (item) => RoastLine.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }
}

class RoastLine {
  const RoastLine({
    required this.id,
    required this.persona,
    required this.type,
    required this.tags,
    required this.dayparts,
    required this.level,
    required this.weight,
    required this.text,
    this.fallbackText,
    this.conditionCodes = const [],
    this.tempMinF,
    this.tempMaxF,
    this.humidityMin,
    this.windMinMph,
    this.precipMinPercent,
    this.locale = 'en-US',
  });

  final String id;
  final String persona;
  final RoastType type;
  final List<WeatherRoastTag> tags;
  final List<Daypart> dayparts;
  final RoastLevel level;
  final double weight;
  final String text;
  final String? fallbackText;
  final List<int> conditionCodes;
  final int? tempMinF;
  final int? tempMaxF;
  final int? humidityMin;
  final double? windMinMph;
  final int? precipMinPercent;
  final String locale;

  bool get isFallback => tags.contains(WeatherRoastTag.fallback);

  bool get isSevere => tags.contains(WeatherRoastTag.severe);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'persona': persona,
      'type': type.name,
      'tags': tags.map((tag) => tag.wireValue).toList(),
      'dayparts': dayparts.map((daypart) => daypart.name).toList(),
      'level': level.name,
      'weight': weight,
      'text': text,
      if (fallbackText != null && fallbackText!.trim().isNotEmpty)
        'fallback_text': fallbackText,
      if (conditionCodes.isNotEmpty) 'condition_codes': conditionCodes,
      if (tempMinF != null) 'temp_min_f': tempMinF,
      if (tempMaxF != null) 'temp_max_f': tempMaxF,
      if (humidityMin != null) 'humidity_min': humidityMin,
      if (windMinMph != null) 'wind_min_mph': windMinMph,
      if (precipMinPercent != null) 'precip_min_percent': precipMinPercent,
      if (locale.trim().isNotEmpty) 'locale': locale,
    };
  }

  factory RoastLine.fromJson(Map<String, dynamic> json) {
    final rawDayparts = (json['dayparts'] ?? json['daypart']) as Object?;
    return RoastLine(
      id: json['id'] as String,
      persona: normalizeRoastPersonaId(json['persona'] as String),
      type: RoastType.parse(json['type'] as String),
      tags: _parseTags(json['tags']),
      dayparts: _parseDayparts(rawDayparts),
      level: RoastLevel.parse(json['level'] as String),
      weight: ((json['weight'] ?? 1) as num).toDouble(),
      text: json['text'] as String,
      fallbackText: json['fallback_text'] as String?,
      conditionCodes: _parseConditionCodes(json['condition_codes']),
      tempMinF: (json['temp_min_f'] as num?)?.round(),
      tempMaxF: (json['temp_max_f'] as num?)?.round(),
      humidityMin: (json['humidity_min'] as num?)?.round(),
      windMinMph: (json['wind_min_mph'] as num?)?.toDouble(),
      precipMinPercent: (json['precip_min_percent'] as num?)?.round(),
      locale: (json['locale'] as String?) ?? 'en-US',
    );
  }

  bool matchesStaticWeatherConstraints(WeatherRoastContext context) {
    if (conditionCodes.isNotEmpty &&
        context.conditionCode != null &&
        !conditionCodes.contains(context.conditionCode)) {
      return false;
    }

    final minTemp = tempMinF;
    if (minTemp != null && context.tempF < minTemp) return false;

    final maxTemp = tempMaxF;
    if (maxTemp != null && context.tempF > maxTemp) return false;

    final minHumidity = humidityMin;
    if (minHumidity != null && context.humidity < minHumidity) return false;

    final minWind = windMinMph;
    if (minWind != null && context.windMph < minWind) return false;

    final minPrecip = precipMinPercent;
    if (minPrecip != null && context.precipChance < minPrecip) return false;

    return true;
  }

  bool matchesDaypart(Daypart daypart) {
    return dayparts.contains(Daypart.any) || dayparts.contains(daypart);
  }
}

class WeatherRoastContext {
  const WeatherRoastContext({
    required this.city,
    required this.tempF,
    required this.feelsLikeF,
    required this.condition,
    required this.humidity,
    required this.windMph,
    required this.precipChance,
    required this.daypart,
    required this.tags,
    this.conditionCode,
  });

  final String city;
  final int tempF;
  final int feelsLikeF;
  final String condition;
  final int humidity;
  final double windMph;
  final int precipChance;
  final Daypart daypart;
  final Set<WeatherRoastTag> tags;
  final int? conditionCode;

  factory WeatherRoastContext.fromWeatherBundle(
    WeatherBundle weather, {
    DateTime? now,
  }) {
    final current = weather.current;
    final observedAt = now ?? current.displayUpdatedAt;
    final tempF = current.temperatureF.round();
    final feelsLikeF = current.feelsLikeF.round();
    final windMph = current.windMph;
    final precipChance = current.precipitationChance;
    final conditionCode = current.weatherId;
    final normalizedCondition = current.condition.toLowerCase();
    final weatherMain = (current.weatherMain ?? '').toLowerCase();
    final tags = <WeatherRoastTag>{};

    if (tempF >= 90) tags.add(WeatherRoastTag.hot);
    if (tempF <= 32) tags.add(WeatherRoastTag.cold);
    if (current.humidity >= 65 && tempF >= 75) {
      tags.add(WeatherRoastTag.humid);
    }
    if (current.humidity <= 30) tags.add(WeatherRoastTag.dry);
    if (windMph >= 20) tags.add(WeatherRoastTag.windy);
    if (current.uvIndex >= 7) tags.add(WeatherRoastTag.highUv);
    if (_isBadAir(current.aqi, current.aqiCategory)) {
      tags.add(WeatherRoastTag.badAir);
    }

    if (_isStorm(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.storm);
    }
    if (_isSnow(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.snow);
    }
    if (_isFog(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.fog);
    }
    if (_isRain(conditionCode, normalizedCondition, weatherMain) ||
        precipChance >= 50) {
      tags.add(
        _isHeavyRain(
          conditionCode,
          normalizedCondition,
          precipChance,
          current.rainLastHour,
        )
            ? WeatherRoastTag.heavyRain
            : WeatherRoastTag.lightRain,
      );
    }
    if (_isClear(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.clear);
    }
    if (_isPartlyCloudy(conditionCode, normalizedCondition)) {
      tags.add(WeatherRoastTag.partlyCloudy);
    } else if (_isCloudy(conditionCode, normalizedCondition, weatherMain)) {
      tags.add(WeatherRoastTag.cloudy);
    }

    if (weather.alerts.isNotEmpty ||
        current.alertIds.isNotEmpty ||
        _mentionsSevereWeather(normalizedCondition)) {
      tags.add(WeatherRoastTag.severe);
    }

    final gross = tags.contains(WeatherRoastTag.humid) ||
        tags.contains(WeatherRoastTag.heavyRain) ||
        tags.contains(WeatherRoastTag.badAir) ||
        tags.contains(WeatherRoastTag.fog) ||
        (tags.contains(WeatherRoastTag.hot) &&
            tags.contains(WeatherRoastTag.highUv));
    if (gross) tags.add(WeatherRoastTag.gross);

    final commuteRisk = tags.contains(WeatherRoastTag.lightRain) ||
        tags.contains(WeatherRoastTag.heavyRain) ||
        tags.contains(WeatherRoastTag.storm) ||
        tags.contains(WeatherRoastTag.snow) ||
        tags.contains(WeatherRoastTag.fog) ||
        tags.contains(WeatherRoastTag.windy) ||
        tags.contains(WeatherRoastTag.severe);
    if (commuteRisk) tags.add(WeatherRoastTag.commuteRisk);

    final nice = tempF >= 60 &&
        tempF <= 82 &&
        !gross &&
        !commuteRisk &&
        !tags.contains(WeatherRoastTag.cold);
    if (nice) tags.add(WeatherRoastTag.nice);

    final weekend = observedAt.weekday == DateTime.friday ||
        observedAt.weekday == DateTime.saturday ||
        observedAt.weekday == DateTime.sunday;
    if (weekend && nice) tags.add(WeatherRoastTag.weekendGood);

    if (tags.isEmpty) tags.add(WeatherRoastTag.fallback);

    return WeatherRoastContext(
      city: _cityName(current.locationName),
      tempF: tempF,
      feelsLikeF: feelsLikeF,
      condition: current.condition,
      humidity: current.humidity,
      windMph: windMph,
      precipChance: precipChance,
      daypart: Daypart.fromDateTime(observedAt),
      tags: tags,
      conditionCode: conditionCode,
    );
  }

  String render(String template) {
    final values = <String, String>{
      'city': city.trim().isEmpty ? 'your area' : city,
      'temp': tempF.toString(),
      'temp_unit': '°F',
      'feels_like': feelsLikeF.toString(),
      'condition': condition.trim().isEmpty ? 'weather' : condition,
      'humidity': humidity.toString(),
      'wind_mph': windMph.round().toString(),
      'precip_chance': precipChance.toString(),
      'daypart': daypart.name,
    };

    final rendered =
        template.replaceAllMapped(RegExp(r'\{([a-zA-Z0-9_]+)\}'), (match) {
      final key = match.group(1)!;
      return values[key] ?? '';
    });
    return _cleanRenderedText(rendered);
  }

  static WeatherRoastContext fallback({
    String city = 'your area',
    Daypart daypart = Daypart.any,
  }) {
    return WeatherRoastContext(
      city: city,
      tempF: 0,
      feelsLikeF: 0,
      condition: 'weather',
      humidity: 0,
      windMph: 0,
      precipChance: 0,
      daypart: daypart,
      tags: const {WeatherRoastTag.fallback},
    );
  }
}

String normalizeRoastPersonaId(String id) {
  final normalized = id.trim().toLowerCase().replaceAll(' ', '_');
  return legacyWeatherRoastPersonaAliases[normalized] ?? normalized;
}

List<WeatherRoastTag> _parseTags(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((item) => WeatherRoastTag.parse(item.toString()))
        .toList(growable: false);
  }
  return value
      .toString()
      .split(RegExp(r'[|,]'))
      .where((tag) => tag.trim().isNotEmpty)
      .map(WeatherRoastTag.parse)
      .toList(growable: false);
}

List<Daypart> _parseDayparts(Object? value) {
  if (value == null) return const [Daypart.any];
  if (value is List) {
    return value
        .map((item) => Daypart.parse(item.toString()))
        .toList(growable: false);
  }
  final parsed = value
      .toString()
      .split(RegExp(r'[|,]'))
      .where((daypart) => daypart.trim().isNotEmpty)
      .map(Daypart.parse)
      .toList(growable: false);
  return parsed.isEmpty ? const [Daypart.any] : parsed;
}

List<int> _parseConditionCodes(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((code) => (code as num).round()).toList(growable: false);
  }
  return value
      .toString()
      .split(RegExp(r'[|,]'))
      .where((code) => code.trim().isNotEmpty)
      .map((code) => int.parse(code.trim()))
      .toList(growable: false);
}

bool _isBadAir(int aqi, String category) {
  final normalized = category.toLowerCase();
  return aqi >= 151 ||
      normalized.contains('unhealthy') ||
      normalized.contains('hazardous');
}

bool _isStorm(int? code, String condition, String main) {
  return (code != null && code >= 200 && code < 300) ||
      main.contains('thunderstorm') ||
      condition.contains('thunder') ||
      condition.contains('storm');
}

bool _isSnow(int? code, String condition, String main) {
  return (code != null && code >= 600 && code < 700) ||
      main.contains('snow') ||
      condition.contains('snow') ||
      condition.contains('sleet');
}

bool _isFog(int? code, String condition, String main) {
  const fogCodes = {701, 711, 721, 731, 741, 751, 761, 762, 771, 781};
  return (code != null && fogCodes.contains(code)) ||
      main.contains('mist') ||
      main.contains('haze') ||
      condition.contains('fog') ||
      condition.contains('mist') ||
      condition.contains('haze') ||
      condition.contains('smoke') ||
      condition.contains('dust');
}

bool _isRain(int? code, String condition, String main) {
  return (code != null && code >= 500 && code < 600) ||
      (code != null && code >= 300 && code < 400) ||
      main.contains('rain') ||
      main.contains('drizzle') ||
      condition.contains('rain') ||
      condition.contains('drizzle') ||
      condition.contains('shower');
}

bool _isHeavyRain(
  int? code,
  String condition,
  int precipChance,
  double? rainLastHour,
) {
  return (code != null && code >= 502 && code < 600) ||
      condition.contains('heavy') ||
      precipChance >= 75 ||
      (rainLastHour ?? 0) >= 0.25;
}

bool _isClear(int? code, String condition, String main) {
  return code == 800 ||
      main.contains('clear') ||
      condition.contains('clear') ||
      condition.contains('sunny');
}

bool _isPartlyCloudy(int? code, String condition) {
  return code == 801 ||
      condition.contains('partly') ||
      condition.contains('few clouds') ||
      condition.contains('mostly sunny');
}

bool _isCloudy(int? code, String condition, String main) {
  return (code != null && code >= 802 && code <= 804) ||
      main.contains('cloud') ||
      condition.contains('cloud') ||
      condition.contains('overcast');
}

bool _mentionsSevereWeather(String condition) {
  return condition.contains('severe') ||
      condition.contains('tornado') ||
      condition.contains('hurricane') ||
      condition.contains('warning');
}

String _cityName(String locationName) {
  final trimmed = locationName.trim();
  if (trimmed.isEmpty) return 'your area';
  return trimmed.split(',').first.trim();
}

String _cleanRenderedText(String text) {
  var cleaned = text
      .replaceAllMapped(
        RegExp(r'\s+([,.!?;:])'),
        (match) => match.group(1)!,
      )
      .replaceAllMapped(
        RegExp(r'[,;:]\s*([.!?])'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  return cleaned;
}

String _iso8601Seconds(DateTime value) {
  final utc = value.toUtc();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${twoDigits(utc.month)}-'
      '${twoDigits(utc.day)}T'
      '${twoDigits(utc.hour)}:'
      '${twoDigits(utc.minute)}:'
      '${twoDigits(utc.second)}Z';
}
