import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/platform/plancast_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.plancast');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'calendarPermission':
          return 'writeOnly';
        case 'events':
          return <Map<String, dynamic>>[
            {
              'id': 'recurring_123',
              'calendarId': 'selected',
              'isAllDay': true,
              'startMs': 1792022400000,
              'endMs': 1792108800000,
              'allDayStart': '2026-10-15',
              'allDayEnd': '2026-10-16',
              'timeZone': 'America/Chicago'
            },
          ];
        case 'speak':
          return false;
        default:
          return null;
      }
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('unsupported platforms never ask for permission or call native methods',
      () async {
    final bridge = PlanCastPlatform(channel: channel, supported: false);
    expect(await bridge.calendarPermission(), 'unsupported');
    expect(await bridge.requestCalendarPermission(), 'unsupported');
    expect(await bridge.calendars(), isEmpty);
    expect(await bridge.speechStatus(), 'unavailable');
    expect(await bridge.speak('Private calendar text'), isFalse);
    await bridge.disconnect();
    expect(calls, isEmpty);
  });
  test(
      'write-only permission remains distinct and does not imply calendar reads',
      () async {
    final bridge = PlanCastPlatform(channel: channel, supported: true);
    expect(await bridge.calendarPermission(), 'writeOnly');
    expect(calls.map((c) => c.method), ['calendarPermission']);
  });
  test(
      'selected bounded queries retain UTC instants and all-day exclusive dates',
      () async {
    final bridge = PlanCastPlatform(channel: channel, supported: true);
    final start = DateTime.parse('2026-10-15T00:00:00-05:00');
    final end = start.add(const Duration(days: 14));
    final rows =
        await bridge.events(calendarIds: ['selected'], start: start, end: end);
    expect((calls.single.arguments as Map)['calendarIds'], ['selected']);
    expect((calls.single.arguments as Map)['startMs'],
        start.toUtc().millisecondsSinceEpoch);
    expect(rows.single['allDayStart'], '2026-10-15');
    expect(rows.single['allDayEnd'], '2026-10-16');
    expect(rows.single['timeZone'], 'America/Chicago');
  });
  test('empty selection reads nothing and unbounded histories are rejected',
      () async {
    final bridge = PlanCastPlatform(channel: channel, supported: true);
    final start = DateTime.utc(2026, 10, 15);
    expect(
        await bridge.events(
            calendarIds: [],
            start: start,
            end: start.add(const Duration(days: 14))),
        isEmpty);
    await expectLater(
        bridge.events(
            calendarIds: ['selected'],
            start: start,
            end: start.add(const Duration(days: 365))),
        throwsArgumentError);
    expect(calls, isEmpty);
  });
  test('native queue is bounded and disconnect uses feature-wide cleanup',
      () async {
    final bridge = PlanCastPlatform(channel: channel, supported: true);
    await bridge.replaceNotifications(List.generate(100, (i) => {'id': '$i'}));
    expect(((calls.single.arguments as Map)['notices'] as List).length, 32);
    await bridge.disconnect();
    expect(calls.last.method, 'disconnect');
  });
  test('missing native plugin degrades to unsupported without a crash',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel, (_) async => throw MissingPluginException());
    final bridge = PlanCastPlatform(channel: channel, supported: true);
    expect(await bridge.calendarPermission(), 'unsupported');
    expect(await bridge.calendars(), isEmpty);
    expect(await bridge.speak('Read my day'), isFalse);
  });
}
