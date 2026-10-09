import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';
import 'forecast_temperature.dart';

class ForecastCurrentWeatherCard extends StatelessWidget {
  const ForecastCurrentWeatherCard(
      {super.key, required this.weather, required this.now, this.today});
  final CurrentWeather weather;
  final DateTime now;
  final DailyForecast? today;

  @override
  Widget build(BuildContext context) {
    final unit = forecastTemperatureUnit(context);
    final temperature = forecastTemperature(weather.temperatureC, unit);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final partlyCloudy = weather.weatherId == 801 || weather.weatherId == 802;
    final isDay = weather.weatherIcon != null
        ? weather.weatherIcon!.endsWith('d')
        : now.isAfter(weather.sunrise) && now.isBefore(weather.sunset);
    return LayoutBuilder(builder: (context, constraints) {
      final expandedText = scale > 1.35 || constraints.maxWidth < 300;
      final art = partlyCloudy && isDay
          ? Image.asset('assets/approved_v1/weather/sun_grumpy_cloud.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => _weatherIcon(150))
          : _weatherIcon(150);
      final values = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(weather.condition.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: context.dmColors.textSecondary)),
            Text(temperature,
                style: TextStyle(
                    fontSize: temperature.length > 3 ? 84 : 102,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -6,
                    color: context.dmColors.textPrimary)),
            Text('Feels like ${forecastTemperature(weather.feelsLikeC, unit)}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (today != null)
              Text(
                  'H: ${forecastTemperature(today!.maxTempC, unit)}   L: ${forecastTemperature(today!.minTempC, unit)}',
                  style: TextStyle(
                      fontSize: 13, color: context.dmColors.textSecondary)),
          ]);
      return Container(
        constraints: const BoxConstraints(minHeight: 176),
        child: expandedText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [values, SizedBox(height: 145, child: art)])
            : Stack(children: [
                Positioned(
                    right: -10,
                    top: 0,
                    bottom: 0,
                    width: constraints.maxWidth * .58,
                    child: art),
                Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: SizedBox(
                        width: constraints.maxWidth * .54, child: values)),
              ]),
      );
    });
  }

  Widget _weatherIcon(double size) => DaymakerWeatherIcon(
      conditionId: weather.weatherId,
      openWeatherIconCode: weather.weatherIcon,
      conditionMain: weather.weatherMain,
      conditionDescription: weather.condition,
      forecastTime: now,
      sunrise: weather.sunrise,
      sunset: weather.sunset,
      size: size,
      semanticLabel: weather.condition);
}
