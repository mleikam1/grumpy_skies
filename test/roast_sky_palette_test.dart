import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/features/roasts/models/roast_mood.dart';
import 'package:grumpy_skies/shared/widgets/dm_approved_components.dart';
import 'package:grumpy_skies/shared/widgets/dm_roast_mood_badge.dart';
import 'package:grumpy_skies/shared/widgets/dm_roast_surface.dart';

void main() {
  test('persona sky palette retains the specified light and dark tokens', () {
    expect(_tokens(DMRoastColors.light), [
      0xFFF3FAFF,
      0xFFC4E6FF,
      0xFFDDF1FF,
      0xFFF2FAFF,
      0xFFDDF1FF,
      0xFFA6CEED,
      0xFF101B3E,
      0xFF476487,
      0xFFE4F3FF,
      0xFF476487,
      0xFFA6CEED,
      0xFFF8FCFF,
      0xFF101B3E,
      0xFFB8D8F0,
      0xFFE4F3FF,
      0xFF101B3E,
      0xFF5B7EA0,
      0xFFFFE16A,
      0xFF101B3E,
      0xFFB8D8F0,
    ]);
    expect(_tokens(DMRoastColors.dark), [
      0xFF08182E,
      0xFF173D73,
      0xFF112D53,
      0xFF0C203D,
      0xFF112D53,
      0xFF355A86,
      0xFFF4F8FF,
      0xFFB8CCE7,
      0xFF17385F,
      0xFFC2DCF5,
      0xFF426A98,
      0xFF244E7A,
      0xFFF4F8FF,
      0xFF547FAC,
      0xFF163459,
      0xFFF4F8FF,
      0xFF7098CA,
      0xFFFFE16A,
      0xFF101B3E,
      0xFF33547A,
    ]);
    for (final colors in [DMRoastColors.light, DMRoastColors.dark]) {
      expect(colors.gradient.begin, Alignment.topLeft);
      expect(colors.gradient.end, Alignment.bottomRight);
      expect(colors.gradient.stops, [0, .55, 1]);
      for (final (text, surface) in [
        (colors.personaText, colors.personaSurface),
        (colors.moodText, colors.moodSurface),
        (colors.anotherText, colors.anotherSurface),
        (colors.shareText, colors.shareSurface),
      ]) {
        expect(_contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(colors.anotherOutline, colors.anotherSurface),
          greaterThanOrEqualTo(3));
      // A conservative bound also covers arbitrary card aspect ratios:
      // maximum illumination composited onto the brightest dark gradient stop.
      expect(
          _contrast(colors.anotherOutline,
              Color.alphaBlend(colors.illuminationColor, colors.gradientStart)),
          greaterThanOrEqualTo(3));
    }
  });

  for (final dark in [false, true]) {
    final colors = dark ? DMRoastColors.dark : DMRoastColors.light;
    final mode = dark ? 'dark' : 'light';
    for (final illuminationAlignment in [
      const Alignment(-.78, -.26),
      const Alignment(.65, -.55),
    ]) {
      for (final size in [
        const Size(360, 260),
        const Size(320, 680),
        const Size(760, 300),
      ]) {
        testWidgets(
            '$mode painted sky contrast, $size at $illuminationAlignment',
            (tester) async {
          tester.view.physicalSize = const Size(900, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(MaterialApp(
            theme: dark ? DMTheme.dark : DMTheme.light,
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: DmRoastSurface(
                    illuminationAlignment: illuminationAlignment,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ));
          final sampled = <int>{};
          var allOpaque = true;
          // Exclude only the decorative border and the outside of the rounded clip.
          final interior = RRect.fromRectAndRadius(
              Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
              const Radius.circular(20));
          await tester.runAsync(() async {
            final render = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            final bytes =
                (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                if (!interior.contains(Offset(x + .5, y + .5))) continue;
                final offset = (y * image.width + x) * 4;
                allOpaque = allOpaque && bytes.getUint8(offset + 3) == 255;
                sampled.add(Color.fromARGB(
                  255,
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                ).toARGB32());
              }
            }
            image.dispose();
          });
          expect(allOpaque, isTrue);
          expect(sampled.length, greaterThan(20),
              reason: 'The raster must include the gradient, not a flat fill.');
          for (final (foreground, threshold, role) in [
            (colors.textPrimary, 4.5, 'primary copy / standard icon'),
            (colors.textSecondary, 4.5, 'secondary metadata'),
            (colors.anotherOutline, 3.0, 'Another outline against card'),
          ]) {
            final ratios =
                sampled.map((pixel) => _contrast(foreground, Color(pixel)));
            final least = ratios.reduce((a, b) => a < b ? a : b);
            debugPrint(
                '$mode $size $illuminationAlignment $role: ${least.toStringAsFixed(3)}:1');
            expect(least, greaterThanOrEqualTo(threshold),
                reason: '$mode $role worst composited contrast: $least');
          }
        });
      }
    }

    testWidgets('$mode action overrides keep interaction feedback and contrast',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? DMTheme.dark : DMTheme.light,
        home: Scaffold(
          body: Column(children: [
            DmApprovedAction(
              label: 'Another',
              icon: Icons.refresh,
              onPressed: () => taps++,
              backgroundColor: colors.anotherSurface,
              foregroundColor: colors.anotherText,
              outlineColor: colors.anotherOutline,
            ),
            DmApprovedAction(
              label: 'Share',
              icon: Icons.share_outlined,
              primary: true,
              onPressed: () => taps++,
              backgroundColor: colors.shareSurface,
              foregroundColor: colors.shareText,
            ),
            DmApprovedAction(
              label: 'Disabled',
              icon: Icons.refresh,
              onPressed: null,
              backgroundColor: colors.anotherSurface,
              foregroundColor: colors.anotherText,
              outlineColor: colors.anotherOutline,
            ),
          ]),
        ),
      ));
      final buttons = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .toList();
      for (var i = 0; i < 2; i++) {
        final style = buttons[i].style!;
        final base = style.backgroundColor!.resolve({})!;
        final ink = style.foregroundColor!.resolve({})!;
        expect(style.minimumSize!.resolve({}), const Size(48, 48));
        for (final state in [
          WidgetState.hovered,
          WidgetState.focused,
          WidgetState.pressed,
        ]) {
          final overlay = style.overlayColor!.resolve({state})!;
          expect(overlay.a, greaterThan(0));
          final composed = Color.alphaBlend(overlay, base);
          expect(_contrast(ink, composed), greaterThanOrEqualTo(4.5),
              reason: '$mode button $i $state');
          if (i == 0) {
            expect(_contrast(colors.anotherOutline, composed),
                greaterThanOrEqualTo(3));
          }
        }
      }
      expect(buttons[1].style!.foregroundColor!.resolve({}),
          const Color(0xFF101B3E));
      await tester.tap(find.text('Another'));
      await tester.tap(find.text('Share'));
      expect(taps, 2);
      expect(buttons[2].onPressed, isNull);
      await tester.tap(find.text('Disabled'));
      expect(taps, 2);
    });
  }

  testWidgets('shared palette follows resolved theme; badges opt in locally',
      (tester) async {
    final key = GlobalKey();
    Widget app(ThemeData theme) => MaterialApp(
          theme: theme,
          home: Builder(
            key: key,
            builder: (context) => Column(children: [
              DmPersonaTitleBadge(label: 'SKY', colors: context.dmRoastColors),
              DmRoastMoodBadge(
                  mood: RoastMood.confident, colors: context.dmRoastColors),
              const DmPersonaTitleBadge(label: 'UNCHANGED'),
            ]),
          ),
        );
    await tester.pumpWidget(app(DMTheme.light));
    expect(key.currentContext!.dmRoastColors, same(DMRoastColors.light));
    expect(tester.widget<Text>(find.text('SKY')).style!.color,
        DMRoastColors.light.personaText);
    expect(tester.widget<Text>(find.text('UNCHANGED')).style!.color,
        DMSemanticColors.light.textSecondary);
    await tester.pumpWidget(app(DMTheme.dark));
    await tester.pumpAndSettle();
    expect(key.currentContext!.dmRoastColors, same(DMRoastColors.dark));
    expect(tester.widget<Text>(find.text('SKY')).style!.color,
        DMRoastColors.dark.personaText);
    expect(tester.widget<Text>(find.text('CONFIDENT')).style!.color,
        DMRoastColors.dark.moodText);
    expect(tester.widget<Text>(find.text('UNCHANGED')).style!.color,
        DMSemanticColors.dark.textSecondary);
  });
}

List<int> _tokens(DMRoastColors c) => [
      c.canvas,
      c.gradientStart,
      c.gradientMiddle,
      c.gradientEnd,
      c.surface,
      c.border,
      c.textPrimary,
      c.textSecondary,
      c.personaSurface,
      c.personaText,
      c.personaBorder,
      c.moodSurface,
      c.moodText,
      c.moodBorder,
      c.anotherSurface,
      c.anotherText,
      c.anotherOutline,
      c.shareSurface,
      c.shareText,
      c.divider,
    ].map((color) => color.toARGB32()).toList();

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
}
