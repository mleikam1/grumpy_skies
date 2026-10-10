import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/design/dm_colors.dart';
import 'package:grumpy_skies/shared/widgets/daymaker_weather_icon.dart';
import 'package:grumpy_skies/shared/widgets/active_viewport.dart';
import 'package:lottie/lottie.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';

void main() {
  tearDown(() => DaymakerWeatherIcon.debugAnimateInTests = false);

  testWidgets(
      'filled static fallback keeps colors, size and clear night mapping',
      (tester) async {
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: 800,
      openWeatherIconCode: '01n',
      size: 36,
      color: Colors.red,
      animated: false,
    )));
    await tester.pumpAndSettle();
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, 'assets/fill/svg-static/clear-night.svg');
    expect(loader.packageName, WeatherIcons.packageName);
    expect(svg.colorFilter, isNull);
    expect(find.byType(ActiveViewport), findsNothing);
    expect(svg.fit, BoxFit.contain);
    expect(tester.getSize(find.byType(SvgPicture)), const Size(36, 36));
    final mapper = loader.colorMapper!;
    expect(mapper.substitute(null, 'path', 'stroke', const Color(0xffe6effc)),
        DMColors.slate);
    expect(
        mapper.substitute(null, 'stop', 'stop-color', const Color(0xfffbbf24)),
        const Color(0xfffbbf24));
  });

  testWidgets('unknown conditions retain readable neutral static fallback',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: -99,
      size: 32,
      animated: false,
    )));
    await tester.pumpAndSettle();
    expect(_svgPath(tester), 'assets/fill/svg-static/not-available.svg');
    expect(
        find.bySemanticsLabel('Weather condition unavailable'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('real bundled Lottie advances without extra transforms',
      (tester) async {
    await _enableLottie(tester, 'rain');
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: 500,
      size: 42,
    )));
    await _loadFrames(tester);
    expect(find.byType(LottieBuilder), findsOneWidget);
    final builder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect((builder.lottie as AssetLottie).assetName,
        'assets/fill/lottie/rain.json');
    expect(builder.fit, BoxFit.contain);
    expect(builder.renderCache, RenderCache.drawingCommands);
    final before = tester.widget<RawLottie>(find.byType(RawLottie)).progress;
    await tester.pump(const Duration(milliseconds: 600));
    final after = tester.widget<RawLottie>(find.byType(RawLottie)).progress;
    expect(after, isNot(before));
    expect(
        find.descendant(
            of: find.byType(DaymakerWeatherIcon),
            matching: find.byType(Transform)),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
      'mist uses filled cloud with genuinely moving fog and static fallback',
      (tester) async {
    await _enableLottie(tester, 'fog');
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: 701,
      conditionDescription: 'Mist',
      size: 36,
    )));
    await _loadFrames(tester);
    final builder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect((builder.lottie as AssetLottie).assetName,
        'assets/fill/lottie/fog.json');
    final before = tester.widget<RawLottie>(find.byType(RawLottie)).progress;
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<RawLottie>(find.byType(RawLottie)).progress,
        isNot(before));
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: 701,
      conditionDescription: 'Mist',
      size: 36,
      animated: false,
    )));
    await tester.pumpAndSettle();
    expect(_svgPath(tester), 'assets/fill/svg-static/fog.svg');
    final loader = tester
        .widget<SvgPicture>(find.byType(SvgPicture))
        .bytesLoader as SvgAssetLoader;
    expect(
        loader.colorMapper!
            .substitute(null, 'stop', 'stop-color', const Color(0xffd4d7dd)),
        DMColors.slate);
    expect(tester.getSize(find.byType(SvgPicture)), const Size(36, 36));
  });

  testWidgets(
      'iOS Reduce Motion and Android disableAnimations show full static',
      (tester) async {
    await _enableLottie(tester, 'clear-day');
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: 800,
      openWeatherIconCode: '01d',
      size: 36,
    )));
    await _loadFrames(tester);
    expect(find.byType(LottieBuilder), findsOneWidget);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
            autoPlayAnimatedImages: true, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(find.byType(LottieBuilder), findsNothing);
    expect(_svgPath(tester), 'assets/fill/svg-static/clear-day.svg');
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
            autoPlayAnimatedImages: true, disableAnimations: true);
    await tester.pumpAndSettle();
    expect(_svgPath(tester), 'assets/fill/svg-static/clear-day.svg');
    expect(tester.getSize(find.byType(SvgPicture)), const Size(36, 36));
  });

  testWidgets('app preference and MediaQuery reduced motion disable Lottie',
      (tester) async {
    await _enableLottie(tester, 'snow');
    await tester.pumpWidget(_app(const DaymakerWeatherIcon(
      conditionId: 600,
      size: 38,
      animated: false,
    )));
    await tester.pumpAndSettle();
    expect(_svgPath(tester), 'assets/fill/svg-static/snow.svg');
    await tester.pumpWidget(_app(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: DaymakerWeatherIcon(conditionId: 600, size: 38),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(LottieBuilder), findsNothing);
  });

  testWidgets('Lottie decoding failure falls back to same filled condition',
      (tester) async {
    await _enableLottie(tester, 'rain');
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _BrokenLottieBundle(),
      child: _app(const DaymakerWeatherIcon(conditionId: 500, size: 42)),
    ));
    await tester.pumpAndSettle();
    expect(_svgPath(tester), 'assets/fill/svg-static/rain.svg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lottie stops in background and restarts only in foreground',
      (tester) async {
    await _enableLottie(tester, 'rain');
    await tester.pumpWidget(
        _app(const DaymakerWeatherIcon(conditionId: 500, size: 36)));
    await _loadFrames(tester);
    expect(find.byType(LottieBuilder), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.byType(LottieBuilder), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _loadFrames(tester);
    expect(find.byType(LottieBuilder), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _app(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));
String _svgPath(WidgetTester tester) =>
    (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
            as SvgAssetLoader)
        .assetName;

Future<void> _enableLottie(WidgetTester tester, String slug) async {
  DaymakerWeatherIcon.debugAnimateInTests = true;
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(autoPlayAnimatedImages: true);
  addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.runAsync(() => AssetLottie('assets/fill/lottie/$slug.json',
          package: WeatherIcons.packageName, bundle: rootBundle)
      .load());
}

Future<void> _loadFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _BrokenLottieBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.endsWith('.json') && key.contains('/lottie/')) {
      return Future.error(StateError('simulated corrupt bundled animation'));
    }
    return rootBundle.load(key);
  }
}
