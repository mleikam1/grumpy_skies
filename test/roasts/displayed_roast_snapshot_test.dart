import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/features/fun/meme/meme_weather.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/services/local_roast_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'same caption repeated retains exact separate frozen handoffs across restart',
      () async {
    final registry = await DisplayedRoastRegistry.restore();
    final engine = LocalRoastEngine();
    final now = DateTime.utc(2026, 10, 10, 12);
    final first = engine.select(
        pack: LocalRoastEngine.fallbackPack,
        context: WeatherRoastContext.unavailable(now: now),
        persona: 'grandpa',
        type: RoastType.today);
    final tags = ['cloudy'];
    final original = DisplayedRoastSnapshot(
        id: first.id,
        text: first.renderedText,
        personaId: first.persona,
        mood: first.mood,
        selection: first,
        sourceKey: 'forecast',
        sourceLabel: 'Home forecast',
        isSample: false,
        weatherSnapshot: {
          'observedAt': now.toIso8601String(),
          'temperature': 22,
          'tags': tags
        });
    registry.publish(original);
    tags.add('rain');
    expect(original.weatherSnapshot!['tags'], ['cloudy']);
    expect(() => (original.weatherSnapshot!['tags'] as List).add('snow'),
        throwsUnsupportedError);
    final second = engine.select(
        pack: LocalRoastEngine.fallbackPack,
        context: WeatherRoastContext.unavailable(
            now: now.add(const Duration(minutes: 1))),
        persona: 'grandpa',
        type: RoastType.today,
        another: true);
    expect(second.id, first.id);
    expect(second.selectionId, isNot(first.selectionId));
    registry.publish(DisplayedRoastSnapshot(
        id: second.id,
        text: second.renderedText,
        personaId: second.persona,
        mood: second.mood,
        selection: second,
        sourceKey: 'forecast',
        sourceLabel: 'Home forecast',
        isSample: false,
        weatherSnapshot: {
          'observedAt': now.add(const Duration(minutes: 1)).toIso8601String(),
          'temperature': 23
        }));
    expect(registry.latestForecast!.selection, same(second));
    expect(registry.forSelection(first)!.weatherSnapshot!['temperature'], 22);
    await registry.pendingWrites;
    final restored = await DisplayedRoastRegistry.restore();
    expect(restored.forSelection(first)!.weatherSnapshot,
        original.weatherSnapshot);
    expect(restored.forSelection(first)!.mood, first.mood);
    expect(restored.forSelection(second)!.weatherSnapshot!['temperature'], 23);
    expect(restored.choices, isEmpty,
        reason: 'Historical snapshots must not become current on launch.');
  });
  test('corrupt optional snapshot storage cannot block launch', () async {
    SharedPreferences.setMockInitialValues(
        {'displayed_roast_snapshots_v1': '{bad'});
    final restored = await DisplayedRoastRegistry.restore();
    expect(restored.choices, isEmpty);
  });
}
