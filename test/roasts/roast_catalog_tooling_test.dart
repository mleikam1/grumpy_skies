import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_csv_builder.dart';
import 'package:grumpy_skies/features/roasts/content/roast_pack_validator.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';

List<Map<String, dynamic>> _rules() =>
    ((jsonDecode(File('content/roasts/rules_v1.json').readAsStringSync())
            as Map)['rules'] as List)
        .map((r) => (r as Map).cast<String, dynamic>())
        .toList();
Map<String, dynamic> _json() =>
    (jsonDecode(File('assets/roasts/roast_pack_v1.json').readAsStringSync())
            as Map)
        .cast<String, dynamic>();
String _csv(List<Map<String, String>> rows, {bool modern = false}) {
  final headers = [...roastCsvHeaders, if (modern) ...roastEditorialHeaders];
  String quote(String value) => '"${value.replaceAll('"', '""')}"';
  return [
    headers.map(quote).join(','),
    for (final row in rows) headers.map((h) => quote(row[h] ?? '')).join(',')
  ].join('\n');
}

Map<String, String> _row(
        {String id = 'test',
        String text = 'My imagination brought its own clipboard.'}) =>
    {
      'id': id,
      'persona': 'karen',
      'persona_display_name': 'Karen',
      'roast_type': 'today',
      'weather_tags': 'fallback',
      'daypart': 'any',
      'roast_level': 'mild',
      'text': text,
      'weight': '1',
      'active': 'TRUE',
      'locale': 'en-US',
      'mood': 'neutral',
      'family_id': id,
      'rule_id': 'context_free',
      'status': 'active',
      'review_status': 'machine_reviewed',
      'provenance': 'Test fixture'
    };
void main() {
  const builder = RoastPackCsvBuilder();
  const validator = RoastPackValidator();
  test('source is reproducible across input row order and build timestamps',
      () {
    final rows = [
      _row(id: 'b'),
      _row(
          id: 'a',
          text: 'The tiny committee has adjourned for imaginary snacks.')
    ];
    final a = builder.build(_csv(rows), generatedAt: DateTime.utc(2026, 1, 1));
    final b = builder.build(_csv(rows.reversed.toList()),
        generatedAt: DateTime.utc(2027, 1, 1));
    expect(a.toPrettyJson(), b.toPrettyJson());
    expect(a.buildTimestamp, isNot(b.buildTimestamp));
  });
  test(
      'repository source matches bundle and preserves private review notes only in CSV',
      () {
    final result = builder.build(
        File('content/roasts/roasts_template.csv').readAsStringSync(),
        rules: _rules());
    expect(jsonDecode(result.toPrettyJson()), _json());
    expect(result.pack.roasts.length, 615);
    expect(result.toPrettyJson(), isNot(contains('machine_reviewed')));
    for (final persona in supportedWeatherRoastPersonas) {
      expect(result.pack.roasts.where((r) => r.persona == persona).length, 123);
      for (final type in RoastType.values) {
        expect(
            result.pack.roasts.any((r) =>
                r.persona == persona &&
                r.type == type &&
                r.isFallback &&
                r.level == RoastLevel.mild),
            isTrue,
            reason: '$persona/$type');
      }
    }
    expect(result.pack.roasts.map((r) => r.effectiveMood).toSet(),
        RoastMood.values.toSet());
  });
  test('rejects duplicate ID and normalized punctuation-only duplicates', () {
    final rows = [
      _row(),
      _row(text: 'My imagination brought its own clipboard!')
    ];
    expect(
        () => builder.build(_csv(rows)),
        throwsA(isA<RoastPackCsvBuildException>().having(
            (e) => e.errors.join(' '),
            'errors',
            allOf(
                contains('Duplicate roast id'), contains('Duplicate text')))));
  });
  test('rejects near duplicates instead of padding counts', () {
    final rows = [
      _row(
          text:
              'My tiny committee has brought a magnificent imaginary clipboard today.'),
      _row(
          id: 'b',
          text:
              'My tiny committee has brought a magnificent imaginary clipboard tonight.')
    ];
    expect(
        () => builder.build(_csv(rows)),
        throwsA(isA<RoastPackCsvBuildException>().having(
            (e) => e.errors.join(' '), 'errors', contains('Near-duplicate'))));
  });
  test('rejects spreadsheet formulas and preserves escaped literals', () {
    expect(
        () => builder
            .build(_csv([_row(text: '=HYPERLINK("https://invalid","click")')])),
        throwsA(isA<RoastPackCsvBuildException>().having(
            (e) => e.errors.join(' '),
            'errors',
            contains('spreadsheet formula'))));
    final safe =
        builder.build(_csv([_row(text: "'=Literal weather commentary.")]));
    expect(safe.pack.roasts.single.text, '=Literal weather commentary.');
  });
  test('rejects unknown CSV fields and requires explicit editorial mood', () {
    expect(
        () => builder.build(
            '${_csv([_row()])}\n'.replaceFirst('"notes"', '"unexpected"')),
        throwsA(isA<RoastPackCsvBuildException>()));
    final row = _row()..['mood'] = '';
    expect(
        () => builder.build(_csv([row], modern: true)),
        throwsA(isA<RoastPackCsvBuildException>()
            .having((e) => e.errors.join(' '), 'errors', contains('mood'))));
  });
  test(
      'rejects invalid moods, placeholders, nonfinite weights and invalid dates',
      () {
    for (final entry in {
      'mood': 'not_a_mood',
      'text': 'Broken {wind speed}',
      'weight': 'NaN',
      'valid_from': '2026-02-31'
    }.entries) {
      final row = _row()..[entry.key] = entry.value;
      expect(
          () => builder.build(_csv([row], modern: true), rules: [
                {'id': 'context_free', 'required_all': []}
              ]),
          throwsA(isA<RoastPackCsvBuildException>()),
          reason: entry.key);
    }
  });
  test(
      'raw validation rejects unknown fields instead of losing them in parsing',
      () {
    final json = _json();
    (json['roasts'] as List).first['moods'] = 'happy';
    expect(validator.validateJson(json).errors.join(' '),
        contains('Unknown field moods'));
  });
  test(
      'rejects unknown rules, impossible facts, units, bounds and fractional age',
      () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => (j['roasts'] as List).first['rule_id'] = 'missing',
      (j) => (j['rules'] as List).first.addAll({
            'required_all': ['hot'],
            'forbidden': ['hot']
          }),
      (j) => (j['rules'] as List).first['numeric'] = [
            {'fact': 'precip_chance', 'unit': 'inches', 'min': 10}
          ],
      (j) => (j['rules'] as List).first['numeric'] = [
            {'fact': 'humidity', 'unit': 'percent', 'min': 90, 'max': 10}
          ],
      (j) => (j['rules'] as List).first['max_age_minutes'] = 1.5,
    ]) {
      final json = _json();
      change(json);
      expect(validator.validateJson(json).isValid, isFalse);
    }
  });
  test('fallback coverage is a hard error for each locale and intensity floor',
      () {
    final json = _json();
    json['roasts'] = (json['roasts'] as List)
        .where((r) => !(r['persona'] == 'karen' &&
            (r['tags'] as List).contains('fallback')))
        .toList();
    expect(validator.validateJson(json).errors.join(' '),
        contains('Missing mild context-free fallback for karen/en-US'));
  });
  test('rejects fractional schema versions and malformed nested structures',
      () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['schema_version'] = 1.2,
      (j) => j['rule_schema_version'] = 1.2,
      (j) => j['roasts'] = 'not-a-list',
      (j) => (j['rules'] as List).first['numeric'] = 'not-a-list',
      (j) => (j['roasts'] as List).first['condition_codes'] = [800.5],
    ]) {
      final json = _json();
      change(json);
      expect(validator.validateJson(json).isValid, isFalse);
    }
  });
  test('draft and retired source rows stay out of public runtime packs', () {
    final rows = [
      _row(),
      _row(id: 'draft', text: 'The appendix is still considering its options.')
        ..['status'] = 'draft',
      _row(
          id: 'retired',
          text: 'This historical paragraph has left the building.')
        ..['status'] = 'retired',
    ];
    final result = builder.build(_csv(rows, modern: true), rules: [
      {'id': 'context_free', 'required_all': []}
    ]);
    expect(result.pack.roasts.map((r) => r.id), ['test']);
    expect(result.toPrettyJson(), isNot(contains('historical paragraph')));
  });
  test('date validity rejects overflow and accepts real leap days', () {
    expect(validRoastDate('2026-02-31'), isFalse);
    expect(validRoastDate('2028-02-29'), isTrue);
    expect(validRoastDate('2026-10-10T25:00:00Z'), isFalse);
    expect(validRoastDate('2026-10-10T12:00:00Z'), isTrue);
  });
}
