import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../content/roast_pack_repository.dart';
import '../content/roast_local_preferences.dart';

import '../content/roast_selector.dart';
import '../content/weather_roast_models.dart';
import '../services/local_roast_engine.dart';
import '../services/hourly_timeline_roasts.dart';

export '../content/roast_local_preferences.dart' show RoastFeedback;
export '../services/hourly_timeline_roasts.dart' show HourlyTimelineRoast;

/// Local presentation state. This boundary has no weather, ads, AI, geocoding,
/// database or HTTP clients. Weather is published by the existing refresh path.
class LocalRoastController extends ChangeNotifier {
  LocalRoastController(
      {RoastPackRepository? repository,
      LocalRoastEngine? engine,
      RoastPack? initialPack})
      : repository = repository ?? RoastPackRepository(),
        engine = engine ?? LocalRoastEngine(),
        _pack = initialPack;

  final RoastPackRepository repository;
  final LocalRoastEngine engine;
  final _localPreferences = RoastLocalPreferences();
  Set<String> get favoriteIds => _localPreferences.favorites;
  Map<String, RoastFeedback> get feedback => _localPreferences.feedback;
  final Set<String> _usedPersonas = {};
  RoastPack? _pack;
  Future<void>? _initializing;
  SharedPreferences? _preferences;
  WeatherBundle? weather;
  LocationCandidate? location;
  String? activity;
  RoastLevel intensity = RoastLevel.medium;
  Object? loadError;
  WeatherRoastContext? lastContext;
  bool _disposed = false;
  bool _savePending = false;
  final List<RoastSelection> _exposures = [];
  final _timelinePlans = <String, List<HourlyTimelineRoast>>{};
  static const _historyKey = 'local_roast_history_v2';
  static const _activityKey = 'local_roast_activity_v1';
  static const _intensityKey = 'local_roast_intensity_v1';
  static const _feedbackKey = 'local_roast_preferences_v1';

  bool get ready => _pack != null;
  RoastPack? get pack => _pack;
  List<RoastSelection> get exposures => List.unmodifiable(_exposures.reversed);
  static const activities = <String>[
    'walking',
    'commuting',
    'grilling',
    'outdoorExercise',
    'stayingIn',
  ];

  Future<void> initialize({bool persist = true}) =>
      _initializing ??= _initialize(persist);

  Future<void> _initialize(bool persist) async {
    try {
      if (persist) {
        try {
          _preferences = await SharedPreferences.getInstance();
          final opinions = _preferences?.getString(_feedbackKey);
          if (opinions != null) {
            try {
              _localPreferences.restore(
                  (jsonDecode(opinions) as Map).cast<String, dynamic>());
            } catch (_) {
              /* Damaged opinions do not affect history or content. */
            }
          }
          final raw = _preferences?.getString(_historyKey);
          if (raw != null) {
            final saved = jsonDecode(raw) as Map<String, dynamic>;
            engine.importHistory(saved);
            _exposures.addAll(engine.displayedSelections);
            if (saved['schema'] == 1) _save();
          }
          final savedActivity = _preferences?.getString(_activityKey);
          activity = activities.contains(savedActivity) ? savedActivity : null;
          final savedIntensity = _preferences?.getString(_intensityKey);
          intensity = RoastLevel.values.firstWhere(
            (level) => level.name == savedIntensity,
            orElse: () => RoastLevel.medium,
          );
        } catch (_) {
          // Eviction, private browsing and damaged metadata cannot block humor.
        }
      }
      _pack ??= await repository.loadPack();
      loadError = null;
    } catch (error) {
      loadError = error;
    }
    if (!_disposed) notifyListeners();
  }

  void publishWeather(WeatherBundle? bundle, LocationCandidate? place) {
    if (identical(weather, bundle) && identical(location, place)) return;
    weather = bundle;
    location = place;
    if (!_disposed) notifyListeners();
  }

  /// Preferences affect the next fresh selection, never mutate a displayed
  /// caption, bypass eligibility or send feedback to a service.
  void setFavorite(String roastId, bool favorite) {
    if (!_localPreferences.setFavorite(roastId, favorite)) return;
    _save();
    if (!_disposed) notifyListeners();
  }

  void setFeedback(String roastId, RoastFeedback? value) {
    if (!_localPreferences.setFeedback(roastId, value)) return;
    _save();
    if (!_disposed) notifyListeners();
  }

  void setActivity(String? value) {
    final next = activities.contains(value) ? value : null;
    if (activity == next) return;
    activity = next;
    _save();
    notifyListeners();
  }

  void setIntensity(RoastLevel value) {
    if (intensity == value) return;
    intensity = value;
    _save();
    notifyListeners();
  }

  RoastSelection select({
    required String persona,
    WeatherBundle? bundle,
    RoastScope scope = RoastScope.current,
    RoastType type = RoastType.today,
    DateTime? targetTime,
    DateTime? targetEnd,
    DateTime? now,
    TemperatureUnit unit = TemperatureUnit.fahrenheit,
    String locale = 'en-US',
    bool another = false,
    bool timelineOnly = false,
    Set<String> reservedIds = const {},
    Set<String> reservedTexts = const {},
  }) {
    _usedPersonas.add(normalizeRoastPersonaId(persona));
    final evaluation = now ?? DateTime.now();
    final source = bundle ?? weather;
    final roastContext = source == null
        ? WeatherRoastContext.unavailable(
            now: evaluation,
            locale: locale,
            scope: scope,
            temperatureUnit: unit,
            city: location?.name ?? '',
            placeId:
                location == null ? null : '${location!.lat},${location!.lon}',
            country: location?.country,
            region: location?.state,
            activity: RoastActivity.values
                .where((item) => item.name == activity)
                .firstOrNull)
        : WeatherRoastContext.fromWeatherBundle(
            source,
            now: evaluation,
            temperatureUnit: unit,
            scope: scope,
            targetTime: targetTime,
            targetEnd: targetEnd,
            activity: RoastActivity.values
                .where((item) => item.name == activity)
                .firstOrNull,
            locale: locale,
            selectedLocation: location,
          );
    lastContext = roastContext;
    final content = _pack ?? LocalRoastEngine.fallbackPack;
    final excludedIds = <String>{...reservedIds};
    if (timelineOnly) {
      for (final line
          in const RoastSelector().candidates(content, persona, type)) {
        if (line.isFallback ||
            line.isSevere ||
            !roastContext.hasFreshWeather ||
            !roastContext.forecastComplete ||
            !roastContext.canRender(line.text) ||
            roastContext.render(line.text).length > 140) {
          excludedIds.add(line.id);
        }
      }
    }
    final result = engine.select(
      pack: content,
      context: roastContext,
      persona: persona,
      type: type,
      maxLevel: intensity,
      disabledIds: repository.disabledIds,
      excludedIds: excludedIds,
      excludedTexts: reservedTexts,
      preferenceWeights: _localPreferences.weights,
      another: another,
      slot: timelineOnly ? 'hourly_timeline' : null,
      retainWhileEligible: timelineOnly,
      source: repository.sourceForPersona(persona, locale),
    );
    return result;
  }

  /// Prepare stable, pending timeline choices from the already loaded bundle.
  /// The caller commits only cards that become visible. No persistence or
  /// network work occurs while scheduling or selecting these candidates.
  List<HourlyTimelineRoast> selectHourlyTimeline({
    required String persona,
    List<HourlyForecast>? hours,
    WeatherBundle? bundle,
    DateTime? now,
    TemperatureUnit unit = TemperatureUnit.fahrenheit,
    String locale = 'en-US',
  }) {
    final source = bundle ?? weather;
    if (source == null) return const [];
    final evaluation = now ?? DateTime.now();
    final records = hours ?? source.hourly;
    final place = location ?? source.location;
    final planKey = jsonEncode([
      normalizeRoastPersonaId(persona),
      locale,
      place?.lat ?? source.current.latitude,
      place?.lon ?? source.current.longitude,
      place?.name ?? source.current.locationName,
    ]);
    RoastSelection? selectHour(
        HourlyForecast hour, Set<String> ids, Set<String> texts) {
      final selection = select(
        persona: persona,
        bundle: source,
        scope: RoastScope.hourly,
        type: RoastType.hourly,
        targetTime: hour.time,
        targetEnd: hour.time.add(const Duration(hours: 1)),
        now: evaluation,
        unit: unit,
        locale: locale,
        timelineOnly: true,
        reservedIds: ids,
        reservedTexts: texts,
      );
      return selection.source == 'application' ||
              selection.line.isFallback ||
              selection.line.isSevere
          ? null
          : selection;
    }

    final byTime = {
      for (final hour in records) hour.time.millisecondsSinceEpoch: hour,
    };
    final previous = (_timelinePlans[planKey] ?? const <HourlyTimelineRoast>[])
        .where((entry) =>
            byTime.containsKey(entry.targetTime.millisecondsSinceEpoch) &&
            isSelectionEligible(entry.selection,
                bundle: source, now: evaluation, unit: unit))
        .toList()
      ..sort((a, b) => a.targetTime.compareTo(b.targetTime));
    final retained = <HourlyTimelineRoast>[];
    for (final entry in previous) {
      final others = previous.where((other) => !identical(other, entry));
      final ids = {
        ...others.map((e) => e.selection.id),
        ...retained.map((e) => e.selection.id)
      };
      final texts = {
        ...others.map((e) => normalizeRoastText(e.selection.renderedText)),
        ...retained.map((e) => normalizeRoastText(e.selection.renderedText))
      };
      final hour = byTime[entry.targetTime.millisecondsSinceEpoch]!;
      final selection = selectHour(hour, ids, texts);
      if (selection != null) {
        retained.add(HourlyTimelineRoast(hour: hour, selection: selection));
      }
    }
    final result = scheduleHourlyTimelineRoasts(
      hours: records,
      retained: retained,
      select: selectHour,
    );
    _timelinePlans.remove(planKey);
    _timelinePlans[planKey] = result;
    while (_timelinePlans.length > 20) {
      _timelinePlans.remove(_timelinePlans.keys.first);
    }
    return result;
  }

  /// Revalidates a displayed selection without replacing it or recording an
  /// impression. Share/reveal guards may call this after weather/time changes.
  bool isSelectionEligible(
    RoastSelection selection, {
    WeatherBundle? bundle,
    DateTime? now,
    TemperatureUnit unit = TemperatureUnit.fahrenheit,
  }) {
    final source = bundle ?? weather;
    final evaluation = now ?? DateTime.now();
    final context = source == null
        ? WeatherRoastContext.unavailable(
            now: evaluation,
            scope: selection.scope,
            locale: selection.line.locale,
            temperatureUnit: unit)
        : WeatherRoastContext.fromWeatherBundle(source,
            now: evaluation,
            scope: selection.scope,
            targetTime: selection.windowStart,
            targetEnd: selection.windowEnd,
            selectedLocation: location,
            temperatureUnit: unit,
            locale: selection.line.locale,
            activity: RoastActivity.values
                .where((v) => v.name == activity)
                .firstOrNull);
    if (repository.disabledIds.contains(selection.id)) return false;
    if (selection.source == 'application') {
      return selection.line.isSevere == context.requiresSafetyMessage;
    }
    return const RoastSelector()
        .eligibilityFailures(
          line: selection.line,
          pack: _pack ?? LocalRoastEngine.fallbackPack,
          context: context,
          persona: selection.persona,
          type: selection.line.type,
          maxLevel: intensity,
          disabledIds: repository.disabledIds,
        )
        .isEmpty;
  }

  /// Called only by the foreground lifecycle boundary. Optional sync never
  /// blocks a displayed choice and is disabled until an origin is verified.
  Future<void> syncUpdatesInForeground(
      {RoastUpdatePolicy policy = RoastUpdatePolicy.disabled}) async {
    if (!policy.enabled) return;
    await repository.syncIfDue(
        policy: policy,
        relevantPersonas: Set.unmodifiable(_usedPersonas),
        locale: 'en-US');
    try {
      _pack =
          await repository.loadInstalledPack(appBuildNumber: policy.appBuild);
      if (!_disposed) notifyListeners();
    } catch (_) {/* Installed and bundled content remain usable. */}
  }

  bool commitDisplayed(RoastSelection selection) {
    if (!engine.commitDisplayed(selection)) return false;
    _exposures.add(selection);
    if (_exposures.length > 200) _exposures.removeAt(0);
    _save();
    return true;
  }

  void _save() {
    if (_preferences == null || _savePending) return;
    _savePending = true;
    scheduleMicrotask(() async {
      _savePending = false;
      try {
        await _preferences!
            .setString(_historyKey, jsonEncode(engine.exportHistory()));
        if (activity == null) {
          await _preferences!.remove(_activityKey);
        } else {
          await _preferences!.setString(_activityKey, activity!);
        }
        await _preferences!.setString(_intensityKey, intensity.name);
        await _preferences!
            .setString(_feedbackKey, jsonEncode(_localPreferences.toJson()));
      } catch (_) {
        // Selection remains usable if local storage is unavailable.
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
