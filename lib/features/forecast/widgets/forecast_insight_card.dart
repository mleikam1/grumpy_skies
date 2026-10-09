import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import 'forecast_hourly_strip.dart';

class ForecastInsightCard extends StatelessWidget {
  const ForecastInsightCard(
      {super.key,
      required this.weather,
      required this.now,
      this.unavailable = false});
  final WeatherBundle weather;
  final DateTime now;
  final bool unavailable;
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
    final local = rain?.time
        .toUtc()
        .add(Duration(seconds: weather.current.timezoneOffset ?? 0));
    final hour = local == null
        ? ''
        : '${local.hour % 12 == 0 ? 12 : local.hour % 12} ${local.hour >= 12 ? 'PM' : 'AM'}';
    final title =
        rain == null ? 'Your next few hours.' : 'A little plot twist at $hour.';
    final detail = unavailable
        ? 'Cached forecast · check the observation time.'
        : rain == null
            ? 'Explore the hourly forecast.'
            : 'Rain chance ${weather.current.precipitationChanceKnown && rain.precipitationChance > weather.current.precipitationChance ? 'rises to' : 'is'} ${rain.precipitationChance}%.';
    return Material(
        color: context.dmColors.insightSurface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const DmApprovedSectionHeader(
                                  title: 'Forecast details'),
                              Text(detail),
                              ForecastHourlyStrip(
                                  hourly: weather.hourly,
                                  sunrise: weather.current.sunrise,
                                  sunset: weather.current.sunset,
                                  referenceTime: now,
                                  timezoneOffset:
                                      weather.current.timezoneOffset)
                            ])))),
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
