import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/features/guidance/domain/guidance.dart';
import 'package:grumpy_skies/features/guidance/forecast_guidance.dart';
import 'package:grumpy_skies/features/guidance/guidance_controller.dart';
import 'package:grumpy_skies/features/guidance/local_guidance_history.dart';
import 'package:grumpy_skies/models/guidance_preferences.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/repositories/shared_preferences_settings_repository.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'guidance_test_support.dart';

class _MalformedAssets extends CachingAssetBundle {
  int reads = 0;
  @override
  Future<ByteData> load(String key) async {
    reads++;
    return ByteData.sublistView(
        Uint8List.fromList(utf8.encode('{"bad":true}')));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = ApprovedFixture.now;
  final bundle = guidanceTestBundle();
  final location = forecastGuidanceLocation(bundle);
  final weather = GuidanceWeatherAdapter.fromBundle(bundle, location: location);
  final context = GuidanceContext(
      surface: GuidanceSurface.todaySummary, location: location);
  const prefs = GuidancePreferences();

  test(
      'pins survive 1000 renders and visible recording; only one batched local write',
      () async {
    var writes = 0;
    final controller = GuidanceController(
        catalog: testGuidanceCatalog(),
        clock: () => now,
        persistHistory: (_) async {
          writes++;
        });
    final first = controller.select(
        weather: weather, context: context, preferences: prefs)!;
    final scope = controller.scopeFor(context, null, prefs);
    for (var i = 0; i < 1000; i++) {
      final next = controller.select(
          weather: weather, context: context, preferences: prefs)!;
      expect(next.templateId, first.templateId);
      controller.recordVisible(next, scope);
    }
    expect(controller.history.entries, hasLength(1));
    expect(writes, 0);
    await controller.flush();
    expect(writes, 1);
    await controller.flush();
    expect(writes, 1);
    controller.dispose();
  });

  test(
      'nearby surfaces dedupe ordinary actions; official alert overrides pins and cooldown',
      () {
    final controller =
        GuidanceController(catalog: testGuidanceCatalog(), clock: () => now);
    final first = controller.select(
        weather: weather, context: context, preferences: prefs)!;
    controller.recordVisible(first, controller.scopeFor(context, null, prefs));
    final second = controller.select(
        weather: weather,
        context: context,
        preferences: prefs,
        scopeKey: 'another-surface');
    expect(second?.semanticDedupeKey, isNot(first.semanticDedupeKey));
    final warned = guidanceTestBundle(alert: true);
    final result = controller.select(
        weather: GuidanceWeatherAdapter.fromBundle(warned, location: location),
        context: context,
        preferences: prefs)!;
    expect(result.serious, true);
    expect(result.alert?.event, 'Flood Watch');
    controller.dismiss(result, controller.scopeFor(context, null, prefs));
    expect(
        controller
            .select(
                weather: GuidanceWeatherAdapter.fromBundle(warned,
                    location: location),
                context: context,
                preferences: prefs)!
            .serious,
        true);
    controller.dispose();
  });

  test(
      'history is bounded, expires, validates restoration and clears for account change',
      () async {
    final controller = GuidanceController(clock: () => now);
    for (var i = 0; i < 150; i++) {
      controller.history.record(
          GuidanceImpression(
              templateId: 'tip_$i',
              familyId: 'rain',
              semanticKey: 'rain',
              situation: '$i',
              scope: 'hash',
              location: 'point-hash',
              shownAt: now.subtract(Duration(minutes: 150 - i))),
          now);
    }
    expect(controller.history.entries, hasLength(100));
    final restored = LocalGuidanceHistory()
      ..restore(controller.history.encode(), now);
    expect(restored.entries, hasLength(100));
    restored.prune(now.add(const Duration(days: 14)));
    expect(restored.entries, isEmpty);
    restored.restore('{bad', now);
    expect(restored.entries, isEmpty);
    await controller.resetHistory();
    expect(controller.history.entries, isEmpty);
    controller.dispose();
  });

  test('commute routine needs selected weekday and local window', () {
    final controller =
        GuidanceController(catalog: testGuidanceCatalog(), clock: () => now);
    const commute = GuidancePreferences(
        driving: true,
        commuteStartMinute: 600,
        commuteEndMinute: 660,
        commuteDaysMask: 1);
    final selected = controller.select(
        weather: weather, context: context, preferences: commute);
    expect(selected?.activity, GuidanceActivity.drivingCommute);
    final noDays = controller.select(
        weather: weather,
        context: context,
        preferences: commute.copyWith(commuteDaysMask: 0));
    expect(noDays?.activity, isNot(GuidanceActivity.drivingCommute));
    final wrongTime = controller.select(
        weather: weather,
        context: context,
        preferences:
            commute.copyWith(commuteStartMinute: 1200, commuteEndMinute: 1260));
    expect(wrongTime?.activity, isNot(GuidanceActivity.drivingCommute));
    controller.dispose();
  });

  test(
      'malformed catalog fails locally without repeat checks or request fallback',
      () async {
    final assets = _MalformedAssets();
    final controller = GuidanceController(clock: () => now);
    await controller.initialize(assets: assets, persist: false);
    expect(controller.ready, false);
    for (var i = 0; i < 1000; i++) {
      expect(
          controller.select(
              weather: weather, context: context, preferences: prefs),
          isNull);
    }
    expect(assets.reads, 2);
    controller.dispose();
  });

  test(
      'optional preferences validate and use only existing change-driven settings storage',
      () async {
    SharedPreferences.setMockInitialValues({'settings.guidance.v1': '{bad'});
    final repository = SharedPreferencesSettingsRepository(
        await SharedPreferences.getInstance());
    final settings = SettingsController(repository: repository);
    await settings.loadSettings();
    expect(settings.guidance, const GuidancePreferences());
    const value = GuidancePreferences(
        dogWalking: true,
        driving: true,
        commuteStartMinute: 1380,
        commuteEndMinute: 60,
        outingMinutes: 45);
    settings.setGuidancePreferences(value);
    await settings.waitForPendingSave();
    expect((await repository.loadSettings()).guidance, value);
    expect(
        GuidancePreferences.fromJson({'outingMinutes': 0, 'enabled': 'yes'})
            .outingMinutes,
        30);
    expect(GuidancePreferences.fromJson(value.toJson()), value);
    expect(settings.settings.temperatureUnit,
        UserSettings.defaults.temperatureUnit);
    settings.dispose();
  });
}
