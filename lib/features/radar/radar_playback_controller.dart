import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/weather_models.dart';
import '../../services/open_weather_backend_client.dart';

/// The single timeline owner for normal and expanded radar chrome.
///
/// Map tiles retain their existing renderer/HTTP cache. This controller only
/// owns metadata, per-mode selections, and the existing bounded health warmup.
class RadarPlaybackController extends ChangeNotifier {
  RadarPlaybackController({
    required OpenWeatherBackendClient client,
    required LocationCandidate location,
    DateTime Function()? now,
  })  : _client = client,
        _location = location,
        _now = now ?? DateTime.now,
        _mode = _liveModeFor(location);

  static const playbackInterval = Duration(milliseconds: 900);
  static const refreshInterval = Duration(minutes: 1);
  static const _preloadDelay = Duration(milliseconds: 180);

  final OpenWeatherBackendClient _client;
  final DateTime Function() _now;
  final Map<RadarMode, _ModeState> _states = {};
  LocationCandidate _location;
  RadarMode _mode;
  Timer? _playTimer;
  Timer? _boundaryTimer;
  Timer? _preloadTimer;
  bool _active = true;
  bool _initialized = false;
  bool _playing = false;
  bool _disposed = false;
  int _locationGeneration = 0;

  _ModeState get _state => _states.putIfAbsent(_mode, _ModeState.new);

  LocationCandidate get location => _location;
  RadarMode get mode => _mode;
  RadarMode get liveMode => _liveModeFor(_location);
  bool get futureCastSupported => liveMode == RadarMode.usForecast;
  bool get active => _active;
  bool get playing => _playing;
  bool get loading => _state.loading;
  String? get message => _state.message;
  List<RadarFrame> get frames => _state.frames;
  RadarFrameSet? get frameSet => _state.frameSet;

  /// Time this mode's metadata request actually succeeded, never its valid time.
  DateTime? get lastSuccessfulRefresh => _state.lastSuccessfulRefresh;

  int get selectedIndex {
    if (frames.isEmpty) return 0;
    return _nearestIndex(
        frames, _state.selectedTimestamp ?? frames.first.timestamp);
  }

  RadarFrame? get selectedFrame =>
      frames.isEmpty ? null : frames[selectedIndex];

  bool get isLatest =>
      !_mode.isFutureCast &&
      frames.isNotEmpty &&
      selectedIndex == frames.length - 1;

  bool get canJumpToNow => _mode.isFutureCast
      ? _nowIndex(frames, frameSet) != null
      : frames.isNotEmpty;

  @visibleForTesting
  bool get hasPlaybackTimer => _playTimer?.isActive ?? false;

  @visibleForTesting
  bool get hasRefreshTimer => _boundaryTimer?.isActive ?? false;

  Future<void> initialize() {
    if (_disposed) return Future.value();
    if (_initialized) return _state.pending ?? Future.value();
    _initialized = true;
    _startBoundaryTimer();
    return _active ? refresh() : Future.value();
  }

  Future<void> setLocation(LocationCandidate location) {
    if (_disposed) return Future.value();
    final unchanged = location.lat == _location.lat &&
        location.lon == _location.lon &&
        _liveModeFor(location) == liveMode;
    _location = location;
    if (unchanged) {
      notifyListeners();
      return Future.value();
    }
    _pause();
    _cancelPreload();
    _locationGeneration++;
    _states.clear();
    // Keep the user's mode when its provider supports the new area.
    _mode = _mode.isFutureCast && futureCastSupported ? _mode : liveMode;
    notifyListeners();
    return _initialized && _active ? refresh() : Future.value();
  }

  Future<void> setMode(RadarMode mode) {
    if (_disposed) return Future.value();
    final target = mode.isFutureCast ? mode : liveMode;
    if (target == _mode) return _state.pending ?? Future.value();
    _pause();
    _cancelPreload();
    _mode = target;
    _reconcile(_state);
    notifyListeners();
    if (!_initialized || !_active) return Future.value();
    if (_mode.isFutureCast && !futureCastSupported) {
      _state.message = 'FutureCast is available for US locations.';
      notifyListeners();
      return Future.value();
    }
    if (_needsRefreshOnEntry) {
      return refresh();
    }
    _schedulePreload();
    return Future.value();
  }

  /// A manual scrub always pauses, even when it lands on the current frame.
  void selectIndex(int index) {
    if (_disposed) return;
    _pause();
    if (frames.isNotEmpty) {
      final next = index.clamp(0, frames.length - 1);
      _state.selectedTimestamp = frames[next].timestamp;
      _state.followLatest = !_mode.isFutureCast && next == frames.length - 1;
      _schedulePreload();
    }
    notifyListeners();
  }

  void jumpToLatestOrNow() {
    if (_disposed || frames.isEmpty) return;
    final target =
        _mode.isFutureCast ? _nowIndex(frames, frameSet) : frames.length - 1;
    if (target != null) selectIndex(target);
  }

  void togglePlayback() {
    if (_disposed) return;
    if (_playing) {
      _pause();
      notifyListeners();
      return;
    }
    if (!_active || frames.length < 2) return;
    _reconcile(_state);
    if (frames.length < 2) {
      notifyListeners();
      return;
    }
    // Latest begins a useful history loop immediately; a paused intermediate
    // frame resumes in place and advances at the existing 900 ms cadence.
    if (isLatest) _state.selectedTimestamp = frames.first.timestamp;
    _state.followLatest = false;
    _playing = true;
    _playTimer?.cancel();
    _playTimer = Timer.periodic(playbackInterval, (_) {
      if (_disposed || !_active || !_playing) return;
      _reconcile(_state);
      if (frames.length < 2) {
        _pause();
      } else {
        _state.selectedTimestamp =
            frames[(selectedIndex + 1) % frames.length].timestamp;
        _schedulePreload();
      }
      notifyListeners();
    });
    _schedulePreload();
    notifyListeners();
  }

  /// The screen combines tab visibility and app lifecycle into this gate.
  /// Returning leaves playback paused, matching the prior lifecycle policy.
  void setActive(bool active, {bool notify = true}) {
    if (_disposed || _active == active) return;
    _active = active;
    if (!active) {
      _pause();
      _boundaryTimer?.cancel();
      _boundaryTimer = null;
      _cancelPreload();
    } else if (_initialized) {
      _startBoundaryTimer();
      _reconcile(_state);
      if (_needsRefreshOnEntry) {
        unawaited(refresh());
      } else {
        _schedulePreload();
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> refresh() {
    if (_disposed || !_initialized || !_active) return Future.value();
    final state = _state;
    if (state.pending != null) return state.pending!;
    if (!_location.hasValidCoordinates) {
      state.message = 'Choose a location to view radar.';
      notifyListeners();
      return Future.value();
    }
    if (_mode.isFutureCast && !futureCastSupported) {
      state.message = 'FutureCast is available for US locations.';
      notifyListeners();
      return Future.value();
    }
    state.loading = true;
    state.message = null;
    state.lastAttempt = _now();
    final requestMode = _mode;
    final requestLocation = _location;
    final generation = _locationGeneration;
    notifyListeners();
    final pending = _load(state, requestMode, requestLocation, generation);
    state.pending = pending;
    return pending;
  }

  Future<void> _load(
    _ModeState state,
    RadarMode requestMode,
    LocationCandidate requestLocation,
    int generation,
  ) async {
    try {
      final result = await _client.radarFrames(
        mode: requestMode,
        latitude: requestLocation.lat,
        longitude: requestLocation.lon,
        hours: 6,
      );
      if (_disposed || generation != _locationGeneration) return;
      state.frameSet = result;
      state.lastSuccessfulRefresh = _now();
      // Read selection at completion, not request start: a manual scrub during
      // refresh must not be rolled back by a slower metadata response.
      _reconcile(state, mode: requestMode);
      state.message = state.frames.isEmpty
          ? _unavailableMessage(result, requestMode)
          : result.diagnosticMessage;
      final keys = state.frames.map(_frameKey).toSet();
      state.preloaded.retainAll(keys);
    } catch (error) {
      if (_disposed || generation != _locationGeneration) return;
      // Keep the previous real frame and its actual valid time on refresh
      // failure; no new timestamp or invented clear-weather frame is supplied.
      _reconcile(state, mode: requestMode);
      final detail = error is OpenWeatherBackendException
          ? error.message
          : 'Radar could not refresh. Try again soon.';
      state.message = state.frames.isEmpty
          ? detail
          : '$detail Showing previously loaded frames.';
    } finally {
      state.loading = false;
      state.pending = null;
      if (!_disposed &&
          generation == _locationGeneration &&
          _mode == requestMode) {
        if (frames.length < 2) _pause();
        _schedulePreload();
        if (_active) notifyListeners();
      }
    }
  }

  void _reconcile(_ModeState state, {RadarMode? mode}) {
    final selectedMode = mode ?? _mode;
    final source = state.frameSet;
    if (source == null) return;
    final sorted = source.frames
        .where((frame) =>
            frame.renderable &&
            frame.timestamp > 0 &&
            frame.source == selectedMode.sourceParam)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final seen = <int>{};
    final unique = sorted.where((frame) => seen.add(frame.timestamp)).toList();
    // Forecast range metadata may extend the last valid frame beyond its point
    // timestamp. Otherwise only actual frames at/after now are usable.
    final nowIndex =
        selectedMode.isFutureCast ? _nowIndex(unique, source) : null;
    final usable = selectedMode.isFutureCast
        ? (nowIndex == null ? <RadarFrame>[] : unique.sublist(nowIndex))
        : unique;
    state.frames = List.unmodifiable(usable);
    if (usable.isEmpty) {
      if (selectedMode.isFutureCast) {
        state.message = _unavailableMessage(source, selectedMode);
      }
      return;
    }
    final target = !selectedMode.isFutureCast && state.followLatest
        ? usable.last.timestamp
        : state.selectedTimestamp ?? usable.first.timestamp;
    state.selectedTimestamp = usable[_nearestIndex(usable, target)].timestamp;
  }

  int? _nowIndex(List<RadarFrame> values, RadarFrameSet? source) {
    if (values.isEmpty) return null;
    final now = _now().millisecondsSinceEpoch ~/ 1000;
    final next = values.indexWhere((frame) => frame.timestamp >= now);
    if (next >= 0) return next;
    if (source?.availableTo != null && source!.availableTo! >= now) {
      return values.length - 1;
    }
    return null;
  }

  String _unavailableMessage(RadarFrameSet set, RadarMode mode) {
    if (mode.isFutureCast &&
        set.frames.any((frame) => frame.renderable) &&
        _nowIndex(set.frames, set) == null) {
      return 'This forecast has expired. Refresh or return to Live Radar.';
    }
    return set.diagnosticMessage ??
        (mode.isFutureCast
            ? 'FutureCast is temporarily unavailable. Live Radar is still available.'
            : 'Radar source temporarily unavailable. The base map is still usable.');
  }

  void _startBoundaryTimer() {
    _boundaryTimer?.cancel();
    if (!_active || !_initialized) return;
    _boundaryTimer = Timer.periodic(refreshInterval, (_) {
      // Preserve the prior active radar cadence; unavailable products do not
      // introduce a new background retry/polling loop.
      if (_active && frames.isNotEmpty) unawaited(refresh());
    });
  }

  // Failed requests are also coalesced across quick tab/mode changes. Their
  // attempt time is deliberately separate from user-visible successful age.
  bool get _needsRefreshOnEntry {
    final attempted = _state.lastAttempt;
    return attempted == null || _now().difference(attempted) >= refreshInterval;
  }

  void _schedulePreload() {
    _cancelPreload();
    if (!_active || frames.length < 2 || _disposed) return;
    final generation = _locationGeneration;
    final requestMode = _mode;
    _preloadTimer = Timer(_preloadDelay, () {
      if (_disposed ||
          !_active ||
          generation != _locationGeneration ||
          _mode != requestMode) {
        return;
      }
      final state = _state;
      for (var step = 1; step <= 2 && step < frames.length; step++) {
        final frame = frames[(selectedIndex + step) % frames.length];
        if (!state.preloaded.add(_frameKey(frame))) continue;
        unawaited(_client
            .radarTileHealth(
          mode: _mode,
          timestamp: frame.timestamp,
          latitude: _location.lat,
          longitude: _location.lon,
          source: frame.source,
        )
            .then<void>((_) {}, onError: (Object error, StackTrace stack) {
          state.preloaded.remove(_frameKey(frame));
        }));
      }
    });
  }

  void _cancelPreload() {
    _preloadTimer?.cancel();
    _preloadTimer = null;
  }

  void _pause() {
    _playTimer?.cancel();
    _playTimer = null;
    _playing = false;
  }

  static String _frameKey(RadarFrame frame) =>
      '${frame.source}:${frame.timestamp}';

  static int _nearestIndex(List<RadarFrame> frames, int timestamp) {
    var nearest = 0;
    for (var index = 1; index < frames.length; index++) {
      if ((frames[index].timestamp - timestamp).abs() <
          (frames[nearest].timestamp - timestamp).abs()) {
        nearest = index;
      }
    }
    return nearest;
  }

  static RadarMode _liveModeFor(LocationCandidate location) {
    final coordinateLooksUs = location.lat >= 18 &&
        location.lat <= 72 &&
        location.lon >= -170 &&
        location.lon <= -64;
    return location.isUs || coordinateLooksUs
        ? RadarMode.usForecast
        : RadarMode.global;
  }

  @override
  void dispose() {
    _disposed = true;
    _pause();
    _boundaryTimer?.cancel();
    _cancelPreload();
    super.dispose();
  }
}

class _ModeState {
  RadarFrameSet? frameSet;
  List<RadarFrame> frames = const [];
  int? selectedTimestamp;
  bool followLatest = true;
  bool loading = false;
  String? message;
  DateTime? lastSuccessfulRefresh;
  DateTime? lastAttempt;
  Future<void>? pending;
  final Set<String> preloaded = {};
}
