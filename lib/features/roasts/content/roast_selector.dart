import 'dart:math';

import 'weather_roast_models.dart';

class RoastSelection {
  const RoastSelection({
    required this.line,
    required this.renderedText,
    required this.packVersion,
    required this.primaryWeatherTag,
  });

  final RoastLine line;
  final String renderedText;
  final String packVersion;
  final WeatherRoastTag primaryWeatherTag;
}

class RoastSelector {
  const RoastSelector();

  RoastSelection select({
    required RoastPack pack,
    required WeatherRoastContext context,
    required String persona,
    required RoastType type,
    RoastLevel maxLevel = RoastLevel.medium,
    Set<String> disabledIds = const {},
    Iterable<String> recentRoastIds = const [],
    String seed = '',
  }) {
    final normalizedPersona = normalizeRoastPersonaId(persona);
    final recentIds = recentRoastIds.toSet();
    final candidates = pack.roasts
        .where((line) => line.persona == normalizedPersona)
        .where((line) => line.type == type)
        .where((line) => maxLevel.allows(line.level))
        .where((line) => !disabledIds.contains(line.id))
        .where((line) => line.matchesDaypart(context.daypart))
        .where((line) => line.matchesStaticWeatherConstraints(context))
        .toList(growable: false);

    final selected = _selectFromFallbackOrder(
          candidates: candidates,
          context: context,
          recentIds: recentIds,
          seed: seed,
        ) ??
        _selectFromFallbackOrder(
          candidates: candidates,
          context: context,
          recentIds: const {},
          seed: seed,
        ) ??
        _neutralFallback(type);

    return RoastSelection(
      line: selected,
      renderedText: context.render(selected.text),
      packVersion: pack.packVersion,
      primaryWeatherTag: _primaryWeatherTag(context.tags),
    );
  }

  RoastLine? _selectFromFallbackOrder({
    required List<RoastLine> candidates,
    required WeatherRoastContext context,
    required Set<String> recentIds,
    required String seed,
  }) {
    final available = candidates
        .where((line) => !recentIds.contains(line.id))
        .toList(growable: false);

    final exact = available
        .where((line) => _isExactWeatherMatch(line, context))
        .toList(growable: false);
    if (exact.isNotEmpty) return _weightedTopScore(exact, context, seed);

    final general = available
        .where((line) => _isGeneralWeatherMatch(line, context))
        .toList(growable: false);
    if (general.isNotEmpty) return _weightedTopScore(general, context, seed);

    final fallback = available.where((line) => line.isFallback).toList();
    if (fallback.isNotEmpty) return _weightedTopScore(fallback, context, seed);

    return null;
  }

  RoastLine _weightedTopScore(
    List<RoastLine> candidates,
    WeatherRoastContext context,
    String seed,
  ) {
    final scored = candidates
        .map((line) => _ScoredRoast(line, _score(line, context)))
        .toList(growable: false);
    final topScore = scored.map((item) => item.score).reduce(max);
    final top = scored
        .where((item) => item.score == topScore)
        .map((item) => item.line)
        .toList(growable: false);
    if (top.length == 1) return top.first;

    final stableSeed = _stableHash(
      [
        seed,
        context.city,
        context.tempF,
        context.condition,
        context.daypart.name,
        ...top.map((line) => line.id),
      ].join('|'),
    );
    final random = Random(stableSeed);
    final totalWeight = top.fold<double>(
      0,
      (sum, line) => sum + max(line.weight, 0.01),
    );
    var roll = random.nextDouble() * totalWeight;
    for (final line in top) {
      roll -= max(line.weight, 0.01);
      if (roll <= 0) return line;
    }
    return top.last;
  }

  int _score(RoastLine line, WeatherRoastContext context) {
    var score = 0;
    for (final tag in line.tags) {
      if (tag == WeatherRoastTag.fallback) continue;
      if (context.tags.contains(tag)) score += 10;
    }
    if (line.conditionCodes.isNotEmpty &&
        context.conditionCode != null &&
        line.conditionCodes.contains(context.conditionCode)) {
      score += 6;
    }
    if (line.dayparts.contains(context.daypart)) score += 3;
    if (line.isSevere && context.tags.contains(WeatherRoastTag.severe)) {
      score += 100;
    }
    return score;
  }

  bool _isExactWeatherMatch(RoastLine line, WeatherRoastContext context) {
    if (line.isFallback) return false;
    final weatherTags =
        line.tags.where((tag) => tag != WeatherRoastTag.fallback).toSet();
    if (weatherTags.isEmpty) return false;
    return context.tags.containsAll(weatherTags);
  }

  bool _isGeneralWeatherMatch(RoastLine line, WeatherRoastContext context) {
    if (line.isFallback) return false;
    return line.tags.any(
      (tag) => tag != WeatherRoastTag.fallback && context.tags.contains(tag),
    );
  }

  WeatherRoastTag _primaryWeatherTag(Set<WeatherRoastTag> tags) {
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
      WeatherRoastTag.cloudy,
      WeatherRoastTag.fallback,
    ];
    return priority.firstWhere(
      tags.contains,
      orElse: () => WeatherRoastTag.fallback,
    );
  }

  RoastLine _neutralFallback(RoastType type) {
    return RoastLine(
      id: 'neutral_${type.name}_fallback',
      persona: 'neutral',
      type: type,
      tags: const [WeatherRoastTag.fallback],
      dayparts: const [Daypart.any],
      level: RoastLevel.mild,
      weight: 1,
      text: 'The weather is doing weather things. Dress for the bit.',
    );
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _ScoredRoast {
  const _ScoredRoast(this.line, this.score);

  final RoastLine line;
  final int score;
}
