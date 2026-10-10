import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_csv_builder.dart';

Future<void> main(List<String> args) async {
  try {
    final options = _BuildOptions.parse(args);
    final registry = jsonDecode(await File(options.rulesPath).readAsString())
        as Map<String, dynamic>;
    if (registry.keys
            .any((key) => !{'schema_version', 'rules'}.contains(key)) ||
        registry['schema_version'] != 1) {
      throw const FormatException(
          'Unsupported or unknown rule registry schema.');
    }
    final rules = (registry['rules'] as List)
        .map((rule) => (rule as Map).cast<String, dynamic>())
        .toList();
    final csvSource = await File(options.inputPath).readAsString();
    final result = const RoastPackCsvBuilder()
        .build(csvSource, packVersion: options.packVersion, rules: rules);
    await File(options.outputPath).parent.create(recursive: true);
    await result.writeJsonFile(options.outputPath);
    final bytes = await File(options.outputPath).readAsBytes();
    final audit = {
      'built_at': result.buildTimestamp.toIso8601String(),
      'pack_version': result.pack.packVersion,
      'sha256': sha256.convert(bytes).toString(),
      'source_sha256': sha256.convert(utf8.encode(csvSource)).toString(),
      'rules_sha256':
          sha256.convert(utf8.encode(jsonEncode(registry))).toString(),
      'bytes': bytes.length,
      'gzip_bytes': gzip.encode(bytes).length,
      'review_status': 'machine_reviewed; no human approval claimed',
      'counts': {
        for (final persona in result.pack.personas)
          persona: result.pack.roasts.where((r) => r.persona == persona).length
      }
    };
    await File('${options.outputPath}.audit.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(audit)}\n');
    stdout.writeln(
        'Built ${result.pack.roasts.length} roasts into ${options.outputPath}. SHA-256 ${audit['sha256']}; ${bytes.length} bytes / ${audit['gzip_bytes']} gzip.');
    for (final warning in result.warnings) {
      stderr.writeln('Warning: $warning');
    }
  } on RoastPackCsvBuildException catch (error) {
    for (final warning in error.warnings) {
      stderr.writeln('Warning: $warning');
    }
    for (final message in error.errors) {
      stderr.writeln('Error: $message');
    }
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Error: $error');
    exitCode = 1;
  }
}

class _BuildOptions {
  const _BuildOptions(
      {required this.inputPath,
      required this.outputPath,
      required this.packVersion,
      required this.rulesPath});
  final String inputPath, outputPath, packVersion, rulesPath;
  static _BuildOptions parse(List<String> args) {
    var input = 'content/roasts/roasts_template.csv';
    var output = 'assets/roasts/roast_pack_v1.json';
    var version = RoastPackCsvBuilder.defaultPackVersion;
    var rules = 'content/roasts/rules_v1.json';
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--help' || arg == '-h') {
        stdout.writeln(_usage);
        exit(0);
      }
      if (index + 1 >= args.length) {
        throw FormatException('$arg requires a value.');
      }
      final value = args[++index];
      switch (arg) {
        case '--input':
          input = value;
        case '--output':
          output = value;
        case '--pack-version':
          version = value;
        case '--rules':
          rules = value;
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }
    return _BuildOptions(
        inputPath: input,
        outputPath: output,
        packVersion: version,
        rulesPath: rules);
  }
}

const _usage = '''Build and validate a reproducible bundled roast pack.
  dart run tool/build_roast_pack.dart
  --input <csv> --output <json> --rules <json> --pack-version <version>
Build wall-clock time and private source hashes are written to a separate audit sidecar.
''';
