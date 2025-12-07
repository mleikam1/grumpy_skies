import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/xp_state.dart';

class XpService extends ChangeNotifier {
  static const _storageKey = 'progression_xp_state';

  final SharedPreferences _prefs;
  XpState _state = XpState.initial();

  XpState get state => _state;

  XpService._(this._prefs);

  static Future<XpService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final service = XpService._(prefs);
    service._state = await service.loadXpState();
    await service.markAppOpened();
    return service;
  }

  Future<XpState> loadXpState() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return XpState.initial();

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return XpState.fromJson(map);
    } catch (_) {
      return XpState.initial();
    }
  }

  Future<void> saveXpState(XpState state) async {
    _state = state;
    await _prefs.setString(_storageKey, jsonEncode(state.toJson()));
    notifyListeners();
  }

  Future<void> addXp(int amount) async {
    final nextXp = _state.currentXp + amount;
    final nextLevel = calculateLevel(nextXp);
    final updated = _state.copyWith(currentXp: nextXp, level: nextLevel);
    await saveXpState(updated);
  }

  int xpForLevel(int level) {
    if (level <= 1) return 100;
    if (level == 2) return 150;
    if (level == 3) return 200;
    return 300;
  }

  int calculateLevel(int totalXp) {
    var level = 1;
    var remaining = totalXp;
    while (true) {
      final xpNeeded = xpForLevel(level);
      if (remaining < xpNeeded) break;
      remaining -= xpNeeded;
      level++;
    }
    return level;
  }

  Future<void> markAppOpened() async {
    final now = DateTime.now();
    final lastOpened = _state.lastOpened;
    final isNewDay =
        lastOpened == null || !_isSameDay(lastOpened, now);

    if (isNewDay) {
      final isConsecutive =
          lastOpened != null && _isYesterday(lastOpened, now);
      final streak = isConsecutive ? _state.streakCount + 1 : 1;

      _state = _state.copyWith(
        streakCount: streak,
        lastOpened: now,
        viewedMorning: false,
        viewedAfternoon: false,
        viewedNight: false,
      );
      await addXp(25);
    } else {
      _state = _state.copyWith(lastOpened: now);
      await saveXpState(_state);
    }
  }

  Future<void> markViewedMorning() async {
    await markAppOpened();
    if (_state.viewedMorning) return;

    final alreadyHadAll = _hasViewedAll();
    _state = _state.copyWith(viewedMorning: true);
    await saveXpState(_state);
    await addXp(10);
    await _awardAllDayBonusIfNeeded(alreadyHadAll);
  }

  Future<void> markViewedAfternoon() async {
    await markAppOpened();
    if (_state.viewedAfternoon) return;

    final alreadyHadAll = _hasViewedAll();
    _state = _state.copyWith(viewedAfternoon: true);
    await saveXpState(_state);
    await addXp(10);
    await _awardAllDayBonusIfNeeded(alreadyHadAll);
  }

  Future<void> markViewedNight() async {
    await markAppOpened();
    if (_state.viewedNight) return;

    final alreadyHadAll = _hasViewedAll();
    _state = _state.copyWith(viewedNight: true);
    await saveXpState(_state);
    await addXp(10);
    await _awardAllDayBonusIfNeeded(alreadyHadAll);
  }

  bool _hasViewedAll() {
    return _state.viewedMorning &&
        _state.viewedAfternoon &&
        _state.viewedNight;
  }

  Future<void> _awardAllDayBonusIfNeeded(bool alreadyHadAll) async {
    if (!alreadyHadAll && _hasViewedAll()) {
      await addXp(30);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isYesterday(DateTime last, DateTime now) {
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return _isSameDay(last, yesterday);
  }
}
