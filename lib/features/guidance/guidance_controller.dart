import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../models/guidance_preferences.dart';
import 'domain/guidance.dart';
import 'local_guidance_history.dart';

/// Local orchestration only. No weather/calendar repositories or remote clients.
class GuidanceController extends ChangeNotifier {
  GuidanceController(
      {GuidanceCatalog? catalog,
      DateTime Function()? clock,
      Future<void> Function(String)? persistHistory})
      : _catalog = catalog,
        clock = clock ?? DateTime.now,
        _persistHistory = persistHistory;

  static const historyKey = 'guidance.visibleHistory.v1';
  final DateTime Function() clock;
  final Future<void> Function(String)? _persistHistory;
  final history = LocalGuidanceHistory();
  final _pins = <String, GuidanceCandidate>{};
  final _scopeIntervals =
      <String, ({String situation, GuidanceInterval interval})>{};
  final _dismissed = <String, String>{};
  final _engine = const GuidanceEngine();
  GuidanceCatalog? _catalog;
  SharedPreferences? _preferences;
  Timer? _saveTimer;
  Future<void> _save = Future.value();
  bool _dirty = false, _disposed = false, _initializing = false;
  int evaluationCount = 0;
  int localHistoryWrites = 0;
  bool get ready => _catalog != null;

  Future<void> initialize({AssetBundle? assets, bool persist = true}) async {
    if (_initializing || ready) return;
    _initializing = true;
    try {
      final bundle = assets ?? rootBundle;
      final files = await Future.wait([
        bundle.loadString('assets/guidance/wingman_tips.en-US.json'),
        bundle.loadString('assets/guidance/wingman_tip_family_contracts.json'),
      ]);
      final catalog = GuidanceCatalog.fromJson(
          (jsonDecode(files[0]) as Map).cast<String, dynamic>(),
          (jsonDecode(files[1]) as Map).cast<String, dynamic>());
      if (persist) {
        _preferences = await SharedPreferences.getInstance();
        final stored = _preferences!.getString(historyKey);
        history.restore(stored, clock());
        if (stored != null && stored != history.encode()) _scheduleSave();
      }
      if (!_disposed) _catalog = catalog;
    } catch (_) {
      // Missing/malformed local content omits the optional slot. No repair fetch.
      _catalog = null;
    } finally {
      _initializing = false;
      if (!_disposed) notifyListeners();
    }
  }

  String scopeFor(GuidanceContext context, String? scopeKey,
          GuidancePreferences preferences) =>
      guidanceFingerprint(
          '${context.surface.name}|${scopeKey ?? ''}|${context.location.key}|'
          '${context.activity.name}|${context.window?.signature ?? ''}|'
          '${jsonEncode(preferences.toJson())}');

  GuidanceCandidate? select(
      {required WeatherEvidence weather,
      required GuidanceContext context,
      required GuidancePreferences preferences,
      String? scopeKey,
      DateTime? now}) {
    final time = now ?? clock();
    final catalog = _catalog;
    if (history.prune(time)) _scheduleSave();
    if (!preferences.enabled || catalog == null) return null;
    evaluationCount++;
    final scope = scopeFor(context, scopeKey, preferences);
    final candidates = <GuidanceCandidate>[];
    final intervals = <GuidanceCandidate, GuidanceInterval>{};
    for (final c in _contexts(context, preferences, time)) {
      for (final candidate in _engine.evaluate(
          weather: weather, context: c, now: time, catalog: catalog)) {
        candidates.add(candidate);
        intervals[candidate] = candidate.comparisonWindow ??
            c.window ??
            GuidanceInterval(time, time.add(c.outingDuration));
      }
    }
    candidates.removeWhere((c) => !c.validAt(time));
    candidates.sort((a, b) {
      final p = b.priority.compareTo(a.priority);
      if (p != 0) return p;
      final s = b.specificity.compareTo(a.specificity);
      if (s != 0) return s;
      return b.reliability.compareTo(a.reliability);
    });
    if (candidates.isEmpty) {
      _pins.remove(scope);
      _scopeIntervals.remove(scope);
      return null;
    }
    final highest = candidates.first.priority;
    final eligible = candidates
        .where((c) =>
            c.priority == highest &&
            (c.serious ||
                (!history.duplicates(
                        semantic: c.semanticDedupeKey,
                        scope: scope,
                        location: guidanceFingerprint(c.location.key),
                        targetInterval: intervals[c],
                        now: time) &&
                    _dismissed[scope] != c.situationFingerprint)))
        .toList();
    if (eligible.isEmpty) {
      _pins.remove(scope);
      _scopeIntervals.remove(scope);
      return null;
    }
    final bestSpecificity = eligible.first.specificity;
    final bestReliability = eligible.first.reliability;
    final choices = eligible
        .where((c) =>
            c.specificity == bestSpecificity &&
            c.reliability == bestReliability)
        .toList();
    final pinned = _pins[scope];
    if (pinned != null) {
      for (final c in choices) {
        if (c.templateId == pinned.templateId &&
            c.situationFingerprint == pinned.situationFingerprint) {
          _rememberInterval(scope, c, intervals[c]!);
          return c;
        }
      }
    }
    // Novelty only breaks ties among equally ranked, eligible actions.

    choices.sort((a, b) {
      final aTime = history.lastShown(a.templateId);
      final bTime = history.lastShown(b.templateId);
      if (aTime != bTime) {
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return aTime.compareTo(bTime);
      }
      final aSeed = guidanceFingerprint(
          '$scope|${a.situationFingerprint}|${a.templateId}');
      final bSeed = guidanceFingerprint(
          '$scope|${b.situationFingerprint}|${b.templateId}');
      return aSeed.compareTo(bSeed);
    });
    final result = choices.first;
    _pins[scope] = result;
    _rememberInterval(scope, result, intervals[result]!);
    if (_pins.length > 64) _pins.remove(_pins.keys.first);
    return result;
  }

  void _rememberInterval(
      String scope, GuidanceCandidate candidate, GuidanceInterval interval) {
    _scopeIntervals[scope] =
        (situation: candidate.situationFingerprint, interval: interval);
    if (_scopeIntervals.length > 64) {
      _scopeIntervals.remove(_scopeIntervals.keys.first);
    }
  }

  Iterable<GuidanceContext> _contexts(
      GuidanceContext context, GuidancePreferences p, DateTime now) sync* {
    yield context;
    if (context.activity != GuidanceActivity.outdoor ||
        context.allDay ||
        context.surface == GuidanceSurface.eventDetail ||
        context.surface == GuidanceSurface.plancastSummary) {
      return;
    }
    GuidanceContext activity(GuidanceActivity a, {GuidanceInterval? window}) =>
        GuidanceContext(
            surface: context.surface,
            location: context.location,
            activity: a,
            userSelectedWindow: a == GuidanceActivity.drivingCommute,
            window: window ?? context.window,
            knownActivity: false,
            outingDuration: Duration(minutes: p.outingMinutes),
            allowRefresh: context.allowRefresh,
            unsupported: context.unsupported,
            permissionDenied: context.permissionDenied);
    if (p.dogWalking) yield activity(GuidanceActivity.dogWalking);
    if (p.cycling) yield activity(GuidanceActivity.cycling);
    if (p.walking) yield activity(GuidanceActivity.walking);
    if (p.driving && context.surface == GuidanceSurface.todaySummary) {
      final local = context.location.localTime(now);
      if (local is tz.TZDateTime) {
        tz.TZDateTime at(int day, int minutes) => tz.TZDateTime(local.location,
            local.year, local.month, day, minutes ~/ 60, minutes % 60);
        final overnight = p.commuteEndMinute <= p.commuteStartMinute;
        var start = at(local.day, p.commuteStartMinute);
        var end = at(local.day + (overnight ? 1 : 0), p.commuteEndMinute);
        if (overnight && now.isBefore(at(local.day, p.commuteEndMinute))) {
          start = at(local.day - 1, p.commuteStartMinute);
          end = at(local.day, p.commuteEndMinute);
        } else if (!now.isBefore(end)) {
          start = at(local.day + 1, p.commuteStartMinute);
          end = at(local.day + (overnight ? 2 : 1), p.commuteEndMinute);
        }
        // A preference is only relevant close to its window, in the viewed area.
        if (p.commutesOn(start.weekday) &&
            start.difference(now) <= const Duration(hours: 3)) {
          yield activity(GuidanceActivity.drivingCommute,
              window: GuidanceInterval(start.toUtc(), end.toUtc()));
        }
      }
    }
  }

  void recordVisible(GuidanceCandidate candidate, String scope,
      {DateTime? now}) {
    final time = now ?? clock();
    if (_disposed || !candidate.validAt(time)) return;
    final remembered = _scopeIntervals[scope];
    final interval = remembered?.situation == candidate.situationFingerprint
        ? remembered!.interval
        : candidate.comparisonWindow;
    if (!candidate.serious &&
        history.duplicates(
            semantic: candidate.semanticDedupeKey,
            scope: scope,
            location: guidanceFingerprint(candidate.location.key),
            now: time,
            targetInterval: interval)) {
      notifyListeners();
      return;
    }
    final added = history.record(
        GuidanceImpression(
            templateId: candidate.templateId,
            familyId: candidate.familyId,
            semanticKey: candidate.semanticDedupeKey,
            situation: candidate.situationFingerprint,
            scope: scope,
            location: guidanceFingerprint(candidate.location.key),
            actionStart: interval?.start,
            actionEnd: interval?.end,
            shownAt: time),
        time);
    if (!added) return;
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer ??= Timer(const Duration(seconds: 2), () {
      _saveTimer = null;
      unawaited(flush());
    });
  }

  void dismiss(GuidanceCandidate candidate, String scope) {
    if (candidate.serious) return;
    _dismissed[scope] = candidate.situationFingerprint;
    _pins.remove(scope);
    _scopeIntervals.remove(scope);
    if (_dismissed.length > 64) _dismissed.remove(_dismissed.keys.first);
    notifyListeners();
  }

  /// No account system exists today. A future account switch must call this
  /// before selecting for the new user; history must never enter account sync.
  Future<void> resetHistory() async {
    history.clear();
    _pins.clear();
    _scopeIntervals.clear();
    _dismissed.clear();
    _dirty = true;
    await flush();
    if (!_disposed) notifyListeners();
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return _save;
    _dirty = false;
    final encoded = history.encode();
    _save = _save.then((_) async {
      try {
        if (_persistHistory != null) {
          await _persistHistory!(encoded);
          localHistoryWrites++;
        } else if (_preferences != null) {
          if (await _preferences!.setString(historyKey, encoded)) {
            localHistoryWrites++;
          }
        }
      } catch (_) {/* local persistence failure keeps the in-memory ring */}
    });
    return _save;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(flush());
    super.dispose();
  }
}
