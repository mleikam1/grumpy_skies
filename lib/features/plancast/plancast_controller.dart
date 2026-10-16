import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/temperature_unit.dart';
import '../../models/weather_models.dart';
import '../../repositories/weather_repository.dart';
import '../roasts/content/roast_pack_repository.dart';
import '../roasts/content/weather_roast_models.dart';
import '../roasts/services/local_roast_engine.dart';
import 'calendar_repository.dart';
import 'event_weather_evaluator.dart';
import 'forecast_change_detector.dart';
import 'plancast_briefing.dart';
import 'plancast_models.dart';
import 'plancast_notification_planner.dart';
import 'platform/plancast_platform.dart';
import 'venue_weather_repository.dart';

export 'plancast_models.dart';

/// Feature state is isolated from Today, radar, analytics and ad controllers.
/// Calendar snapshots and rendered briefings are memory-only. Protected native
/// storage holds just selected calendars, expiring overrides and preferences.
class PlanCastController extends ChangeNotifier {
  PlanCastController(
      {required WeatherRepository weatherRepository,
      PlanCastPlatform? platform,
      CalendarRepository? calendarRepository,
      RoastPackRepository? roastPackRepository,
      DateTime Function()? clock})
      : platform = platform ?? PlanCastPlatform(),
        clock = clock ?? DateTime.now,
        venueWeather = VenueWeatherRepository(weatherRepository, clock: clock),
        _roastPackRepository = roastPackRepository ?? RoastPackRepository(),
        _injectedCalendars = calendarRepository;
  final PlanCastPlatform platform;
  final DateTime Function() clock;
  final VenueWeatherRepository venueWeather;
  final CalendarRepository? _injectedCalendars;
  final RoastPackRepository _roastPackRepository;
  late final CalendarRepository calendarRepository =
      _injectedCalendars ?? DeviceCalendarRepository(platform);
  final evaluator = const EventWeatherEvaluator();
  final _composer = const PlanCastBriefingComposer();
  final _planner = const PlanCastNotificationPlanner();
  final _changeDetector = const ForecastChangeDetector();
  final Map<String, DateTime> _lastChangeNotice = {};
  final Map<String, DateTime> _pendingChanges = {};
  final Map<String, Set<String>> _routineReservations = {};
  final Map<String, DateTime> _reservationTimes = {};
  final Set<String> _deferredEvents = {};
  LocalRoastEngine _roasts = LocalRoastEngine();
  RoastPack? _pack;
  final Map<String, EventOverride> _overrides = {};
  final Map<String, WeatherBundle> _eventWeather = {};
  final Map<String, String> _eventWeatherVenueKeys = {};
  final Map<String, PlanCastBriefing> _briefings = {};
  final Map<String, String> _opinions = {};
  StreamSubscription<String>? _subscription;
  Timer? _debounce;
  Future<void>? _initializing;
  Future<void> _writes = Future.value();
  SharedPreferences? _publicPreferences;
  int _revision = 0;
  int _connectionGeneration = 0;
  bool _disposed = false;
  bool _connected = false;
  bool loading = false;
  bool invitationDismissed = false;
  String? error;
  String calendarPermission = 'notDetermined';
  String notificationPermission = 'notDetermined';
  List<DeviceCalendar> calendars = const [];
  Set<String> selectedCalendarIds = {};
  List<PlanCastEventWeather> events = const [];
  PlanCastPreferences preferences = const PlanCastPreferences();
  DateTime? calendarSyncedAt;
  bool get supported => calendarRepository.supported;
  bool get connected => _connected && calendarPermission == 'authorized';
  static const _dismissKey = 'plancast_invitation_dismissed_v1';

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      _publicPreferences = await SharedPreferences.getInstance();
      invitationDismissed = _publicPreferences?.getBool(_dismissKey) ?? false;
      if (!supported) {
        calendarPermission = 'unsupported';
        _notify();
        return;
      }
      final raw = await platform.secureRead();
      if (raw != null) {
        final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final history = Map<String, dynamic>.from(
            (value['routineReservations'] as Map?) ?? {});
        final reservedTimes = Map<String, dynamic>.from(
            (value['reservationTimes'] as Map?) ?? {});
        for (final entry in reservedTimes.entries) {
          final time = DateTime.tryParse(entry.value.toString());
          if (time != null &&
              clock().difference(time) < const Duration(days: 2)) {
            _reservationTimes[entry.key] = time;
          }
        }
        for (final entry in history.entries) {
          final date = DateTime.tryParse(entry.key);
          if (date != null && clock().difference(date).inDays < 2) {
            _routineReservations[entry.key] =
                (entry.value as List).whereType<String>().toSet();
          }
        }
        final changes = Map<String, dynamic>.from(
            (value['lastChangeNotice'] as Map?) ?? {});
        for (final entry in changes.entries) {
          final date = DateTime.tryParse(entry.value.toString());
          if (date != null &&
              clock().difference(date) < const Duration(days: 1)) {
            _lastChangeNotice[entry.key] = date;
          }
        }
        _connected = value['connected'] == true;
        selectedCalendarIds = ((value['calendarIds'] as List?) ?? const [])
            .whereType<String>()
            .toSet();
        preferences = PlanCastPreferences.fromJson(
            Map<String, dynamic>.from((value['preferences'] as Map?) ?? {}));
        final overrides =
            Map<String, dynamic>.from((value['overrides'] as Map?) ?? {});
        for (final entry in overrides.entries) {
          final item = EventOverride.fromJson(
              Map<String, dynamic>.from(entry.value as Map));
          if (item.expiresAt.isAfter(clock())) _overrides[entry.key] = item;
        }
      }
      calendarPermission = await calendarRepository.permission();
      notificationPermission = await platform.notificationPermission();
      _subscription = calendarRepository.changes.listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 600), () {
          if (connected) unawaited(refresh());
        });
      });
      if (_connected && calendarPermission != 'authorized') {
        await disconnect();
        return;
      }
      if (connected) {
        await calendarRepository.startObserving();
        await refresh();
      }
    } catch (_) {
      error =
          'PlanCast could not load. Your normal forecast is still available.';
    }
    _notify();
    // Local bundled content only. No external pack sync or private roast history.
    unawaited(_loadRoasts());
  }

  Future<void> _loadRoasts() async {
    try {
      _pack = await _roastPackRepository.loadPack();
      _briefings.clear();
      _opinions.clear();
      _notify();
    } catch (_) {/* Humor is optional. */}
  }

  /// Called only by the explicit Connect action after the privacy explanation.
  /// No calendar is silently selected.
  Future<void> connect() async {
    await initialize();
    if (!supported) return;
    error = null;
    try {
      calendarPermission = await calendarRepository.requestPermission();
      if (calendarPermission != 'authorized') {
        error = calendarPermission == 'writeOnly'
            ? 'Write-only calendar access cannot read plans. Allow full event access in device settings.'
            : 'Calendar access was not granted. Device weather works without it.';
        _notify();
        return;
      }
      _connected = true;
      calendars = await calendarRepository.calendars();
      await calendarRepository.startObserving();
      await _save();
    } catch (_) {
      error =
          'Device calendars could not be connected. Try again in device settings.';
    }
    _notify();
  }

  Future<void> selectCalendars(Set<String> ids) async {
    selectedCalendarIds = ids.intersection(calendars.map((c) => c.id).toSet());
    _revision++;
    events = const [];
    _eventWeather.clear();
    _eventWeatherVenueKeys.clear();
    _invalidateBriefings();
    await _replaceNotifications(const []);
    await _save();
    await refresh();
  }

  /// Also call on foreground resume; authorization is checked before every read.
  Future<void> refresh() async {
    if (!supported || !_connected) return;
    final revision = ++_revision;
    loading = true;
    error = null;
    _notify();
    try {
      calendarPermission = await calendarRepository.permission();
      if (calendarPermission != 'authorized') {
        await disconnect();
        return;
      }
      notificationPermission = await platform.notificationPermission();
      calendars = await calendarRepository.calendars();
      if (revision != _revision || _disposed) return;
      selectedCalendarIds =
          selectedCalendarIds.intersection(calendars.map((c) => c.id).toSet());
      final now = clock().toUtc();
      final localNow = clock().toLocal();
      final civilToday =
          DateTime.utc(localNow.year, localNow.month, localNow.day);
      final previous = {for (final item in events) item.event.id: item};
      final source = await calendarRepository.events(
          calendarIds: selectedCalendarIds,
          // Android all-day bounds encode UTC civil dates; include the previous
          // UTC day so a still-current floating day west of UTC is not dropped.
          // Timed history is immediately filtered below and never persisted.
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 14)));
      if (revision != _revision || _disposed) return;
      if (!await _stillAuthorized(revision)) return;
      _overrides.removeWhere((_, value) => !value.expiresAt.isAfter(now));
      final normalized = source
          .where((e) =>
              selectedCalendarIds.contains(e.calendarId) &&
              (e.isAllDay
                  ? e.allDayEnd!.isAfter(civilToday)
                  : e.endUtc.isAfter(now)) &&
              e.startUtc.isBefore(now.add(const Duration(days: 14))))
          .toList()
        ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
      calendarSyncedAt = now;
      _deferredEvents.clear();
      _eventWeather
          .removeWhere((key, _) => !normalized.any((e) => e.id == key));
      _eventWeatherVenueKeys
          .removeWhere((key, _) => !normalized.any((e) => e.id == key));
      // Publish missing/online states promptly. Forecast work never blocks Today.
      events =
          normalized.map((e) => _evaluate(e, _eventWeather[e.id])).toList();
      _notify();
      final results = <String, PlanCastEventWeather>{};
      final requestedVenues = <String>{};
      var cursor = 0;
      Future<void> worker() async {
        while (
            cursor < normalized.length && revision == _revision && !_disposed) {
          final event = normalized[cursor++];
          final initial = _evaluate(event, null);
          if (initial.venue == null ||
              initial.environment == EventEnvironment.online) {
            results[event.id] = initial;
            continue;
          }
          final venueKey = VenueWeatherRepository.keyFor(initial.venue!);
          if (!venueWeather.hasReusable(initial.venue!) &&
              !requestedVenues.contains(venueKey)) {
            if (requestedVenues.length >= 6) {
              _deferredEvents.add(event.id);
              results[event.id] = _evaluate(event, null);
              continue;
            }
            requestedVenues.add(venueKey);
          }
          try {
            final weather = await venueWeather.get(initial.venue!);
            if (revision != _revision || _disposed) return;
            _eventWeather[event.id] = weather;
            _eventWeatherVenueKeys[event.id] = venueKey;
            results[event.id] = _evaluate(event, weather);
          } on VenueWeatherDeferred {
            _deferredEvents.add(event.id);
            results[event.id] = _evaluate(event, null);
          } catch (_) {
            final previousWeather = _eventWeather[event.id];
            if (_eventWeatherVenueKeys[event.id] == venueKey &&
                previousWeather != null) {
              final offline = previousWeather.asOfflineCache();
              _eventWeather[event.id] = offline;
              results[event.id] = _evaluate(event, offline);
            } else {
              results[event.id] = initial;
            }
          }
        }
      }

      await Future.wait([worker(), worker()]);
      if (revision != _revision || _disposed) return;
      if (!await _stillAuthorized(revision)) return;
      events =
          normalized.map((e) => results[e.id] ?? _evaluate(e, null)).toList();
      _pendingChanges.removeWhere((id, time) =>
          !time.isAfter(now) || !events.any((e) => e.event.id == id));
      _lastChangeNotice.removeWhere(
          (_, time) => now.difference(time) > const Duration(days: 1));
      if (preferences.notifications && preferences.eventHeadsUp) {
        for (final item in events) {
          final last = _lastChangeNotice[item.event.id];
          if ((last == null ||
                  now.difference(last) >= const Duration(hours: 2)) &&
              _changeDetector.materiallyChanged(
                  previous[item.event.id], item, now)) {
            _pendingChanges[item.event.id] =
                now.add(const Duration(minutes: 1));
            _lastChangeNotice[item.event.id] = now;
          }
        }
      }
      await _schedule();
      if (!await _stillAuthorized(revision)) return;
      await _save();
    } catch (_) {
      if (revision == _revision) {
        error =
            'PlanCast could not refresh. Check permissions and connectivity; existing event information may be outdated.';
      }
    } finally {
      if (revision == _revision) {
        loading = false;
        _notify();
      }
    }
  }

  /// Native permission can change while a read or forecast request is in flight.
  /// Recheck before publication/persistence so native cleanup is never followed
  /// by reconstructing a stale connected state from an earlier async response.
  Future<bool> _stillAuthorized(int revision) async {
    final permission = await calendarRepository.permission();
    if (revision != _revision || _disposed) return false;
    calendarPermission = permission;
    if (permission != 'authorized') {
      await disconnect();
      return false;
    }
    return true;
  }

  PlanCastEventWeather _evaluate(CalendarEvent event, WeatherBundle? weather) {
    final override = _overrides[event.id] ?? _overrides[event.recurringKey];
    final environment = override?.environment ?? EventEnvironment.unknown;
    // An explicit correction revokes trust in the source's old coordinates.
    // Structured coordinates remain first choice before a user corrects them.
    final venue = override?.venue ??
        (event.hasCoordinates
            ? LocationCandidate(
                name: event.locationText.isEmpty
                    ? 'Event venue'
                    : event.locationText,
                country: '',
                lat: event.latitude!,
                lon: event.longitude!,
                source: 'calendar')
            : null);
    // Event identity can stay stable when its venue changes. A cache association
    // is valid only for the exact requested coordinates, including during a
    // failed/deferred refresh and while the next venue request is in flight.
    if (weather != null &&
        (venue == null ||
            _eventWeatherVenueKeys[event.id] !=
                VenueWeatherRepository.keyFor(venue))) {
      weather = null;
    }
    return PlanCastEventWeather(
        event: event,
        venue: venue,
        environment: environment,
        remindersEnabled: override?.remindersEnabled ?? true,
        assessment: _deferredEvents.contains(event.id) && weather == null
            ? const EventWeatherAssessment(
                coverage: ForecastCoverage.unavailable,
                impact: WeatherImpact.unavailable,
                explanation:
                    'Venue forecast deferred to limit requests. Nearest plans load first; refresh later for farther venues.')
            : evaluator.evaluate(
                event: event,
                weather: weather,
                now: clock(),
                environment: environment,
                bufferMinutes: preferences.bufferMinutes,
                hasLocation: venue != null));
  }

  Future<List<LocationCandidate>> searchVenues(String text) =>
      venueWeather.search(text);

  /// Only the source location field reaches the existing geocoder, never title
  /// or meeting contents. The UI must require an explicit candidate selection.
  Future<List<LocationCandidate>> venueCandidates(CalendarEvent event) =>
      venueWeather.search(event.locationText);
  Future<void> setEventOverride(CalendarEvent event,
      {LocationCandidate? venue,
      EventEnvironment? environment,
      bool? remindersEnabled,
      bool recurringVenue = false}) async {
    if (!connected) return;
    final key = recurringVenue ? event.recurringKey : event.id;
    final prior = _overrides[key] ??
        _overrides[event.id] ??
        _overrides[event.recurringKey];
    _overrides[key] = EventOverride(
        venue: venue ?? prior?.venue,
        environment:
            environment ?? prior?.environment ?? EventEnvironment.unknown,
        remindersEnabled: remindersEnabled ?? prior?.remindersEnabled ?? true,
        // Do not assume perpetual rights to third-party geocoding data.
        expiresAt: recurringVenue
            ? clock().add(const Duration(days: 30))
            : event.endUtc.add(const Duration(days: 1)));
    await _save();
    await refresh();
  }

  Future<void> updatePreferences(PlanCastPreferences value) async {
    preferences = PlanCastPreferences.fromJson(value.toJson());
    _invalidateBriefings();
    events = events
        .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
        .toList();
    await _schedule();
    await _save();
    _notify();
  }

  Future<void> requestNotifications() async {
    try {
      notificationPermission = await platform.requestNotificationPermission();
      await updatePreferences(preferences.copyWith(
          notifications: notificationPermission == 'authorized'));
      if (notificationPermission != 'authorized') {
        error =
            'Notifications are off. Calendar weather remains available in PlanCast.';
      }
    } catch (_) {
      error = 'Notification permission could not be checked.';
    }
    _notify();
  }

  Future<void> _schedule() async {
    if (!connected ||
        !preferences.notifications ||
        notificationPermission != 'authorized' ||
        calendarSyncedAt == null) {
      await _replaceNotifications(const []);
      return;
    }
    // The whole pending queue is replaced. Future reservations have not fired
    // and can be reassigned when an event moves or reminder settings change.
    // Retain past reservations conservatively: a prior notice may have delivered.
    final now = clock();
    _routineReservations.updateAll((_, ids) => ids.where((id) {
          final at = _reservationTimes[id];
          return at == null || !at.isAfter(now);
        }).toSet());
    _reservationTimes.removeWhere((_, at) =>
        at.isAfter(now) || now.difference(at) >= const Duration(days: 2));
    final notices = _planner.plan(
        now: clock(),
        calendarSyncedAt: calendarSyncedAt!,
        events: events,
        preferences: preferences,
        routineReservations: _routineReservations,
        forecastChanges: _pendingChanges);
    for (final notice in notices) {
      final at = DateTime.fromMillisecondsSinceEpoch(notice['fireAtMs'] as int)
          .toLocal();
      final day =
          '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      if (notice['id'] != planCastId('morning|$day')) {
        _routineReservations
            .putIfAbsent(day, () => {})
            .add(notice['id'] as String);
        _reservationTimes[notice['id'] as String] = at.toUtc();
      }
    }
    _routineReservations.removeWhere(
        (day, _) => clock().difference(DateTime.parse(day)).inDays >= 2);
    await _replaceNotifications(notices);
  }

  Future<void> _replaceNotifications(List<Map<String, dynamic>> notices) async {
    final generation = _connectionGeneration;
    try {
      await platform.replaceNotifications(notices);
      if (generation != _connectionGeneration) await platform.disconnect();
    } catch (_) {
      error =
          'PlanCast notifications could not be updated. Open device settings and try again.';
      _notify();
    }
  }

  /// Refresh display validity from the clock without making service requests.
  /// Stored snapshots remain available for comparing the next calendar refresh.
  List<PlanCastEventWeather> get currentEvents {
    final now = clock();
    final localNow = now.toLocal();
    final civilToday =
        DateTime.utc(localNow.year, localNow.month, localNow.day);
    return events
        .where((e) => e.event.isAllDay
            ? e.event.allDayEnd!.isAfter(civilToday)
            : e.event.endUtc.isAfter(now))
        .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
        .toList();
  }

  List<PlanCastEventWeather> eventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final civil = DateTime.utc(day.year, day.month, day.day);
    return currentEvents
        .where((e) => e.event.isAllDay
            ? !civil.isBefore(e.event.allDayStart!) &&
                civil.isBefore(e.event.allDayEnd!)
            : e.event.startUtc.isBefore(end.toUtc()) &&
                e.event.endUtc.isAfter(start.toUtc()))
        .toList();
  }

  List<PlanCastEventWeather> get previews {
    final upcoming = currentEvents;
    if (upcoming.isEmpty) return const [];
    final affected = [...upcoming]..sort((a, b) =>
        b.assessment.impact.index.compareTo(a.assessment.impact.index));
    final mostAffected =
        affected.where((e) => e.assessment.materiallyAffected).firstOrNull;
    return [
      upcoming.first,
      if (mostAffected != null &&
          mostAffected.event.id != upcoming.first.event.id)
        mostAffected
      else if (upcoming.length > 1)
        upcoming[1]
    ];
  }

  PlanCastBriefing briefingForDay(DateTime day,
      {String? personaLine,
      String? persona,
      bool? privateTitles,
      TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit}) {
    final today = eventsForDay(day);
    final tomorrow = eventsForDay(DateTime(day.year, day.month, day.day + 1));
    final hideTitles = privateTitles ?? true;
    final opinion = personaLine ??
        (persona == null ? null : _opinion(today, persona, temperatureUnit));
    final signature = [...today, ...tomorrow]
        .map((e) =>
            '${e.event.id}|${e.event.title}|${e.assessment.coverage}|${e.assessment.impact}|${e.assessment.forecastUpdatedAt}|${e.assessment.peakPrecipitationChance}|${e.assessment.explanation}')
        .join(';');
    final key =
        '${day.year}-${day.month}-${day.day}|$hideTitles|${temperatureUnit.name}|$opinion|${planCastId(signature)}';
    if (_briefings.length > 32) _briefings.remove(_briefings.keys.first);
    return _briefings.putIfAbsent(
        key,
        () => _composer.compose(
            today: today,
            tomorrow: tomorrow,
            now: clock(),
            personaLine: opinion,
            privateTitles: hideTitles));
  }

  String? _opinion(List<PlanCastEventWeather> day, String persona,
      TemperatureUnit temperatureUnit) {
    if (_pack == null || day.any((e) => e.assessment.serious)) return null;
    final item = day
        .where((e) =>
            e.assessment.usable &&
            e.assessment.coverage == ForecastCoverage.hourly)
        .firstOrNull;
    if (item == null) return null;
    final weather = _eventWeather[item.event.id];
    if (weather == null) return null;
    final key =
        '${item.event.id}|$persona|${item.venue == null ? '' : VenueWeatherRepository.keyFor(item.venue!)}|'
        '${item.assessment.forecastUpdatedAt}|${item.assessment.condition}|${item.assessment.peakPrecipitationChance}|'
        '${item.assessment.minTemperatureC}|${item.assessment.maxTemperatureC}|${item.assessment.maxWindKph}|${item.assessment.impact}';
    // Unit changes rerender the same engine selection instead of keeping a
    // previously cached Fahrenheit string or choosing a different punchline.
    final opinion = _opinions.putIfAbsent('$key|${temperatureUnit.name}', () {
      // Roast placeholders may include a city name. Never substitute a calendar
      // venue/address there, including in a privacy-preserving spoken briefing.
      final roastVenue = item.venue == null
          ? null
          : LocationCandidate(
              name: 'your venue',
              country: '',
              lat: item.venue!.lat,
              lon: item.venue!.lon,
              source: 'plancast');
      final context = WeatherRoastContext.fromWeatherBundle(weather,
          now: clock(),
          temperatureUnit: temperatureUnit,
          scope: RoastScope.hourly,
          targetTime: item.event.startUtc,
          targetEnd: item.event.endUtc,
          selectedLocation: roastVenue);
      if (context.requiresSafetyMessage) return '';
      return _roasts
          .select(
              pack: _pack!,
              context: context,
              persona: persona,
              type: RoastType.hourly,
              maxLevel: RoastLevel.mild,
              slot: key)
          .renderedText;
    });
    return opinion.trim().isEmpty ? null : opinion;
  }

  Future<void> dismissInvitation() async {
    invitationDismissed = true;
    _publicPreferences ??= await SharedPreferences.getInstance();
    await _publicPreferences!.setBool(_dismissKey, true);
    _notify();
  }

  Future<String> speechStatus() => platform.speechStatus();
  Future<bool> speakBriefing(String text) => platform.speak(text);
  Future<void> stopSpeaking() => platform.stopSpeaking();
  Future<String?> consumeNotificationRoute() =>
      platform.consumeNotificationRoute();
  Future<void> onResume() => refresh();

  Future<void> disconnect() async {
    _revision++;
    _connectionGeneration++;
    _debounce?.cancel();
    _connected = false;
    loading = false;
    events = const [];
    calendars = const [];
    selectedCalendarIds = {};
    preferences = const PlanCastPreferences();
    calendarSyncedAt = null;
    _overrides.clear();
    _lastChangeNotice.clear();
    _pendingChanges.clear();
    _routineReservations.clear();
    _reservationTimes.clear();
    _deferredEvents.clear();
    _eventWeather.clear();
    _eventWeatherVenueKeys.clear();
    venueWeather.clear();
    _invalidateBriefings();
    _roasts = LocalRoastEngine();
    _notify();
    // Wait for prior protected writes before deletion so a late save cannot
    // resurrect private data after disconnect.
    await _writes;
    try {
      await calendarRepository.stopObserving();
      await platform.disconnect();
    } catch (_) {
      error =
          'Local cleanup could not finish. Retry Disconnect when the device is available.';
    }
    _notify();
  }

  Future<void> _save() {
    final generation = _connectionGeneration;
    final state = jsonEncode({
      'routineReservations': _routineReservations
          .map((key, value) => MapEntry(key, value.toList())),
      'reservationTimes': _reservationTimes
          .map((key, value) => MapEntry(key, value.toIso8601String())),
      'lastChangeNotice': _lastChangeNotice
          .map((key, value) => MapEntry(key, value.toIso8601String())),
      'connected': _connected,
      'calendarIds': selectedCalendarIds.toList(),
      'preferences': preferences.toJson(),
      'overrides': _overrides.map((key, value) => MapEntry(key, value.toJson()))
    });
    _writes = _writes.catchError((_) {}).then((_) async {
      if (generation != _connectionGeneration || _disposed) return;
      try {
        await platform.secureWrite(state);
      } catch (_) {
        error = 'PlanCast preferences could not be saved securely.';
        _notify();
      }
    });
    return _writes;
  }

  void _invalidateBriefings() {
    _briefings.clear();
    _opinions.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(calendarRepository.stopObserving());
    unawaited(platform.stopSpeaking());
    venueWeather.clear();
    _eventWeather.clear();
    _eventWeatherVenueKeys.clear();
    _overrides.clear();
    super.dispose();
  }
}
