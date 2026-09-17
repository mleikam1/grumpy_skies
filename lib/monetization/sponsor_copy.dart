import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'interstitial_policy.dart';

/// This is DayMaker editorial copy, never a claim of paid sponsorship.
class EditorialAside {
  const EditorialAside(
      {required this.id, required this.personaId, required this.text});
  final String id;
  final String? personaId;
  final String text;

  static List<EditorialAside> parseCatalog(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Editorial catalog version');
    }
    final lines = (data['lines'] as List).map((entry) {
      final item = entry as Map<String, dynamic>;
      return EditorialAside(
        id: item['id'] as String,
        personaId: item['persona'] as String?,
        text: item['text'] as String,
      );
    }).toList(growable: false);
    if (lines.map((line) => line.id).toSet().length != lines.length ||
        lines.any((line) => line.id.isEmpty || line.text.trim().isEmpty)) {
      throw const FormatException('Invalid editorial catalog entries');
    }
    return List.unmodifiable(lines);
  }
}

/// Choose once for the lifetime of an eligible section visit, outside build.
/// Gates are rechecked even for cached selections so warnings/kill switches
/// remove existing asides immediately. Plain "Advertisements" remains in UI.
class SponsorCopySelector {
  SponsorCopySelector({
    required this.storage,
    required this.catalog,
    Random? random,
    double probability = .25,
    int maxPerSession = 2,
  })  : random = random ?? Random.secure(),
        probability = probability.clamp(0, .25),
        maxPerSession = maxPerSession.clamp(0, 2);

  static const assetPath = 'assets/monetization/editorial_asides.v1.json';
  static const storageKey = 'daymaker.editorial-asides.v1';
  final MonetizationStorage storage;
  final List<EditorialAside> catalog;
  final Random random;
  final double probability;
  final int maxPerSession;
  final Map<String, EditorialAside?> _visits = {};
  final List<String> _recentIds = [];
  String? _sessionId;
  int _sessionCount = 0;
  bool _healthy = true;
  bool _initialized = false;
  Future<void> _writes = Future.value();

  static Future<SponsorCopySelector> load({
    required MonetizationStorage storage,
    required String sessionId,
    AssetBundle? bundle,
  }) async {
    final catalog = EditorialAside.parseCatalog(
        await (bundle ?? rootBundle).loadString(assetPath));
    final selector = SponsorCopySelector(storage: storage, catalog: catalog);
    await selector.initialize(sessionId: sessionId);
    return selector;
  }

  Future<void> initialize({required String sessionId}) async {
    if (_initialized) {
      await setSession(sessionId);
      return;
    }
    try {
      final raw = storage.read(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 1) {
          throw const FormatException('Editorial history version');
        }
        _sessionId = data['sessionId'] as String;
        _sessionCount = data['sessionCount'] as int;
        _recentIds.addAll((data['recentIds'] as List).cast<String>());
      }
    } catch (_) {
      _healthy = false;
    }
    _initialized = true;
    await setSession(sessionId);
  }

  Future<void> setSession(String sessionId) async {
    if (sessionId == _sessionId) return;
    _sessionId = sessionId;
    _sessionCount = 0;
    _visits.clear();
    await _persist();
  }

  Future<EditorialAside?> chooseForVisit({
    required String visitId,
    required String personaId,
    required bool enabled,
    required bool isWeb,
    required bool severeWarning,
    bool safetyKnown = true,
    bool safetyFresh = true,
  }) async {
    // Adjacent web humor is intentionally unavailable in the launch adapter.
    if (!_initialized ||
        !_healthy ||
        !enabled ||
        isWeb ||
        severeWarning ||
        !safetyKnown ||
        !safetyFresh) {
      return null;
    }
    if (_visits.containsKey(visitId)) return _visits[visitId];
    _visits[visitId] = null;
    if (_sessionCount >= maxPerSession || random.nextDouble() >= probability) {
      return null;
    }
    final candidates = catalog
        .where((line) => line.personaId == null || line.personaId == personaId)
        .toList();
    var eligible =
        candidates.where((line) => !_recentIds.contains(line.id)).toList();
    // A single persona has fewer lines than the global recent-history capacity.
    // Once that entire pool has been used, recycle its least-recent line; never
    // strand the persona permanently or immediately repeat its previous line.
    if (eligible.isEmpty && candidates.length > 1) {
      final recyclable = candidates
          .where((line) => line.id != _recentIds.lastOrNull)
          .toList()
        ..sort((a, b) =>
            _recentIds.indexOf(a.id).compareTo(_recentIds.indexOf(b.id)));
      if (recyclable.isNotEmpty) eligible = [recyclable.first];
    }
    if (eligible.isEmpty) return null;
    final choice = eligible[random.nextInt(eligible.length)];
    _visits[visitId] = choice;
    _sessionCount++;
    _recentIds.remove(choice.id);
    _recentIds.add(choice.id);
    if (_recentIds.length > 20) {
      _recentIds.removeRange(0, _recentIds.length - 20);
    }
    await _persist();
    return _healthy ? choice : null;
  }

  Future<void> _persist() {
    if (!_initialized || !_healthy) return Future.value();
    final value = jsonEncode({
      'version': 1,
      'sessionId': _sessionId,
      'sessionCount': _sessionCount,
      'recentIds': _recentIds,
    });
    _writes = _writes
        .then((_) => storage.write(storageKey, value))
        .catchError((Object _) {
      _healthy = false;
    });
    return _writes;
  }
}
