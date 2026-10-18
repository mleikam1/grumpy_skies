import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:grumpy_skies/features/fun/meme/meme_catalog.dart';
import 'package:grumpy_skies/features/fun/meme/models/meme_document.dart';
import 'package:grumpy_skies/features/fun/meme/storage/meme_store.dart';
import 'package:grumpy_skies/features/progression/services/achievement_service.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'package:grumpy_skies/repositories/shared_preferences_settings_repository.dart';
import 'package:grumpy_skies/services/wingman_upgrade_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upgrade removes only retired keys and preserves existing installation',
      () async {
    final preserved = <String, Object>{
      'settings.appearance': 'dark',
      'settings.temperatureUnit': 'celsius',
      'settings.notificationsEnabled': false,
      'settings.adsEnabled': false,
      'settings.xp': 1470,
      'settings.level': 8,
      'settings.streakDays': 31,
      'calendarSelections': <String>['work', 'family', 'sports', 'holidays'],
      'calendarPermission': 'authorized',
      'weather.selectedLocation.v1': '{"name":"Saved place"}',
      'plancast.reminders': '{"enabled":true}',
      'purchase.entitlements': '["premium"]',
      'progression_achievements': '["streak_7","karen_10","level_5"]',
      'progression_xp_state': '{"currentXp":1470,"level":8,"streakCount":31}',
      'unknown.user.setting': 'leave this alone',
    };
    SharedPreferences.setMockInitialValues({
      ...preserved,
      for (final key in WingmanUpgradeMigration.retiredPreferenceKeys)
        key: 'unrecognized-legacy-persona',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSettingsRepository(prefs);
    final settings = await repository.loadSettings();
    expect(settings.appearance, AppAppearance.dark);
    expect(settings.temperatureUnit.name, 'celsius');
    expect(settings.notificationsEnabled, false);
    expect(settings.xp, 1470);
    expect(settings.level, 8);
    expect(settings.streakDays, 31);
    for (final entry in preserved.entries) {
      expect(prefs.get(entry.key), entry.value, reason: entry.key);
    }
    for (final key in WingmanUpgradeMigration.retiredPreferenceKeys) {
      expect(prefs.containsKey(key), false, reason: key);
    }
    final once = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    await repository.loadSettings();
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, once);
    await repository.saveSettings(settings);
    expect(prefs.containsKey('settings.selectedPersonaId'), false);
    expect(prefs.getInt(WingmanUpgradeMigration.versionKey), 1);
  });

  test('fresh settings initialize without persona preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSettingsRepository(prefs);
    final settings = await repository.loadSettings();
    await repository.saveSettings(settings);
    expect(settings.appearance, AppAppearance.light);
    expect(prefs.getKeys().any((key) => key.toLowerCase().contains('persona')),
        false);
  });

  test('legacy saved meme opens and exports without rewriting text or art',
      () async {
    final catalog = await MemeCatalog.load();
    final original = catalog.templates.first.createDocument().copyWith(
      personaId: 'retired_unknown_persona',
      roastSnapshot: {
        'id': 'legacy_caption',
        'text': 'My exact saved caption, Mixed CASE ☔',
        'persona': 'retired_unknown_persona',
      },
    );
    final saved = original.copyWith(layers: [
      original.layers.first
          .copyWith(text: 'My exact saved caption, Mixed CASE ☔'),
      original.layers.last.copyWith(text: 'My own second line'),
    ]);
    final backend = MemoryMemeBackend();
    final record = Uint8List.fromList(utf8.encode(jsonEncode(saved.toJson())));
    await backend.write('documents', saved.id, record);
    final store = MemeStore(backend);
    final restored = (await store.listDocuments()).single;
    expect(restored.toJson(), saved.toJson());
    expect(await backend.read('documents', saved.id), record);
    final backup = await store.exportBackup(restored);
    final imported = await MemeStore(MemoryMemeBackend()).importBackup(backup);
    expect(imported.layers.map((layer) => layer.text),
        saved.layers.map((layer) => layer.text));
    expect(imported.background.assetRef, saved.background.assetRef);
    expect(imported.personaId, saved.personaId);
    expect(imported.roastSnapshot, saved.roastSnapshot);
    for (final template in catalog.templates) {
      final fresh = template.createDocument();
      expect(fresh.personaId, isNull);
      expect(fresh.roastSnapshot, isNull);
    }
  });

  test('verified obsolete pack blobs do not break the saved meme library',
      () async {
    final backend = MemoryMemeBackend();
    final blob = Uint8List.fromList(utf8.encode('{"retired":"content pack"}'));
    final key = 'roast_${sha256.convert(blob)}';
    await backend.write('documents', key, blob);
    final store = MemeStore(backend);
    final document = MemeDocument.blank(name: 'My saved document');
    await store.save(document);
    expect((await store.listDocuments()).single.id, document.id);
    expect(store.recoveryIssues, isEmpty);
    expect(await backend.read('documents', key), blob);
  });

  test('retired achievements stay stored while unrelated awards remain visible',
      () async {
    const original = '["streak_7","karen_10","level_5"]';
    SharedPreferences.setMockInitialValues(
        {'progression_achievements': original});
    final service = await AchievementService.create();
    final achievements = await service.loadAchievements();
    expect(achievements.any((item) => item.id == 'karen_10'), false);
    expect(achievements.singleWhere((item) => item.id == 'streak_7').unlocked,
        true);
    expect(achievements.singleWhere((item) => item.id == 'level_5').unlocked,
        true);
    expect(
        (await SharedPreferences.getInstance())
            .getString('progression_achievements'),
        original);
  });
}
