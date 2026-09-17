import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/monetization/ad_config.dart';
import 'package:grumpy_skies/monetization/ad_modal_observer.dart';
import 'package:grumpy_skies/monetization/monetization_controller.dart';
import 'package:grumpy_skies/repositories/fake_weather_repository.dart';
import 'package:grumpy_skies/services/weather_location_controller.dart';

void main() {
  late WeatherLocationController weather;
  late MonetizationController controller;
  setUp(() {
    weather =
        WeatherLocationController(repository: const FakeWeatherRepository());
    controller =
        MonetizationController(config: const AdConfig(), weather: weather);
  });
  tearDown(() {
    controller.dispose();
    weather.dispose();
  });

  Future<GlobalKey<NavigatorState>> mount(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester
        .pumpWidget(ChangeNotifierProvider<MonetizationController>.value(
      value: controller,
      child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [AdModalObserver()],
          home: const Scaffold(body: Text('Weather remains usable'))),
    ));
    await tester.pumpAndSettle();
    return navigator;
  }

  testWidgets(
      'popup closes presentation gate synchronously and keeps it through reverse animation',
      (tester) async {
    final navigator = await mount(tester);
    final popup = DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) =>
            const AlertDialog(content: Text('Privacy or editing operation')));
    unawaited(navigator.currentState!.push(popup));
    // No frame or asynchronous persistence completion may race this gate.
    expect(controller.modalActive, isTrue);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    expect(controller.modalActive, isTrue);
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.modalActive, isTrue);
    await tester.pumpAndSettle();
    expect(controller.modalActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested popups release only their own operation after removal',
      (tester) async {
    final navigator = await mount(tester);
    DialogRoute<void> popup(String label) => DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => AlertDialog(content: Text(label)));
    unawaited(navigator.currentState!.push(popup('First')));
    await tester.pumpAndSettle();
    unawaited(navigator.currentState!.push(popup('Second')));
    expect(controller.modalActive, isTrue);
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(controller.modalActive, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(controller.modalActive, isFalse);
  });

  testWidgets(
      'disposing during asynchronous startup creates no late timer or ad work',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final early =
        MonetizationController(config: const AdConfig(), weather: weather);
    final starting = early.start();
    early.dispose();
    await starting;
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });
}
