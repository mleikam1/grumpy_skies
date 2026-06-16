import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ASSET_MANIFEST.md matches DmAssets paths', () {
    final assetRegistry =
        File('lib/shared/assets/dm_assets.dart').readAsStringSync();
    final manifest = File('ASSET_MANIFEST.md').readAsStringSync();

    final registryPaths = _assetPathsIn(assetRegistry);
    final manifestPaths = RegExp(r'\| `(assets/[^`]+)` \|')
        .allMatches(manifest)
        .map((match) => match.group(1)!)
        .toSet();

    expect(manifestPaths, registryPaths);
  });

  test('pubspec declares every DmAssets folder', () {
    final assetRegistry =
        File('lib/shared/assets/dm_assets.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final requiredFolders = _assetPathsIn(assetRegistry)
        .map((path) => path.substring(0, path.lastIndexOf('/') + 1))
        .toSet();
    final declaredFolders = RegExp(r'^\s+- (assets/.*/)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((match) => match.group(1)!)
        .toSet();

    expect(declaredFolders.containsAll(requiredFolders), isTrue);
  });
}

Set<String> _assetPathsIn(String source) {
  return RegExp("'(assets/[^']+)'")
      .allMatches(source)
      .map((match) => match.group(1)!)
      .toSet();
}
