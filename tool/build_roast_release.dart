import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_validator.dart';

/// Produces local candidates only. This command never deploys or changes the
/// application's bundled-only update policy.
Future<void> main(List<String> args) async {
  var input = 'assets/roasts/roast_pack_v1.json';
  var output = 'build/roast_release';
  Uri? origin;
  try {
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--help') {
        stdout.writeln(
            'dart run tool/build_roast_release.dart [--input file] [--output directory] [--origin https://verified-host]');
        return;
      }
      final flag = args[i];
      if (i + 1 >= args.length) {
        throw FormatException('$flag requires a value.');
      }
      final value = args[++i];
      switch (flag) {
        case '--input':
          input = value;
        case '--output':
          output = value;
        case '--origin':
          origin = Uri.parse(value);
        default:
          throw FormatException('Unknown flag $flag');
      }
    }
    if (origin != null &&
        (origin.scheme != 'https' ||
            origin.host.isEmpty ||
            origin.userInfo.isNotEmpty ||
            origin.hasQuery ||
            origin.hasFragment ||
            (origin.path.isNotEmpty && origin.path != '/'))) {
      throw const FormatException(
          'Origin must be an HTTPS origin without credentials, path, query or fragment.');
    }
    final inputBytes = await File(input).readAsBytes();
    final bundled =
        (jsonDecode(utf8.decode(inputBytes)) as Map).cast<String, dynamic>();
    final validation = const RoastPackValidator().validateJson(bundled);
    if (!validation.isValid) {
      throw FormatException(validation.errors.join('\n'));
    }
    await Directory(output).create(recursive: true);
    final packs = <Map<String, dynamic>>[];
    final sizes = <Map<String, dynamic>>[];
    final rows = (bundled['roasts'] as List).cast<Map>();
    final groups = {
      for (final row in rows) '${row['persona']}|${row['locale']}': true
    }.keys.toList()
      ..sort();
    for (final group in groups) {
      final parts = group.split('|');
      final lines = rows
          .where((r) => r['persona'] == parts[0] && r['locale'] == parts[1])
          .toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      final ids = lines.map((r) => r['rule_id']).toSet();
      final pack = {
        ...bundled,
        'personas': [parts[0]],
        'roasts': lines,
        'rules': (bundled['rules'] as List? ?? [])
            .where((r) => ids.contains(r['id']))
            .toList()
      };
      final bytes = utf8.encode('${jsonEncode(pack)}\n');
      final digest = sha256.convert(bytes).toString();
      final path = 'content/roasts/packs/$digest.json';
      await Directory('$output/packs').create(recursive: true);
      await File('$output/packs/$digest.json').writeAsBytes(bytes);
      final compressed = gzip.encode(bytes);
      await File('$output/packs/$digest.json.gz').writeAsBytes(compressed);
      packs.add({
        'persona': parts[0],
        'locale': parts[1],
        'version': bundled['pack_version'],
        'url': origin == null ? '/$path' : origin.resolve(path).toString(),
        'sha256': digest,
        'bytes': bytes.length,
        'min_app_build': 1
      });
      sizes.add({
        'persona': parts[0],
        'locale': parts[1],
        'roasts': lines.length,
        'bytes': bytes.length,
        'gzip_bytes': compressed.length,
        'sha256': digest
      });
    }
    final manifest = {
      'schema_version': 1,
      'min_app_build': 1,
      'disabled_ids': <String>[],
      'packs': packs
    };
    final manifestBytes = utf8.encode('${jsonEncode(manifest)}\n');
    final manifestName =
        origin == null ? 'manifest.candidate.json' : 'manifest.json';
    await File('$output/$manifestName').writeAsBytes(manifestBytes);
    final report = {
      'built_at': DateTime.now().toUtc().toIso8601String(),
      'candidate_only': true,
      'origin_verified': false,
      'publication_status':
          'not deployed; deployment origin must be independently verified',
      'manifest_bytes': manifestBytes.length,
      'manifest_gzip_bytes': gzip.encode(manifestBytes).length,
      'bundled_bytes': inputBytes.length,
      'bundled_gzip_bytes': gzip.encode(inputBytes).length,
      'packs': sizes,
      'total_roasts': rows.length,
      'target_roasts': 5000,
      'gap': 5000 - rows.length,
      'review_status': 'machine_reviewed; no human-approved content claimed'
    };
    await File('$output/release_report.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    stdout.writeln(
        'Wrote ${packs.length} candidate packs and $manifestName in $output; manifest ${manifestBytes.length} bytes. No deployment performed.');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
