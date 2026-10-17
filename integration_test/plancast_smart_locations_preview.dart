// Explicit simulator fixture, never imported by production main.dart.
// flutter run -t integration_test/plancast_smart_locations_preview.dart
//   --dart-define=PREVIEW_SCENE=plans --dart-define=PREVIEW_DARK=true
// Scenes: plans, today, hotel, flight, missing, settings, denied, travel.
// Public fixture adapters are also used by UI interaction/request-count tests.
// Real widgets, controller, resolver and evaluator; SYNTHETIC calendar/weather/
// device-area data. No native calendar reads, location permissions or network IO.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/plancast/device_area_service.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_settings_screen.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:grumpy_skies/repositories/weather_repository.dart';
import 'package:grumpy_skies/services/location_service.dart';

const _home = LocationCandidate(
    name: 'Overland Park',
    state: 'KS',
    country: 'US',
    lat: 38.9822,
    lon: -94.6708,
    source: 'synthetic-device-area');
const _miami = LocationCandidate(
    name: 'Miami Beach',
    state: 'FL',
    country: 'US',
    lat: 25.7907,
    lon: -80.1300,
    source: 'synthetic-city-result');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const configuredScene =
      String.fromEnvironment('PREVIEW_SCENE', defaultValue: 'plans');
  const configuredDark = bool.fromEnvironment('PREVIEW_DARK');
  final scene = Uri.base.queryParameters['scene'] ?? configuredScene;
  final dark = Uri.base.queryParameters['dark'] == 'true' || configuredDark;
  final textScale = double.tryParse(Uri.base.queryParameters['textScale'] ??
          const String.fromEnvironment('PREVIEW_TEXT_SCALE',
              defaultValue: '1')) ??
      1;
  var now = ApprovedFixture.now;
  final area = PlanCastPreviewArea(now, denied: scene == 'denied');
  final platform = PlanCastPreviewPlatform();
  final controller = PlanCastController(
    weatherRepository: PlanCastPreviewWeather(() => now),
    platform: platform,
    deviceAreaService: area,
    roastPackRepository: ApprovedRoastPackRepository(),
    clock: () => now,
  );
  await controller.initialize();
  if (scene == 'travel') {
    // Corroborated foreground samples exercise the actual grouped-travel logic.
    for (var i = 0; i < 2; i++) {
      now = now.add(const Duration(minutes: 6));
      area.move(_miami, now);
      await controller.refresh();
    }
  }
  final session = ApprovedPreviewSession(
      appearance: dark ? AppAppearance.dark : AppAppearance.light);
  await session.initialize();
  final event = controller.currentEvents
      .where((e) => e.event.nativeId == scene)
      .firstOrNull;
  final initial = scene == 'today'
      ? AppRoutes.forecast
      : scene == 'settings'
          ? '/plancast/settings'
          : event == null
              ? AppRoutes.planCast
              : '${AppRoutes.planCast}?event=${Uri.encodeQueryComponent(event.event.id)}';
  final router = GoRouter(initialLocation: AppRoutes.forecast, routes: [
    ...session.router.configuration.routes,
    GoRoute(
        path: AppRoutes.planCast,
        builder: (_, state) =>
            PlanCastScreen(eventId: state.uri.queryParameters['event'])),
    GoRoute(
        path: '/plancast/settings',
        builder: (_, __) => const PlanCastSettingsScreen()),
  ]);
  runApp(ChangeNotifierProvider<PlanCastController>.value(
      value: controller,
      child: session.build(routerOverride: router, textScale: textScale)));
  if (initial != AppRoutes.forecast) {
    WidgetsBinding.instance.addPostFrameCallback((_) => router.push(initial));
  }
}

class PlanCastPreviewArea extends DeviceAreaService {
  PlanCastPreviewArea(DateTime now, {this.denied = false}) {
    if (!denied) move(_home, now);
  }
  final bool denied;
  DeviceAreaSample? _sample;
  void move(LocationCandidate area, DateTime now) => _sample = DeviceAreaSample(
      candidate: area,
      observedAt: now,
      accuracyMeters: 1500,
      approximate: true,
      locality: area.name,
      provenance: 'synthetic-foreground-observation');
  @override
  DeviceAreaSample? get sample => _sample;
  @override
  DeviceLocationFailure? get failure => denied
      ? const DeviceLocationFailure(
          type: DeviceLocationFailureType.permissionDenied,
          message:
              'Location permission is off in this fixture. Choose one default city.')
      : null;
  @override
  Stream<DeviceAreaSample?> get changes => const Stream.empty();
  @override
  Future<DeviceAreaSample?> refresh(
          {bool requestPermission = false, bool force = false}) async =>
      _sample;
  @override
  Future<void> setActive(bool active) async {}
  @override
  Future<void> clear() async {
    _sample = null;
  }

  @override
  void dispose() {}
}

class PlanCastPreviewPlatform extends PlanCastPlatform {
  PlanCastPreviewPlatform() : super(supported: true);
  String _state = jsonEncode({
    'connected': true,
    'calendarIds': ['personal', 'work', 'family', 'travel'],
    'preferences': const PlanCastPreferences().toJson(),
    'smartLocations': SmartLocationState(
        onlineMatchingEnabled: true,
        explanationShown: true,
        savedPlaces: [
          SavedPlanCastPlace(
              id: 'fixture-home',
              label: 'Home',
              candidate: _home,
              aliases: const ['home'],
              createdAt: ApprovedFixture.now)
        ]).toJson(),
  });
  @override
  Future<String> calendarPermission() async => 'authorized';
  @override
  Future<String> requestCalendarPermission() async => 'authorized';
  @override
  Future<String> notificationPermission() async => 'denied';
  @override
  Future<String> requestNotificationPermission() async => 'denied';
  @override
  Stream<String> get changes => const Stream.empty();
  @override
  Future<void> startObserving() async {}
  @override
  Future<void> stopObserving() async {}
  @override
  Future<String?> secureRead() async => _state;
  @override
  Future<void> secureWrite(String value) async {
    _state = value;
  }

  @override
  Future<void> secureDelete() async {
    _state = '{}';
  }

  @override
  Future<void> disconnect() async {
    _state = '{}';
  }

  @override
  Future<void> replaceNotifications(List<Map<String, dynamic>> notices) async {}
  @override
  Future<String> speechStatus() async => 'unavailable';
  @override
  Future<bool> speak(String text) async => false;
  @override
  Future<void> stopSpeaking() async {}
  @override
  Future<List<Map<String, dynamic>>> calendars() async => [
        {'id': 'personal', 'name': 'Personal', 'colorArgb': 0xFF258D87},
        {'id': 'work', 'name': 'Work', 'colorArgb': 0xFF5278B8},
        {'id': 'family', 'name': 'Family', 'colorArgb': 0xFF9469B4},
        {'id': 'travel', 'name': 'Travel plans', 'colorArgb': 0xFFD48F44},
      ];
  @override
  Future<List<Map<String, dynamic>>> events(
      {required List<String> calendarIds,
      required DateTime start,
      required DateTime end}) async {
    Map<String, dynamic> plan(
            String id, String title, DateTime start, DateTime end,
            {String location = '',
            String zone = 'America/Chicago',
            String calendar = 'personal'}) =>
        {
          'id': id,
          'calendarId': calendar,
          'title': title,
          'startMs': start.millisecondsSinceEpoch,
          'endMs': end.millisecondsSinceEpoch,
          'timeZone': zone,
          'location': location,
          'status': 'confirmed',
        };
    return [
      plan('tree', 'Tree trimming', DateTime.utc(2026, 10, 12, 16),
          DateTime.utc(2026, 10, 12, 18)),
      plan('online', 'Team check-in', DateTime.utc(2026, 10, 12, 19),
          DateTime.utc(2026, 10, 12, 20),
          location: 'Online', calendar: 'work'),
      plan('missing', 'Dinner reservation', DateTime.utc(2026, 10, 12, 23),
          DateTime.utc(2026, 10, 13, 0),
          location: '321 Unresolved Street, Unknown City', calendar: 'family'),
      plan(
          'hotel',
          'Reservation at UNFRAMED, Miami Beach, Autograph Collection',
          DateTime.utc(2026, 10, 13, 19),
          DateTime.utc(2026, 10, 16, 15),
          zone: 'America/New_York',
          calendar: 'travel'),
      plan('flight', 'Flight AA7310', DateTime.utc(2026, 10, 12, 21),
          DateTime.utc(2026, 10, 12, 22),
          calendar: 'travel'),
      plan('dinner-away', 'Dinner with friends', DateTime.utc(2026, 10, 14, 23),
          DateTime.utc(2026, 10, 15, 0),
          calendar: 'family'),
      plan('walk', 'Morning walk', DateTime.utc(2026, 10, 13, 13),
          DateTime.utc(2026, 10, 13, 14)),
    ].where((event) => calendarIds.contains(event['calendarId'])).toList();
  }
}

class PlanCastPreviewWeather extends WeatherRepository {
  PlanCastPreviewWeather(this.clock);
  final DateTime Function() clock;
  int forecastLoads = 0;
  int geocodingQueries = 0;
  @override
  Future<List<LocationCandidate>> searchLocations(
      {required String query, int limit = 5}) async {
    geocodingQueries++;
    return query.toLowerCase().contains('miami beach') ? [_miami] : [];
  }

  @override
  Future<LocationCandidate?> reverseGeocode(
          {required double latitude, required double longitude}) async =>
      latitude < 30 ? _miami : _home;
  @override
  Future<WeatherSnapshot> getSnapshot(
          {required double latitude,
          required double longitude,
          bool forceRefresh = false}) async =>
      ApprovedFixture.snapshot;
  @override
  Future<List<RadarAlert>> getRadarAlerts(
          {required double latitude, required double longitude}) async =>
      [];
  @override
  Future<WeatherBundle> getWeather(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false,
      LocationCandidate? location}) async {
    forecastLoads++;
    final remote = latitude < 30;
    final place = remote ? _miami : _home;
    final condition = remote ? 'Rain' : 'Partly cloudy';
    final icon = remote ? '10d' : '02d';
    final temperature = remote ? 27.0 : 21.0;
    final now = clock();
    final current = CurrentWeather.fromJson({
      ...ApprovedFixture.weather.current.toJson(),
      'locationName': place.displayName,
      'latitude': latitude,
      'longitude': longitude,
      'timezone': remote ? 'America/New_York' : 'America/Chicago',
      'timezoneOffset': remote ? -14400 : -18000,
      'temperatureC': temperature,
      'condition': condition,
      'weatherIcon': icon,
      'lastUpdated': now.toIso8601String(),
      'sourceUpdatedAt': now.toIso8601String(),
      'fetchedAt': now.toIso8601String(),
    });
    final hours = [
      for (var i = 0; i < 48; i++)
        HourlyForecast(
            time: DateTime.utc(2026, 10, 12, 15 + i),
            temperatureC: temperature + i % 3,
            condition: condition,
            weatherIcon: icon,
            precipitationChance: remote ? 65 : 10)
    ];
    return WeatherBundle(
        current: current,
        location: place,
        hourly: hours,
        timeline: [
          for (final h in hours)
            TimelineWeatherPoint(
                time: h.time,
                temperatureF: h.temperatureF,
                feelsLikeF: h.temperatureF,
                windMph: 9,
                condition: h.condition,
                icon: h.weatherIcon,
                precipitationChance: h.precipitationChance)
        ],
        daily: [
          for (var i = 0; i < 7; i++)
            DailyForecast(
                date: DateTime.utc(2026, 10, 12 + i, 12),
                minTempC: temperature - 3,
                maxTempC: temperature + 3,
                condition: i == 3 ? 'Clear' : condition,
                weatherIcon: i == 3 ? '01d' : icon,
                precipitationChance: i == 3
                    ? 5
                    : remote
                        ? 65
                        : 10)
        ],
        alertCoverageVerified: true,
        alertsCheckedAt: now);
  }
}
