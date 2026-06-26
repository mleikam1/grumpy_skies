import 'package:flutter/widgets.dart';
import 'package:weather_icons_animated/weather_icons_animated.dart';

import '../../core/weather/openweather_icon_mapper.dart';

class DaymakerWeatherIcon extends StatelessWidget {
  const DaymakerWeatherIcon({
    super.key,
    this.conditionId,
    this.openWeatherIconCode,
    this.conditionMain,
    this.conditionDescription,
    this.forecastTime,
    this.sunrise,
    this.sunset,
    required this.size,
    this.animated = true,
    this.semanticLabel,
  });

  final int? conditionId;
  final String? openWeatherIconCode;
  final String? conditionMain;
  final String? conditionDescription;
  final DateTime? forecastTime;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double size;
  final bool animated;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mappedSlug = OpenWeatherIconMapper.map(
      conditionId: conditionId,
      openWeatherIconCode: openWeatherIconCode,
      conditionMain: conditionMain,
      conditionDescription: conditionDescription,
      forecastTime: forecastTime,
      sunrise: sunrise,
      sunset: sunset,
    );
    final icon = WeatherIcons.maybeNamed(mappedSlug) ??
        WeatherIcons.named(OpenWeatherIconMapper.fallbackSlug);
    final label = semanticLabel ??
        OpenWeatherIconMapper.semanticLabel(
          conditionMain: conditionMain,
          conditionDescription: conditionDescription,
        );

    final child = WeatherIcon(
      icon: icon,
      style: WeatherIconStyle.fill,
      format: animated
          ? WeatherIconFormat.svgAnimated
          : WeatherIconFormat.svgStatic,
      size: size,
    );

    if (label == null || label.isEmpty) {
      return child;
    }

    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}
