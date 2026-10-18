import 'dart:convert';

import 'domain/guidance_evidence.dart';

class GuidanceImpression {
  const GuidanceImpression(
      {required this.templateId,
      required this.familyId,
      required this.semanticKey,
      required this.situation,
      required this.scope,
      required this.location,
      required this.shownAt,
      this.actionStart,
      this.actionEnd});
  final String templateId, familyId, semanticKey, situation, scope, location;
  final DateTime shownAt;
  final DateTime? actionStart, actionEnd;
  GuidanceInterval? get actionInterval =>
      actionStart != null && actionEnd?.isAfter(actionStart!) == true
          ? GuidanceInterval(actionStart!, actionEnd!)
          : null;
  Map<String, Object> toJson() => {
        'template': templateId,
        'family': familyId,
        'semantic': semanticKey,
        'situation': situation,
        'scope': scope,
        'location': location,
        'at': shownAt.toUtc().toIso8601String(),
        if (actionInterval != null) ...{
          'actionStart': actionStart!.toUtc().toIso8601String(),
          'actionEnd': actionEnd!.toUtc().toIso8601String(),
        },
      };
}

/// Only visible selections enter this ring. Pins deliberately live elsewhere.
/// Scope and location are opaque hashes; calendar titles/coordinates are absent.
class LocalGuidanceHistory {
  static const maximumEntries = 100;
  static const retention = Duration(days: 14);
  final List<GuidanceImpression> _entries = [];
  List<GuidanceImpression> get entries => List.unmodifiable(_entries);
  bool prune(DateTime now) {
    final before = _entries.length;
    _entries.removeWhere((e) =>
        e.shownAt.isAfter(now) || now.difference(e.shownAt) >= retention);
    if (_entries.length > maximumEntries) {
      _entries.removeRange(0, _entries.length - maximumEntries);
    }
    return before != _entries.length;
  }

  bool record(GuidanceImpression entry, DateTime now) {
    prune(now);
    if (_entries
        .any((e) => e.scope == entry.scope && e.situation == entry.situation)) {
      return false;
    }
    _entries.add(entry);
    prune(now);
    return true;
  }

  void clear() => _entries.clear();
  DateTime? lastShown(String templateId) {
    for (final e in _entries.reversed) {
      if (e.templateId == templateId) return e.shownAt;
    }
    return null;
  }

  bool duplicates(
          {required String semantic,
          required String scope,
          required String location,
          required DateTime now,
          GuidanceInterval? targetInterval}) =>
      _entries.any((e) =>
          e.semanticKey == semantic &&
          e.scope != scope &&
          e.location == location &&
          (targetInterval == null ||
              e.actionInterval == null ||
              e.actionInterval!.overlaps(targetInterval)) &&
          !e.shownAt.isAfter(now) &&
          now.difference(e.shownAt) < const Duration(minutes: 10));
  String encode() => jsonEncode(
      {'version': 1, 'entries': _entries.map((e) => e.toJson()).toList()});
  void restore(String? encoded, DateTime now) {
    clear();
    if (encoded == null || encoded.length > 100000) return;
    try {
      final root = jsonDecode(encoded);
      if (root is! Map || root['version'] != 1 || root['entries'] is! List) {
        return;
      }
      for (final e in (root['entries'] as List).take(1000)) {
        if (e is! Map) continue;
        final keys = [
          'template',
          'family',
          'semantic',
          'situation',
          'scope',
          'location',
          'at'
        ];
        if (keys.any((k) => e[k] is! String || (e[k] as String).length > 180)) {
          continue;
        }
        final at = DateTime.tryParse(e['at'] as String);
        if (at == null) continue;
        _entries.add(GuidanceImpression(
            templateId: e['template'],
            familyId: e['family'],
            semanticKey: e['semantic'],
            situation: e['situation'],
            scope: e['scope'],
            location: e['location'],
            shownAt: at,
            actionStart: e['actionStart'] is String
                ? DateTime.tryParse(e['actionStart'])
                : null,
            actionEnd: e['actionEnd'] is String
                ? DateTime.tryParse(e['actionEnd'])
                : null));
      }
      _entries.sort((a, b) => a.shownAt.compareTo(b.shownAt));
      prune(now);
    } catch (_) {
      clear();
    }
  }
}
