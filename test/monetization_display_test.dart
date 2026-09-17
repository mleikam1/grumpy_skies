import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/monetization/ad_config.dart';
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/monetization_controller.dart';
import 'package:grumpy_skies/monetization/platform/ad_platform.dart';
import 'package:grumpy_skies/monetization/widgets/ad_section.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

class CountingWeatherRepository extends FakeWeatherRepository {
  int reads = 0;
  @override
  Future<WeatherSnapshot> getSnapshot(
      {required double latitude,
      required double longitude,
      bool forceRefresh = false}) {
    reads++;
    return super.getSnapshot(
        latitude: latitude, longitude: longitude, forceRefresh: forceRefresh);
  }
}

class FakeDisplayHandle implements DisplayAdHandle {
  int disposals = 0;
  @override
  Widget get widget => const ColoredBox(
      color: Colors.blue, child: Center(child: Text('Test creative')));
  @override
  void dispose() {
    disposals++;
  }
}

class FakeDeferredDisplayHandle extends FakeDisplayHandle
    implements DeferredDisplayAdHandle {
  @override
  final ValueNotifier<int> stateChanges = ValueNotifier(0);
  @override
  bool failed = false;
  void noFill() {
    failed = true;
    stateChanges.value++;
  }
}

class FakeDisplayController extends MonetizationController {
  FakeDisplayController(WeatherLocationController weather)
      : super(
            config: const AdConfig(enabled: true, testMode: true),
            weather: weather);
  bool allowed = true;
  String? aside;
  final requests = <Completer<DisplayAdHandle?>>[];
  final sizes = <DisplaySize>[];
  @override
  bool displayAllowed(AdPlacement placement) => allowed;
  @override
  Future<DisplayAdHandle?> loadDisplay(
      AdPlacement placement, DisplaySize size) {
    sizes.add(size);
    final request = Completer<DisplayAdHandle?>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<String?> asideForVisit(String visitId) async => aside;
  void setAllowed(bool value) {
    allowed = value;
    notifyListeners();
  }

  void rebuild() => notifyListeners();
}

void main() {
  late CountingWeatherRepository repository;
  late WeatherLocationController weather;
  late FakeDisplayController controller;
  setUp(() {
    repository = CountingWeatherRepository();
    weather = WeatherLocationController(repository: repository);
    controller = FakeDisplayController(weather);
  });
  tearDown(() {
    controller.dispose();
    weather.dispose();
  });

  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester,
      {double width = 390,
      AdPlacement placement = AdPlacement.memeLibraryMrec,
      int count = 6,
      bool sample = false,
      bool available = true,
      bool showSection = true,
      double spaceBefore = 0,
      double textScale = 1,
      double keyboard = 0}) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
        ChangeNotifierProvider<MonetizationController>.value(
            value: controller,
            child: MaterialApp(
                home: Builder(
                    builder: (context) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(textScale),
                            viewInsets: EdgeInsets.only(bottom: keyboard)),
                        child: Scaffold(
                          bottomNavigationBar: const SizedBox(
                              height: 70,
                              child: Center(child: Text('Weather navigation'))),
                          body: SingleChildScrollView(
                              child: Column(children: [
                            SizedBox(height: spaceBefore),
                            if (showSection)
                              AdSection(
                                  key: const ValueKey('slot'),
                                  placement: placement,
                                  contentCount: count,
                                  sample: sample,
                                  available: available),
                            SizedBox(
                                height: 150,
                                child: Center(
                                    child: ElevatedButton(
                                        key: const ValueKey('action'),
                                        onPressed: () {},
                                        child:
                                            const Text('Continue creating')))),
                          ])),
                        ))))));
    await frame(tester);
  }

  testWidgets('insufficient/filtered/sample content makes no SDK request',
      (tester) async {
    await mount(tester, count: 5);
    expect(controller.requests, isEmpty);
    await mount(tester, count: 6, sample: true);
    expect(controller.requests, isEmpty);
    await mount(tester, count: 6, available: false);
    expect(controller.requests, isEmpty);
    await mount(tester, count: 6);
    expect(controller.requests, hasLength(1));
  });

  testWidgets('MREC is omitted below300 and never scales the creative',
      (tester) async {
    await mount(tester, width: 299);
    expect(controller.requests, isEmpty);
    expect(find.text('Advertisements'), findsNothing);
    await mount(tester, width: 300);
    expect(controller.sizes, [const DisplaySize(300, 250)]);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    final creative = tester.getRect(find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.blue));
    expect(creative.size, const Size(300, 250));
    expect(creative.bottom,
        lessThan(tester.getRect(find.text('Weather navigation')).top));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0]) {
    testWidgets(
        'forecast slot fits width$width with large text and separate controls',
        (tester) async {
      await mount(tester,
          width: width,
          placement: AdPlacement.forecastBanner,
          count: 1,
          textScale: 2);
      final expected = width >= 728
          ? const DisplaySize(728, 90)
          : const DisplaySize(320, 50);
      expect(controller.sizes, [expected]);
      controller.requests.single.complete(FakeDisplayHandle());
      await frame(tester);
      final creative = tester.getRect(find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == Colors.blue));
      expect(creative.width, expected.width.toDouble());
      expect(creative.height, expected.height.toDouble());
      expect(creative.bottom,
          lessThan(tester.getRect(find.byKey(const ValueKey('action'))).top));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'no fill removes whole section and duplicate rebuilds never reload',
      (tester) async {
    await mount(tester);
    expect(find.text('Advertisements'), findsOneWidget);
    controller.rebuild();
    await frame(tester);
    expect(controller.requests, hasLength(1));
    controller.requests.single.complete(null);
    await frame(tester);
    expect(find.text('Advertisements'), findsNothing);
    controller.rebuild();
    await frame(tester);
    expect(controller.requests, hasLength(1));
  });

  testWidgets(
      'late load after consent/safety/background suppression is disposed',
      (tester) async {
    await mount(tester);
    controller.setAllowed(false);
    await frame(tester);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    expect(handle.disposals, 1);
    expect(find.text('Test creative'), findsNothing);
    expect(find.text('Advertisements'), findsNothing);
  });

  testWidgets('same-route library/editor transition tears down slot',
      (tester) async {
    await mount(tester);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    expect(find.text('Test creative'), findsOneWidget);
    await mount(tester, showSection: false);
    expect(handle.disposals, 1);
    expect(find.text('Test creative'), findsNothing);
  });

  testWidgets('unmount while loading disposes a late native handle',
      (tester) async {
    await mount(tester);
    await mount(tester, showSection: false);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    expect(handle.disposals, 1);
    expect(find.text('Advertisements'), findsNothing);
  });

  testWidgets(
      'keyboard conflict suppresses requests and retires existing creative',
      (tester) async {
    await mount(tester, keyboard: 200);
    expect(controller.requests, isEmpty);
    await mount(tester);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    await mount(tester, keyboard: 200);
    expect(handle.disposals, 1);
    expect(find.text('Advertisements'), findsNothing);
  });

  testWidgets('offscreen slot does not request until visible', (tester) async {
    await mount(tester, spaceBefore: 1100);
    expect(controller.requests, isEmpty);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(controller.requests, hasLength(1));
    controller.requests.single.complete(FakeDisplayHandle());
    await frame(tester);
    expect(find.text('Test creative'), findsOneWidget);
  });

  testWidgets(
      'no-fill collapse waits for pointer release to preserve control position',
      (tester) async {
    await mount(tester);
    final action = find.byKey(const ValueKey('action'));
    final topBefore = tester.getTopLeft(action).dy;
    final gesture = await tester.startGesture(tester.getCenter(action));
    controller.requests.single.complete(null);
    await frame(tester);
    expect(tester.getTopLeft(action).dy, topBefore);
    await gesture.up();
    await frame(tester);
    expect(tester.getTopLeft(action).dy, lessThan(topBefore));
    expect(find.text('Advertisements'), findsNothing);
  });

  testWidgets(
      'ad loading, rebuild, suppression and teardown never fetch or alter weather',
      (tester) async {
    final original = await repository.getSnapshot(latitude: 1, longitude: 1);
    final currentTemperature = original.temperatureF;
    await mount(tester);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    controller.rebuild();
    await frame(tester);
    controller.setAllowed(false);
    await frame(tester);
    await mount(tester, showSection: false);
    expect(repository.reads, 1);
    expect(original.temperatureF, currentTemperature);
    expect(handle.disposals, 1);
  });

  testWidgets(
      'deferred DOM slot reports no fill and removes its complete section',
      (tester) async {
    await mount(tester);
    final handle = FakeDeferredDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    expect(find.text('Test creative'), findsOneWidget);
    handle.noFill();
    await frame(tester);
    expect(handle.disposals, 1);
    expect(find.text('Advertisements'), findsNothing);
    expect(find.text('Test creative'), findsNothing);
    handle.stateChanges.dispose();
  });

  testWidgets(
      'warning suppression removes humor immediately without moving held controls',
      (tester) async {
    controller.aside = 'DayMaker editorial test line';
    await mount(tester);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    final action = find.byKey(const ValueKey('action'));
    final before = tester.getTopLeft(action).dy;
    final gesture = await tester.startGesture(tester.getCenter(action));
    controller.setAllowed(false);
    await frame(tester);
    expect(find.text('DayMaker editorial test line'), findsNothing);
    expect(find.text('Test creative'), findsNothing);
    expect(tester.getTopLeft(action).dy, before);
    await gesture.up();
    await frame(tester);
    expect(tester.getTopLeft(action).dy, lessThan(before));
  });

  testWidgets(
      'window keyboard metrics retire an existing slot without rebuilding its parent',
      (tester) async {
    await mount(tester);
    final handle = FakeDisplayHandle();
    controller.requests.single.complete(handle);
    await frame(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await frame(tester);
    expect(handle.disposals, 1);
    expect(find.text('Advertisements'), findsNothing);
  });

  testWidgets(
      'real controller startup and privacy/navigation lifecycle do not fetch weather',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final real =
        MonetizationController(config: const AdConfig(), weather: weather);
    final original = await repository.getSnapshot(latitude: 1, longitude: 1);
    final before = original.toJson();
    await real.start();
    real.setRoute('/fun');
    real.beginOperation();
    await real.recordMemeCompletion(
        documentId: 'local-only-document', revisionId: 'revision');
    real.endOperation();
    real.didChangeAppLifecycleState(AppLifecycleState.paused);
    real.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await real.completeMemeTransition(continueNavigation: () {});
    expect(
        await real.loadDisplay(
            AdPlacement.funHubMrec, const DisplaySize(300, 250)),
        isNull);
    expect(repository.reads, 1);
    expect(original.toJson(), before);
    real.dispose();
  });
}
