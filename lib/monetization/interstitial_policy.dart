import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small local store. No event, document identity, or copy selection is uploaded.
abstract interface class MonetizationStorage {
  String? read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesMonetizationStorage implements MonetizationStorage {
  SharedPreferencesMonetizationStorage(this.preferences);
  final SharedPreferences preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Could not persist advertising limits');
    }
  }
}

/// Optional configuration can tighten these limits, never loosen the baseline.
class InterstitialLimits {
  InterstitialLimits({
    Duration foregroundEngagement = const Duration(seconds: 180),
    int meaningfulCompletions = 3,
    Duration cooldown = const Duration(seconds: 300),
    int perSession = 1,
    int perRollingDay = 3,
  })  : foregroundEngagement =
            foregroundEngagement < const Duration(seconds: 180)
                ? const Duration(seconds: 180)
                : foregroundEngagement,
        meaningfulCompletions =
            meaningfulCompletions < 3 ? 3 : meaningfulCompletions,
        cooldown = cooldown < const Duration(seconds: 300)
            ? const Duration(seconds: 300)
            : cooldown,
        perSession = perSession.clamp(0, 1),
        perRollingDay = perRollingDay.clamp(0, 3);

  final Duration foregroundEngagement;
  final int meaningfulCompletions;
  final Duration cooldown;
  final int perSession;
  final int perRollingDay;
  static const inactivityThreshold = Duration(minutes: 30);
}

/// Read a fresh snapshot immediately before a presentation. Safety values refer
/// to the currently selected location; changing location must first mark them
/// unknown. Unresolved consent is represented by consentAllowed == false.
class InterstitialGates {
  const InterstitialGates({
    required this.nativePlatform,
    required this.consentAllowed,
    required this.configEnabled,
    required this.foreground,
    required this.modalActive,
    required this.safetyKnown,
    required this.safetyFresh,
    required this.severeWarning,
    this.adFree = false,
    this.holdout = false,
    this.onboarding = false,
  });

  final bool nativePlatform;
  final bool consentAllowed;
  final bool configEnabled;
  final bool foreground;
  final bool modalActive;
  final bool safetyKnown;
  final bool safetyFresh;
  final bool severeWarning;
  final bool adFree;
  final bool holdout;
  final bool onboarding;

  String? get suppressionReason {
    if (!nativePlatform) return 'platform';
    if (!configEnabled) return 'configuration';
    if (!consentAllowed) return 'consent';
    if (adFree) return 'ad_free';
    if (holdout) return 'holdout';
    if (onboarding) return 'onboarding';
    if (!foreground) return 'background';
    if (modalActive) return 'modal';
    if (!safetyKnown) return 'safety_unknown';
    if (!safetyFresh) return 'safety_stale';
    if (severeWarning) return 'severe_warning';
    return null;
  }
}

class InterstitialReservation {
  InterstitialReservation._(this.id, this.sessionId);
  final int id;
  final String sessionId;
}

/// Persistent caps and completions; SDK lifecycle lives in the coordinator.
///
/// Foreground engagement uses a monotonic clock. The wall clock is only used for
/// rolling windows and restart inactivity. Runtime wall-clock jumps are placed
/// in a conservative 24-hour quarantine. Device time across a terminated process
/// cannot be authenticated without a trusted time service.
class InterstitialPolicy {
  InterstitialPolicy({
    required this.storage,
    DateTime Function()? clock,
    Duration Function()? monotonicClock,
    InterstitialLimits? limits,
  })  : clock = clock ?? DateTime.now,
        limits = limits ?? InterstitialLimits() {
    final stopwatch = Stopwatch()..start();
    _monotonicClock = monotonicClock ?? (() => stopwatch.elapsed);
  }

  static const storageKey = 'daymaker.interstitial-policy.v1';
  final MonetizationStorage storage;
  final DateTime Function() clock;
  final InterstitialLimits limits;
  late final Duration Function() _monotonicClock;
  bool _initialized = false;
  bool _persistenceHealthy = true;
  bool _foreground = false;
  bool _externalOperation = false;
  int _sessionNumber = 1;
  int _sessionShown = 0;
  int _reservationSequence = 0;
  int _completionCount = 0;
  int _engagementMicros = 0;
  final Set<String> _completedIdentities = {};
  final List<DateTime> _shown = [];
  DateTime? _lastWall;
  DateTime? _backgroundAt;
  DateTime? _clockBlockedUntil;
  DateTime? _uncertainPresentationUntil;
  Duration? _lastMonotonic;
  InterstitialReservation? _reservation;
  Future<void> _writes = Future<void>.value();

  String get sessionId => 'session-$_sessionNumber';
  bool get initialized => _initialized;
  int get completedTaskCount => _completionCount;
  int get sessionShownCount => _sessionShown;
  List<DateTime> get shownHistory => List.unmodifiable(_shown);
  Duration get foregroundEngagement {
    _tick();
    return Duration(microseconds: _engagementMicros);
  }

  Future<void> initialize({bool foreground = true}) async {
    if (_initialized) return;
    final now = clock().toUtc();
    try {
      final raw = storage.read(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 1) throw const FormatException('policy version');
        _sessionNumber = data['sessionNumber'] as int;
        _sessionShown = data['sessionShown'] as int;
        _completionCount = data['completionCount'] as int;
        _engagementMicros = data['engagementMicros'] as int;
        _completedIdentities
            .addAll((data['completedIdentities'] as List).cast<String>());
        _shown
            .addAll((data['shown'] as List).cast<String>().map(DateTime.parse));
        _lastWall = DateTime.parse(data['lastWall'] as String);
        _clockBlockedUntil = _date(data['clockBlockedUntil']);
        _uncertainPresentationUntil = _date(data['uncertainPresentationUntil']);
        if (data['pendingPresentation'] == true) {
          // The process died between reserving and the SDK's terminal callback.
          // Do not call this an impression; simply avoid a potentially extra ad.
          _uncertainPresentationUntil = now.add(const Duration(hours: 24));
        }
        if (now.isBefore(_lastWall!)) {
          _clockBlockedUntil = _lastWall!.add(const Duration(hours: 24));
        } else if (now.difference(_lastWall!) >=
            InterstitialLimits.inactivityThreshold) {
          _newSession();
        }
      }
    } catch (_) {
      // A corrupt/unavailable history must never grant fresh caps.
      _persistenceHealthy = false;
    }
    _initialized = true;
    _foreground = foreground;
    _lastWall = now;
    _lastMonotonic = _monotonicClock();
    await _persist();
  }

  Future<void> setForeground(bool foreground,
      {bool externalOperation = false}) async {
    if (!_initialized) return;
    _tick();
    final now = clock().toUtc();
    if (foreground && !_foreground) {
      final inactiveSince = _backgroundAt;
      if (!_externalOperation &&
          inactiveSince != null &&
          now.difference(inactiveSince) >=
              InterstitialLimits.inactivityThreshold) {
        _newSession();
      }
      _backgroundAt = null;
      _externalOperation = false;
    } else if (!foreground && _foreground) {
      _backgroundAt = now;
      _externalOperation = externalOperation;
    }
    _foreground = foreground;
    await _persist();
  }

  /// Call only after a durable save or a successful export has delivered a
  /// result. Identities are hashed locally and never included in analytics.
  Future<bool> recordCompletion({
    required String documentId,
    required String revisionId,
    required bool safelyPersisted,
  }) async {
    if (!_initialized ||
        !safelyPersisted ||
        documentId.isEmpty ||
        revisionId.isEmpty) {
      return false;
    }
    _tick();
    final identity = sha256
        .convert(utf8.encode(jsonEncode([documentId, revisionId])))
        .toString();
    if (!_completedIdentities.add(identity)) return false;
    _completionCount++;
    await _persist();
    return true;
  }

  /// null means eligible. This performs no SDK work and never displays anything.
  String? eligibility(InterstitialGates gates,
      {InterstitialReservation? reservation}) {
    if (!_initialized) return 'not_initialized';
    _tick();
    final gate = gates.suppressionReason;
    if (gate != null) return gate;
    if (!_persistenceHealthy) return 'persistence';
    if (!_foreground) return 'background';
    final now = clock().toUtc();
    if (_clockBlockedUntil != null && now.isBefore(_clockBlockedUntil!)) {
      return 'clock';
    }
    if (_uncertainPresentationUntil != null &&
        now.isBefore(_uncertainPresentationUntil!)) {
      return 'uncertain_previous_presentation';
    }
    if (_reservation != null && !identical(_reservation, reservation)) {
      return 'reserved';
    }
    if (_sessionNumber == 1) return 'first_session';
    if (_engagementMicros < limits.foregroundEngagement.inMicroseconds) {
      return 'engagement';
    }
    if (_completionCount < limits.meaningfulCompletions) return 'completions';
    if (_sessionShown >= limits.perSession) return 'session_cap';
    if (_shown.any((at) => at.isAfter(now))) return 'clock';
    if (_shown.isNotEmpty && now.difference(_shown.last) < limits.cooldown) {
      return 'cooldown';
    }
    final cutoff = now.subtract(const Duration(hours: 24));
    if (_shown.where((at) => at.isAfter(cutoff)).length >=
        limits.perRollingDay) {
      return 'daily_cap';
    }
    return null;
  }

  /// Synchronous reservation makes concurrent taps/callbacks mutually exclusive.
  InterstitialReservation? reserve(InterstitialGates gates) {
    if (eligibility(gates) != null) return null;
    return _reservation =
        InterstitialReservation._(++_reservationSequence, sessionId);
  }

  /// Persist uncertainty before entering the SDK, then recheck gates afterwards.
  Future<bool> persistReservation(InterstitialReservation reservation) async {
    if (!identical(_reservation, reservation)) return false;
    await _persist();
    return _persistenceHealthy && identical(_reservation, reservation);
  }

  Future<void> markShown(InterstitialReservation reservation) async {
    if (!identical(_reservation, reservation)) return;
    _tick();
    _shown.add(clock().toUtc());
    _sessionShown++;
    _completionCount = 0;
    // Keep all identity hashes: exporting an unchanged old revision after an ad
    // still is not a new meaningful task. Their contents never leave the device.
    _reservation = null;
    await _persist();
  }

  Future<void> release(InterstitialReservation reservation) async {
    if (!identical(_reservation, reservation)) return;
    _reservation = null;
    await _persist();
  }

  Future<void> checkpoint() async {
    _tick();
    await _persist();
  }

  void _newSession() {
    _sessionNumber++;
    _sessionShown = 0;
    _engagementMicros = 0;
  }

  void _tick() {
    if (!_initialized) return;
    final now = clock().toUtc();
    final monotonic = _monotonicClock();
    final previousWall = _lastWall;
    final previousMonotonic = _lastMonotonic;
    if (previousWall != null && previousMonotonic != null) {
      final delta = monotonic - previousMonotonic;
      final wallDelta = now.difference(previousWall);
      final drift = (wallDelta - delta).inSeconds.abs();
      if (delta.isNegative || wallDelta.isNegative || drift > 60) {
        final later = now.isAfter(previousWall) ? now : previousWall;
        _clockBlockedUntil = later.add(const Duration(hours: 24));
      } else if (_foreground) {
        _engagementMicros += delta.inMicroseconds;
      }
    }
    _lastWall = now;
    _lastMonotonic = monotonic;
  }

  Future<void> _persist() {
    if (!_initialized || !_persistenceHealthy) return Future.value();
    final value = jsonEncode({
      'version': 1,
      'sessionNumber': _sessionNumber,
      'sessionShown': _sessionShown,
      'completionCount': _completionCount,
      'engagementMicros': _engagementMicros,
      'completedIdentities': _completedIdentities.toList(),
      'shown': _shown.map((date) => date.toIso8601String()).toList(),
      'lastWall': _lastWall!.toIso8601String(),
      'clockBlockedUntil': _clockBlockedUntil?.toIso8601String(),
      'uncertainPresentationUntil':
          _uncertainPresentationUntil?.toIso8601String(),
      'pendingPresentation': _reservation != null,
    });
    _writes = _writes
        .then((_) => storage.write(storageKey, value))
        .catchError((Object _) {
      _persistenceHealthy = false;
    });
    return _writes;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
