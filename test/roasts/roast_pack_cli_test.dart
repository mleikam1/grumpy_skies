import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editorial pack builds in the plain Dart VM and matches bundled data',
      () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'daymaker_roast_pack_cli_',
    );
    addTearDown(() => outputDirectory.delete(recursive: true));
    final output = File('${outputDirectory.path}/pack.json');

    // Direct invocation verifies the tooling has no Flutter dependency without
    // asking `dart run` to mutate native-asset manifests during Flutter tests.
    final result = await Process.run(
      Platform.isWindows ? 'dart.bat' : 'dart',
      ['tool/build_roast_pack.dart', '--output', output.path],
      workingDirectory: Directory.current.path,
      runInShell: Platform.isWindows,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
      jsonDecode(await output.readAsString()),
      jsonDecode(await File('assets/roasts/roast_pack_v1.json').readAsString()),
    );
  });
}
