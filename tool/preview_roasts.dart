import 'dart:convert';
import 'dart:io';
import 'package:grumpy_skies/features/roasts/content/roast_selector.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_validator.dart';
import 'package:grumpy_skies/models/weather_safety.dart';
import 'package:grumpy_skies/shared/assets/persona_emotion_assets.dart';

/// A local static review artifact backed by actual Dart eligibility and seeded
/// selection, not a second implementation of weather matching in JavaScript.
void main(List<String> args) {
  buildEditorialPreview(args.isEmpty ? 'build/roast_preview' : args.single);
}

void buildEditorialPreview(String output) {
  final raw =
      (jsonDecode(File('assets/roasts/roast_pack_v1.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>();
  final checked = const RoastPackValidator().validateJson(raw);
  if (!checked.isValid) throw FormatException(checked.errors.join('\n'));
  final pack = RoastPack.fromJson(raw);
  const selector = RoastSelector();
  final now = DateTime.utc(2026, 10, 10, 18);
  WeatherRoastContext context(
          {Set<WeatherRoastTag> tags = const {},
          int? temp = 72,
          int? code,
          int? chance,
          int localHour = 13,
          RoastScope scope = RoastScope.current,
          RoastActivity? activity,
          WeatherFreshness freshness = WeatherFreshness.fresh,
          WeatherSafetyStatus safety = WeatherSafetyStatus.clear,
          bool complete = true}) =>
      WeatherRoastContext(
          city: 'Simulated selected place',
          placeId: 'preview-place',
          country: 'US',
          region: 'IL',
          timezone: 'America/Chicago',
          tempF: temp,
          feelsLikeF: temp,
          humidity: tags.contains(WeatherRoastTag.humid) ? 85 : 50,
          windMph: tags.contains(WeatherRoastTag.windy) ? 24 : 5,
          condition: code == 800
              ? 'Clear'
              : code == 500
                  ? 'Light rain'
                  : 'Simulated condition',
          conditionCode: code,
          precipChance: chance,
          tags: tags,
          scope: scope,
          activity: activity,
          freshness: freshness,
          safetyStatus: safety,
          evaluatedAt: now,
          localTime: DateTime.utc(2026, 10, 10, localHour),
          daypart: Daypart.fromDateTime(DateTime.utc(2026, 10, 10, localHour)),
          observedAt: freshness == WeatherFreshness.stale
              ? now.subtract(const Duration(days: 1))
              : now.subtract(const Duration(minutes: 5)),
          windowStart: scope == RoastScope.current
              ? now
              : now.add(const Duration(hours: 1)),
          windowEnd: scope == RoastScope.current
              ? now
              : now.add(const Duration(hours: 2)),
          forecastComplete: complete);
  final scenarios = <String, WeatherRoastContext>{
    'Clear / pleasant':
        context(tags: {WeatherRoastTag.clear, WeatherRoastTag.nice}, code: 800),
    'Cloudy': context(tags: {WeatherRoastTag.cloudy}, code: 804),
    'Observed light rain':
        context(tags: {WeatherRoastTag.lightRain}, code: 500),
    'Cold': context(tags: {WeatherRoastTag.cold}, temp: 25),
    'Hot': context(tags: {WeatherRoastTag.hot}, temp: 94),
    'Windy': context(tags: {WeatherRoastTag.windy}),
    'Snow': context(tags: {WeatherRoastTag.snow}, code: 600, temp: 28),
    'Fog': context(tags: {WeatherRoastTag.fog}, code: 741),
    'Humid': context(tags: {WeatherRoastTag.humid}, temp: 78),
    'Hot and humid':
        context(tags: {WeatherRoastTag.hot, WeatherRoastTag.humid}, temp: 94),
    'Selected-location morning': context(localHour: 9),
    'Hourly clear': context(
        tags: {WeatherRoastTag.clear}, code: 800, scope: RoastScope.hourly),
    'Hourly cloudy': context(
        tags: {WeatherRoastTag.cloudy}, code: 804, scope: RoastScope.hourly),
    'Commute wind':
        context(tags: {WeatherRoastTag.windy}, scope: RoastScope.commute),
    'Hourly rain probability only':
        context(scope: RoastScope.hourly, chance: 70),
    'Weekend rain probability only':
        context(scope: RoastScope.weekend, chance: 70),
    'Incomplete weekend':
        context(scope: RoastScope.weekend, chance: 70, complete: false),
    'Unknown alerts': context(
        tags: {WeatherRoastTag.clear, WeatherRoastTag.nice},
        code: 800,
        safety: WeatherSafetyStatus.unknown),
    'Active alert / safety gate': context(
        tags: {WeatherRoastTag.clear},
        code: 800,
        safety: WeatherSafetyStatus.activeAlert),
    'Stale weather': context(
        tags: {WeatherRoastTag.clear},
        code: 800,
        freshness: WeatherFreshness.stale),
    'Unavailable weather': WeatherRoastContext.unavailable(now: now),
    for (final activity in RoastActivity.values)
      'Activity: ${activity.name}': context(activity: activity),
  };
  final matrix = <String, dynamic>{};
  final missingArt = <String>{};
  for (final scenario in scenarios.entries) {
    for (final persona in pack.personas) {
      for (final type in RoastType.values) {
        final ctx = scenario.value;
        final seen = <String>[];
        final selections = <Map<String, dynamic>>[];
        for (var i = 0; i < 12; i++) {
          final selected = selector.select(
              pack: pack,
              context: ctx,
              persona: persona,
              type: type,
              seed: 'preview-$i',
              recentRoastIds: seen);
          seen.add(selected.id);
          final options =
              PersonaEmotionAssets.fallbacks(selected.persona, selected.mood);
          final asset = options.firstWhere((path) => File(path).existsSync(),
              orElse: () => options.last);
          if (!File(asset).existsSync()) missingArt.add(asset);
          selections.add({
            ...selected.toJson(),
            'artwork': asset,
            'neutral_artwork_fallback': asset != options.first,
            'resolved_mood': selected.mood.name
          });
        }
        final eligibility = [
          for (final line in pack.roasts
              .where((r) => r.persona == persona && r.type == type))
            {
              'id': line.id,
              'rule': line.ruleId,
              'line': line.toJson(),
              'resolved_mood': line.effectiveMood.name,
              'artwork': PersonaEmotionAssets.fallbacks(
                      line.persona, line.effectiveMood)
                  .firstWhere((path) => File(path).existsSync(),
                      orElse: () => ''),
              'text':
                  ctx.canRender(line.text) ? ctx.render(line.text) : line.text,
              'failures': selector.eligibilityFailures(
                  line: line,
                  pack: pack,
                  context: ctx,
                  persona: persona,
                  type: type)
            }
        ];
        matrix['${scenario.key}|$persona|${type.name}'] = {
          'context': ctx.diagnostics,
          'selections': selections,
          'eligibility': eligibility
        };
      }
    }
  }
  final payload = {
    'scenarios': scenarios.keys.toList(),
    'personas': pack.personas,
    'types': RoastType.values.map((t) => t.name).toList(),
    'pack_version': pack.packVersion,
    'roasts': pack.roasts.length,
    'rules': {for (final rule in pack.rules) rule.id: rule.toJson()},
    'matrix': matrix,
    'missing_portraits': missingArt.toList(),
    'expression_variants_available': [
      for (final p in pack.personas)
        for (final m in RoastMood.values) PersonaEmotionAssets.path(p, m)
    ].every((path) => File(path).existsSync())
  };
  final html = File('tool/roast_preview_template.html')
      .readAsStringSync()
      .replaceFirst(
          '/*CATALOG_DATA*/', jsonEncode(payload).replaceAll('<', '\\u003c'));
  Directory(output).createSync(recursive: true);
  File('$output/index.html').writeAsStringSync(html);
  File('$output/context_matrix.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n');
  stdout.writeln(
      'Preview: $output/index.html; ${matrix.length} engine context/persona/type cases. Missing portrait files: ${missingArt.length}. Actual requested mood artwork is used when present, followed by the established same-persona fallback chain.');
}
