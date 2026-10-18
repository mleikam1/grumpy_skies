import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/xp_state.dart';

class AchievementService {
  static const _storageKey = 'progression_achievements';

  final SharedPreferences _prefs;
  final Set<String> _unlockedIds = {};

  AchievementService._(this._prefs);

  static Future<AchievementService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final service = AchievementService._(prefs);
    await service._loadUnlocked();
    return service;
  }

  Future<void> _loadUnlocked() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;

    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      _unlockedIds.addAll(list);
    } catch (_) {
      _unlockedIds.clear();
    }
  }

  Future<void> _saveUnlocked() async {
    await _prefs.setString(_storageKey, jsonEncode(_unlockedIds.toList()));
  }

  List<Achievement> _baseAchievements() {
    return const [
      Achievement(
        id: 'streak_3',
        name: '3-day streak',
        description: 'Open the app three days in a row.',
        unlocked: false,
        xpReward: 50,
      ),
      Achievement(
        id: 'streak_7',
        name: '7-day streak',
        description: 'Keep the streak alive for a full week.',
        unlocked: false,
        xpReward: 100,
      ),
      Achievement(
        id: 'streak_30',
        name: '30-day streak',
        description: 'Check the weather for a full month.',
        unlocked: false,
        xpReward: 300,
      ),
      Achievement(
        id: 'severe_weather',
        name: 'Storm chaser',
        description: 'Check the app during severe weather.',
        unlocked: false,
        xpReward: 60,
      ),
      Achievement(
        id: 'level_3',
        name: 'Getting warmed up',
        description: 'Reach level 3.',
        unlocked: false,
        xpReward: 50,
      ),
      Achievement(
        id: 'level_5',
        name: 'Forecast regular',
        description: 'Reach level 5.',
        unlocked: false,
        xpReward: 120,
      ),
      Achievement(
        id: 'level_10',
        name: 'Weather expert',
        description: 'Reach level 10.',
        unlocked: false,
        xpReward: 250,
      ),
    ];
  }

  Future<List<Achievement>> loadAchievements() async {
    return _baseAchievements()
        .map((a) => a.copyWith(unlocked: _unlockedIds.contains(a.id)))
        .toList();
  }

  Future<void> unlockAchievement(String id) async {
    if (_unlockedIds.contains(id)) return;
    _unlockedIds.add(id);
    await _saveUnlocked();
  }

  List<Achievement> evaluate(XpState state, {bool severeWeather = false}) {
    final wasUnlocked = Set<String>.from(_unlockedIds);

    void checkAndUnlock(String id, bool condition) {
      if (condition && !_unlockedIds.contains(id)) {
        _unlockedIds.add(id);
        unawaited(_saveUnlocked());
      }
    }

    checkAndUnlock('streak_3', state.streakCount >= 3);
    checkAndUnlock('streak_7', state.streakCount >= 7);
    checkAndUnlock('streak_30', state.streakCount >= 30);

    checkAndUnlock('severe_weather', severeWeather);

    checkAndUnlock('level_3', state.level >= 3);
    checkAndUnlock('level_5', state.level >= 5);
    checkAndUnlock('level_10', state.level >= 10);

    final unlockedChanged = wasUnlocked.length != _unlockedIds.length;
    if (unlockedChanged) {
      unawaited(_saveUnlocked());
    }

    return _baseAchievements()
        .map((a) => a.copyWith(unlocked: _unlockedIds.contains(a.id)))
        .toList();
  }
}
