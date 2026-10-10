import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_repository.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/controllers/local_roast_controller.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/services/network_counters.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_roast_engine_test.dart' as fixture;

class _UnavailablePack extends RoastPackRepository {
  @override
  Future<RoastPack> loadPack({
    RoastRemoteConfig remoteConfig = RoastRemoteConfig.disabled,
    int appBuildNumber = 1,
  }) async =>
      throw StateError('bundled asset unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkCounters.instance.reset();
  });

  test(
      'before initialization and after asset failure safe fallback stays usable',
      () async {
    final controller = LocalRoastController(repository: _UnavailablePack());
    addTearDown(controller.dispose);
    final first = controller.select(persona: 'karen', now: fixture.now);
    expect(first.renderedText, isNotEmpty);
    expect(first.line.isFallback, isTrue);
    await controller.initialize();
    expect(controller.loadError, isNotNull);
    final hazard = controller.select(
        persona: 'frat_bro',
        bundle: fixture.bundle(code: 781),
        now: fixture.now);
    expect(hazard.reason, 'application_safety_gate');
    expect(hazard.mood, RoastMood.worried);
    expect(NetworkCounters.instance.snapshot, isEmpty);
  });

  test(
      '100 another/persona/rebuild interactions and history cause zero requests',
      () async {
    var updateRequests = 0;
    final repository = RoastPackRepository(
        scheduler: RoastUpdateScheduler(
      metadata: MemoryRoastUpdateMetadataStore(),
      fetcher: (_, a, b) async {
        updateRequests++;
        throw StateError('unexpected');
      },
    ));
    final pack = fixture.packOf([
      for (final persona in supportedWeatherRoastPersonas)
        for (var i = 0; i < 5; i++)
          fixture.line('${persona}_$i', persona: persona),
    ]);
    final controller =
        LocalRoastController(repository: repository, initialPack: pack);
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.publishWeather(fixture.bundle(), fixture.place);
    for (var i = 0; i < 100; i++) {
      final persona = supportedWeatherRoastPersonas.elementAt(i % 5);
      final choice = controller.select(
          persona: persona,
          another: true,
          now: fixture.now.add(Duration(seconds: i)));
      expect(controller.exposures.length, i);
      expect(controller.commitDisplayed(choice), isTrue);
      expect(controller.commitDisplayed(choice), isFalse);
      final rebuilt = controller.select(
          persona: persona, now: fixture.now.add(Duration(seconds: i)));
      expect(identical(choice, rebuilt), isTrue);
      expect(controller.exposures.first.toJson(), choice.toJson());
    }
    await controller.syncUpdatesInForeground();
    await Future<void>.delayed(Duration.zero);
    expect(controller.exposures.length, 100);
    expect(updateRequests, 0);
    expect(NetworkCounters.instance.snapshot, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final metadata = prefs.getString('local_roast_history_v2')!;
    expect(utf8.encode(metadata).length, lessThan(300000));
    final restarted = LocalRoastController(initialPack: pack);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.exposures.length, 100);
    expect(restarted.exposures.first.toJson(),
        controller.exposures.first.toJson());
    restarted.publishWeather(fixture.bundle(), fixture.place);
    final last = controller.exposures.first;
    final restored = restarted.select(
        persona: last.persona,
        now: fixture.now.add(const Duration(seconds: 100)));
    expect(restored.id, last.id);
    expect(restarted.commitDisplayed(restored), isFalse);
  });

  test(
      'unit change keeps ID and updates numeric rendering without new exposure',
      () async {
    final controller = LocalRoastController(
        initialPack: fixture.packOf([
      fixture.line('temperature', text: '{temp}{temp_unit}: one opinion.'),
    ]));
    addTearDown(controller.dispose);
    await controller.initialize(persist: false);
    controller.publishWeather(fixture.bundle(), fixture.place);
    final first = controller.select(persona: 'karen', now: fixture.now);
    controller.commitDisplayed(first);
    final celsius = controller.select(
        persona: 'karen', now: fixture.now, unit: TemperatureUnit.celsius);
    expect(celsius.id, first.id);
    expect(first.renderedText, '72°F: one opinion.');
    expect(celsius.renderedText, '22°C: one opinion.');
    expect(controller.commitDisplayed(celsius), isFalse);
    expect(controller.engine.exposureCount, 1);
  });

  test(
      'legacy history migration removes coordinate keys and keeps exact captions',
      () async {
    final pack = fixture.packOf([fixture.line('legacy')]);
    final first = LocalRoastController(initialPack: pack);
    await first.initialize(persist: false);
    final selection = first.select(
        persona: 'karen', bundle: fixture.bundle(), now: fixture.now);
    final old = {
      'schema': 1,
      'sequence': 7,
      'ids': {
        'karen': {'legacy': fixture.now.toIso8601String()}
      },
      'families': {},
      'slots': {
        'karen|41.8,-87.6|current': {
          'pack_version': pack.packVersion,
          'selection': {
            ...selection.toJson(),
            'selection_id': '41.8,-87.6|legacy'
          },
        }
      },
    };
    first.dispose();
    SharedPreferences.setMockInitialValues(
        {'local_roast_history_v2': jsonEncode(old)});
    final migrated = LocalRoastController(initialPack: pack);
    addTearDown(migrated.dispose);
    await migrated.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(migrated.exposures.single.renderedText, selection.renderedText);
    final saved = (await SharedPreferences.getInstance())
        .getString('local_roast_history_v2')!;
    expect(saved, isNot(contains('41.8')));
    expect(saved, isNot(contains('-87.6')));
    expect(jsonDecode(saved)['schema'], 2);
  });

  test(
      'favorites and feedback persist bounded locally without rerolling display',
      () async {
    final pack = fixture.packOf([fixture.line('one'), fixture.line('two')]);
    final controller = LocalRoastController(initialPack: pack);
    addTearDown(controller.dispose);
    await controller.initialize();
    controller.publishWeather(fixture.bundle(), fixture.place);
    final displayed = controller.select(persona: 'karen', now: fixture.now);
    controller.setFavorite(displayed.id, true);
    controller.setFeedback(displayed.id, RoastFeedback.disliked);
    expect(controller.select(persona: 'karen', now: fixture.now).selectionId,
        displayed.selectionId);
    for (var i = 0; i < 205; i++) {
      controller.setFavorite('line_$i', true);
      controller.setFeedback('line_$i', RoastFeedback.liked);
    }
    controller.setFavorite('41.8,-87.6', true);
    controller.setFeedback('41.8,-87.6', RoastFeedback.liked);
    expect(controller.favoriteIds.length, 200);
    expect(controller.feedback.length, 200);
    expect(controller.favoriteIds, isNot(contains('line_4')));
    expect(controller.favoriteIds, contains('line_204'));
    expect(
        () => controller.favoriteIds.add('mutation'), throwsUnsupportedError);
    expect(() => controller.feedback.clear(), throwsUnsupportedError);
    await Future<void>.delayed(Duration.zero);
    final restarted = LocalRoastController(initialPack: pack);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.favoriteIds, controller.favoriteIds);
    expect(restarted.feedback, controller.feedback);
    restarted.setFavorite('line_204', false);
    restarted.setFeedback('line_204', null);
    await Future<void>.delayed(Duration.zero);
    final stored = (await SharedPreferences.getInstance())
        .getString('local_roast_preferences_v1')!;
    expect(stored, isNot(contains('line_204')));
    expect(stored, isNot(contains('41.8')));
    expect(NetworkCounters.instance.snapshot, isEmpty);
  });

  test(
      'corrupt optional local metadata and invalid settings do not block bundle',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_roast_history_v2': '{broken',
      'local_roast_activity_v1': 'assumed_job',
    });
    final controller =
        LocalRoastController(initialPack: fixture.packOf([fixture.line('a')]));
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.ready, isTrue);
    expect(controller.activity, isNull);
    expect(controller.loadError, isNull);
  });
}
