import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/temperature_unit.dart';
import '../../models/weather_models.dart';
import '../../repositories/weather_repository.dart';
import 'calendar_repository.dart';
import 'device_area_service.dart';
import 'location_resolver.dart';
import 'smart_location_lookup.dart';
import 'smart_location_travel.dart';
import 'event_weather_evaluator.dart';
import 'forecast_change_detector.dart';
import 'plancast_briefing.dart';
import 'plancast_models.dart';
import 'plancast_day_summary.dart';
import 'plancast_readout.dart';
import 'plancast_notification_planner.dart';
import 'platform/plancast_platform.dart';
import 'venue_weather_repository.dart';

export 'plancast_models.dart';
export 'plancast_day_summary.dart';
export 'plancast_readout.dart';

/// Feature state is isolated from Today, radar, analytics and ad controllers.
/// Calendar snapshots and rendered briefings are memory-only. Protected native
/// storage holds selected calendars, intentional location rules and preferences.
class PlanCastController extends ChangeNotifier {
  PlanCastController(
      {required WeatherRepository weatherRepository,
      PlanCastPlatform? platform,
      CalendarRepository? calendarRepository,
      DeviceAreaService? deviceAreaService,
      SmartLocationLookup? locationLookup,
      this.locationResolver = const SmartLocationResolver(),
      this.maximumNewAreasPerRefresh = 6,
      DateTime Function()? clock})
      : platform = platform ?? PlanCastPlatform(),
        clock = clock ?? DateTime.now,
        venueWeather = VenueWeatherRepository(weatherRepository, clock: clock),
        _injectedCalendars = calendarRepository,
        deviceAreaService = deviceAreaService ??
            ForegroundDeviceAreaService(
                reverseGeocode: weatherRepository.reverseGeocode, clock: clock),
        locationLookup = locationLookup ??
            SmartLocationLookup(weatherRepository, clock: clock);
  final PlanCastPlatform platform;
  final DeviceAreaService deviceAreaService;
  final SmartLocationLookup locationLookup;
  final SmartLocationResolver locationResolver;
  final int maximumNewAreasPerRefresh;
  SmartLocationState smartLocations = const SmartLocationState();
  DeviceAreaSample? _area;
  StreamSubscription<DeviceAreaSample?>? _areaSubscription;
  final SmartTravelTracker _travelTracker = SmartTravelTracker();
  TravelNotice? travelNotice;
  DeviceAreaMovement? _pendingMovement;
  SmartLocationUndo? _locationUndo;
  final Set<String> _loadingWeather = {};
  bool _foreground = true;
  int _readingArea = 0;
  Future<void> _notificationWrites = Future.value();
  final DateTime Function() clock;
  final VenueWeatherRepository venueWeather;
  final CalendarRepository? _injectedCalendars;
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
  final Map<String, EventOverride> _overrides = {};
  final Map<String, WeatherBundle> _eventWeather = {};
  final Map<String, String> _eventWeatherVenueKeys = {};
  final Map<String, PlanCastBriefing> _briefings = {};
  final Map<String, PlanCastReadout> _readouts = {};
  // Current-day completed identity is memory-only and never used for requests.
  List<CalendarEvent> _completedEvents = const [];
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
    final generation = _connectionGeneration;
    try {
      _publicPreferences = await SharedPreferences.getInstance();
      invitationDismissed = _publicPreferences?.getBool(_dismissKey) ?? false;
      if (!supported) {
        calendarPermission = 'unsupported';
        _notify();
        return;
      }
      final raw = await platform.secureRead();
      if (generation != _connectionGeneration || _disposed) return;
      if (raw != null) {
        final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        smartLocations = SmartLocationState.fromStorage(value).prune(clock());
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
      final permission = await calendarRepository.permission();
      final notifications = await platform.notificationPermission();
      if (generation != _connectionGeneration || _disposed) return;
      calendarPermission = permission;
      notificationPermission = notifications;
      _areaSubscription = deviceAreaService.changes.listen(_areaChanged);
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
        await _activateArea();
        await calendarRepository.startObserving();
        await refresh();
      }
    } catch (_) {
      error =
          'PlanCast could not load. Your normal forecast is still available.';
    }
    _notify();
  }

  /// Called only by the explicit Connect action after the privacy explanation.
  /// No calendar is silently selected.
  Future<void> connect() async {
    await initialize();
    if (!supported || _disposed) return;
    final generation = _connectionGeneration;
    error = null;
    try {
      final permission = await calendarRepository.requestPermission();
      if (generation != _connectionGeneration || _disposed) return;
      calendarPermission = permission;
      if (calendarPermission != 'authorized') {
        error = calendarPermission == 'writeOnly'
            ? 'Write-only calendar access cannot read plans. Allow full event access in device settings.'
            : 'Calendar access was not granted. Device weather works without it.';
        _notify();
        return;
      }
      _connected = true;
      await _activateArea();
      if (generation != _connectionGeneration || _disposed) return;
      final availableCalendars = await calendarRepository.calendars();
      if (generation != _connectionGeneration || _disposed) return;
      calendars = availableCalendars;
      await calendarRepository.startObserving();
      await _save();
    } catch (_) {
      error =
          'Device calendars could not be connected. Try again in device settings.';
    }
    _notify();
  }

  Future<void> selectCalendars(Set<String> ids) async {
    if (!connected) return;
    selectedCalendarIds = ids.intersection(calendars.map((c) => c.id).toSet());
    _revision++;
    events = const [];
    _completedEvents = const [];
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
      final permission = await calendarRepository.permission();
      if (revision != _revision || _disposed || !_connected) return;
      calendarPermission = permission;
      if (calendarPermission != 'authorized') {
        await disconnect();
        return;
      }
      final notifications = await platform.notificationPermission();
      if (revision != _revision || _disposed || !_connected) return;
      notificationPermission = notifications;
      await _refreshArea();
      if (revision != _revision || _disposed || !_connected) return;
      smartLocations = smartLocations.prune(clock());
      final availableCalendars = await calendarRepository.calendars();
      if (revision != _revision || _disposed || !_connected) return;
      calendars = availableCalendars;
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
      _completedEvents = source
          .where((e) =>
              selectedCalendarIds.contains(e.calendarId) &&
              !e.isAllDay &&
              !e.endUtc.isAfter(now) &&
              PlanCastDaySummary.occursOnDay(e, localNow))
          .toList();
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
      _loadingWeather
        ..clear()
        ..addAll(normalized.map((e) => e.id));
      _eventWeather
          .removeWhere((key, _) => !normalized.any((e) => e.id == key));
      _eventWeatherVenueKeys
          .removeWhere((key, _) => !normalized.any((e) => e.id == key));
      // Publish missing/online states promptly. Forecast work never blocks Today.
      events =
          normalized.map((e) => _evaluate(e, _eventWeather[e.id])).toList();
      _updateTravelNotice();
      _notify();
      final results = <String, PlanCastEventWeather>{};
      final requestedVenues = <String>{};
      var cursor = 0;
      Future<void> worker() async {
        while (
            cursor < normalized.length && revision == _revision && !_disposed) {
          final event = normalized[cursor++];
          var resolution = _resolve(event);
          if (smartLocations.onlineMatchingEnabled) {
            for (final request in resolution.lookupRequests) {
              await locationLookup.lookup(request, enabled: true);
              if (revision != _revision || _disposed || !_connected) return;
            }
          }
          final initial = _evaluate(event, null);
          if (initial.venue == null ||
              initial.environment == EventEnvironment.online) {
            _loadingWeather.remove(event.id);
            results[event.id] = initial;
            continue;
          }
          final venueKey = VenueWeatherRepository.keyFor(initial.venue!);
          if (!venueWeather.hasReusable(initial.venue!) &&
              !requestedVenues.contains(venueKey)) {
            if (requestedVenues.length >= maximumNewAreasPerRefresh) {
              _loadingWeather.remove(event.id);
              _deferredEvents.add(event.id);
              results[event.id] = _evaluate(event, null);
              continue;
            }
            requestedVenues.add(venueKey);
          }
          try {
            final weather = await venueWeather.get(initial.venue!);
            if (revision != _revision || _disposed) return;
            _loadingWeather.remove(event.id);
            _eventWeather[event.id] = weather;
            _eventWeatherVenueKeys[event.id] = venueKey;
            results[event.id] = _evaluate(event, weather);
          } on VenueWeatherDeferred {
            _loadingWeather.remove(event.id);
            _deferredEvents.add(event.id);
            results[event.id] = _evaluate(event, null);
          } catch (_) {
            if (revision != _revision || _disposed || !_connected) return;
            _loadingWeather.remove(event.id);
            final previousWeather = _eventWeather[event.id];
            if (_eventWeatherVenueKeys[event.id] == venueKey &&
                previousWeather != null) {
              final offline = previousWeather.asOfflineCache();
              _eventWeather[event.id] = offline;
              results[event.id] = _evaluate(event, offline);
            } else {
              results[event.id] = _evaluate(event, null);
            }
          }
        }
      }

      await Future.wait([worker(), worker()]);
      if (revision != _revision || _disposed) return;
      if (!await _stillAuthorized(revision)) return;
      _loadingWeather.clear();
      events =
          normalized.map((e) => results[e.id] ?? _evaluate(e, null)).toList();
      _updateTravelNotice();
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
        _loadingWeather.clear();
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

  LocationResolution _resolve(CalendarEvent event) => locationResolver.resolve(
      event: event,
      now: clock(),
      state: smartLocations,
      occurrenceOverride: _overrides[event.id],
      deviceArea: deviceAreaService.failure == null ? _area : null,
      lastKnownArea: _area,
      lookupResults: locationLookup.cachedResults);

  PlanCastEventWeather _evaluate(CalendarEvent event, WeatherBundle? weather) {
    final override = _overrides[event.id] ??
        _overrides[event.recurringKey] ??
        _overrides[event.legacyRecurringKey];
    final resolution = _resolve(event);
    final location = resolution.location;
    final environment = resolution.isOnline
        ? EventEnvironment.online
        : override?.environment == EventEnvironment.online
            ? EventEnvironment.unknown
            : override?.environment ?? EventEnvironment.unknown;
    final venue = location.hasWeatherBasis ? location.candidate : null;
    if (weather != null &&
        (venue == null ||
            _eventWeatherVenueKeys[event.id] !=
                VenueWeatherRepository.keyFor(venue))) {
      weather = null;
    }
    final EventWeatherAssessment assessment;
    if (!resolution.isOnline &&
        venue != null &&
        weather == null &&
        _deferredEvents.contains(event.id)) {
      assessment = const EventWeatherAssessment(
          coverage: ForecastCoverage.deferred,
          impact: WeatherImpact.unavailable,
          explanation:
              'Forecast deferred to limit requests. Nearer plans load first; refresh later.');
    } else if (!resolution.isOnline &&
        venue != null &&
        weather == null &&
        _loadingWeather.contains(event.id)) {
      assessment = const EventWeatherAssessment(
          coverage: ForecastCoverage.loading,
          impact: WeatherImpact.unavailable,
          explanation: 'Loading the forecast for this area.');
    } else if (!resolution.isOnline && venue == null) {
      assessment = EventWeatherAssessment(
          coverage: ForecastCoverage.needsLocation,
          impact: WeatherImpact.unavailable,
          explanation: location.reason);
    } else {
      assessment = evaluator.evaluate(
          event: event,
          weather: weather,
          now: clock(),
          environment: environment,
          bufferMinutes: preferences.bufferMinutes,
          hasLocation: venue != null,
          isStay: resolution.evidence.isStay);
    }
    return PlanCastEventWeather(
        event: event,
        venue: venue,
        environment: environment,
        resolvedLocation: location,
        participation: resolution.participation,
        venueTimeZone: weather?.current.timezone,
        venueTimeZoneOffset: weather?.current.timezoneOffset,
        remindersEnabled: override?.remindersEnabled ?? true,
        assessment: assessment);
  }

  Future<List<LocationCandidate>> searchVenues(String text) =>
      venueWeather.search(text);

  /// Optional matching uses locally extracted geographic queries only. Manual
  /// city search remains an explicit user action in the correction sheet.
  Future<List<LocationCandidate>> venueCandidates(CalendarEvent event) async {
    if (!smartLocations.onlineMatchingEnabled) return const [];
    final resolution = _resolve(event);
    for (final request in resolution.lookupRequests) {
      final result = await locationLookup.lookup(request, enabled: true);
      if (result.usableAt(clock())) return result.candidates;
    }
    return const [];
  }

  Future<void> setEventOverride(CalendarEvent event,
      {LocationCandidate? venue,
      EventEnvironment? environment,
      bool? remindersEnabled,
      bool recurringVenue = false}) async {
    if (!connected) return;
    final key = recurringVenue ? event.recurringKey : event.id;
    final prior = _overrides[key] ??
        _overrides[event.id] ??
        _overrides[event.recurringKey] ??
        _overrides[event.legacyRecurringKey];
    _overrides[key] = EventOverride(
        venue: venue ?? prior?.venue,
        environment:
            environment ?? prior?.environment ?? EventEnvironment.unknown,
        remindersEnabled: remindersEnabled ?? prior?.remindersEnabled ?? true,
        // Do not assume perpetual rights to third-party geocoding data.
        expiresAt: recurringVenue
            ? clock().add(const Duration(days: 30))
            : event.endUtc.add(const Duration(days: 1)));
    if (venue != null || environment == EventEnvironment.online) {
      await setLocationChoice(
          event,
          environment == EventEnvironment.online
              ? const LocationChoice.online()
              : LocationChoice.place(venue!),
          scope: recurringVenue && event.isRecurring
              ? LocationRuleScope.seriesMissing
              : LocationRuleScope.occurrence);
    } else {
      if (environment != null) {
        smartLocations = smartLocations.copyWith(
            rules: smartLocations.rules
                .where((r) => !(r.targetId == event.id &&
                    r.choice.kind == LocationChoiceKind.online))
                .toList());
      }
      await _locationsChanged();
    }
  }

  Future<void> updatePreferences(PlanCastPreferences value) async {
    if (!connected) return;
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

  Future<void> _replaceNotifications(List<Map<String, dynamic>> notices) {
    final generation = _connectionGeneration;
    final revision = _revision;
    // Serialize native queue replacement. A stale request already in native
    // code completes before the newer cancellation/replan, never after it.
    _notificationWrites =
        _notificationWrites.catchError((_) {}).then((_) async {
      if (_disposed ||
          generation != _connectionGeneration ||
          (notices.isNotEmpty && revision != _revision)) {
        return;
      }
      try {
        await platform.replaceNotifications(notices);
      } catch (_) {
        if (generation != _connectionGeneration || _disposed) return;
        error =
            'PlanCast notifications could not be updated. Open device settings and try again.';
        _notify();
      }
    });
    return _notificationWrites;
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

  PlanCastDaySummary summaryForDay(DateTime day,
          {Set<String>? calendarFilter}) =>
      PlanCastDaySummary.build(
          day: day,
          now: clock(),
          events:
              events.map((e) => _evaluate(e.event, _eventWeather[e.event.id])),
          completedEvents: _completedEvents,
          connected: connected,
          selectedCalendarIds: selectedCalendarIds,
          loading: loading,
          calendarFilter: calendarFilter);

  PlanCastAgendaSummary summaryForRange(DateTime start,
      {int days = 7, Set<String>? calendarFilter}) {
    final snapshot = events
        .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
        .toList();
    final now = clock();
    return PlanCastAgendaSummary(
        start: DateTime(start.year, start.month, start.day),
        days: [
          for (var i = 0; i < days.clamp(0, 14); i++)
            PlanCastDaySummary.build(
                day: DateTime(start.year, start.month, start.day + i),
                now: now,
                events: snapshot,
                completedEvents: _completedEvents,
                connected: connected,
                selectedCalendarIds: selectedCalendarIds,
                loading: loading,
                calendarFilter: calendarFilter)
        ]);
  }

  PlanCastReadout readoutForDay(DateTime day,
      {TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
      Set<String>? calendarFilter,
      PlanCastDaySummary? summary,
      bool privateTitles = true}) {
    final snapshot =
        summary ?? summaryForDay(day, calendarFilter: calendarFilter);
    final key = '${snapshot.signature}|${temperatureUnit.name}|$privateTitles';
    if (_readouts.length >= 64) _readouts.remove(_readouts.keys.first);
    return _readouts.putIfAbsent(
        key,
        () => const PlanCastReadoutComposer().compose(
            summary: snapshot,
            now: clock(),
            temperatureUnit: temperatureUnit,
            privateTitles: privateTitles));
  }

  /// UI-only access: no forecast/geocoding request, persistence, or budget reset.
  /// A detail opened from an old row cannot show hours from its replaced venue.
  List<HourlyForecast> cachedHoursForEvent(PlanCastEventWeather item) {
    if (!connected || item.event.isAllDay) return const [];
    final latest =
        currentEvents.where((e) => e.event.id == item.event.id).firstOrNull;
    final weather = _eventWeather[item.event.id];
    if (latest == null ||
        weather == null ||
        latest.isOnline ||
        item.venue == null ||
        latest.venue == null ||
        !latest.assessment.usable ||
        weather.isOfflineCache ||
        _eventWeatherVenueKeys[item.event.id] !=
            VenueWeatherRepository.keyFor(latest.venue!) ||
        VenueWeatherRepository.keyFor(item.venue!) !=
            VenueWeatherRepository.keyFor(latest.venue!)) {
      return const [];
    }
    final age = clock().difference(weather.current.lastUpdated);
    if (age > evaluator.maximumAge || age < const Duration(minutes: -5)) {
      return const [];
    }
    final buffer = Duration(minutes: preferences.bufferMinutes);
    final start = latest.event.startUtc.subtract(buffer);
    final end = latest.event.endUtc.add(buffer);
    final hours = <int, HourlyForecast>{};
    for (final hour in weather.hourly) {
      if (hour.time.isBefore(end) &&
          hour.time.add(const Duration(hours: 1)).isAfter(start)) {
        hours.putIfAbsent(hour.time.toUtc().millisecondsSinceEpoch, () => hour);
      }
    }
    return hours.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  List<PlanCastEventWeather> get previews {
    final upcoming = eventsForDay(clock());
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
      {bool? privateTitles,
      TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit}) {
    final today = eventsForDay(day);
    final tomorrow = eventsForDay(DateTime(day.year, day.month, day.day + 1));
    final hideTitles = privateTitles ?? true;
    final signature = [...today, ...tomorrow]
        .map((e) =>
            '${e.event.id}|${e.event.title}|${e.event.startUtc}|${e.event.endUtc}|${e.event.timeZone}|${e.venueTimeZone}|${e.resolvedLocation?.signature}|${e.assessment.coverage}|${e.assessment.impact}|${e.assessment.forecastUpdatedAt}|${e.assessment.peakPrecipitationChance}|${e.assessment.explanation}')
        .join(';');
    final key =
        '${day.year}-${day.month}-${day.day}|$hideTitles|${temperatureUnit.name}|${planCastId(signature)}';
    if (_briefings.length > 32) _briefings.remove(_briefings.keys.first);
    return _briefings.putIfAbsent(
        key,
        () => _composer.compose(
            today: today,
            tomorrow: tomorrow,
            now: clock(),
            privateTitles: hideTitles));
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
  Future<void> onResume() async {
    _foreground = true;
    if (connected) await _activateArea();
    await refresh();
  }

  Future<void> onPause() async {
    _foreground = false;
    await deviceAreaService.setActive(false);
    await stopSpeaking();
  }

  Future<void> disconnect() async {
    _revision++;
    _connectionGeneration++;
    _debounce?.cancel();
    _connected = false;
    loading = false;
    events = const [];
    _completedEvents = const [];
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
    _loadingWeather.clear();
    smartLocations = const SmartLocationState();
    _area = null;
    travelNotice = null;
    _pendingMovement = null;
    _locationUndo = null;
    _travelTracker.clear();
    locationLookup.clear();
    await deviceAreaService.clear();
    _eventWeather.clear();
    _eventWeatherVenueKeys.clear();
    venueWeather.clear();
    _invalidateBriefings();
    _notify();
    // Wait for prior protected writes before deletion so a late save cannot
    // resurrect private data after disconnect.
    await _writes;
    await _notificationWrites;
    try {
      await calendarRepository.stopObserving();
      await platform.disconnect();
    } catch (_) {
      error =
          'Local cleanup could not finish. Retry Disconnect when the device is available.';
    }
    _notify();
  }

  Future<void> _save() async {
    if (!_connected || _disposed) return;
    final generation = _connectionGeneration;
    final revision = _revision;
    try {
      if (!await _stillAuthorized(revision)) return;
    } catch (_) {
      error = 'PlanCast could not verify calendar access before saving.';
      _notify();
      return;
    }
    if (generation != _connectionGeneration || _disposed || !_connected) return;
    final state = jsonEncode({
      'version': SmartLocationState.version,
      'smartLocations': smartLocations.toJson(),
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
    _readouts.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  LocationCandidate? get currentArea {
    final sample = _area;
    return locationResolver.policy.accepts(sample, clock(), current: false)
        ? sample!.candidate
        : null;
  }

  LocationCandidate? get defaultArea => smartLocations.defaultArea;
  List<SavedPlanCastPlace> get savedPlaces =>
      List.unmodifiable(smartLocations.savedPlaces);
  List<ScopedLocationRule> get locationRules =>
      List.unmodifiable(smartLocations.rules);
  bool get canUndoLocationChange => _locationUndo != null;
  bool get showSmartLocationExplanation =>
      connected && !smartLocations.explanationShown;
  bool get onlineLocationMatchingEnabled =>
      smartLocations.onlineMatchingEnabled;
  String get locationMatchingCapability => locationLookup.capabilityLabel;
  String? get locationPermissionMessage => deviceAreaService.failure?.message;

  Future<void> _activateArea() async {
    if (!connected || !_foreground) return;
    await deviceAreaService.setActive(true);
  }

  Future<void> _refreshArea(
      {bool requestPermission = false, bool force = false}) async {
    if (!connected || !_foreground) return;
    final generation = _connectionGeneration;
    _readingArea++;
    final previousLocations = {
      for (final item in events) item.event.id: _areaBasis(item)
    };
    try {
      final sample = await deviceAreaService.refresh(
          requestPermission: requestPermission, force: force);
      if (generation != _connectionGeneration || _disposed || !connected) {
        return;
      }
      _acceptArea(sample);
      final refreshed = events
          .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
          .toList();
      if (refreshed
          .any((e) => previousLocations[e.event.id] != _areaBasis(e))) {
        events = refreshed;
        _pendingChanges.clear();
        _invalidateBriefings();
        _notify();
        await _replaceNotifications(const []);
      }
    } finally {
      _readingArea--;
    }
  }

  String _areaBasis(PlanCastEventWeather item) =>
      '${item.venue?.lat}|${item.venue?.lon}|${item.resolvedLocation?.source}|${item.resolvedLocation?.evidenceQuality}|${item.resolvedLocation?.provisional}';

  void _acceptArea(DeviceAreaSample? sample) {
    _area = sample;
    if (sample != null && deviceAreaService.failure == null) {
      final movement = _travelTracker.observe(sample, now: clock());
      if (movement.travelConfirmed) _pendingMovement = movement;
    }
  }

  void _areaChanged(DeviceAreaSample? sample) {
    if (_disposed || !connected || !_foreground || _readingArea > 0) return;
    final before = {for (final item in events) item.event.id: _areaBasis(item)};
    _acceptArea(sample);
    var updated = events
        .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
        .toList();
    final changed = updated.any((e) => before[e.event.id] != _areaBasis(e));
    for (final item in updated) {
      if (before[item.event.id] != _areaBasis(item) &&
          !item.isOnline &&
          item.venue != null) {
        _loadingWeather.add(item.event.id);
      }
    }
    if (changed) {
      updated = updated
          .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
          .toList();
    }
    events = updated;
    _updateTravelNotice();
    _notify();
    // Denied/unchanged service observations must not cancel an unrelated
    // calendar refresh. A changed basis removes old-city weather immediately.
    if (!changed) return;
    _revision++;
    _pendingChanges.clear();
    _invalidateBriefings();
    unawaited(_replaceNotifications(const []));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (connected && _foreground) unawaited(refresh());
    });
  }

  void _updateTravelNotice() {
    final movement = _pendingMovement;
    if (movement != null) {
      final notice = const SmartTravelNotices().build(
          movement: movement,
          events: events,
          state: smartLocations,
          now: clock(),
          calendarIds: selectedCalendarIds);
      if (notice != null) {
        travelNotice = notice;
        _pendingMovement = null;
      }
    }
    final notice = travelNotice;
    if (notice == null) return;
    final affected = batchAffected(
            start: notice.windowStart,
            end: notice.windowEnd,
            calendarIds: notice.calendarIds)
        .map((e) => e.event.id)
        .toSet()
        .intersection(notice.eventIds);
    final area = currentArea;
    if (!notice.windowEnd.isAfter(clock()) ||
        affected.isEmpty ||
        area == null ||
        locationDistanceMeters(area, notice.area) > 50000) {
      travelNotice = null;
    } else {
      travelNotice = TravelNotice(
          id: notice.id,
          area: notice.area,
          windowStart: notice.windowStart,
          windowEnd: notice.windowEnd,
          calendarIds: notice.calendarIds,
          eventIds: affected,
          createdAt: notice.createdAt);
    }
  }

  Future<void> _locationsChanged() async {
    if (!connected) return;
    _revision++;
    _pendingChanges.clear();
    _loadingWeather.clear();
    _deferredEvents.clear();
    _invalidateBriefings();
    events = events
        .map((e) => _evaluate(e.event, _eventWeather[e.event.id]))
        .toList();
    _notify();
    final generation = _connectionGeneration;
    await _replaceNotifications(const []);
    await _save();
    if (generation == _connectionGeneration && connected) await refresh();
  }

  Future<void> setDefaultArea(LocationCandidate? area) async {
    if (!connected || (area != null && !area.hasValidCoordinates)) return;
    smartLocations = smartLocations.copyWith(
        defaultArea: area, clearDefaultArea: area == null);
    await _locationsChanged();
  }

  Future<void> setOnlineLocationMatching(bool enabled) async {
    if (!connected) return;
    smartLocations = smartLocations.copyWith(onlineMatchingEnabled: enabled);
    if (!enabled) locationLookup.clear();
    await _locationsChanged();
  }

  Future<void> acknowledgeSmartLocations() async {
    if (!connected) return;
    smartLocations = smartLocations.copyWith(explanationShown: true);
    await _save();
    _notify();
  }

  Future<void> useCurrentArea({bool requestPermission = true}) async {
    if (!connected) return;
    await _activateArea();
    await _refreshArea(requestPermission: requestPermission, force: true);
    await _locationsChanged();
  }

  bool _validChoice(LocationChoice choice) =>
      choice.kind != LocationChoiceKind.place ||
      choice.candidate?.hasValidCoordinates == true;

  Future<void> setLocationChoice(CalendarEvent event, LocationChoice choice,
      {LocationRuleScope scope = LocationRuleScope.occurrence}) async {
    if (!connected ||
        !_validChoice(choice) ||
        !selectedCalendarIds.contains(event.calendarId)) {
      return;
    }
    if (scope == LocationRuleScope.seriesMissing && !event.isRecurring) return;
    if (scope == LocationRuleScope.legacy) return;
    final target = switch (scope) {
      LocationRuleScope.occurrence => event.id,
      LocationRuleScope.seriesMissing => event.seriesKey,
      LocationRuleScope.calendarDefault => event.calendarId,
      LocationRuleScope.legacy => event.id,
    };
    final id = planCastId('location-rule|${scope.name}|$target');
    smartLocations = smartLocations.copyWith(rules: [
      ...smartLocations.rules.where((r) =>
          !(r.scope == scope && r.targetId == target) &&
          !(scope == LocationRuleScope.occurrence &&
              r.scope == LocationRuleScope.legacy &&
              r.targetId == target)),
      ScopedLocationRule(
          id: id,
          scope: scope,
          targetId: target,
          choice: choice,
          createdAt: clock())
    ]);
    // Legacy presentation/reminder settings are independent of location intent.
    // An explicit new location choice also clears an older explicit Online flag.
    final prior = _overrides[event.id];
    if (prior != null && scope == LocationRuleScope.occurrence) {
      _overrides[event.id] = EventOverride(
          environment: prior.environment == EventEnvironment.online
              ? EventEnvironment.unknown
              : prior.environment,
          remindersEnabled: prior.remindersEnabled,
          expiresAt: prior.expiresAt);
    }
    await _locationsChanged();
  }

  /// A reset is scoped to this occurrence, including migrated recurring choices.
  /// Sibling occurrences retain their old choice; modern defaults still apply.
  Future<void> resetEventLocation(CalendarEvent event) async {
    if (!connected || !selectedCalendarIds.contains(event.calendarId)) return;
    final hasLegacySeries = smartLocations.rules.any((r) =>
        r.enabled &&
        r.scope == LocationRuleScope.legacy &&
        event.matchesLegacyRecurringKey(r.targetId));
    smartLocations = smartLocations.copyWith(rules: [
      ...smartLocations.rules.where((r) =>
          !((r.scope == LocationRuleScope.occurrence ||
                  r.scope == LocationRuleScope.legacy) &&
              r.targetId == event.id)),
      if (hasLegacySeries)
        ScopedLocationRule(
            id: planCastId('location-rule|occurrence|${event.id}'),
            scope: LocationRuleScope.occurrence,
            targetId: event.id,
            choice: const LocationChoice.currentArea(),
            useAutomatic: true,
            createdAt: clock()),
    ]);
    final prior = _overrides[event.id] ??
        _overrides[event.recurringKey] ??
        _overrides[event.legacyRecurringKey];
    if (prior != null) {
      _overrides[event.id] = EventOverride(
          environment: prior.environment == EventEnvironment.online
              ? EventEnvironment.unknown
              : prior.environment,
          remindersEnabled: prior.remindersEnabled,
          expiresAt: event.endUtc.add(const Duration(days: 1)));
    }
    await _locationsChanged();
  }

  Future<void> removeLocationRule(String id) async {
    if (!connected) return;
    final removed = smartLocations.rules.where((r) => r.id == id).firstOrNull;
    smartLocations = smartLocations.copyWith(
        rules: smartLocations.rules.where((r) => r.id != id).toList());
    if (removed != null) {
      final prior = _overrides[removed.targetId];
      if (prior != null) {
        _overrides[removed.targetId] = EventOverride(
            environment: prior.environment == EventEnvironment.online
                ? EventEnvironment.unknown
                : prior.environment,
            remindersEnabled: prior.remindersEnabled,
            expiresAt: prior.expiresAt);
      }
    }
    await _locationsChanged();
  }

  Future<void> updateLocationRule(String id, LocationChoice choice) async {
    if (!connected || !_validChoice(choice)) return;
    final existing = smartLocations.rules.where((r) => r.id == id).firstOrNull;
    final prior = existing == null ? null : _overrides[existing.targetId];
    if (existing != null && prior != null) {
      _overrides[existing.targetId] = EventOverride(
          environment: prior.environment == EventEnvironment.online
              ? EventEnvironment.unknown
              : prior.environment,
          remindersEnabled: prior.remindersEnabled,
          expiresAt: prior.expiresAt);
    }
    smartLocations = smartLocations.copyWith(rules: [
      for (final rule in smartLocations.rules)
        if (rule.id != id)
          rule
        else
          ScopedLocationRule(
              id: rule.id,
              scope: rule.scope,
              targetId: rule.targetId,
              choice: choice,
              createdAt: clock(),
              enabled: rule.enabled)
    ]);
    await _locationsChanged();
  }

  String locationRuleLabel(ScopedLocationRule rule) {
    final scope = switch (rule.scope) {
      LocationRuleScope.occurrence => 'This event',
      LocationRuleScope.seriesMissing =>
        'Missing-location events in this series',
      LocationRuleScope.calendarDefault => 'Calendar default',
      LocationRuleScope.legacy => 'Saved location choice',
    };
    final choice = rule.useAutomatic
        ? 'Automatic location'
        : switch (rule.choice.kind) {
            LocationChoiceKind.online => 'Online',
            LocationChoiceKind.currentArea => 'Current area',
            LocationChoiceKind.place =>
              rule.choice.candidate?.displayName ?? 'Choose a place',
            LocationChoiceKind.savedPlace => savedPlaces
                    .where((p) => p.id == rule.choice.savedPlaceId)
                    .firstOrNull
                    ?.label ??
                'Saved place unavailable',
          };
    return '$scope · $choice';
  }

  bool _hasOccurrenceChoice(CalendarEvent event) =>
      smartLocations.rules.any((r) =>
          r.enabled &&
          !r.useAutomatic &&
          r.targetId == event.id &&
          {LocationRuleScope.occurrence, LocationRuleScope.legacy}
              .contains(r.scope)) ||
      _overrides[event.id]?.venue != null ||
      _overrides[event.id]?.environment == EventEnvironment.online;

  bool _hasSeriesChoice(CalendarEvent event) => smartLocations.rules.any((r) =>
      r.enabled &&
      (r.scope == LocationRuleScope.seriesMissing &&
              event.isRecurring &&
              r.targetId == event.seriesKey ||
          r.scope == LocationRuleScope.legacy &&
              !smartLocations.rules.any((reset) =>
                  reset.enabled &&
                  reset.useAutomatic &&
                  reset.scope == LocationRuleScope.occurrence &&
                  reset.targetId == event.id) &&
              event.matchesLegacyRecurringKey(r.targetId)));

  List<PlanCastEventWeather> locationChoiceAffected(
      CalendarEvent event, LocationRuleScope scope) {
    if (scope == LocationRuleScope.occurrence) {
      return currentEvents.where((e) => e.event.id == event.id).toList();
    }
    if (scope == LocationRuleScope.seriesMissing && !event.isRecurring) {
      return const [];
    }
    return currentEvents.where((item) {
      if (item.event.calendarId != event.calendarId ||
          _hasOccurrenceChoice(item.event)) {
        return false;
      }
      if (scope == LocationRuleScope.seriesMissing &&
          (!item.event.isRecurring ||
              item.event.seriesKey != event.seriesKey)) {
        return false;
      }
      final evidence = locationResolver.extractor.extract(item.event);
      final physical = {EventEnvironment.indoor, EventEnvironment.outdoor}
          .contains(_overrides[item.event.id]?.environment);
      if (item.event.hasCoordinates ||
          evidence.fromCalendarField ||
          evidence.virtualOnly && !physical ||
          item.resolvedLocation?.source == LocationSource.savedPlace) {
        return false;
      }
      if (scope == LocationRuleScope.calendarDefault &&
          (evidence.hasDestinationEvidence || _hasSeriesChoice(item.event))) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> savePlace(SavedPlanCastPlace place) async {
    if (!connected ||
        !place.candidate.hasValidCoordinates ||
        place.label.trim().isEmpty) {
      return;
    }
    smartLocations = smartLocations.copyWith(
        savedPlaces: [...savedPlaces.where((p) => p.id != place.id), place]);
    await _locationsChanged();
  }

  Future<void> removeSavedPlace(String id) async {
    if (!connected) return;
    smartLocations = smartLocations.copyWith(
        savedPlaces: savedPlaces.where((p) => p.id != id).toList());
    await _locationsChanged();
  }

  List<PlanCastEventWeather> batchAffected(
      {required DateTime start,
      required DateTime end,
      required Set<String> calendarIds}) {
    if (!end.isAfter(start)) return const [];
    return currentEvents.where((item) {
      if (item.isOnline ||
          !selectedCalendarIds.contains(item.event.calendarId) ||
          !calendarIds.contains(item.event.calendarId) ||
          _hasOccurrenceChoice(item.event) ||
          _hasSeriesChoice(item.event) ||
          smartLocations.rules.any((r) =>
              r.enabled &&
              r.scope == LocationRuleScope.calendarDefault &&
              r.targetId == item.event.calendarId) ||
          !locationIntervalFits(
              start: item.event.startUtc,
              end: item.event.endUtc,
              windowStart: start,
              windowEnd: end,
              allDayStart: item.event.allDayStart,
              allDayEnd: item.event.allDayEnd)) {
        return false;
      }
      final evidence = locationResolver.extractor.extract(item.event);
      if (item.event.hasCoordinates || evidence.hasDestinationEvidence) {
        return false;
      }
      return {
        LocationSource.currentArea,
        LocationSource.lastKnownArea,
        LocationSource.defaultArea,
        LocationSource.unavailable
      }.contains(item.resolvedLocation?.source);
    }).toList();
  }

  Future<void> applyTripArea(LocationCandidate area,
      {required DateTime start,
      required DateTime end,
      required Set<String> calendarIds}) async {
    if (!connected ||
        !area.hasValidCoordinates ||
        !end.isAfter(start) ||
        !end.isAfter(clock())) {
      return;
    }
    final ids = calendarIds.intersection(selectedCalendarIds);
    final affected = batchAffected(start: start, end: end, calendarIds: ids);
    if (affected.isEmpty) return;
    final trip = ConfirmedTripContext(
        id: planCastId(
            'trip|${clock().microsecondsSinceEpoch}|${area.lat}|${area.lon}'),
        label: area.name,
        candidate: area,
        startUtc: start.toUtc(),
        endUtc: end.toUtc(),
        calendarIds: ids,
        eventIds: affected.map((e) => e.event.id).toSet(),
        createdAt: clock());
    final mutation = applyConfirmedTrip(smartLocations, trip);
    smartLocations = mutation.state;
    _locationUndo = mutation.undo;
    _dismissNoticeInMemory();
    await _locationsChanged();
  }

  Future<void> removeTripArea(String id) async {
    if (!connected) return;
    smartLocations = smartLocations.copyWith(
        trips: smartLocations.trips.where((t) => t.id != id).toList());
    if (_locationUndo?.addedTripId == id) _locationUndo = null;
    await _locationsChanged();
  }

  Future<void> undoLocationChange() async {
    if (!connected || _locationUndo == null) return;
    smartLocations = _locationUndo!.apply(smartLocations).prune(clock());
    _locationUndo = null;
    await _locationsChanged();
  }

  void _dismissNoticeInMemory() {
    if (travelNotice != null) {
      final dismissed = {
        ...smartLocations.dismissedTravelNotices,
        travelNotice!.id
      };
      smartLocations = smartLocations.copyWith(
          dismissedTravelNotices: dismissed.toList().reversed.take(32).toSet());
    }
    travelNotice = null;
    _pendingMovement = null;
  }

  Future<void> dismissTravelNotice() async {
    if (!connected) return;
    _dismissNoticeInMemory();
    await _save();
    _notify();
  }

  LocationCandidate? tripSuggestion(PlanCastEventWeather item) =>
      TripSuggestion.fromEvent(item)?.area;

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_areaSubscription?.cancel());
    deviceAreaService.dispose();
    locationLookup.clear();
    unawaited(calendarRepository.stopObserving());
    unawaited(platform.stopSpeaking());
    venueWeather.clear();
    _eventWeather.clear();
    _eventWeatherVenueKeys.clear();
    _overrides.clear();
    _completedEvents = const [];
    _invalidateBriefings();
    super.dispose();
  }
}
