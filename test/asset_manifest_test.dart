import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ASSET_MANIFEST.md matches app registry and shipped meme catalog', () {
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
