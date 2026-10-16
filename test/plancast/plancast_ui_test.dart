import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/device_area_service.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_settings_screen.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_card.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/location_service.dart';

class UiArea extends DeviceAreaService {
  @override
  DeviceAreaSample? get sample => null;
  @override
  DeviceLocationFailure? get failure => null;
  @override
  Stream<DeviceAreaSample?> get changes => const Stream.empty();
  @override
  Future<DeviceAreaSample?> refresh(
          {bool requestPermission = false, bool force = false}) async =>
      null;
  @override
  Future<void> setActive(bool active) async {}
  @override
  Future<void> clear() async {}
  @override
  void dispose() {}
}

class UiDevice extends PlanCastPlatform {
  UiDevice({bool supported = true}) : super(supported: supported);
  int calendarRequests = 0, notificationRequests = 0, eventReads = 0;
  String permission = 'notDetermined';
  bool voice = false;
  Completer<bool>? speech;
  int stops = 0;
  String? spoken;
  String? stored;
  @override
  Future<String> calendarPermission() async => permission;
  @override
  Future<String> requestCalendarPermission() async {
    calendarRequests++;
    return permission = 'authorized';
  }

  @override
  Future<String> notificationPermission() async => 'denied';
  @override
  Future<String> requestNotificationPermission() async {
    notificationRequests++;
    return 'denied';
  }

  @override
  Future<List<Map<String, dynamic>>> calendars() async => [
        {'id': 'a', 'name': 'Personal'},
        {'id': 'b', 'name': 'Work'}
      ];
  @override
  Future<List<Map<String, dynamic>>> events(
      {required List<String> calendarIds,
      required DateTime start,
      required DateTime end}) async {
    eventReads++;
    return [
      {
        'id': 'one',
        'calendarId': 'a',
        'title':
            'A very long private appointment title that wraps across several lines without losing accessibility or overflowing the screen',
        'startMs': DateTime.utc(2026, 6, 14, 18).millisecondsSinceEpoch,
        'endMs': DateTime.utc(2026, 6, 14, 20).millisecondsSinceEpoch,
        'timeZone': 'America/Chicago',
        'location': 'TBD',
        'status': 'confirmed'
      },
      {
        'id': 'two',
        'calendarId': 'a',
        'title': 'Second plan',
        'startMs': DateTime.utc(2026, 6, 14, 21).millisecondsSinceEpoch,
        'endMs': DateTime.utc(2026, 6, 14, 22).millisecondsSinceEpoch,
        'timeZone': 'America/Chicago',
        'location': 'Online',
        'status': 'confirmed'
      },
    ];
  }

  @override
  Stream<String> get changes => const Stream.empty();
  @override
  Future<void> startObserving() async {}
  @override
  Future<void> stopObserving() async {}
  @override
  Future<String?> secureRead() async => stored;
  @override
  Future<void> secureWrite(String value) async {
    stored = value;
  }

  @override
  Future<void> disconnect() async {
    stored = null;
  }

  @override
  Future<void> replaceNotifications(List<Map<String, dynamic>> notices) async {}
  @override
  Future<bool> speak(String text) async {
    spoken = text;
    return speech == null ? voice : await speech!.future;
  }

  @override
  Future<void> stopSpeaking() async {
    stops++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<PlanCastController> controller(UiDevice device,
      {bool connect = false}) async {
    final c = PlanCastController(
        weatherRepository: const FakeWeatherRepository(),
        deviceAreaService: UiArea(),
        platform: device,
        clock: () => DateTime.utc(2026, 6, 14, 17));
    await c.initialize();
    if (connect) {
      await c.connect();
      await c.selectCalendars({'a'});
    }
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pump(WidgetTester tester, PlanCastController c, Widget child,
      {double scale = 1, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ChangeNotifierProvider<PlanCastController>.value(
        value: c,
        child: MaterialApp(
            theme: DMTheme.light,
            home: MediaQuery(
                data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true),
                child: child))));
    await tester.pumpAndSettle();
  }

  testWidgets('invitation never requests access on launch; dismissal persists',
      (tester) async {
    final device = UiDevice();
    final c = await controller(device);
    await pump(tester, c, const Scaffold(body: PlanCastCard()));
    expect(find.text('Connect calendars'), findsOneWidget);
    expect(device.calendarRequests, 0);
    expect(device.notificationRequests, 0);
    expect(device.eventReads, 0);
    await tester.tap(find.byTooltip('Dismiss PlanCast invitation'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plancast-card')), findsNothing);
    final restored = await controller(UiDevice());
    expect(restored.invitationDismissed, isTrue);
  });

  testWidgets('web displays honest unsupported state with no permission button',
      (tester) async {
    final c = await controller(UiDevice(supported: false));
    await pump(tester, c, const PlanCastScreen());
    expect(find.textContaining('Web browsers cannot'), findsOneWidget);
    expect(find.text('Connect calendars'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'connect requires explicit calendar choice and keeps notifications separate',
      (tester) async {
    final device = UiDevice();
    final c = await controller(device);
    await pump(tester, c, const PlanCastScreen());
    await tester.ensureVisible(find.text('Connect calendars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect calendars'));
    await tester.pumpAndSettle();
    expect(device.calendarRequests, 1);
    expect(device.notificationRequests, 0);
    expect(device.eventReads, 0);
    expect(c.selectedCalendarIds, isEmpty);
    expect(find.text('Choose calendars'), findsOneWidget);
    expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((w) => w.value == false),
        isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected preview has two unique events and explicit gaps',
      (tester) async {
    final c = await controller(UiDevice(), connect: true);
    await pump(tester, c,
        const Scaffold(body: SingleChildScrollView(child: PlanCastCard())));
    expect(find.byType(PlanCastEventTile), findsNWidgets(2));
    expect(find.text('0 with weather · 1 online · 1 without weather'),
        findsOneWidget);
    expect(find.text('View my PlanCast'), findsOneWidget);
    expect(c.previews.map((e) => e.event.id).toSet().length, c.previews.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text small screen and long title remains usable',
      (tester) async {
    final c = await controller(UiDevice(), connect: true);
    await pump(tester, c, const PlanCastScreen(),
        scale: 1.8, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.textContaining('A very long private appointment'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('A very long private appointment'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline voice failure keeps text and explains no cloud fallback',
      (tester) async {
    final device = UiDevice();
    final c = await controller(device, connect: true);
    await pump(tester, c, const PlanCastScreen(), size: const Size(768, 1024));
    await tester.ensureVisible(find.text('Read my day'));
    await tester.tap(find.text('Read my day'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('An offline voice is unavailable'), findsOneWidget);
    expect(device.spoken, isNot(contains('private appointment')));
    expect(find.text('Your day'), findsOneWidget);
  });

  testWidgets('notification denial cannot disconnect calendars',
      (tester) async {
    final device = UiDevice();
    final c = await controller(device, connect: true);
    await pump(tester, c, const PlanCastSettingsScreen());
    final toggle =
        find.widgetWithText(SwitchListTile, 'PlanCast notifications');
    await tester.scrollUntilVisible(toggle, 300);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(device.notificationRequests, 1);
    expect(c.preferences.notifications, isFalse);
    expect(c.connected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnect can reconnect with existing OS permission',
      (tester) async {
    final device = UiDevice();
    final c = await controller(device, connect: true);
    await c.disconnect();
    expect(c.calendarPermission, 'authorized');
    await pump(tester, c, const PlanCastScreen(), size: const Size(768, 1024));
    await tester.ensureVisible(find.text('Connect calendars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect calendars'));
    await tester.pumpAndSettle();
    expect(device.calendarRequests, 2);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(c.selectedCalendarIds, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('day deep link shows the exact requested future date',
      (tester) async {
    final c = await controller(UiDevice(), connect: true);
    final date = DateTime(2026, 6, 18);
    await pump(tester, c, PlanCastScreen(day: date));
    final context = tester.element(find.byType(PlanCastScreen));
    expect(find.text(MaterialLocalizations.of(context).formatFullDate(date)),
        findsOneWidget);
    expect(find.byType(PlanCastEventTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending offline voice can be cancelled without a late message',
      (tester) async {
    final device = UiDevice()..speech = Completer<bool>();
    final c = await controller(device, connect: true);
    await pump(tester, c, const PlanCastScreen(), size: const Size(768, 1024));
    await tester.ensureVisible(find.text('Read my day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read my day'));
    await tester.pumpAndSettle();
    expect(find.text('Stop reading'), findsOneWidget);
    await tester.tap(find.text('Stop reading'));
    await tester.pumpAndSettle();
    expect(device.stops, greaterThan(0));
    device.speech!.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Reading stopped.'), findsOneWidget);
    expect(
        find.textContaining('An offline voice is unavailable'), findsNothing);
  });

  testWidgets('card route opens the real full PlanCast screen', (tester) async {
    final c = await controller(UiDevice());
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: PlanCastCard())),
      GoRoute(path: '/plancast', builder: (_, __) => const PlanCastScreen())
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<PlanCastController>.value(
        value: c,
        child: MaterialApp.router(theme: DMTheme.light, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect calendars'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanCastScreen), findsOneWidget);
    expect(find.text(planCastPrivacyExplanation), findsOneWidget);
  });
}
