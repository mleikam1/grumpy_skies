import 'roast_content_models.dart';

class RoastPackValidationResult {
  const RoastPackValidationResult(
      {this.errors = const [], this.warnings = const []});
  final List<String> errors;
  final List<String> warnings;
  bool get isValid => errors.isEmpty;
}

/// Validation runs before installation and in the editorial build, never in a
/// widget build. Private notes and provenance are deliberately not runtime keys.
class RoastPackValidator {
  static const expectedSchemaVersion = 1;
  const RoastPackValidator();

  static const _packKeys = {
    'schema_version',
    'pack_version',
    'generated_at',
    'personas',
    'roasts',
    'rules',
    'rule_schema_version'
  };
  static const _lineKeys = {
    'id',
    'persona',
    'type',
    'tags',
    'dayparts',
    'daypart',
    'level',
    'weight',
    'text',
    'fallback_text',
    'condition_codes',
    'temp_min_f',
    'temp_max_f',
    'humidity_min',
    'wind_min_mph',
    'precip_min_percent',
    'locale',
    'mood',
    'family_id',
    'rule_id',
    'status',
    'valid_from',
    'valid_until',
    'regions'
  };
  static const _ruleKeys = {
    'id',
    'required_all',
    'any_of',
    'forbidden',
    'scopes',
    'max_age_minutes',
    'placeholders',
    'numeric'
  };
  static const _moods = {
    'happy',
    'excited',
    'hyped',
    'cozy',
    'complaining',
    'annoyed',
    'sad',
    'worried',
    'confident',
    'neutral'
  };
  static const _scopes = {'current', 'hourly', 'today', 'commute', 'weekend'};
  static const _numericUnits = {
    'temperature': 'F',
    'feels_like': 'F',
    'wind': 'mph',
    'precip_probability': 'percent',
    'observed_rain': 'mm',
    'aqi': 'openweather_1_5',
    'temp_f': 'fahrenheit',
    'feels_like_f': 'fahrenheit',
    'humidity': 'percent',
    'wind_mph': 'mph',
    'precip_chance': 'percent',
    'rain_mm_per_hour': 'mm/hour',
    'uv_index': 'index',
  };

  /// Use before fromJson: deserializers intentionally retain legacy aliases but
  /// must not silently drop new misspelled fields from untrusted updates.
  RoastPackValidationResult validateJson(Map<String, dynamic> json) {
    final errors = <String>[];
    void unknown(Map map, Set<String> allowed, String where) {
      for (final key in map.keys) {
        if (!allowed.contains(key)) errors.add('Unknown field $key in $where.');
      }
    }

    try {
      unknown(json, _packKeys, 'pack');
      if (json['schema_version'] is! int ||
          json['schema_version'] != 1 ||
          (json.containsKey('rule_schema_version') &&
              (json['rule_schema_version'] is! int ||
                  json['rule_schema_version'] != 1))) {
        errors.add('Unsupported or non-integer schema version.');
      }
      for (final raw in (json['roasts'] as List? ?? const [])) {
        if (raw is Map) {
          unknown(raw, _lineKeys, 'roast ${raw['id']}');
          for (final key in [
            'temp_min_f',
            'temp_max_f',
            'humidity_min',
            'precip_min_percent'
          ]) {
            if (raw[key] != null && raw[key] is! int) {
              errors.add('Non-integer $key for ${raw['id']}.');
            }
          }
          if (raw['condition_codes'] is List &&
              (raw['condition_codes'] as List).any((code) => code is! int)) {
            errors.add('Non-integer condition code for ${raw['id']}.');
          }
          if (raw['mood'] != null && !_moods.contains(raw['mood'])) {
            errors.add('Invalid mood for ${raw['id']}.');
          }
          if (raw['rule_id'] != null && raw['mood'] == null) {
            errors.add(
                'Explicit mood required for rule-based roast ${raw['id']}.');
          }
          for (final key in ['valid_from', 'valid_until']) {
            if (raw[key] != null && !validRoastDate(raw[key].toString())) {
              errors.add(
                  'Invalid $key for ${raw['id']}. Use a real ISO date or UTC timestamp.');
            }
          }
        }
      }
      for (final raw in (json['rules'] as List? ?? const [])) {
        if (raw is Map) {
          unknown(raw, _ruleKeys, 'rule ${raw['id']}');
          if (raw['max_age_minutes'] != null &&
              raw['max_age_minutes'] is! int) {
            errors
                .add('Freshness must be integer minutes in rule ${raw['id']}.');
          }
          for (final number in (raw['numeric'] as List? ?? const [])) {
            if (number is Map) {
              unknown(number, {'fact', 'unit', 'min', 'max'},
                  'numeric rule ${raw['id']}');
            }
          }
        }
      }
      final parsed = validatePack(RoastPack.fromJson(json));
      return RoastPackValidationResult(
          errors: [...errors, ...parsed.errors], warnings: parsed.warnings);
    } catch (error) {
      return RoastPackValidationResult(
          errors: [...errors, 'Invalid pack structure: $error']);
    }
  }

  RoastPackValidationResult validatePack(RoastPack pack) {
    final errors = <String>[];
    final warnings = <String>[];
    final seenIds = <String>{};
    final seenText = <String, String>{};
    final fallbackKeys = <String>{};
    final json = pack.toJson();
    final rules = <String, Map>{};
    if (pack.schemaVersion != expectedSchemaVersion) {
      errors.add(
          'Unsupported schema_version ${pack.schemaVersion}; expected $expectedSchemaVersion.');
    }
    if ((json['rule_schema_version'] ?? 1) != 1) {
      errors.add('Unsupported rule_schema_version.');
    }
    if (pack.packVersion.trim().isEmpty) {
      errors.add('pack_version is required.');
    }
    if (pack.roasts.isEmpty) {
      errors.add('Pack must contain at least one roast.');
    }
    if (pack.personas.toSet().length != pack.personas.length) {
      errors.add('Duplicate persona in personas list.');
    }
    for (final persona in pack.personas) {
      if (!supportedWeatherRoastPersonas
          .contains(normalizeRoastPersonaId(persona))) {
        errors.add('Unknown persona in personas list: $persona.');
      }
    }
    for (final raw in (json['rules'] as List? ?? const [])) {
      final rule = raw as Map;
      final id = rule['id'].toString();
      if (rules.containsKey(id)) errors.add('Duplicate rule id: $id.');
      rules[id] = rule;
      errors.addAll(_ruleErrors(rule));
    }
    // Index by a shared meaningful token instead of all-pairs comparison. Near
    // duplicates are rejected, not silently counted as new editorial material.
    final tokenIndex = <String, Set<String>>{};
    final textTokens = <String, Set<String>>{};
    for (final roast in pack.roasts) {
      errors.addAll(validateRoast(roast));
      if (!pack.personas.contains(roast.persona)) {
        errors.add('Undeclared persona ${roast.persona} for ${roast.id}.');
      }
      if (!seenIds.add(roast.id)) {
        errors.add('Duplicate roast id: ${roast.id}.');
      }
      final normalized = normalizeText(roast.text);
      final previous = seenText[normalized];
      if (previous != null) {
        errors.add('Duplicate text: ${roast.id} and $previous.');
      }
      seenText[normalized] = roast.id;
      final tokens =
          normalized.split(' ').where((word) => word.length > 2).toSet();
      final candidates = <String>{};
      for (final token in tokens) {
        candidates.addAll(tokenIndex[token] ?? const {});
      }
      for (final other in candidates) {
        final old = textTokens[other]!;
        if (tokens.length >= 5 && old.length >= 5) {
          final similarity = 2 *
              tokens.intersection(old).length /
              (tokens.length + old.length);
          if (similarity >= .85 && previous != other) {
            errors.add(
                'Near-duplicate text: ${roast.id} and $other (${(similarity * 100).round()}% token overlap).');
          }
        }
      }
      textTokens[roast.id] = tokens;
      for (final token in tokens) {
        tokenIndex.putIfAbsent(token, () => {}).add(roast.id);
      }
      if (roast.text.length > 220) {
        warnings.add('Long copy (${roast.text.length} chars): ${roast.id}.');
      }
      final line = roast.toJson();
      final ruleId = line['rule_id'];
      if (ruleId != null && !rules.containsKey(ruleId)) {
        errors.add('Unknown rule $ruleId for ${roast.id}.');
      }
      final rule = rules[ruleId];
      if (rule != null) {
        final requested = RegExp(r'\{([a-zA-Z0-9_]+)\}')
            .allMatches(roast.text)
            .map((m) => m.group(1))
            .toSet();
        final requirements =
            (rule['placeholders'] as List? ?? const []).toSet();
        if (!requirements.containsAll(requested)) {
          errors.add(
              'Rule $ruleId must require all placeholders in ${roast.id}.');
        }
      }
      if (roast.isFallback && (line['status'] ?? 'active') == 'active') {
        if (roast.level != RoastLevel.mild ||
            roast.conditionCodes.isNotEmpty ||
            roast.tempMinF != null ||
            roast.tempMaxF != null ||
            roast.humidityMin != null ||
            roast.windMinMph != null ||
            roast.precipMinPercent != null ||
            roast.tags.any((tag) => tag != WeatherRoastTag.fallback) ||
            !roast.dayparts.contains(Daypart.any) ||
            RegExp(r'[{}]').hasMatch(roast.text) ||
            (line['regions'] as List? ?? const []).isNotEmpty ||
            line['valid_from'] != null ||
            line['valid_until'] != null ||
            (rule != null && _hasRequiredWeather(rule))) {
          errors.add(
              'Fallback must be unconditional, mild and context-free: ${roast.id}.');
        } else {
          fallbackKeys.add('${roast.persona}|${roast.locale}');
        }
      }
    }
    for (final roast in pack.roasts) {
      if (!fallbackKeys.contains('${roast.persona}|${roast.locale}')) {
        final error =
            'Missing mild context-free fallback for ${roast.persona}/${roast.locale}.';
        if (!errors.contains(error)) errors.add(error);
      }
    }
    return RoastPackValidationResult(
        errors: List.unmodifiable(errors),
        warnings: List.unmodifiable(warnings));
  }

  List<String> validateRoast(RoastLine roast) {
    final errors = <String>[];
    final json = roast.toJson();
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$').hasMatch(roast.id)) {
      errors.add('Invalid roast id: ${roast.id}.');
    }
    if (!supportedWeatherRoastPersonas.contains(roast.persona)) {
      errors.add('Unknown persona for ${roast.id}: ${roast.persona}.');
    }
    if (roast.text.trim().isEmpty) {
      errors.add('Roast text is required for ${roast.id}.');
    }
    if (!roast.weight.isFinite || roast.weight <= 0 || roast.weight > 1000) {
      errors.add('Weight must be finite, > 0 and <= 1000 for ${roast.id}.');
    }
    if (roast.tags.isEmpty) {
      errors.add('At least one weather tag is required for ${roast.id}.');
    }
    if (roast.dayparts.isEmpty) {
      errors.add('At least one daypart is required for ${roast.id}.');
    }
    if (roast.tempMinF != null &&
        roast.tempMaxF != null &&
        roast.tempMinF! > roast.tempMaxF!) {
      errors.add('temp_min_f must be <= temp_max_f for ${roast.id}.');
    }
    for (final pair in {
      'humidity_min': roast.humidityMin,
      'precip_min_percent': roast.precipMinPercent
    }.entries) {
      if (pair.value != null && (pair.value! < 0 || pair.value! > 100)) {
        errors.add('${pair.key} outside 0..100 for ${roast.id}.');
      }
    }
    if (roast.windMinMph != null &&
        (!roast.windMinMph!.isFinite || roast.windMinMph! < 0)) {
      errors.add('Invalid wind_min_mph for ${roast.id}.');
    }
    if (!RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$').hasMatch(roast.locale)) {
      errors.add('Invalid locale for ${roast.id}.');
    }
    if (json['mood'] != null && !_moods.contains(json['mood'])) {
      errors.add('Invalid mood for ${roast.id}.');
    }
    if (!const {'active', 'draft', 'retired', 'disabled'}
        .contains(json['status'] ?? 'active')) {
      errors.add('Invalid status for ${roast.id}.');
    }
    final start = json['valid_from'] == null
        ? null
        : DateTime.tryParse(json['valid_from']);
    final end = json['valid_until'] == null
        ? null
        : DateTime.tryParse(json['valid_until']);
    if (start != null && end != null && start.isAfter(end)) {
      errors.add('Reversed validity dates for ${roast.id}.');
    }
    errors.addAll(_placeholderErrors(roast.text, roast.id));
    if (roast.fallbackText != null) {
      errors.addAll(_placeholderErrors(roast.fallbackText!, roast.id));
      if (roast.fallbackText!.trim().isEmpty ||
          RegExp(r'[{}]').hasMatch(roast.fallbackText!)) {
        errors.add(
            'Legacy fallback_text must be a complete context-free literal for ${roast.id}.');
      }
    }
    return errors;
  }

  List<String> _ruleErrors(Map rule) {
    final errors = <String>[];
    final id = rule['id'];
    if (id is! String || !RegExp(r'^[a-z][a-z0-9_.-]{0,95}$').hasMatch(id)) {
      errors.add('Invalid rule id: $id.');
    }
    final facts = {
      for (final tag in WeatherRoastTag.values) tag.wireValue,
      'observed_rain',
      'forecast_rain_probability',
      'activity_walking',
      'activity_commuting',
      'activity_grilling',
      'activity_outdoor_exercise',
      'activity_staying_in'
    };
    final required = (rule['required_all'] as List? ?? const []).toSet();
    final forbidden = (rule['forbidden'] as List? ?? const []).toSet();
    final groups = (rule['any_of'] as List? ?? const []);
    for (final fact in [
      ...required,
      ...forbidden,
      for (final group in groups) ...(group as List)
    ]) {
      if (!facts.contains(fact)) errors.add('Unknown fact $fact in rule $id.');
    }
    if (required.intersection(forbidden).isNotEmpty) {
      errors.add('Impossible required/forbidden facts in rule $id.');
    }
    for (final exclusive in [
      {'clear', 'cloudy'},
      {'clear', 'partly_cloudy'},
      {'hot', 'cold'},
      {'humid', 'dry'},
      {'light_rain', 'heavy_rain'}
    ]) {
      if (required.containsAll(exclusive)) {
        errors.add(
            'Impossible mutually exclusive facts in rule $id: $exclusive.');
      }
    }
    for (final group in groups) {
      if ((group as List).isEmpty || group.every(forbidden.contains)) {
        errors.add('Impossible any_of group in rule $id.');
      }
    }
    for (final scope in (rule['scopes'] as List? ?? const [])) {
      if (!_scopes.contains(scope)) {
        errors.add('Unknown scope $scope in rule $id.');
      }
    }
    final age = rule['max_age_minutes'];
    if (age != null && (age is! int || age <= 0 || age > 10080)) {
      errors.add('Invalid freshness in rule $id.');
    }
    for (final placeholder in (rule['placeholders'] as List? ?? const [])) {
      if (!supportedRoastPlaceholders.contains(placeholder)) {
        errors.add('Invalid placeholder {$placeholder} in rule $id.');
      }
    }
    for (final raw in (rule['numeric'] as List? ?? const [])) {
      final number = raw as Map;
      if (!_numericUnits.containsKey(number['fact']) ||
          (_numericUnits[number['fact']] != number['unit'] &&
              !(number['fact'] == 'aqi' && number['unit'] == 'us_epa'))) {
        errors.add(
            'Unknown fact/unit ${number['fact']}/${number['unit']} in rule $id.');
      }
      final min = number['min'] as num?;
      final max = number['max'] as num?;
      if (min == null && max == null ||
          min != null && !min.isFinite ||
          max != null && !max.isFinite ||
          min != null && max != null && min > max) {
        errors.add('Impossible numeric constraint in rule $id.');
      }
      final unit = number['unit'];
      if (unit == 'percent' &&
          ((min != null && (min < 0 || min > 100)) ||
              (max != null && (max < 0 || max > 100)))) {
        errors.add('Percentage outside 0..100 in rule $id.');
      }
      if (number['fact'] == 'aqi' &&
          unit == 'openweather_1_5' &&
          ((min != null && (min < 1 || min > 5)) ||
              (max != null && (max < 1 || max > 5)))) {
        errors.add('OpenWeather AQI outside 1..5 in rule $id.');
      }
    }
    return errors;
  }

  bool _hasRequiredWeather(Map rule) =>
      (rule['required_all'] as List? ?? const []).isNotEmpty ||
      (rule['any_of'] as List? ?? const []).isNotEmpty ||
      (rule['numeric'] as List? ?? const []).isNotEmpty ||
      (rule['placeholders'] as List? ?? const []).isNotEmpty ||
      (rule['forbidden'] as List? ?? const []).isNotEmpty ||
      (rule['scopes'] as List? ?? const []).isNotEmpty ||
      rule['max_age_minutes'] != null;

  List<String> _placeholderErrors(String text, String id) {
    final errors = <String>[];
    final expression = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    for (final match in expression.allMatches(text)) {
      if (!supportedRoastPlaceholders.contains(match.group(1))) {
        errors.add('Invalid placeholder {${match.group(1)}} in $id.');
      }
    }
    if (text.replaceAll(expression, '').contains(RegExp(r'[{}]'))) {
      errors.add('Malformed placeholder in $id.');
    }
    return errors;
  }

  static String normalizeText(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'\{[^}]+\}'), ' value ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

/// Reject Dart's otherwise permissive overflow normalization (February 31).
bool validRoastDate(String raw) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z)?$')
      .hasMatch(raw)) {
    return false;
  }
  final parsed = DateTime.tryParse(raw);
  return parsed != null &&
      parsed.toIso8601String().substring(0, 10) == raw.substring(0, 10) &&
      (!raw.contains('T') ||
          parsed.toIso8601String().substring(11, 19) == raw.substring(11, 19));
}
