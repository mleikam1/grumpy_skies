import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/roasts/content/roast_selector.dart';
import 'package:grumpy_skies/features/roasts/content/weather_roast_models.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/features/roasts/widgets/persona_avatar.dart';
import 'package:grumpy_skies/features/roasts/widgets/roast_history_list.dart';
import 'package:grumpy_skies/models/daymaker_models.dart';
import 'package:grumpy_skies/repositories/in_memory_settings_repository.dart';
import 'package:grumpy_skies/repositories/shared_preferences_settings_repository.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
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

  test('every persona has complete unique configuration and a bundled asset',
      () {
    final ids = <String>{};
    final assets = <String>{};

    for (final persona in RoastPersonas.all) {
      expect(persona.id.trim(), isNotEmpty);
      expect(persona.displayName.trim(), isNotEmpty);
      expect(persona.badgeText.trim(), isNotEmpty);
      expect(persona.assetPath.trim(), isNotEmpty);
      expect(File(persona.assetPath).existsSync(), isTrue);
      expect(ids.add(persona.id), isTrue);
      expect(assets.add(persona.assetPath), isTrue);
    }
  });

  test('all personas can be selected through the shared settings state',
      () async {
    final repository = InMemorySettingsRepository();
    final controller = SettingsController(repository: repository);
    await controller.loadSettings();

    for (final id in [
      'frat_bro',
      'politician',
      'grandpa',
      'two_year_old',
      'karen',
    ]) {
      controller.setSelectedPersonaId(id);
      expect(controller.selectedPersonaId, id);
    }
  });

  test('legacy persona names resolve to stable IDs', () {
    expect(RoastPersonas.normalizeId('Frat Bro'), 'frat_bro');
    expect(RoastPersonas.normalizeId('2-Year-Old'), 'two_year_old');
    expect(RoastPersonas.normalizeId('Toddler'), 'two_year_old');
    expect(RoastPersonas.normalizeId('Old Grandpa'), 'grandpa');
  });

  test('invalid saved persona falls back to Karen', () async {
    SharedPreferences.setMockInitialValues({
      'settings.selectedPersonaId': 'not-a-real-persona',
    });

    final repository = await SharedPreferencesSettingsRepository.create();
    final settings = await repository.loadSettings();

    expect(settings.selectedPersonaId, 'karen');
  });

  test('saved persona is restored', () async {
    SharedPreferences.setMockInitialValues({
      'settings.selectedPersonaId': 'politician',
    });

    final repository = await SharedPreferencesSettingsRepository.create();
    final settings = await repository.loadSettings();

    expect(settings.selectedPersonaId, 'politician');
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

  testWidgets('missing persona artwork renders a safe fallback',
      (tester) async {
    const persona = Persona(
      id: 'karen',
      name: 'Karen',
      title: 'Roast Queen',
      avatarAsset: 'assets/personas/does_not_exist.png',
      requiredXp: 0,
      unlocked: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersonaAvatar(persona: persona, size: 80),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('all valid persona portraits decode without generic fallbacks',
      (tester) async {
    final personas = RoastPersonas.toDayMakerPersonas();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final persona in personas)
                PersonaAvatar(persona: persona, size: 80),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person_rounded), findsNothing);
    for (final persona in personas) {
      expect(
        find.bySemanticsLabel('${persona.name} persona portrait'),
        findsOneWidget,
      );
    }
  });

  testWidgets('history keeps the persona that generated each roast',
      (tester) async {
    final personas = RoastPersonas.toDayMakerPersonas();
    final roast = Roast(
      id: 'legacy-frat-roast',
      personaId: 'Frat Bro',
      weatherSnapshotId: 'weather-1',
      text: 'Original Frat Bro history.',
      category: 'hourly',
      createdAt: DateTime(2026, 7, 11, 7),
      xpReward: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoastHistoryList(
            roasts: [roast],
            personas: personas,
            onShareRoast: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7:00 AM - Frat Bro'), findsOneWidget);
    expect(find.text('Original Frat Bro history.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Frat Bro persona portrait'),
      findsOneWidget,
    );
  });
}

RoastPack _loadBundledPack() {
  final raw = File('assets/roasts/roast_pack_v1.json').readAsStringSync();
  return RoastPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
