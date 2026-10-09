import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:grumpy_skies/app/daymaker_shell.dart';

import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/features/fun/meme_generator_screen.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_document_canvas.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_inspector.dart';
import 'package:grumpy_skies/features/fun/meme/widgets/meme_library.dart';
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
        expect(find.text('daymaker.'), findsOneWidget);
        expect(find.text('Weather that brightens your day.'), findsOneWidget);
      });
    }

    const mainTabs = <String, String>{
      'Today': AppRoutes.forecast,
      'Radar': AppRoutes.radar,
      'Roasts': AppRoutes.roasts,
      'Fun': AppRoutes.fun,
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

    testWidgets('four destinations keep the approved order and route mapping',
        (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.forecast);
      expect(DmBottomNav.defaultItems.map((item) => item.label),
          ['Today', 'Radar', 'Roasts', 'Fun']);
      expect(DaymakerShell.tabLocations, mainTabs.values.toList());
      for (var index = 0; index < DmBottomNav.defaultItems.length; index++) {
        final item = DmBottomNav.defaultItems[index];
        await tester.tap(find.bySemanticsLabel(item.semanticLabel));
        await tester.pumpAndSettle();
        final nav = tester.widget<DmBottomNav>(find.byType(DmBottomNav));
        expect(nav.currentIndex, index);
        final router = GoRouter.of(tester.element(find.byType(DmBottomNav)));
        expect(router.routeInformationProvider.value.uri.path,
            DaymakerShell.tabLocations[index]);
        expectNoFlutterExceptions(tester);
      }
    });

    testWidgets('header gear opens Settings and back restores Today navigation',
        (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.forecast);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreenBody), findsOneWidget);
      expect(find.byType(DmBottomNav), findsNothing);
      final router =
          GoRouter.of(tester.element(find.byType(SettingsScreenBody)));
      expect(
          GoRouterState.of(tester.element(find.byType(SettingsScreenBody)))
              .uri
              .path,
          AppRoutes.settings);
      router.pop();
      await tester.pumpAndSettle();
      expect(
          tester.widget<DmBottomNav>(find.byType(DmBottomNav)).currentIndex, 0);
      expect(
          router.routeInformationProvider.value.uri.path, AppRoutes.forecast);
      expectNoFlutterExceptions(tester);
    });

    for (final route in [AppRoutes.settings, AppRoutes.about]) {
      testWidgets('$route is a secondary screen without bottom navigation',
          (tester) async {
        await tester.pumpDayMakerRoute(initialLocation: route);
        expect(find.byType(DmBottomNav), findsNothing);
        expect(DaymakerShell.indexForLocation(route), -1);
        expectNoFlutterExceptions(tester);
      });
    }

    testWidgets('forecast screen displays sample temperature and location',
        (tester) async {
      await tester.pumpDayMakerRoute(initialLocation: AppRoutes.forecast);

      expectNoFlutterExceptions(tester);
      expect(find.text('72°'), findsOneWidget);
      expect(find.text('Demo City, US'), findsOneWidget);
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

      await tester.tap(find.bySemanticsLabel('Today tab'));
      await tester.pumpAndSettle();

      expectNoFlutterExceptions(tester);
      expect(find.text("Frat Bro's take"), findsOneWidget);
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

    testWidgets('meme route opens the library and edits a blank caption',
        (tester) async {
      await tester.pumpDayMakerRoute(
        initialLocation: AppRoutes.memeGenerator,
      );
      expect(
          tester
              .widget<MemeLibrary>(find.byType(MemeLibrary))
              .catalog
              .templates,
          hasLength(19));
      await _scrollMemeGeneratorUntilVisible(tester, find.text('Blank Canvas'));
      await tester.tap(find.text('Blank Canvas'));
      await tester.pumpAndSettle();
      final editor = tester
          .widget<MemeDocumentCanvas>(find.byType(MemeDocumentCanvas))
          .editor;
      final field = find.descendant(
        of: find.byWidgetPredicate((widget) =>
            widget is CaptionInput && widget.label == 'Top caption'),
        matching: find.byType(TextField),
      );
      await _scrollMemeGeneratorUntilVisible(tester, field);
      await tester.enterText(field, 'storm mode');
      await tester.pump();
      expect(editor.document.layers.first.text, 'storm mode');
      expectNoFlutterExceptions(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

Future<void> _scrollMemeGeneratorUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  for (var attempts = 0; attempts < 30; attempts++) {
    if (finder.evaluate().isNotEmpty) {
      await Scrollable.ensureVisible(tester.element(finder.first),
          alignment: .5);
      await tester.pumpAndSettle();
      if (finder.hitTestable().evaluate().isNotEmpty) {
        return;
      }
    }
    await tester.drag(
      find
          .descendant(
            of: find.byType(MemeGeneratorScreen),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}
