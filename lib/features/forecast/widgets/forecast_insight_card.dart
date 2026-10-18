import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import 'forecast_sheet.dart';
import 'forecast_hourly_strip.dart';
import '../models/hourly_timeline.dart';

class ForecastInsightCard extends StatelessWidget {
  const ForecastInsightCard(
      {super.key,
      required this.weather,
      required this.now,
      this.unavailable = false,
      this.clock});
  final WeatherBundle weather;
  final DateTime now;
  final bool unavailable;
  final DateTime Function()? clock;
  @override
  Widget build(BuildContext context) {
    final upcoming = weather.hourly
        .where((h) =>
            h.precipitationChanceKnown &&
            h.precipitationChance >= 30 &&
            h.time.isAfter(now) &&
            h.time.isBefore(now.add(const Duration(hours: 24))))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final rain = !unavailable && upcoming.isNotEmpty ? upcoming.first : null;
    final hour = rain == null
        ? ''
        : forecastHourLabel(rain.time, weather.current.timezone,
            weather.current.timezoneOffset);
    final title = rain == null
        ? 'Your next few hours.'
        : 'Precipitation possible around $hour.';
    final detail = unavailable
        ? 'Cached forecast · check the observation time.'
        : rain == null
            ? 'Explore the hourly forecast.'
            : 'Precipitation chance ${weather.current.precipitationChanceKnown && rain.precipitationChance > weather.current.precipitationChance ? 'rises to' : 'is'} ${rain.precipitationChance}%.';
    return Material(
        color: context.dmColors.insightSurface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showForecastSheet(context,
                    title: 'Forecast details',
                    subtitle: detail,
                    children: [
                      const SizedBox(height: 14),
                      ForecastHourlyStrip(
                          hourly: weather.hourly,
                          weather: weather,
                          clock: clock,
                          timezone: weather.current.timezone,
                          sunrise: weather.current.sunrise,
                          sunset: weather.current.sunset,
                          referenceTime: now,
                          timezoneOffset: weather.current.timezoneOffset),
                    ]),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Icon(
                      rain == null
                          ? Icons.cloud_outlined
                          : Icons.beach_access_outlined,
                      color: context.dmColors.insightIcon,
                      size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(detail,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.dmColors.textSecondary))
                      ])),
                  const Icon(Icons.chevron_right, size: 22),
                ]))));
  }
}
