import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';

void main() {
  test(
      'ASSET_MANIFEST.md matches registry, approved artwork and retained assets',
      () {
    final manifest = File('ASSET_MANIFEST.md').readAsStringSync();

    final registryPaths = _runtimeAssetPaths();
    final manifestPaths = RegExp(r'\| `(assets/[^`]+)` \|')
        .allMatches(manifest)
        .map((match) => match.group(1)!)
        .toSet();

    expect(manifestPaths, registryPaths);
  });

  test('pubspec declares every app and meme catalog asset folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final requiredFolders = _runtimeAssetPaths()
        .map((path) => path.substring(0, path.lastIndexOf('/') + 1))
        .toSet();
    final declaredFolders = RegExp(r'^\s+- (assets/.*/)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((match) => match.group(1)!)
        .toSet();

    expect(declaredFolders.containsAll(requiredFolders), isTrue);
  });
}

Set<String> _runtimeAssetPaths() {
  final appRegistry =
      File('lib/shared/assets/dm_assets.dart').readAsStringSync();
  // The studio replaced the old unshipped preset paths with catalog assets.
  // Keep checking every unrelated app registry path exactly as before.
  final paths = _assetPathsIn(appRegistry)
      .where((path) =>
          !path.startsWith('assets/meme_backgrounds/') &&
          !path.startsWith('assets/meme_stickers/'))
      .toSet();
  // Approved screen illustrations include static references outside DmAssets.
  // Include every such production reference so the manifest cannot omit a hero.
  for (final file
      in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('/preview/')) {
      continue;
    }
    paths.addAll(_assetPathsIn(file.readAsStringSync()).where((path) =>
        path.startsWith('assets/approved_v1/') && !path.contains(r'$')));
  }
  // Resolve interpolated persona paths through the actual runtime function.
  paths.addAll(RoastPersonas.supportedIds.map(DmPersonaPortrait.pathFor));
  // These original portraits remain shipped for stored-document compatibility.
  const retainedLegacyPortraits = {
    'assets/personas/karen_roast_queen.png',
    'assets/personas/frat_bro_barometer_bro.png',
    'assets/personas/two_year_old_tiny_thunder.png',
    'assets/personas/politician_spin_doctor.png',
    'assets/personas/grandpa_cloud_historian.png',
  };
  for (final path in retainedLegacyPortraits) {
    expect(File(path).existsSync(), isTrue,
        reason: 'Retained legacy asset: $path');
  }
  paths.addAll(retainedLegacyPortraits);
  const contentPaths = [
    'assets/meme_content/weather_meme_catalog.v1.json',
    'assets/meme_content/weather_stickers.v1.json',
    'assets/meme_content/weather_meme_catalog.v1.schema.json',
    'assets/fonts/Nunito.ttf',
    'assets/fonts/SpaceMono-Bold.ttf',
  ];
  paths.addAll(contentPaths);
  for (final path in contentPaths.take(2)) {
    final catalog = jsonDecode(File(path).readAsStringSync()) as Map;
    final entries = (catalog['templates'] ?? catalog['stickers']) as List;
    for (final entry in entries.cast<Map>()) {
      paths.add(entry['assetPath'] as String);
      if (entry['thumbnailPath'] case final String thumbnail) {
        paths.add(thumbnail);
      }
    }
  }
  return paths;
}

Set<String> _assetPathsIn(String source) {
  return RegExp("'(assets/[^']+)'")
      .allMatches(source)
      .map((match) => match.group(1)!)
      .toSet();
}
