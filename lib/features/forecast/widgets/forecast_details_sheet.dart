import 'package:flutter/material.dart';

import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_weather_icon.dart';
import '../models/forecast_view_models.dart';
import 'forecast_sheet.dart';
import 'forecast_temperature.dart';

/// Keeps the existing daily detail presentation inside its existing sheet.
Future<void> showDailyForecastSheet(
  BuildContext context, {
  required List<DailyForecast> daily,
  required DateTime referenceTime,
  String? timezone,
  int? timezoneOffset,
  double? latitude,
  double? longitude,
}) {
  final window = DailyForecastWindow.fromForecast(daily,
      now: referenceTime,
      timezone: timezone,
      timezoneOffset: timezoneOffset,
      horizonDays: null);
  return showForecastSheet(context,
      title: 'Daily forecast',
      subtitle: 'Daily conditions · High / Low'
          '${window.complete ? '' : ' · ${window.coveredDays} of the next 7 forecast days available'}',
      bodyBuilder: (context, controller) => ListView.separated(
            key: const ValueKey('daily-forecast-details'),
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
            itemCount: window.items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.dmColors.divider),
            itemBuilder: (context, index) => ForecastDailyDetailRow(
              key: ValueKey('detail-${window.items[index].id}'),
              item: window.items[index],
              today: window.today,
              timezone: timezone,
              timezoneOffset: timezoneOffset,
              latitude: latitude,
              longitude: longitude,
            ),
          ));
}

class ForecastDailyDetailRow extends StatelessWidget {
  const ForecastDailyDetailRow({
    super.key,
    required this.item,
    required this.today,
    this.timezone,
    this.timezoneOffset,
    this.latitude,
    this.longitude,
  });
  final DailyForecastItem item;
  final DateTime today;
  final String? timezone;
  final int? timezoneOffset;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final day = item.forecast;
    final unit = forecastTemperatureUnit(context);
    final known =
        day.temperatureKnown && day.minTempC.isFinite && day.maxTempC.isFinite;
    final high = known ? forecastTemperature(day.maxTempC, unit) : '—';
    final low = known ? forecastTemperature(day.minTempC, unit) : '—';
    final colors = context.dmColors;
    final label = item.date == today
        ? 'Today'
        : MaterialLocalizations.of(context).formatShortDate(item.date);
    final knownPrecipitation = day.precipitationChanceKnown &&
        day.precipitationChance >= 0 &&
        day.precipitationChance <= 100;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary))),
            const SizedBox(width: 12),
            Flexible(
                child: Semantics(
                    label: known
                        ? 'High $high, low $low'
                        : 'Temperature unavailable',
                    child: ExcludeSemantics(
                        child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: high,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary)),
                              TextSpan(
                                  text: '  /  $low',
                                  style:
                                      TextStyle(color: colors.textSecondary)),
                            ]),
                            style:
                                const TextStyle(fontSize: 17, height: 1.2))))),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DaymakerWeatherIcon(
                key: ValueKey('detail-${item.id}-icon'),
                conditionId: day.weatherId,
                openWeatherIconCode: day.weatherIcon,
                conditionMain: day.weatherMain,
                conditionDescription: day.condition,
                forecastTime: item.noonInstant(timezone, timezoneOffset),
                forecastLocalTime: item.date.add(const Duration(hours: 12)),
                latitude: latitude,
                longitude: longitude,
                size: 38,
                semanticLabel: day.condition),
            const SizedBox(width: 12),
            Expanded(
                child: Text(day.condition,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colors.textSecondary))),
          ]),
          const SizedBox(height: 7),
          Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                  knownPrecipitation
                      ? '${day.precipitationChance}% precipitation'
                      : 'Precipitation unavailable',
                  style: TextStyle(
                      fontSize: 12, height: 1.3, color: colors.link))),
        ]));
  }
}
