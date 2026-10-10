// Pure editorial models shared by the Flutter app and the Dart CSV build tool.
import '../models/roast_mood.dart';
import 'roast_rule_models.dart';
export '../models/roast_mood.dart';
export 'roast_rule_models.dart';

const supportedWeatherRoastPersonas = <String>{
  'karen',
  'frat_bro',
  'two_year_old',
  'politician',
  'grandpa',
};

const legacyWeatherRoastPersonaAliases = <String, String>{
  'frat-bro': 'frat_bro',
  'fratbro': 'frat_bro',
  '2_year_old': 'two_year_old',
  '2-year-old': 'two_year_old',
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
    this.rules = const [],
    this.ruleSchemaVersion = 1,
  });

  final int schemaVersion;
  final String packVersion;
  final DateTime generatedAt;
  final List<String> personas;
  final List<RoastLine> roasts;
  final List<RoastRule> rules;
  final int ruleSchemaVersion;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'pack_version': packVersion,
        'generated_at': _iso8601Seconds(generatedAt.toUtc()),
        'personas': personas,
        if (rules.isNotEmpty) 'rules': rules.map((r) => r.toJson()).toList(),
        if (rules.isNotEmpty) 'rule_schema_version': ruleSchemaVersion,
        'roasts': roasts.map((roast) => roast.toJson()).toList(),
      };

  factory RoastPack.fromJson(Map<String, dynamic> json) {
    return RoastPack(
      schemaVersion: (json['schema_version'] as num).round(),
      ruleSchemaVersion: (json['rule_schema_version'] as num?)?.toInt() ?? 1,
      rules: List<RoastRule>.unmodifiable([
        for (final rule in json['rules'] ?? const [])
          RoastRule.fromJson((rule as Map).cast<String, dynamic>())
      ]),
      packVersion: json['pack_version'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      personas: List<String>.unmodifiable(
          ((json['personas'] as List?) ?? const [])
              .map((persona) => persona.toString())),
      roasts: List<RoastLine>.unmodifiable(
          ((json['roasts'] as List?) ?? const []).map(
        (item) => RoastLine.fromJson(
          (item as Map).cast<String, dynamic>(),
        ),
      )),
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
    this.mood,
    this.familyId,
    this.ruleId,
    this.status = 'active',
    this.validFrom,
    this.validUntil,
    this.regions = const [],
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
  final RoastMood? mood;
  final String? familyId;
  final String? ruleId;
  final String status;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final List<String> regions;

  String get effectiveFamilyId => familyId ?? id;
  // Preserve the current content-first legacy inference and expression registry.
  RoastMood get effectiveMood => RoastMoodResolver.resolve(
      personaId: persona, text: text, explicitMood: mood);

  bool get isFallback => tags.contains(WeatherRoastTag.fallback);

  bool get isSevere => tags.contains(WeatherRoastTag.severe);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (mood != null) 'mood': mood!.name,
      if (familyId != null) 'family_id': familyId,
      if (ruleId != null) 'rule_id': ruleId,
      if (status != 'active') 'status': status,
      if (validFrom != null) 'valid_from': validFrom!.toUtc().toIso8601String(),
      if (validUntil != null)
        'valid_until': validUntil!.toUtc().toIso8601String(),
      if (regions.isNotEmpty) 'regions': regions,
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
      mood: RoastMood.tryParse(json['mood']),
      familyId: json['family_id'] as String?,
      ruleId: json['rule_id'] as String?,
      status: (json['status'] as String?) ?? 'active',
      validFrom: json['valid_from'] == null
          ? null
          : DateTime.parse(json['valid_from'] as String),
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.parse(json['valid_until'] as String),
      regions: List<String>.unmodifiable(json['regions'] ?? const []),
      persona: normalizeRoastPersonaId(json['persona'] as String),
      type: RoastType.parse(json['type'] as String),
      tags: List.unmodifiable(_parseTags(json['tags'])),
      dayparts: List.unmodifiable(_parseDayparts(rawDayparts)),
      level: RoastLevel.parse(json['level'] as String),
      weight: ((json['weight'] ?? 1) as num).toDouble(),
      text: json['text'] as String,
      fallbackText: json['fallback_text'] as String?,
      conditionCodes:
          List.unmodifiable(_parseConditionCodes(json['condition_codes'])),
      tempMinF: (json['temp_min_f'] as num?)?.round(),
      tempMaxF: (json['temp_max_f'] as num?)?.round(),
      humidityMin: (json['humidity_min'] as num?)?.round(),
      windMinMph: (json['wind_min_mph'] as num?)?.toDouble(),
      precipMinPercent: (json['precip_min_percent'] as num?)?.round(),
      locale: (json['locale'] as String?) ?? 'en-US',
    );
  }

  bool matchesDaypart(Daypart daypart) {
    return dayparts.contains(Daypart.any) || dayparts.contains(daypart);
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
