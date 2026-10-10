import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/preview_roasts.dart' as preview;

void main() {
  test(
      'generate editorial preview from production eligibility and actual artwork',
      () {
    preview.buildEditorialPreview('build/roast_preview');
    final payload = jsonDecode(
            File('build/roast_preview/context_matrix.json').readAsStringSync())
        as Map;
    expect(payload['missing_portraits'], isEmpty);
    expect(payload['expression_variants_available'], isTrue);
    expect((payload['matrix'] as Map).length, greaterThanOrEqualTo(450));
    final html = File('build/roast_preview/index.html').readAsStringSync();
    expect(html, contains('ruleFilter'));
    expect(html, contains('moodFilter'));
  });
}
