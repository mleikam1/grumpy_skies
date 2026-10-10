import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';

import '../../core/weather/openweather_icon_mapper.dart';
import '../../design/dm_colors.dart';
import 'active_viewport.dart';

class DaymakerWeatherIcon extends StatefulWidget {
  const DaymakerWeatherIcon({
    super.key,
    this.conditionId,
    this.openWeatherIconCode,
    this.iconSlug,
    this.conditionMain,
    this.conditionDescription,
    this.forecastTime,
    this.forecastLocalTime,
    this.latitude,
    this.longitude,
    this.sunrise,
    this.sunset,
    required this.size,
    this.animated = true,
    this.subtleMotion = true,
    this.semanticLabel,
    this.color,
    this.style = WeatherIconStyle.fill,
  });

  /// Allows dedicated animation tests to exercise the real Lottie renderer.
  /// Normal widget/golden tests remain deterministic and can pumpAndSettle.
  @visibleForTesting
  static bool debugAnimateInTests = false;

  final int? conditionId;
  final String? openWeatherIconCode;
  final String? iconSlug;
  final String? conditionMain;
  final String? conditionDescription;
  final DateTime? forecastTime;
  final DateTime? forecastLocalTime;
  final double? latitude;
  final double? longitude;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double size;
  final bool animated;

  /// Retained for existing callers. Motion now comes only from the condition's
  /// bundled Lottie; an additional transform would double the motion and snap.
  final bool subtleMotion;
  final String? semanticLabel;
  final Color? color;
  final WeatherIconStyle style;

  @override
  State<DaymakerWeatherIcon> createState() => _DaymakerWeatherIconState();
}

class _DaymakerWeatherIconState extends State<DaymakerWeatherIcon>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final accessibility =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    // Flutter 3.44 exposes iOS Reduce Motion separately from Android's
    // disableAnimations. MediaQuery alone does not include the iOS flag.
    var testBinding = false;
    assert(() {
      testBinding = !DaymakerWeatherIcon.debugAnimateInTests &&
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      return true;
    }());
    final motionAllowed = widget.animated &&
        !testBinding &&
        !accessibility.reduceMotion &&
        !accessibility.disableAnimations &&
        accessibility.autoPlayAnimatedImages &&
        !(mediaQuery?.disableAnimations ?? false) &&
        !(mediaQuery?.accessibleNavigation ?? false);
    final mappedSlug = widget.iconSlug?.trim().toLowerCase().isNotEmpty == true
        ? widget.iconSlug!.trim().toLowerCase()
        : OpenWeatherIconMapper.map(
            conditionId: widget.conditionId,
            openWeatherIconCode: widget.openWeatherIconCode,
            conditionMain: widget.conditionMain,
            conditionDescription: widget.conditionDescription,
            forecastTime: widget.forecastTime,
            forecastLocalTime: widget.forecastLocalTime,
            latitude: widget.latitude,
            longitude: widget.longitude,
            sunrise: widget.sunrise,
            sunset: widget.sunset,
          );
    final icon = WeatherIcons.maybeNamed(mappedSlug) ??
        WeatherIcons.named(OpenWeatherIconMapper.fallbackSlug);
    final label = widget.semanticLabel ??
        OpenWeatherIconMapper.semanticLabel(
          conditionMain: widget.conditionMain,
          conditionDescription: widget.conditionDescription,
        ) ??
        (icon.name == OpenWeatherIconMapper.fallbackSlug
            ? 'Weather condition unavailable'
            : null);
    Widget still() {
      final asset = icon.resolve(
        style: widget.style,
        format: WeatherIconFormat.svgStatic,
        fallback: false,
      );
      return SvgPicture.asset(
        asset.path,
        package: WeatherIcons.packageName,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        colorMapper: widget.style == WeatherIconStyle.fill
            ? (icon.name.startsWith('fog')
                ? const _CloudEdgeColors(fog: true)
                : const _CloudEdgeColors())
            : null,
        // Filled weather illustrations always retain their multiple colors.
        colorFilter:
            widget.style != WeatherIconStyle.fill && widget.color != null
                ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
                : null,
      );
    }

    final lottieAsset = icon.maybeResolve(
        style: widget.style, format: WeatherIconFormat.lottie, fallback: false);
    final child = RepaintBoundary(
      child: !motionAllowed || lottieAsset == null
          ? still()
          : ActiveViewport(
              builder: (context, active, _) {
                if (!active) return still();
                return Lottie.asset(
                  lottieAsset.path,
                  package: WeatherIcons.packageName,
                  bundle: DefaultAssetBundle.of(context),
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  frameRate: const FrameRate(30),
                  renderCache: RenderCache.drawingCommands,
                  delegates: widget.style == WeatherIconStyle.fill
                      ? (icon.name.startsWith('fog')
                          ? _fogDelegates
                          : _filledDelegates)
                      : null,
                  // AssetLottie uses the package's shared composition cache. Nothing
                  // is downloaded or decoded on every loop/rebuild.
                  errorBuilder: (context, error, stack) => still(),
                );
              },
            ),
    );
    if (label == null || label.isEmpty) return child;
    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

// Match only the upstream cloud-outline color. Sun, rain, snow, moon, lightning
// and the cloud's filled blue-white gradient keep their original palette.
const _paleCloudEdge = Color(0xffe6effc);
final _filledDelegates = LottieDelegates(values: [
  // The bundled bolt uses short on/off flashes. Replace only that internal
  // opacity track with a restrained six-second pulse; never flash the scene.
  ValueDelegate.transformOpacity(const ['**', 'lightning-bolt'],
      callback: (frame) =>
          (90 + 10 * math.sin(frame.overallProgress * math.pi * 2)).round()),
  ValueDelegate.strokeColor(const ['**'], callback: (frame) {
    final original = frame.startValue ?? _paleCloudEdge;
    return original.toARGB32() == _paleCloudEdge.toARGB32()
        ? DMColors.slate
        : original;
  }),
]);

final _fogDelegates = LottieDelegates(values: [
  ..._filledDelegates.values!,
  // The fog ribbons are very pale gray in the original package. Keep the
  // filled cloud gradient and use the existing slate token for these layers.
  for (final layer in ['fog-1', 'fog-2'])
    ValueDelegate.gradientColor([
      '**',
      layer,
      '**'
    ], value: const [
      DMColors.slate,
      DMColors.slate,
      DMColors.slate,
      DMColors.slate,
      DMColors.slate,
    ]),
]);

class _CloudEdgeColors extends ColorMapper {
  const _CloudEdgeColors({this.fog = false});
  final bool fog;

  @override
  Color substitute(
      String? id, String elementName, String attributeName, Color color) {
    if (attributeName == 'stroke' && color == _paleCloudEdge) {
      return DMColors.slate;
    }
    if (fog &&
        attributeName == 'stop-color' &&
        (color == const Color(0xffd4d7dd) ||
            color == const Color(0xffbec1c6))) {
      return DMColors.slate;
    }
    return color;
  }
}
