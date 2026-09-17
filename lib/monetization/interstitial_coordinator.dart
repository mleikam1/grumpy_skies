import 'dart:async';

import 'interstitial_policy.dart';

/// The native adapter must wire SDK full-screen-content callbacks before show.
/// An SDK load callback never invokes show. Paid events remain adapter-owned.
abstract interface class LoadedInterstitial {
  Future<void> show({
    required void Function() onShown,
    required void Function() onDismissed,
    required void Function(Object error) onFailed,
  });
  Future<void> dispose();
}

abstract interface class InterstitialLoader {
  Future<LoadedInterstitial> load();
}

typedef InterstitialReporter = void Function(String event, String? reason);

/// One single-use opportunity at an explicit, successful entertainment exit.
/// No timer, route listener, load callback, or share-sheet return can show an ad.
class InterstitialCoordinator {
  InterstitialCoordinator({
    required this.policy,
    required this.loader,
    required this.gates,
    this.report,
    this.onAfterDismissal,
    DateTime Function()? clock,
    Duration maxAge = const Duration(minutes: 55),
  })  : clock = clock ?? policy.clock,
        maxAge = maxAge < const Duration(hours: 1)
            ? maxAge
            : const Duration(minutes: 55);

  final InterstitialPolicy policy;
  final InterstitialLoader loader;
  final InterstitialGates Function() gates;
  final InterstitialReporter? report;

  /// Refresh/surface alert UI here after dismissal; do not initiate weather
  /// requests from advertising callbacks.
  final void Function()? onAfterDismissal;
  final DateTime Function() clock;
  final Duration maxAge;
  LoadedInterstitial? _ready;
  DateTime? _loadedAt;
  DateTime? _retryAfter;
  int _failures = 0;
  int _generation = 0;
  bool _loading = false;
  bool _disposed = false;
  Future<void>? _transition;

  bool get isLoading => _loading;
  bool get isReady => _ready != null && !_isExpired;
  bool get _isExpired {
    final loadedAt = _loadedAt;
    if (loadedAt == null) return true;
    final age = clock().toUtc().difference(loadedAt);
    return age.isNegative || age >= maxAge;
  }

  Future<void> preload() async {
    if (_disposed || _loading || _transition != null) return;
    if (_ready != null && !_isExpired) return;
    if (_ready != null) invalidate();
    final reason = policy.eligibility(gates());
    if (reason != null) {
      _emit('suppression', reason);
      return;
    }
    if (_retryAfter != null && clock().toUtc().isBefore(_retryAfter!)) return;
    final generation = _generation;
    _loading = true;
    _emit('request');
    try {
      final ad = await loader.load();
      if (_disposed ||
          generation != _generation ||
          policy.eligibility(gates()) != null) {
        await _disposeAd(ad);
        _emit('suppression', 'late_or_ineligible_load');
        return;
      }
      _ready = ad;
      _loadedAt = clock().toUtc();
      _failures = 0;
      _retryAfter = null;
      _emit('loaded');
    } catch (_) {
      _backoff();
      _emit('load_failure');
    } finally {
      _loading = false;
    }
  }

  /// Call once the result is visible and the user deliberately chooses Done or
  /// Back to Fun. Concurrent taps share the same operation and continuation.
  /// Missing inventory is abandoned immediately; never wait for preload here.
  Future<void> completeTransition(
      {required void Function() continueNavigation}) {
    final active = _transition;
    if (active != null) return active;
    final finished = Completer<void>();
    _transition = finished.future;
    unawaited(_complete(continueNavigation).then((_) {
      finished.complete();
      _transition = null;
    }, onError: (Object error, StackTrace stack) {
      finished.completeError(error, stack);
      _transition = null;
    }));
    return finished.future;
  }

  Future<void> _complete(void Function() navigate) async {
    var navigated = false;
    void continueOnce() {
      if (navigated) return;
      navigated = true;
      navigate();
    }

    _emit('opportunity');
    final reason = policy.eligibility(gates());
    if (_disposed || reason != null || !isReady) {
      _emit('suppression', _disposed ? 'disposed' : reason ?? 'not_ready');
      invalidate();
      continueOnce();
      return;
    }
    final reservation = policy.reserve(gates());
    if (reservation == null) {
      invalidate();
      continueOnce();
      return;
    }
    final ad = _ready!;
    _ready = null;
    _loadedAt = null;
    _generation++;
    final presentationGeneration = _generation;
    final done = Completer<void>();
    var terminal = false;
    var shown = false;
    Future<void> finish({Object? failure}) async {
      if (terminal) return;
      terminal = true;
      try {
        if (failure != null) {
          _backoff();
          _emit('show_failure');
        } else {
          _emit('dismissal');
        }
        await policy.release(reservation);
        await _disposeAd(ad);
        // A presented SDK interstitial cannot be forcibly closed. Fresh safety
        // state becomes visible immediately as normal app UI resumes.
        try {
          onAfterDismissal?.call();
        } catch (_) {
          // Ancillary reporting/safety notification cannot strand navigation.
        }
      } finally {
        try {
          continueOnce();
        } finally {
          if (!done.isCompleted) done.complete();
        }
      }
    }

    try {
      final saved = await policy.persistReservation(reservation);
      final recheck = policy.eligibility(gates(), reservation: reservation);
      if (_disposed ||
          presentationGeneration != _generation ||
          !saved ||
          recheck != null) {
        _emit('suppression', recheck ?? 'persistence_or_disposed');
        await finish(
            failure: StateError('Eligibility changed before presentation'));
      } else {
        // Intentionally no await or unrelated work between final gate and show.
        await ad.show(
          onShown: () {
            if (shown || terminal) return;
            shown = true;
            unawaited(policy.markShown(reservation));
            _emit('shown');
          },
          onDismissed: () => unawaited(finish()),
          onFailed: (error) => unawaited(finish(failure: error)),
        );
      }
    } catch (error) {
      await finish(failure: error);
    }
    await done.future;
  }

  /// Consent/location/modal/screen changes discard inventory and late callbacks.
  /// This never attempts to close an already-presented SDK interstitial.
  void invalidate() {
    _generation++;
    final ad = _ready;
    _ready = null;
    _loadedAt = null;
    if (ad != null) unawaited(_disposeAd(ad));
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }

  void _backoff() {
    _failures = (_failures + 1).clamp(1, 5);
    final seconds = (30 * (1 << (_failures - 1))).clamp(30, 300);
    _retryAfter = clock().toUtc().add(Duration(seconds: seconds));
  }

  Future<void> _disposeAd(LoadedInterstitial ad) async {
    try {
      await ad.dispose();
    } catch (_) {
      // An SDK disposal failure cannot block weather or navigation.
    }
  }

  void _emit(String event, [String? reason]) {
    try {
      report?.call(event, reason);
    } catch (_) {
      // Analytics is never part of the user's navigation critical path.
    }
  }
}
