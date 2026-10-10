import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/forecast/widgets/forecast_header.dart';
import 'package:grumpy_skies/features/roasts/models/roast_mood.dart';
import 'package:grumpy_skies/features/roasts/models/roast_persona.dart';
import 'package:grumpy_skies/features/roasts/widgets/featured_roast_card.dart';
import 'package:grumpy_skies/models/weather_models.dart';
import 'support/ui_preservation_fixture.dart';

void main() {
  const city = 'San Fernando del Valle de Catamarca, Catamarca, Argentina';
  const quote = 'I have a strongly worded note for the forecast department. '
      'The suggestion box has requested annual leave before reading it.';
  for (final dark in [false, true]) {
    testWidgets(
        'long selected-city name wraps at 320 and 200% in ${dark ? 'dark' : 'light'}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = UiPreservationFixture.weather.toJson();
      final weather = WeatherBundle.fromJson({
        ...json,
        'current': {
          ...(json['current'] as Map<String, dynamic>),
          'locationName': city
        }
      });
      await tester.pumpWidget(MaterialApp(
        theme: dark ? DMTheme.dark : DMTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              ForecastHeader(location: city, onChangeLocation: () {}),
              FeaturedRoastCard(
                  persona: RoastPersonas.byId('karen').toDayMakerPersona(),
                  roast: Roast(
                      id: 'stress-local',
                      personaId: 'karen',
                      weatherSnapshotId: 'fixture',
                      text: quote,
                      category: 'fixture',
                      createdAt: UiPreservationFixture.now,
                      xpReward: 0,
                      mood: RoastMood.complaining),
                  weather: weather),
            ]),
          ))),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final element in find.text(city).evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(find.text(city), findsNWidgets(2));
      await tester.ensureVisible(find.text('“$quote”'));
      expect(tester.takeException(), isNull);
      expect(
          tester
              .renderObject<RenderParagraph>(find.text('“$quote”'))
              .didExceedMaxLines,
          isFalse);
    });
  }
}
