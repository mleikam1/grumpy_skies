import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/widgets/meme_canvas.dart';
import 'package:grumpy_skies/features/roasts/roasts_screen.dart';
import 'package:grumpy_skies/features/settings/settings_screen.dart';
import 'package:grumpy_skies/models/temperature_unit.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/shared/widgets/dm_bottom_nav.dart';

import 'helpers/daymaker_test_helpers.dart';

void main() {
  group('DayMaker app UI', () {
    for (final viewport in dayMakerTestViewports) {
      testWidgets('app launches at ${viewport.label}', (tester) async {
        await tester.pumpDayMakerApp(viewport: viewport);

        expectNoFlutterExceptions(tester);
        expect(find.text('DayMaker'), findsOneWidget);
        expect(find.text('Weather that brightens your day.'), findsOneWidget);
      });
    }

    const mainTabs = <String, String>{
      'Forecast': AppRoutes.forecast,
      'Roasts': AppRoutes.roasts,
      'Radar': AppRoutes.radar,
      'Fun': AppRoutes.fun,
      'Settings': AppRoutes.settings,
    };

    for (final tab in mainTabs.entries) {
      testWidgets('bottom nav appears on ${tab.key}', (tester) async {
        await tester.pumpDayMakerRoute(initialLocation: tab.value);

        expectNoFlutterExceptions(tester);
        expect(find.byType(DmBottomNav), findsOneWidget);
        expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);

        for (final item in DmBottomNav.defaultItems) {
          expect(find.bySemanticsLabel(item.semanticLabel), findsOneWidget);
        }
      });
    }

    testWidgets('forecast screen displays sample temperature and location',
        (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.forecast);

      expectNoFlutterExceptions(tester);
      expect(find.text('72°F'), findsOneWidget);
      expect(find.text('Demo City'), findsOneWidget);
    });

    testWidgets('roasts screen displays Karen', (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.roasts);

      expectNoFlutterExceptions(tester);
      expect(find.text('Karen'), findsWidgets);
    });

    testWidgets('Forecast and Roasts share the selected persona',
        (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.roasts);

      await tester.ensureVisible(find.text('Frat Bro').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frat Bro').first);
      await tester.pumpAndSettle();

      final settings =
          tester.element(find.byType(RoastsScreen)).read<SettingsController>();
      expect(settings.selectedPersonaId, 'frat_bro');

      await tester.tap(find.bySemanticsLabel('Forecast tab'));
      await tester.pumpAndSettle();

      expectNoFlutterExceptions(tester);
      expect(find.text('Frat Bro'), findsOneWidget);
      expect(find.text('BAROMETER BRO'), findsOneWidget);
    });

    testWidgets('settings unit toggle works', (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.settings);

      SettingsController settingsController() {
        return tester
            .element(find.byType(SettingsScreenBody))
            .read<SettingsController>();
      }

      expect(
        settingsController().temperatureUnit,
        TemperatureUnit.fahrenheit,
      );

      await tester.tap(find.text('°C Celsius'));
      await tester.pumpAndSettle();

      expectNoFlutterExceptions(tester);
      expect(
        settingsController().temperatureUnit,
        TemperatureUnit.celsius,
      );
    });

    testWidgets('meme text field updates preview', (tester) async {
      await tester.pumpDayMakerRoute(
        initialLocation: AppRoutes.memeGenerator,
      );

      await _scrollMemeGeneratorUntilTextVisible(tester, 'Top Text');
      await tester.enterText(find.byType(TextField).at(0), 'storm mode');
      await tester.enterText(find.byType(TextField).at(1), 'bring snacks');
      await tester.pumpAndSettle();

      expectNoFlutterExceptions(tester);
      expect(
        find.descendant(
          of: find.byType(MemeCanvas),
          matching: find.text('STORM MODE'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(MemeCanvas),
          matching: find.text('BRING SNACKS'),
        ),
        findsWidgets,
      );
    });
  });
}

Future<void> _scrollMemeGeneratorUntilTextVisible(
  WidgetTester tester,
  String text,
) async {
  final finder = find.text(text);
  for (var attempts = 0; attempts < 8; attempts++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(
      find.descendant(
        of: find.byType(MemeGeneratorScreen),
        matching: find.byType(ListView),
      ),
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
  }

  expect(finder, findsOneWidget);
}
