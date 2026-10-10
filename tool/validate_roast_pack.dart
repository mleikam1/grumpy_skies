import 'dart:convert';
import 'dart:io';
import 'package:grumpy_skies/features/roasts/content/roast_pack_validator.dart';

void main(List<String> args) {
  try {
    final path =
        args.isEmpty ? 'assets/roasts/roast_pack_v1.json' : args.single;
    final json = (jsonDecode(File(path).readAsStringSync()) as Map)
        .cast<String, dynamic>();
    final result = const RoastPackValidator().validateJson(json);
    for (final warning in result.warnings) {
      stdout.writeln('Warning: $warning');
    }
    for (final error in result.errors) {
      stderr.writeln('Error: $error');
    }
    if (!result.isValid) {
      exitCode = 1;
      return;
    }
    stdout.writeln(
        'Validated ${(json['roasts'] as List).length} roasts, ${(json['rules'] as List? ?? []).length} rules: $path');
  } catch (error) {
    stderr.writeln('Invalid pack: $error');
    exitCode = 1;
  }
}
