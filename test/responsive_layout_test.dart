import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grumpy_skies/config/app_routes.dart';

import 'helpers/daymaker_test_helpers.dart';

void main() {
  const targetViewports = <DayMakerTestViewport>[
    DayMakerTestViewport(label: 'small phone', size: Size(360, 740)),
    dayMakerPhoneViewport,
    DayMakerTestViewport(label: 'large phone', size: Size(430, 932)),
    dayMakerTabletViewport,
    DayMakerTestViewport(
      label: '1024x768 tablet landscape',
      size: Size(1024, 768),
    ),
    dayMakerDesktopViewport,
  ];

  const routes = <String, String>{
    'splash': AppRoutes.splash,
    'forecast': AppRoutes.forecast,
    'roasts': AppRoutes.roasts,
    'roast reveal': AppRoutes.roastReveal,
    'radar': AppRoutes.radar,
    'fun': AppRoutes.fun,
    'meme generator': AppRoutes.memeGenerator,
    'settings': AppRoutes.settings,
    'about': AppRoutes.about,
  };

  for (final viewport in targetViewports) {
    for (final routeEntry in routes.entries) {
      testWidgets(
        '${routeEntry.key} renders without layout exceptions at '
        '${viewport.label}',
        (tester) async {
          await tester.pumpDayMakerRoute(
            viewport: viewport,
            initialLocation: routeEntry.value,
          );

          expectNoFlutterExceptions(tester);
        },
      );
    }
  }

  for (final routeEntry in routes.entries) {
    testWidgets(
      '${routeEntry.key} tolerates large text on a small phone',
      (tester) async {
        await tester.pumpDayMakerRoute(
          viewport: targetViewports.first,
          initialLocation: routeEntry.value,
          textScale: 1.35,
        );

        expectNoFlutterExceptions(tester);
      },
    );
  }
}
