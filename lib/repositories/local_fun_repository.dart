import '../shared/assets/dm_assets.dart';
import '../models/weather_models.dart';
import 'fun_repository.dart';

/// Bundled content for the existing Fun tools. No generation or network work.
class LocalFunRepository implements FunRepository {
  const LocalFunRepository();

  @override
  Future<List<Achievement>> getAchievements() async => const [
        Achievement(
          id: 'five-day-streak',
          name: 'Five-Day Streak',
          description: 'Checked the forecast five days in a row.',
          xpReward: 100,
          unlocked: true,
          progress: 5,
          target: 5,
        ),
        Achievement(
          id: 'chaos-connoisseur',
          name: 'Chaos Connoisseur',
          description: 'Reached an 82% Chaos Meter day.',
          xpReward: 82,
          unlocked: true,
          progress: 82,
          target: 82,
        ),
      ];

  @override
  Future<List<FunFeature>> getFunFeatures() async => const [
        FunFeature(
          id: 'chaos-meter',
          name: 'Chaos Meter',
          prompt: 'How dramatic is today?',
          value: '82%',
          enabled: true,
        ),
        FunFeature(
          id: 'weather-fortune',
          name: 'Weather Fortune Cookie',
          prompt: 'Tiny prophecy, big attitude.',
          value: 'Today is 82% chaos. Dress accordingly.',
          enabled: true,
        ),
        FunFeature(
          id: 'daily-poll',
          name: 'Daily Weather Poll',
          prompt: 'Would you rather sweat or freeze?',
          value: 'Sweat',
          enabled: true,
        ),
      ];

  @override
  Future<List<MemeTemplate>> getMemeTemplates() async => [
        MemeTemplate(
          id: 'partly-cloudy-scene',
          name: 'Making A Scene',
          imageAsset: DmAssets.memeBackgrounds.sunny,
          topText: 'IT IS 72°F',
          bottomText: 'AND STILL MAKING A SCENE',
        ),
        MemeTemplate(
          id: 'moderate-air',
          name: 'Moderate Air',
          imageAsset: DmAssets.memeBackgrounds.office,
          topText: 'AQI 82',
          bottomText: 'THE AIR HAS NOTES',
        ),
      ];
}
