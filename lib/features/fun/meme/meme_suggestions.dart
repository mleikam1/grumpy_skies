import 'dart:math';

import '../../roasts/models/roast_persona.dart';
import 'meme_catalog.dart';

/// Local, intact joke-pair selection. Recent IDs belong to the small persisted
/// studio settings record; no generated variants, LLM, or network is involved.
abstract final class MemeSuggestions {
  static MemeTemplate? chooseTemplate({
    required MemeCatalog catalog,
    Map<String, dynamic>? weatherSnapshot,
    List<String> recentIds = const [],
    Random? random,
    bool surprise = false,
  }) {
    final tags = _tags(weatherSnapshot);
    final candidates = catalog.templates.where((template) {
      // An explicit creative choice, not weather data.
      if (surprise) {
        return true;
      }
      if (weatherSnapshot == null) return false;
      if (!_hasRequiredSignal(template, tags)) return false;
      return template.tags.any(tags.contains);
    }).toList();
    if (candidates.isEmpty) return null;
    return _pick<MemeTemplate>(
        candidates, (item) => item.id, recentIds, random ?? Random());
  }

  static MemeCaptionPair captionFor({
    required MemeCatalog catalog,
    required MemeTemplate template,
    String? personaId,
    Map<String, dynamic>? weatherSnapshot,
    List<String> recentIds = const [],
    Random? random,
  }) {
    final persona = RoastPersonas.normalizeIdOrNull(personaId);
    final tags = _tags(weatherSnapshot);
    final hasWeather = tags.isNotEmpty;
    final personaPairs = catalog.personaCaptions.where((pair) {
      return persona != null &&
          pair.personaId == persona &&
          pair.tags.any(template.tags.contains) &&
          (!hasWeather || pair.tags.any(tags.contains));
    }).toList();
    final neutralPairs = template.captionPairs;
    // Favor the chosen persona while allowing fresh template jokes to prevent
    // repeating its only compatible line on every tap.
    final unseenPersona =
        personaPairs.where((pair) => !recentIds.contains(pair.id)).toList();
    if (unseenPersona.isNotEmpty) {
      return _pick(unseenPersona, (p) => p.id, recentIds, random ?? Random());
    }
    final combined = [...personaPairs, ...neutralPairs];
    return _pick(combined, (p) => p.id, recentIds, random ?? Random());
  }

  static List<String> remember(
    List<String> recentIds,
    String id, {
    int capacity = 80,
  }) {
    final next = [...recentIds.where((existing) => existing != id), id];
    return List.unmodifiable(next.skip(max(0, next.length - capacity)));
  }

  static bool _hasRequiredSignal(MemeTemplate template, Set<String> tags) {
    // These starter templates include broad secondary tags that must not be
    // mistaken for proof of a rainbow, pollen, snow, or a temperature swing.
    return switch (template.id) {
      'pollen_boss_battle' => tags.contains('pollen'),
      'rainbow_plot_twist' => tags.contains('rainbow'),
      'temperature_whiplash' => tags.contains('temperature_whiplash'),
      'snow_day_victory' => tags.contains('snow'),
      _ => !template.autoSuggestRequiresVerifiedSignal ||
          tags.contains(template.id),
    };
  }

  static Set<String> _tags(Map<String, dynamic>? snapshot) {
    final tags = snapshot?['tags'];
    return tags is List ? tags.whereType<String>().toSet() : const {};
  }

  static T _pick<T>(
    List<T> values,
    String Function(T) id,
    List<String> recent,
    Random random,
  ) {
    final unseen =
        values.where((value) => !recent.contains(id(value))).toList();
    if (unseen.isNotEmpty) return unseen[random.nextInt(unseen.length)];
    // All have been seen: take the least recent complete pair, not an
    // immediately repeated random item or mismatched setup/punchline halves.
    final ordered = [...values]
      ..sort((a, b) => recent.indexOf(id(a)).compareTo(recent.indexOf(id(b))));
    return ordered.first;
  }
}
