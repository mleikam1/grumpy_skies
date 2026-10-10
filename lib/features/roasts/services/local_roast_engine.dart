import '../content/roast_selector.dart';
import '../content/weather_roast_models.dart';

/// Synchronous local selection only. There are intentionally no weather,
/// content, storage, HTTP, ad, AI, or database clients in this engine.
class LocalRoastEngine {
  LocalRoastEngine({RoastSelector selector = const RoastSelector()})
      : _selector = selector;
  final RoastSelector _selector;
  final _slots = <String, RoastSelection>{};
  final _slotPackVersions = <String, String>{};
  final _ids = <String, Map<String, DateTime>>{};
  final _families = <String, Map<String, DateTime>>{};
  int _sequence = 0;
  int _exposureCount = 0;
  int get exposureCount => _exposureCount;
  final _exposures = <RoastSelection>[];
  final _committed = <String>{};

  /// Selection can be prepared in a build; exposure is committed only once the
  /// production display registry has actually shown that immutable selection.
  bool commitDisplayed(RoastSelection selection) {
    final key = selection.selectionId;
    if (key == null || !_committed.add(key)) return false;
    final now = selection.selectedAt ?? DateTime.now().toUtc();
    final ids = _ids.putIfAbsent(selection.persona, () => {});
    final families = _families.putIfAbsent(selection.persona, () => {});
    ids[selection.id] = now;
    families[selection.familyId] = now;
    _bound(ids, 200);
    _bound(families, 50);
    _exposures.add(selection);
    while (_exposures.length > 200) {
      _committed.remove(_exposures.removeAt(0).selectionId);
    }
    _exposureCount++;
    return true;
  }

  static final RoastPack fallbackPack = RoastPack(
    schemaVersion: 1,
    packVersion: 'application-core-1',
    generatedAt: DateTime.utc(2026, 1, 1),
    personas: supportedWeatherRoastPersonas.toList(growable: false),
    roasts: [
      for (final persona in supportedWeatherRoastPersonas)
        for (final type in RoastType.values)
          const RoastSelector()
              .applicationSelection(
                  WeatherRoastContext.unavailable(), persona, type,
                  reason: 'bundled_core')
              .line
    ],
  );

  RoastSelection select(
      {required RoastPack pack,
      required WeatherRoastContext context,
      required String persona,
      required RoastType type,
      RoastLevel maxLevel = RoastLevel.medium,
      Set<String> disabledIds = const {},
      Set<String> excludedIds = const {},
      Set<String> excludedTexts = const {},
      Map<String, double> preferenceWeights = const {},
      bool another = false,
      String? slot,
      bool retainWhileEligible = false,
      String source = 'bundled'}) {
    final id = normalizeRoastPersonaId(persona);
    // Pending timeline choices must be hard exclusions, never repetition hints
    // that the selector can relax when a pool becomes small.
    final unavailableIds = <String>{...disabledIds, ...excludedIds};
    if (excludedTexts.isNotEmpty) {
      for (final line in _selector.candidates(pack, id, type)) {
        if (context.canRender(line.text) &&
            excludedTexts
                .contains(normalizeRoastText(context.render(line.text)))) {
          unavailableIds.add(line.id);
        }
      }
    }
    final key =
        '${slot ?? ''}|${context.stableSlot(id, type, includeWeather: !retainWhileEligible)}|${retainWhileEligible ? 'eligible' : maxLevel.name}';
    final cached = _slots[key];
    if (!another &&
        cached != null &&
        _slotPackVersions[key] == pack.packVersion &&
        !unavailableIds.contains(cached.id)) {
      if (cached.source == 'application') {
        if ((cached.reason == 'application_safety_gate') ==
                context.requiresSafetyMessage &&
            (context.requiresSafetyMessage ||
                !_selector.candidates(pack, id, type).any((line) => _selector
                    .eligibilityFailures(
                        line: line,
                        pack: pack,
                        context: context,
                        persona: id,
                        type: type,
                        maxLevel: maxLevel,
                        disabledIds: unavailableIds)
                    .isEmpty))) {
          return _refreshContext(key, cached, context);
        }
      }
      if (cached.source != 'application' &&
          _selector
              .eligibilityFailures(
                  line: cached.line,
                  pack: pack,
                  context: context,
                  persona: id,
                  type: type,
                  maxLevel: maxLevel,
                  disabledIds: unavailableIds)
              .isEmpty) {
        // Facts in text update without selecting a new punchline or exposure.
        if (context.render(cached.line.text) == cached.renderedText) {
          return _refreshContext(key, cached, context);
        }
        final refreshed = RoastSelection(
            line: cached.line,
            renderedText: context.render(cached.line.text),
            packVersion: cached.packVersion,
            primaryWeatherTag: cached.primaryWeatherTag,
            weatherTimestamp: context.observedAt,
            windowStart: context.windowStart,
            windowEnd: context.windowEnd,
            selectedAt: cached.selectedAt,
            reason: 'display_facts_updated',
            source: cached.source,
            scope: context.scope,
            safetyStatus: context.safetyStatus,
            selectionId: cached.selectionId,
            requiresVerifiedAlerts: cached.requiresVerifiedAlerts);
        _slots[key] = refreshed;
        return refreshed;
      }
    }
    final now = context.evaluatedAt ?? DateTime.now();
    final ids = _ids.putIfAbsent(id, () => {});
    final families = _families.putIfAbsent(id, () => {});
    final candidate = _selector.select(
        pack: pack,
        context: context,
        persona: id,
        type: type,
        maxLevel: maxLevel,
        disabledIds: unavailableIds,
        recentRoastIds: ids.entries
            .where((e) => now.difference(e.value) < const Duration(days: 7))
            .map((e) => e.key),
        recentFamilyIds: families.entries
            .where((e) => now.difference(e.value) < const Duration(days: 3))
            .map((e) => e.key),
        lastSeen: ids,
        preferenceWeights: preferenceWeights,
        seed: '$key|$_sequence',
        source: source);
    final selected = RoastSelection.fromJson(
        {...candidate.toJson(), 'selection_id': '$key|${_sequence++}'});
    _slots.remove(key);
    _slots[key] = selected;
    _slotPackVersions[key] = pack.packVersion;
    while (_slots.length > 100) {
      final oldest = _slots.keys.first;
      _slots.remove(oldest);
      _slotPackVersions.remove(oldest);
    }
    return selected;
  }

  RoastSelection _refreshContext(
      String key, RoastSelection cached, WeatherRoastContext context) {
    if (cached.weatherTimestamp == context.observedAt &&
        cached.windowStart == context.windowStart &&
        cached.windowEnd == context.windowEnd &&
        cached.safetyStatus == context.safetyStatus) {
      return cached;
    }
    return _slots[key] = RoastSelection(
      line: cached.line,
      renderedText: cached.renderedText,
      packVersion: cached.packVersion,
      primaryWeatherTag: cached.primaryWeatherTag,
      weatherTimestamp: context.observedAt,
      windowStart: context.windowStart,
      windowEnd: context.windowEnd,
      selectedAt: cached.selectedAt,
      reason: 'display_context_updated',
      source: cached.source,
      scope: context.scope,
      safetyStatus: context.safetyStatus,
      selectionId: cached.selectionId,
      requiresVerifiedAlerts: cached.requiresVerifiedAlerts,
    );
  }

  static void _bound(Map<String, DateTime> values, int max) {
    if (values.length <= max) return;
    final sorted = values.entries.toList()
      ..sort((a, b) {
        final time = a.value.compareTo(b.value);
        return time == 0 ? a.key.compareTo(b.key) : time;
      });
    for (final entry in sorted.take(values.length - max)) {
      values.remove(entry.key);
    }
  }

  /// Small local metadata; content packs are never serialized into preferences.
  /// A bounded set of displayed snapshots preserves exact captions on restart.
  Map<String, dynamic> exportHistory() => {
        'schema': 2,
        'sequence': _sequence,
        'exposure_count': _exposureCount,
        'exposures': _exposures.map((e) => e.toJson()).toList(),
        'ids': {
          for (final persona in _ids.entries)
            persona.key: {
              for (final e in persona.value.entries)
                e.key: e.value.toUtc().toIso8601String()
            }
        },
        'families': {
          for (final persona in _families.entries)
            persona.key: {
              for (final e in persona.value.entries)
                e.key: e.value.toUtc().toIso8601String()
            }
        },
        'slots': {
          for (final e in _slots.entries)
            e.key: {
              'pack_version': _slotPackVersions[e.key],
              'selection': e.value.toJson()
            }
        },
      };

  void importHistory(Map<String, dynamic> json) {
    if (json['schema'] != 1 && json['schema'] != 2) return;
    _ids.clear();
    _families.clear();
    _slots.clear();
    _slotPackVersions.clear();
    _sequence = (json['sequence'] as num?)?.toInt() ?? 0;
    _exposureCount = (json['exposure_count'] as num?)?.toInt() ?? 0;
    _exposures.clear();
    _committed.clear();
    // Legacy slot keys could contain raw coordinates. Preserve exact historical
    // captions with new opaque exposure tokens; do not restore those slot keys.
    final historical = json['exposures'] as List? ??
        (json['schema'] == 1 && json['slots'] is Map
            ? (json['slots'] as Map)
                .values
                .whereType<Map>()
                .map((entry) => entry['selection'])
                .toList()
            : const []);
    for (final raw in historical.take(200)) {
      try {
        final value = (raw as Map).cast<String, dynamic>();
        final selection = RoastSelection.fromJson({
          ...value,
          if (json['schema'] == 1)
            'selection_id': 'migrated-$_sequence-${_exposures.length}',
        });
        if (supportedWeatherRoastPersonas.contains(selection.persona)) {
          _exposures.add(selection);
          if (selection.selectionId != null) {
            _committed.add(selection.selectionId!);
          }
        }
      } catch (_) {/* Damaged optional history is ignored. */}
    }
    void readHistory(
        Object? raw, Map<String, Map<String, DateTime>> target, int limit) {
      if (raw is! Map) return;
      for (final entry in raw.entries) {
        final persona = normalizeRoastPersonaId(entry.key.toString());
        if (!supportedWeatherRoastPersonas.contains(persona) ||
            entry.value is! Map) {
          continue;
        }
        final values = <String, DateTime>{};
        for (final row in (entry.value as Map).entries) {
          final date = DateTime.tryParse(row.value.toString());
          if (date != null && row.key is String) {
            values[row.key as String] = date;
          }
        }
        _bound(values, limit);
        target[persona] = values;
      }
    }

    readHistory(json['ids'], _ids, 200);
    readHistory(json['families'], _families, 50);
    final slots = json['slots'];
    if (json['schema'] == 2 && slots is Map) {
      for (final entry in slots.entries.take(100)) {
        try {
          final row = (entry.value as Map).cast<String, dynamic>();
          final selection = RoastSelection.fromJson(
              (row['selection'] as Map).cast<String, dynamic>());
          if (!supportedWeatherRoastPersonas.contains(selection.persona)) {
            continue;
          }
          final key = entry.key.toString();
          _slots[key] = selection;
          _slotPackVersions[key] = row['pack_version'] as String;
        } on Object {
          /* Evicted/corrupt optional local history is disposable. */
        }
      }
    }
  }

  List<RoastSelection> get displayedSelections => List.unmodifiable(_exposures);
}

/// Compare displayed text after punctuation/spacing normalization, so a second
/// catalog ID cannot sneak the same joke into one prepared timeline.
String normalizeRoastText(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
