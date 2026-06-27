import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';

import '../../core/weather/openweather_icon_mapper.dart';

class DaymakerWeatherIcon extends StatefulWidget {
  const DaymakerWeatherIcon({
    super.key,
    this.conditionId,
    this.openWeatherIconCode,
    this.iconSlug,
    this.conditionMain,
    this.conditionDescription,
    this.forecastTime,
    this.sunrise,
    this.sunset,
    required this.size,
    this.animated = true,
    this.subtleMotion = true,
    this.semanticLabel,
    this.color,
    this.style = WeatherIconStyle.fill,
  });

  final int? conditionId;
  final String? openWeatherIconCode;
  final String? iconSlug;
  final String? conditionMain;
  final String? conditionDescription;
  final DateTime? forecastTime;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double size;
  final bool animated;
  final bool subtleMotion;
  final String? semanticLabel;
  final Color? color;
  final WeatherIconStyle style;

  @override
  State<DaymakerWeatherIcon> createState() => _DaymakerWeatherIconState();
}

class _DaymakerWeatherIconState extends State<DaymakerWeatherIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: _DaymakerWeatherMotionKind.bob.duration,
    );
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final animationsEnabled = widget.animated &&
        TickerMode.valuesOf(context).enabled &&
        !_debugIsWidgetTestBinding() &&
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
            sunrise: widget.sunrise,
            sunset: widget.sunset,
          );
    final icon = WeatherIcons.maybeNamed(mappedSlug) ??
        WeatherIcons.named(OpenWeatherIconMapper.fallbackSlug);
    final label = widget.semanticLabel ??
        OpenWeatherIconMapper.semanticLabel(
          conditionMain: widget.conditionMain,
          conditionDescription: widget.conditionDescription,
        );
    final motion = _DaymakerWeatherMotionKind.forSlug(icon.name);
    final iconFormat = animationsEnabled
        ? WeatherIconFormat.lottie
        : WeatherIconFormat.svgStatic;
    final child = WeatherIcon(
      icon: icon,
      style: widget.style,
      format: iconFormat,
      size: widget.size,
      color: widget.color,
      animate: animationsEnabled,
      repeat: animationsEnabled,
    );
    final wrappedChild = widget.subtleMotion && animationsEnabled
        ? _buildSubtleMotion(child: child, motion: motion)
        : _stopMotion(child);

    if (label == null || label.isEmpty) {
      return wrappedChild;
    }

    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: wrappedChild),
    );
  }

  Widget _buildSubtleMotion({
    required Widget child,
    required _DaymakerWeatherMotionKind motion,
  }) {
    if (motion == _DaymakerWeatherMotionKind.none) {
      return _stopMotion(child);
    }

    if (_motionController.duration != motion.duration) {
      _motionController.duration = motion.duration;
    }
    if (!_motionController.isAnimating) {
      _motionController.repeat();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _motionController,
        child: child,
        builder: (context, child) {
          final value = _motionController.value;
          final wave = math.sin(value * math.pi * 2);
          final pulse = (wave + 1) / 2;

          return switch (motion) {
            _DaymakerWeatherMotionKind.sun => Transform.rotate(
                angle: value * math.pi * 2 * 0.015,
                child: Transform.scale(
                  scale: 1 + pulse * 0.025,
                  child: child,
                ),
              ),
            _DaymakerWeatherMotionKind.cloud => Transform.translate(
                offset: Offset(wave * 2.5, 0),
                child: child,
              ),
            _DaymakerWeatherMotionKind.precipitation => Transform.translate(
                offset: Offset(0, wave * 2),
                child: child,
              ),
            _DaymakerWeatherMotionKind.thunder => Transform.scale(
                scale: 1 + pulse * 0.03,
                child: child,
              ),
            _DaymakerWeatherMotionKind.wind => Transform.translate(
                offset: Offset(wave * 3, 0),
                child: child,
              ),
            _DaymakerWeatherMotionKind.bob => Transform.translate(
                offset: Offset(0, wave * 1.5),
                child: child,
              ),
            _DaymakerWeatherMotionKind.fade => Opacity(
                opacity: 0.9 + pulse * 0.1,
                child: child,
              ),
            _DaymakerWeatherMotionKind.none => child!,
          };
        },
      ),
    );
  }

  Widget _stopMotion(Widget child) {
    if (_motionController.isAnimating) {
      _motionController.stop();
    }
    return child;
  }

  bool _debugIsWidgetTestBinding() {
    var isWidgetTest = false;
    assert(() {
      isWidgetTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      return true;
    }());
    return isWidgetTest;
  }
}

enum _DaymakerWeatherMotionKind {
  sun(Duration(seconds: 10)),
  cloud(Duration(seconds: 7)),
  precipitation(Duration(seconds: 4)),
  thunder(Duration(milliseconds: 1800)),
  wind(Duration(seconds: 5)),
  bob(Duration(seconds: 5)),
  fade(Duration(seconds: 4)),
  none(Duration(seconds: 1));

  const _DaymakerWeatherMotionKind(this.duration);

  final Duration duration;

  static _DaymakerWeatherMotionKind forSlug(String slug) {
    if (slug == OpenWeatherIconMapper.fallbackSlug) {
      return _DaymakerWeatherMotionKind.none;
    }

    if (slug.contains('thunder') || slug.contains('lightning')) {
      return _DaymakerWeatherMotionKind.thunder;
    }
    if (slug.contains('wind') ||
        slug.contains('tornado') ||
        slug.contains('hurricane') ||
        slug.contains('windsock')) {
      return _DaymakerWeatherMotionKind.wind;
    }
    if (slug.contains('rain') ||
        slug.contains('drizzle') ||
        slug.contains('sleet') ||
        slug.contains('snow') ||
        slug.contains('hail') ||
        slug.contains('raindrop') ||
        slug.contains('umbrella')) {
      return _DaymakerWeatherMotionKind.precipitation;
    }
    if (slug.contains('clear-day') ||
        slug.contains('sun') ||
        slug.contains('uv-index')) {
      return _DaymakerWeatherMotionKind.sun;
    }
    if (slug.contains('cloud') || slug.contains('overcast')) {
      return _DaymakerWeatherMotionKind.cloud;
    }
    if (slug.contains('mist') ||
        slug.contains('fog') ||
        slug.contains('haze') ||
        slug.contains('smoke') ||
        slug.contains('dust') ||
        slug.contains('humidity') ||
        slug.contains('barometer') ||
        slug.contains('pressure') ||
        slug.contains('horizon')) {
      return _DaymakerWeatherMotionKind.bob;
    }
    if (slug.contains('moon') ||
        slug.contains('night') ||
        slug.contains('star')) {
      return _DaymakerWeatherMotionKind.fade;
    }

    return _DaymakerWeatherMotionKind.bob;
  }
}
