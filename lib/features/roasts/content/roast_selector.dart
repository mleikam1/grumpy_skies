import 'dart:math';

import '../../../models/weather_safety.dart';
import 'weather_roast_models.dart';

/// A display, history entry, share and meme all carry this same value. No UI
/// consumer should select again to rediscover the caption or expression.
class RoastSelection {
  const RoastSelection({
    required this.line,
    required this.renderedText,
    required this.packVersion,
    required this.primaryWeatherTag,
    this.weatherTimestamp,
    this.windowStart,
    this.windowEnd,
    this.selectedAt,
    this.reason = 'eligible',
    this.source = 'bundled',
    this.scope = RoastScope.current,
    this.safetyStatus = WeatherSafetyStatus.unknown,
    this.selectionId,
    this.requiresVerifiedAlerts = false,
  });
  final String? selectionId;
  final bool requiresVerifiedAlerts;
  final RoastLine line;
  final String renderedText;
  final String packVersion;
  final WeatherRoastTag primaryWeatherTag;
  final DateTime? weatherTimestamp;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final DateTime? selectedAt;
  final String reason;
  final String source;
  final RoastScope scope;
  final WeatherSafetyStatus safetyStatus;
  String get id => line.id;
  String get familyId => line.effectiveFamilyId;
  String get persona => line.persona;
  RoastMood get mood => line.effectiveMood;
  String? get ruleId => line.ruleId;
  Map<String, dynamic> toJson() => {
        'selection_id': selectionId,
        'requires_verified_alerts': requiresVerifiedAlerts,
        'line': line.toJson(),
        'rendered_text': renderedText,
        'pack_version': packVersion,
        'primary_weather_tag': primaryWeatherTag.wireValue,
        'weather_timestamp': weatherTimestamp?.toUtc().toIso8601String(),
        'window_start': windowStart?.toUtc().toIso8601String(),
        'window_end': windowEnd?.toUtc().toIso8601String(),
        'selected_at': selectedAt?.toUtc().toIso8601String(),
        'reason': reason,
        'source': source,
        'scope': scope.name,
        'safety_status': safetyStatus.name,
      };
  factory RoastSelection.fromJson(Map<String, dynamic> json) => RoastSelection(
        selectionId: json['selection_id'] as String?,
        requiresVerifiedAlerts: json['requires_verified_alerts'] == true ||
            (((json['line'] as Map)['tags'] as List?) ?? const [])
                .any((tag) => {'nice', 'weekend_good'}.contains(tag)),
        line: RoastLine.fromJson((json['line'] as Map).cast<String, dynamic>()),
        renderedText: json['rendered_text'] as String,
        packVersion: json['pack_version'] as String,
        primaryWeatherTag:
            WeatherRoastTag.parse(json['primary_weather_tag'] as String),
        weatherTimestamp: _date(json['weather_timestamp']),
        windowStart: _date(json['window_start']),
        windowEnd: _date(json['window_end']),
        selectedAt: _date(json['selected_at']),
        reason: json['reason'] as String,
        source: json['source'] as String,
        scope: RoastScope.values.byName(json['scope'] as String),
        safetyStatus:
            WeatherSafetyStatus.values.byName(json['safety_status'] as String),
      );
  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.parse(raw as String);
}

class RoastSelector {
  const RoastSelector();
  static final _indexes = Expando<Map<String, List<RoastLine>>>();
  static final _rules = Expando<Map<String, RoastRule>>();

  List<RoastLine> candidates(RoastPack pack, String persona, RoastType type) {
    final index = _indexes[pack] ??= _index(pack);
    return index['${normalizeRoastPersonaId(persona)}|${type.name}'] ??
        const [];
  }

  static Map<String, List<RoastLine>> _index(RoastPack pack) {
    final result = <String, List<RoastLine>>{};
    for (final line in pack.roasts) {
      (result['${normalizeRoastPersonaId(line.persona)}|${line.type.name}'] ??=
              [])
          .add(line);
    }
    for (final lines in result.values) {
      lines.sort((a, b) => a.id.compareTo(b.id));
    }
    return result;
  }

  /// Inspector and tests use the same hard eligibility path as production.
  List<String> eligibilityFailures(
      {required RoastLine line,
      required RoastPack pack,
      required WeatherRoastContext context,
      required String persona,
      required RoastType type,
      RoastLevel maxLevel = RoastLevel.medium,
      Set<String> disabledIds = const {}}) {
    final failed = <String>[];
    if (normalizeRoastPersonaId(line.persona) !=
        normalizeRoastPersonaId(persona)) {
      failed.add('persona');
    }
    if (line.type != type) failed.add('type');
    if (!maxLevel.allows(line.level)) failed.add('intensity');
    if (line.locale.toLowerCase() != context.locale.toLowerCase()) {
      failed.add('locale');
    }
    if (line.status != 'active' || disabledIds.contains(line.id)) {
      failed.add('status');
    }
    if (!line.weight.isFinite || line.weight <= 0) failed.add('weight');
    if (context.requiresSafetyMessage) failed.add('application_safety_gate');
    if (line.isSevere) failed.add('safety_copy_application_owned');
    if (!line.matchesDaypart(context.daypart)) failed.add('daypart');
    if (!line.matchesStaticWeatherConstraints(context)) {
      failed.add('required_numeric_or_code');
    }
    if (!context.canRender(line.text)) failed.add('required_placeholder');
    final now = context.evaluatedAt;
    if (line.validFrom != null &&
        (now == null || now.isBefore(line.validFrom!))) {
      failed.add('valid_from');
    }
    if (line.validUntil != null &&
        (now == null || !now.isBefore(line.validUntil!))) {
      failed.add('valid_until');
    }
    if (line.regions.isNotEmpty &&
        !line.regions.any((r) =>
            r == context.country ||
            r == context.region ||
            r == '${context.country}-${context.region}')) {
      failed.add('region');
    }
    final rule = line.ruleId == null
        ? null
        : (_rules[pack] ??= {
            for (final rule in pack.rules) rule.id: rule
          })[line.ruleId];
    final weatherTags = line.ruleId == null
        ? line.tags.where((t) => t != WeatherRoastTag.fallback).toSet()
        : <WeatherRoastTag>{};
    final ruleFacts = {
      ...?rule?.requiredAll,
      ...?rule?.anyOf.expand((group) => group),
    };
    final ruleWeather = {...ruleFacts, ...?rule?.forbidden}
            .any((f) => !f.startsWith('activity_')) ||
        (rule?.numeric.isNotEmpty ?? false);
    if (!context.tags.containsAll(weatherTags)) failed.add('required_all_tags');
    if (!line.isFallback && !_scopeMatches(type, context.scope)) {
      failed.add('forecast_scope');
    }
    final weatherPlaceholders = RegExp(
            r'\{(temp|feels_like|condition|humidity|wind_mph|precip_chance)\}')
        .hasMatch(line.text);
    final weatherDependent = ruleWeather ||
        weatherTags.isNotEmpty ||
        weatherPlaceholders ||
        line.conditionCodes.isNotEmpty ||
        line.tempMinF != null ||
        line.tempMaxF != null ||
        line.humidityMin != null ||
        line.windMinMph != null ||
        line.precipMinPercent != null;
    if (weatherDependent && !context.hasFreshWeather) failed.add('freshness');
    if (weatherDependent &&
        context.scope != RoastScope.current &&
        !context.forecastComplete) {
      failed.add('forecast_coverage');
    }
    if (requiresVerifiedAlerts(line, pack) &&
        context.safetyStatus != WeatherSafetyStatus.clear) {
      failed.add('alert_availability');
    }
    if (line.ruleId != null) {
      if (rule == null) {
        failed.add('unknown_rule');
      } else {
        final facts = context.facts;
        if (!facts.containsAll(rule.requiredAll)) {
          failed.add('rule_required_all');
        }
        if (rule.anyOf.any((group) => !group.any(facts.contains))) {
          failed.add('rule_any_of');
        }
        if (rule.forbidden.any((fact) => context.factValue(fact) != false)) {
          failed.add('rule_forbidden');
        }
        if (rule.scopes.isNotEmpty && !rule.scopes.contains(context.scope)) {
          failed.add('rule_scope');
        }
        if (rule.placeholders
            .any((p) => !context.placeholderValues.containsKey(p))) {
          failed.add('rule_placeholders');
        }
        if (rule.maxAgeMinutes != null &&
            (now == null ||
                context.observedAt == null ||
                now.difference(context.observedAt!).isNegative ||
                now.difference(context.observedAt!) >
                    Duration(minutes: rule.maxAgeMinutes!))) {
          failed.add('rule_freshness');
        }
        for (final constraint in rule.numeric) {
          final value = _numeric(context, constraint.fact, constraint.unit);
          if (value == null ||
              (constraint.min != null && value < constraint.min!) ||
              (constraint.max != null && value > constraint.max!)) {
            failed.add('rule_numeric:${constraint.fact}');
          }
        }
      }
    }
    return List.unmodifiable(failed);
  }

  RoastSelection select(
      {required RoastPack pack,
      required WeatherRoastContext context,
      required String persona,
      required RoastType type,
      RoastLevel maxLevel = RoastLevel.medium,
      Set<String> disabledIds = const {},
      Iterable<String> recentRoastIds = const [],
      Iterable<String> recentFamilyIds = const [],
      Map<String, DateTime> lastSeen = const {},
      Map<String, double> preferenceWeights = const {},
      String seed = '',
      String source = 'bundled'}) {
    final normalized = normalizeRoastPersonaId(persona);
    if (context.requiresSafetyMessage) {
      return applicationSelection(context, normalized, type,
          reason: 'application_safety_gate', safety: true);
    }
    var available = candidates(pack, normalized, type)
        .where((line) => eligibilityFailures(
                line: line,
                pack: pack,
                context: context,
                persona: normalized,
                type: type,
                maxLevel: maxLevel,
                disabledIds: disabledIds)
            .isEmpty)
        .toList();
    if (available.isEmpty) {
      return applicationSelection(context, normalized, type,
          reason: context.hasFreshWeather
              ? 'no_eligible_content'
              : 'weather_${context.freshness.name}');
    }
    // Maintain relevance before relaxing repetition; a fallback is not an excuse
    // to discard eligible specific content because its pool is small.
    final best = available.map((line) => _score(line, context)).reduce(max);
    available =
        available.where((line) => _score(line, context) >= best - 2).toList();
    final recentIds = recentRoastIds.toSet();
    final families = recentFamilyIds.toSet();
    var pool = available
        .where((l) =>
            !recentIds.contains(l.id) &&
            !families.contains(l.effectiveFamilyId))
        .toList();
    var reason = 'eligible_fresh_family';
    if (pool.isEmpty) {
      pool = available.where((l) => !recentIds.contains(l.id)).toList();
      reason = 'family_reuse';
    }
    if (pool.isEmpty) {
      available.sort((a, b) {
        final da = lastSeen[a.id] ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final db = lastSeen[b.id] ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final time = da.compareTo(db);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
      pool = [available.first];
      reason = 'least_recent_eligible';
    }
    pool.sort((a, b) => a.id.compareTo(b.id));
    final chosen = _weighted(pool,
        '$seed|${context.stableSlot(normalized, type)}', preferenceWeights);
    return RoastSelection(
        requiresVerifiedAlerts: requiresVerifiedAlerts(chosen, pack),
        line: RoastLine.fromJson(chosen.toJson()),
        renderedText: context.render(chosen.text),
        packVersion: pack.packVersion,
        primaryWeatherTag: _primary(context.tags),
        weatherTimestamp: context.observedAt,
        windowStart: context.windowStart,
        windowEnd: context.windowEnd,
        selectedAt: context.evaluatedAt,
        reason: reason,
        source: source,
        scope: context.scope,
        safetyStatus: context.safetyStatus);
  }

  /// Captured on the immutable selection so historical shares do not depend on
  /// whichever editorial rule version happens to be installed later.
  static bool requiresVerifiedAlerts(RoastLine line, RoastPack pack) {
    if (line.tags
        .any({WeatherRoastTag.nice, WeatherRoastTag.weekendGood}.contains)) {
      return true;
    }
    final rule = pack.rules.where((r) => r.id == line.ruleId).firstOrNull;
    return {...?rule?.requiredAll, ...?rule?.anyOf.expand((group) => group)}
        .any({'nice', 'weekend_good'}.contains);
  }

  RoastSelection applicationSelection(
      WeatherRoastContext context, String persona, RoastType type,
      {required String reason, bool safety = false}) {
    final language = context.locale.split(RegExp('[-_]')).first.toLowerCase();
    final text = safety
        ? switch (language) {
            'en' => context.safetyStatus == WeatherSafetyStatus.activeAlert
                ? 'Weather alerts take priority. Read the official alert details.'
                : 'Weather conditions need attention. Check the weather details and available official alerts.',
            'es' =>
              'Consulta los detalles meteorológicos y las alertas oficiales disponibles.',
            'fr' =>
              'Consultez les conditions météo et les alertes officielles disponibles.',
            'de' =>
              'Bitte Wetterdetails und verfügbare amtliche Warnungen prüfen.',
            _ => '',
          }
        : switch (language) {
            'en' => switch (persona) {
                'karen' =>
                  'I have opinions. The suggestion box has been warned.',
                'frat_bro' => 'Bro, even the loading screen needs a spotter.',
                'grandpa' =>
                  'A little patience. Even a good story needs a pause.',
                'politician' =>
                  'My next statement is currently forming a committee.',
                'two_year_old' =>
                  'I have big feelings and a very small microphone.',
                _ => 'A little patience while the next line finds its shoes.',
              },
            'es' => 'La próxima ocurrencia está buscando sus zapatos.',
            'fr' => 'La prochaine réplique cherche encore ses chaussures.',
            'de' => 'Der nächste Spruch sucht noch seine Schuhe.',
            _ => '',
          };
    final line = RoastLine(
        id:
            'application_${safety ? 'safety' : 'fallback'}_${persona}_${context.locale}_${type.name}',
        persona: persona,
        type: type,
        tags: List.unmodifiable(
            [safety ? WeatherRoastTag.severe : WeatherRoastTag.fallback]),
        dayparts: const [Daypart.any],
        level: RoastLevel.mild,
        weight: 1,
        text: text,
        mood: safety ? RoastMood.worried : RoastMood.neutral,
        familyId: 'application_${safety ? 'safety' : 'fallback'}_$persona',
        locale: context.locale);
    return RoastSelection(
        line: line,
        renderedText: text,
        packVersion: 'application-1',
        primaryWeatherTag: _primary(context.tags),
        reason: reason,
        source: 'application',
        weatherTimestamp: context.observedAt,
        windowStart: context.windowStart,
        windowEnd: context.windowEnd,
        selectedAt: context.evaluatedAt,
        scope: context.scope,
        safetyStatus: context.safetyStatus);
  }

  static bool _scopeMatches(RoastType type, RoastScope scope) => switch (type) {
        RoastType.today =>
          scope == RoastScope.current || scope == RoastScope.today,
        RoastType.mood => scope == RoastScope.current,
        RoastType.hourly => scope == RoastScope.hourly,
        RoastType.commute => scope == RoastScope.commute,
        RoastType.weekend => scope == RoastScope.weekend,
      };
  static double? _numeric(WeatherRoastContext c, String fact, String unit) =>
      switch ('$fact|$unit') {
        'temperature|F' || 'temp_f|fahrenheit' => c.tempF?.toDouble(),
        'feels_like|F' || 'feels_like_f|fahrenheit' => c.feelsLikeF?.toDouble(),
        'uv_index|index' => c.uvIndex,
        'humidity|percent' => c.humidity?.toDouble(),
        'wind|mph' || 'wind_mph|mph' => c.windMph,
        'precip_probability|percent' ||
        'precip_chance|percent' =>
          c.precipChance?.toDouble(),
        'observed_rain|mm' || 'rain_mm_per_hour|mm/hour' => c.observedRainMm,
        'aqi|openweather_1_5' =>
          c.aqiScale == 'openweather_1_5' ? c.aqi?.toDouble() : null,
        'aqi|us_epa' => c.aqiScale == 'us_epa' ? c.aqi?.toDouble() : null,
        _ => null,
      };
  static int _score(RoastLine line, WeatherRoastContext c) =>
      (line.isFallback ? 0 : 20) +
      line.tags
              .where(c.tags.contains)
              .where((t) => t != WeatherRoastTag.fallback)
              .length *
          4 +
      (line.dayparts.contains(c.daypart) && c.daypart != Daypart.any ? 2 : 0);
  static RoastLine _weighted(
      List<RoastLine> lines, String seed, Map<String, double> preferences) {
    double weight(RoastLine line) {
      final preference = preferences[line.id] ?? 1.0;
      return line.weight *
          (preference.isFinite ? preference.clamp(0.25, 4.0) : 1.0);
    }

    // FNV multiplication stays within exact JS integer range for native/web parity.
    var hash = 2166136261;
    for (final unit in seed.codeUnits) {
      hash ^= unit;
      hash = (hash * 403 + ((hash & 0xff) << 24)) & 0xffffffff;
    }
    var roll = (hash.toUnsigned(32) / 4294967296.0) *
        lines.fold<double>(0, (v, l) => v + weight(l));
    for (final line in lines) {
      roll -= weight(line);
      if (roll <= 0) return line;
    }
    return lines.last;
  }

  static WeatherRoastTag _primary(Set<WeatherRoastTag> tags) {
    const priority = [
      WeatherRoastTag.severe,
      WeatherRoastTag.storm,
      WeatherRoastTag.snow,
      WeatherRoastTag.heavyRain,
      WeatherRoastTag.badAir,
      WeatherRoastTag.hot,
      WeatherRoastTag.cold,
      WeatherRoastTag.lightRain,
      WeatherRoastTag.windy,
      WeatherRoastTag.fog,
      WeatherRoastTag.nice,
      WeatherRoastTag.partlyCloudy,
      WeatherRoastTag.clear,
      WeatherRoastTag.cloudy
    ];
    return priority.firstWhere(tags.contains,
        orElse: () => WeatherRoastTag.fallback);
  }
}
