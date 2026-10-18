import 'package:shared_preferences/shared_preferences.dart';

/// Targeted upgrade cleanup. Shared preferences, calendar selections, saved
/// projects, purchases and earned progression are never reset or rewritten.
abstract final class WingmanUpgradeMigration {
  static const versionKey = 'wingman.upgradeVersion';
  static const currentVersion = 1;

  // These exact keys belonged exclusively to the removed experience. Do not
  // delete by prefix: weather/calendar/user records can share storage.
  static const retiredPreferenceKeys = <String>[
    'settings.selectedPersonaId',
    'selectedPersonaId',
    'local_roast_history_v2',
    'local_roast_activity_v1',
    'local_roast_intensity_v1',
    'local_roast_preferences_v1',
    'displayed_roast_snapshots_v1',
    'roast_updates_metadata_v2',
    'roast_pack_remote_json_v1',
  ];

  static Future<void> run(SharedPreferences preferences) async {
    final version = preferences.get(versionKey);
    if (version is int && version >= currentVersion) return;
    for (final key in retiredPreferenceKeys) {
      if (preferences.containsKey(key) && !await preferences.remove(key)) {
        throw StateError('Could not finish the app upgrade.');
      }
    }
    if (!await preferences.setInt(versionKey, currentVersion)) {
      throw StateError('Could not save the app upgrade version.');
    }
  }
}
