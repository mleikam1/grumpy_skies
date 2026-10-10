import 'forecast_temperature.dart';
import 'forecast_sheet.dart';
import 'package:flutter/material.dart';
import '../models/hourly_timeline.dart';
import 'forecast_hourly_timeline.dart';
import '../../roasts/controllers/local_roast_controller.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../design/dm_theme.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastHourlyStrip extends StatelessWidget {
  const ForecastHourlyStrip({
    super.key,
    required this.hourly,
    this.sunrise,
    this.sunset,
    this.referenceTime,
    this.timezoneOffset,
    this.errorMessage,
    this.timezone,
    this.weather,
    this.roasts,
    this.personaId,
    this.clock,
  });

  final List<HourlyForecast> hourly;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? referenceTime;
  final int? timezoneOffset;
  final String? errorMessage;
  final String? timezone;
  final WeatherBundle? weather;
  final LocalRoastController? roasts;
  final String? personaId;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final now = referenceTime ?? DateTime.now();
    final allHours = forecastTimelineHours(hourly, now);
    final items = allHours
        .take(12)
        .map((hour) => _HourlyForecastItem(
            hour: hour,
            label: forecastIsCurrentHour(hour.time, now)
                ? 'Now'
                : forecastHourLabel(hour.time, timezone, timezoneOffset)))
        .toList();
    final child = items.isEmpty
        ? _EmptyHourlyState(message: errorMessage)
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              return _HourlyTile(
                key: ValueKey(
                    items[index].hour.time.toUtc().millisecondsSinceEpoch),
                width: ((MediaQuery.sizeOf(context).width - 56) / 5)
                        .clamp(60, 90) *
                    (MediaQuery.textScalerOf(context).scale(14) / 14)
                        .clamp(1, 2),
                hour: items[index].hour,
                label: items[index].label,
                latitude: weather?.current.latitude,
                longitude: weather?.current.longitude,
                localTime: timezone == null && timezoneOffset == null
                    ? null
                    : forecastLocalTime(
                        items[index].hour.time, timezone, timezoneOffset),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmApprovedSectionHeader(
            title: 'Hourly forecast',
            onAction: items.isEmpty
                ? null
                : () => showForecastSheet(context,
                    title: 'Hourly forecast',
                    subtitle: timezone == null && timezoneOffset == null
                        ? 'Location time unavailable · times shown in UTC.'
                        : timezone == null
                            ? 'Forecast times are local to this location, using the provider’s current UTC offset.'
                            : 'Forecast times are local to this location.',
                    bodyBuilder: (context, controller) =>
                        ForecastHourlyTimeline(
                          scrollController: controller,
                          hourly: hourly,
                          weather: weather,
                          roasts: roasts,
                          personaId: personaId,
                          timezone: timezone,
                          timezoneOffset: timezoneOffset,
                          clock: clock,
                        ))),
        if (items.isEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: child,
          )
        else
          SizedBox(
            height: 110 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
            child: child,
          ),
      ],
    );
  }
}

class _EmptyHourlyState extends StatelessWidget {
  const _EmptyHourlyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Center(
        child: Text(
          message ?? 'Hourly forecast unavailable',
          textAlign: TextAlign.center,
          style: DMTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _HourlyForecastItem {
  const _HourlyForecastItem({
    required this.hour,
    required this.label,
  });

  final HourlyForecast hour;
  final String label;
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({
    super.key,
    required this.hour,
    required this.label,
    this.width = 66,
    required this.localTime,
    this.latitude,
    this.longitude,
  });

  final HourlyForecast hour;
  final String label;
  final DateTime? localTime;
  final double? latitude;
  final double? longitude;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DmGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        borderRadius: DMRadius.large,
        shadows: const [],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: context.dmColors.textSecondary),
            ),
            const SizedBox(height: 6),
            DaymakerWeatherIcon(
              conditionId: hour.weatherId,
              openWeatherIconCode: hour.weatherIcon,
              conditionMain: hour.weatherMain,
              conditionDescription: hour.condition,
              forecastTime: hour.time,
              forecastLocalTime: localTime,
              latitude: latitude,
              longitude: longitude,
              size: 36,
              semanticLabel: hour.condition,
            ),
            const SizedBox(height: 4),
            Text(
              hour.temperatureKnown && hour.temperatureC.isFinite
                  ? forecastTemperature(
                      hour.temperatureC, forecastTemperatureUnit(context))
                  : '—',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18, height: 1.1, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: DMSpacing.xxs),
            Text(
              hour.precipitationChanceKnown && hour.precipitationChance > 0
                  ? '${hour.precipitationChance}%'
                  : '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: context.dmColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
