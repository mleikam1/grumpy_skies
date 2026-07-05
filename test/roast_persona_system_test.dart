import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_selector.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/repositories/shared_preferences_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persona registry contains the five roast personas in order', () {
    expect(
      RoastPersonas.all.map((persona) => persona.id),
      [
        'karen',
        'frat_bro',
        'two_year_old',
        'politician',
        'grandpa',
      ],
    );
    expect(
      RoastPersonas.all.map((persona) => persona.badgeText),
      [
        'ROAST QUEEN',
        'BAROMETER BRO',
        'TINY THUNDER',
        'SPIN DOCTOR',
        'CLOUD HISTORIAN',
      ],
    );
  });

  test('default persona is Karen', () {
    expect(RoastPersonas.defaultPersona.id, 'karen');
    expect(RoastPersonas.defaultPersona.displayName, 'Karen');
  });

  test('invalid saved persona falls back to Karen', () async {
    SharedPreferences.setMockInitialValues({
      'settings.selectedPersonaId': 'not-a-real-persona',
    });

    final repository = await SharedPreferencesSettingsRepository.create();
    final settings = await repository.loadSettings();

    expect(settings.selectedPersonaId, 'karen');
  });

  test('roast selector returns non-empty copy for each persona', () {
    final pack = _loadBundledPack();
    const selector = RoastSelector();

    for (final persona in RoastPersonas.all) {
      final selection = selector.select(
        pack: pack,
        context: WeatherRoastContext.fallback(),
        persona: persona.id,
        type: RoastType.today,
        seed: persona.id,
      );

      expect(
        selection.renderedText.trim(),
        isNotEmpty,
        reason: 'Expected non-empty roast copy for ${persona.id}.',
      );
    }
  });
}

RoastPack _loadBundledPack() {
  final raw = File('assets/roasts/roast_pack_v1.json').readAsStringSync();
  return RoastPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
