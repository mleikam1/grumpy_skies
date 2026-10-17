import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grumpy_skies/config/app_routes.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/plancast/plancast_controller.dart';
import 'package:grumpy_skies/features/plancast/screens/plancast_screen.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_card.dart';
import 'package:grumpy_skies/features/plancast/widgets/plancast_presentation.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/preview/approved_fixture.dart';
import 'package:grumpy_skies/preview/approved_preview.dart';
import 'package:grumpy_skies/services/settings_controller.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';
import '../../integration_test/plancast_smart_locations_preview.dart';

Future<void> _settle(WidgetTester tester) async {
  // Weather artwork animates indefinitely. Pump bounded frames, not
  // pumpAndSettle, so reduced-motion and animated paths both remain testable.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<(PlanCastController, PlanCastPreviewWeather, ApprovedPreviewSession)>
      fixture() async {
    final weather = PlanCastPreviewWeather(() => ApprovedFixture.now);
    final controller = PlanCastController(
      weatherRepository: weather,
      platform: PlanCastPreviewPlatform(),
      deviceAreaService: PlanCastPreviewArea(ApprovedFixture.now),
      clock: () => ApprovedFixture.now,
      roastPackRepository: ApprovedRoastPackRepository(),
    );
    final session = ApprovedPreviewSession();
    await controller.initialize();
    await session.initialize();
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    return (controller, weather, session);
  }

  Future<void> pump(WidgetTester tester, PlanCastController controller,
      ApprovedPreviewSession session, Widget child,
      {double width = 390, double scale = 1, bool dark = false}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<PlanCastController>.value(value: controller),
        ChangeNotifierProvider<SettingsController>.value(
            value: session.settings),
      ],
      child: MaterialApp(
        theme: dark ? DMTheme.dark : DMTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!,
        ),
        home: child,
      ),
    ));
    await _settle(tester);
  }

  testWidgets('Today preview is scoped, compact and uses approved portrait',
      (tester) async {
    final (controller, _, session) = await fixture();
    await pump(
        tester,
        controller,
        session,
        const Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: EdgeInsets.all(16), child: PlanCastCard()))));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tree trimming'), findsOneWidget);
    expect(find.text('Team check-in'), findsOneWidget);
    expect(find.text('Flight AA7310'), findsNothing);
    expect(find.text('Change'), findsNothing);
    expect(find.text('Got it'), findsNothing);
    expect(find.textContaining('No material weather issue'), findsNothing);
    final portrait =
        tester.widget<DmPersonaPortrait>(find.byType(DmPersonaPortrait));
    expect(portrait.personaId, 'karen');
    expect(portrait.mood, isNotNull);
    expect(DmPersonaPortrait.pathFor(portrait.personaId, mood: portrait.mood),
        contains('karen'));
    expect(tester.getSize(find.byKey(const ValueKey('plancast-card'))).height,
        lessThan(560));
    expect(controller.selectedCalendarIds,
        {'personal', 'work', 'family', 'travel'});
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets('compact preview reflows at $width dark=$dark and large text',
          (tester) async {
        final (controller, _, session) = await fixture();
        await pump(
            tester,
            controller,
            session,
            const Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: EdgeInsets.all(16), child: PlanCastCard()))),
            width: width,
            dark: dark,
            scale: 2);
        expect(find.byType(PlanCastPersonaCard), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -600));
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('all selectable personas keep approved portraits and stable copy',
      (tester) async {
    final (controller, weather, session) = await fixture();
    final requests = (weather.forecastLoads, weather.geocodingQueries);
    await pump(tester, controller, session,
        const Scaffold(body: SingleChildScrollView(child: PlanCastCard())));
    for (final persona in RoastPersonas.all) {
      session.settings.setSelectedPersonaId(persona.id);
      await _settle(tester);
      final card =
          tester.widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard));
      expect(card.readout.personaId, persona.id);
      final before = card.readout.compactText;
      await tester.pump(const Duration(seconds: 1));
      expect(
          tester
              .widget<PlanCastPersonaCard>(find.byType(PlanCastPersonaCard))
              .readout
              .compactText,
          before);
      expect(find.text("${persona.displayName}'s take"), findsOneWidget);
    }
    expect((weather.forecastLoads, weather.geocodingQueries), requests);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cached UI navigation and readout expansion add no location requests',
      (tester) async {
    final (controller, weather, session) = await fixture();
    final requests = (weather.forecastLoads, weather.geocodingQueries);
    expect(weather.forecastLoads, 2,
        reason:
            'Seven events across four calendars share two weather locations.');
    await pump(tester, controller, session, const PlanCastScreen());
    for (final tab in ['Tomorrow', 'This week', 'Today']) {
      await tester.tap(find.widgetWithText(ChoiceChip, tab));
      await _settle(tester);
    }
    await tester.tap(find.text('Full readout').first);
    await _settle(tester);
    session.settings.setSelectedPersonaId('grandpa');
    await _settle(tester);
    expect((weather.forecastLoads, weather.geocodingQueries), requests);
    expect(controller.selectedCalendarIds,
        {'personal', 'work', 'family', 'travel'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact footer opens full PlanCast without whole-card interception',
      (tester) async {
    final (controller, _, session) = await fixture();
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: PlanCastCard()))),
      GoRoute(
          path: AppRoutes.planCast, builder: (_, __) => const PlanCastScreen()),
    ]);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<PlanCastController>.value(value: controller),
      ChangeNotifierProvider<SettingsController>.value(value: session.settings),
    ], child: MaterialApp.router(theme: DMTheme.light, routerConfig: router)));
    await _settle(tester);
    await tester.ensureVisible(find.text('View my PlanCast'));
    await tester.tap(find.text('View my PlanCast'));
    await _settle(tester);
    expect(find.byType(PlanCastScreen), findsOneWidget);
    expect(find.text('4 calendars'), findsOneWidget);
    router.pop();
    await _settle(tester);
    expect(find.byType(PlanCastCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
