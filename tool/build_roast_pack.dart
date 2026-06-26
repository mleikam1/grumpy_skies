import 'dart:io';

import 'package:grumpy_skies/features/roasts/content/roast_pack_csv_builder.dart';

Future<void> main(List<String> args) async {
  final options = _BuildOptions.parse(args);
  const builder = RoastPackCsvBuilder();

  try {
    final csvSource = await File(options.inputPath).readAsString();
    final result = builder.build(
      csvSource,
      packVersion: options.packVersion,
    );
    await result.writeJsonFile(options.outputPath);

    stdout.writeln(
      'Built ${result.pack.roasts.length} roasts into ${options.outputPath}.',
    );
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
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    exitCode = 1;
  }
}

class _BuildOptions {
  const _BuildOptions({
    required this.inputPath,
    required this.outputPath,
    required this.packVersion,
  });

  final String inputPath;
  final String outputPath;
  final String packVersion;

  static _BuildOptions parse(List<String> args) {
    var inputPath = 'content/roasts/roasts_template.csv';
    var outputPath = 'assets/roasts/roast_pack_v1.json';
    var packVersion = RoastPackCsvBuilder.defaultPackVersion;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      String readValue(String flag) {
        if (index + 1 >= args.length) {
          throw FormatException('$flag requires a value.');
        }
        index++;
        return args[index];
      }

      switch (arg) {
        case '--input':
          inputPath = readValue(arg);
        case '--output':
          outputPath = readValue(arg);
        case '--pack-version':
          packVersion = readValue(arg);
        case '--help':
        case '-h':
          stdout.writeln(_usage);
          exit(0);
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }

    return _BuildOptions(
      inputPath: inputPath,
      outputPath: outputPath,
      packVersion: packVersion,
    );
  }
}

const _usage = '''
Build the bundled DayMaker roast pack.

Usage:
  dart run tool/build_roast_pack.dart

Options:
  --input <path>         CSV source path.
  --output <path>        JSON output path.
  --pack-version <ver>   Pack version string.
''';
