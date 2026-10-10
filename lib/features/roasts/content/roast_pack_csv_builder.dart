import 'dart:convert';
import 'dart:io';

import 'roast_pack_validator.dart';
import 'roast_content_models.dart';

// Legacy headers remain required for explicit, reproducible migration.
const roastCsvHeaders = <String>[
  'id',
  'persona',
  'persona_display_name',
  'roast_type',
  'weather_tags',
  'condition_codes',
  'temp_min_f',
  'temp_max_f',
  'humidity_min',
  'wind_min_mph',
  'precip_min_percent',
  'daypart',
  'roast_level',
  'text',
  'fallback_text',
  'weight',
  'active',
  'locale',
  'notes',
];

const roastEditorialHeaders = <String>[
  'mood',
  'family_id',
  'rule_id',
  'status',
  'valid_from',
  'valid_until',
  'regions',
  'review_status',
  'provenance',
];

class RoastPackCsvBuildResult {
  const RoastPackCsvBuildResult({
    required this.pack,
    required this.warnings,
    required this.buildTimestamp,
  });

  final RoastPack pack;
  final List<String> warnings;
  final DateTime buildTimestamp;

  /// Canonical output excludes wall-clock build timestamps. generated_at is
  /// the explicit release epoch; build audit timestamps belong in a sidecar.
  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(pack.toJson());
  }

  Future<void> writeJsonFile(String outputPath) async {
    await File(outputPath).writeAsString('${toPrettyJson()}\n');
  }
}

class RoastPackCsvBuildException implements Exception {
  const RoastPackCsvBuildException(this.errors, this.warnings);

  final List<String> errors;
  final List<String> warnings;

  @override
  String toString() => errors.join('\n');
}

class RoastPackCsvBuilder {
  const RoastPackCsvBuilder({
    this.validator = const RoastPackValidator(),
  });

  final RoastPackValidator validator;

  static const defaultPackVersion = '2026.10.10.2';
  static final defaultGeneratedAt = DateTime.utc(2026, 10, 10);

  RoastPackCsvBuildResult build(
    String csvSource, {
    String packVersion = defaultPackVersion,
    DateTime? generatedAt,
    List<Map<String, dynamic>> rules = const [],
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final rows = const _CsvParser().parse(csvSource);
    if (rows.isEmpty) {
      throw const RoastPackCsvBuildException(['CSV is empty.'], []);
    }

    final headers = rows.first
        .map((header) => header.replaceFirst('\uFEFF', '').trim())
        .toList();
    final allowedHeaders = {...roastCsvHeaders, ...roastEditorialHeaders};
    if (headers.toSet().length != headers.length) {
      errors.add('Duplicate CSV headers.');
    }
    for (final header in headers) {
      if (!allowedHeaders.contains(header)) {
        errors.add('Unknown CSV header: $header.');
      }
    }
    // A legacy CSV may already include moods. The expanded schema is opted in
    // by its rule/family metadata, not by that compatible existing column.
    final editorial =
        headers.contains('rule_id') || headers.contains('family_id');
    for (final requiredHeader in roastCsvHeaders) {
      if (!headers.contains(requiredHeader)) {
        errors.add('Missing required CSV header: $requiredHeader.');
      }
    }
    if (errors.isNotEmpty) {
      throw RoastPackCsvBuildException(errors, warnings);
    }

    final roasts = <RoastLine>[];
    final sourceIds = <String>{};
    for (var index = 1; index < rows.length; index++) {
      final rowNumber = index + 1;
      final rawRow = rows[index];
      if (rawRow.every((cell) => cell.trim().isEmpty)) continue;

      if (rawRow.length > headers.length) {
        errors.add('Row $rowNumber has more cells than headers.');
        continue;
      }
      final row = <String, String>{};
      for (var column = 0; column < headers.length; column++) {
        row[headers[column]] =
            column < rawRow.length ? rawRow[column].trim() : '';
      }

      final rowErrors = <String>[];
      if (!sourceIds.add(row['id'] ?? '')) {
        errors.add('Duplicate roast id in CSV: ${row['id']}.');
      }
      // Reject executable spreadsheet cells; apostrophe escaping is preserved
      // in source and removed only from literal text after validation.
      for (final cell in row.entries) {
        if (RegExp(r'^[=+@]').hasMatch(cell.value) ||
            (cell.value.startsWith('-') && num.tryParse(cell.value) == null)) {
          rowErrors.add(
              'Row $rowNumber: unsafe spreadsheet formula in ${cell.key}; prefix a literal with an apostrophe.');
        }
      }
      if (editorial) {
        for (final field in [
          'mood',
          'family_id',
          'rule_id',
          'status',
          'review_status',
          'provenance'
        ]) {
          if ((row[field] ?? '').isEmpty) {
            rowErrors.add(
                'Row $rowNumber is missing required editorial field: $field.');
          }
        }
        if (!const {'machine_reviewed', 'human_approved', 'draft'}
            .contains(row['review_status'])) {
          rowErrors.add('Row $rowNumber has invalid review_status.');
        }
      }
      final status = row['status'];
      if (status != null &&
          !const {'active', 'draft', 'retired', 'disabled'}.contains(status)) {
        rowErrors.add('Row $rowNumber has invalid status: $status.');
      }
      final activeValue = row['active'] ?? '';
      final active = _parseActive(activeValue);
      if (active == null) {
        rowErrors.add('Row $rowNumber has invalid active value: $activeValue.');
      } else if (!active || (status != null && status != 'active')) {
        if (rowErrors.isNotEmpty) errors.addAll(rowErrors);
        continue;
      }

      rowErrors.addAll(_missingRequiredFieldErrors(row, rowNumber));
      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
        continue;
      }

      try {
        roasts.add(_roastFromRow(row, rowNumber));
      } catch (error) {
        errors.add('Row $rowNumber: $error');
      }
    }

    roasts.sort((a, b) => a.id.compareTo(b.id));
    final packJson = <String, dynamic>{
      'schema_version': 1,
      'pack_version': packVersion,
      'generated_at': defaultGeneratedAt.toIso8601String(),
      'personas': supportedWeatherRoastPersonas.toList()..sort(),
      'roasts': roasts.map((line) => line.toJson()).toList(),
      'rule_schema_version': 1,
      'rules': [...rules]
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
    };
    final validation = validator.validateJson(packJson);
    final pack = RoastPack.fromJson(packJson);
    errors.addAll(validation.errors);
    warnings.addAll(validation.warnings);

    if (errors.isNotEmpty) {
      throw RoastPackCsvBuildException(
        List.unmodifiable(errors),
        List.unmodifiable(warnings),
      );
    }

    return RoastPackCsvBuildResult(
      pack: pack,
      buildTimestamp: generatedAt ?? DateTime.now().toUtc(),
      warnings: List.unmodifiable(warnings),
    );
  }

  RoastLine _roastFromRow(Map<String, String> row, int rowNumber) {
    for (final field in ['valid_from', 'valid_until']) {
      final value = row[field];
      if (value != null && value.isNotEmpty && !validRoastDate(value)) {
        throw FormatException('Invalid $field on row $rowNumber.');
      }
    }
    final rawMood = _emptyToNull(row['mood']);
    if (rawMood != null &&
        !RoastMood.values.any((mood) => mood.name == rawMood)) {
      throw FormatException('Unknown mood: $rawMood');
    }
    final tags = _parseList(row['weather_tags']!)
        .map(WeatherRoastTag.parse)
        .toList(growable: false);
    final dayparts =
        _parseList(row['daypart']!).map(Daypart.parse).toList(growable: false);

    final legacy = RoastLine(
      id: row['id']!,
      persona: normalizeRoastPersonaId(row['persona']!),
      type: RoastType.parse(row['roast_type']!),
      tags: tags,
      dayparts: dayparts,
      level: RoastLevel.parse(row['roast_level']!),
      weight: _parseRequiredDouble(row['weight']!, 'weight', rowNumber),
      text: _literal(row['text']!),
      fallbackText: _emptyToNull(row['fallback_text']) == null
          ? null
          : _literal(row['fallback_text']!),
      conditionCodes: _parseIntList(row['condition_codes']),
      tempMinF: _parseOptionalInt(row['temp_min_f'], 'temp_min_f', rowNumber),
      tempMaxF: _parseOptionalInt(row['temp_max_f'], 'temp_max_f', rowNumber),
      humidityMin:
          _parseOptionalInt(row['humidity_min'], 'humidity_min', rowNumber),
      windMinMph:
          _parseOptionalDouble(row['wind_min_mph'], 'wind_min_mph', rowNumber),
      precipMinPercent: _parseOptionalInt(
        row['precip_min_percent'],
        'precip_min_percent',
        rowNumber,
      ),
      locale: row['locale']!.isEmpty ? 'en-US' : row['locale']!,
    );
    return RoastLine.fromJson({
      ...legacy.toJson(),
      for (final field in [
        'mood',
        'family_id',
        'rule_id',
        'status',
        'valid_from',
        'valid_until'
      ])
        if ((row[field] ?? '').isNotEmpty) field: row[field],
      if ((row['regions'] ?? '').isNotEmpty)
        'regions': _parseList(row['regions']!),
    });
  }

  List<String> _missingRequiredFieldErrors(
    Map<String, String> row,
    int rowNumber,
  ) {
    const requiredFields = [
      'id',
      'persona',
      'roast_type',
      'weather_tags',
      'daypart',
      'roast_level',
      'text',
      'weight',
      'active',
      'locale',
    ];
    return requiredFields
        .where((field) =>
            field != 'weather_tags' || (row['rule_id'] ?? '').trim().isEmpty)
        .where((field) => (row[field] ?? '').trim().isEmpty)
        .map((field) => 'Row $rowNumber is missing required field: $field.')
        .toList(growable: false);
  }

  String _literal(String value) =>
      RegExp(r"^'[=+@-]").hasMatch(value) ? value.substring(1) : value;

  List<String> _parseList(String value) {
    return value
        .split(RegExp(r'[|,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<int> _parseIntList(String? value) {
    final raw = value ?? '';
    if (raw.trim().isEmpty) return const [];
    return _parseList(raw).map(int.parse).toList(growable: false);
  }

  bool? _parseActive(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
    return null;
  }

  int? _parseOptionalInt(String? value, String field, int rowNumber) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.trim()) ??
        (throw FormatException('$field must be an integer on row $rowNumber.'));
  }

  double? _parseOptionalDouble(String? value, String field, int rowNumber) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim()) ??
        (throw FormatException('$field must be a number on row $rowNumber.'));
  }

  double _parseRequiredDouble(String value, String field, int rowNumber) {
    return double.tryParse(value.trim()) ??
        (throw FormatException('$field must be a number on row $rowNumber.'));
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class _CsvParser {
  const _CsvParser();

  List<List<String>> parse(String source) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < source.length; index++) {
      final char = source[index];

      if (inQuotes) {
        if (char == '"') {
          final next = index + 1 < source.length ? source[index + 1] : null;
          if (next == '"') {
            cell.write('"');
            index++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(char);
        }
        continue;
      }

      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (char == '\n') {
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell.clear();
      } else if (char == '\r') {
        continue;
      } else {
        cell.write(char);
      }
    }

    if (inQuotes) {
      throw const FormatException('CSV has an unterminated quoted field.');
    }
    row.add(cell.toString());
    if (row.length > 1 || row.first.trim().isNotEmpty) {
      rows.add(row);
    }
    return rows;
  }
}
