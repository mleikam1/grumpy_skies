import 'package:flutter/material.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../models/forecast_view_models.dart';
import '../models/hourly_timeline.dart';
import 'forecast_hourly_timeline.dart';
import 'forecast_sheet.dart';
import 'forecast_temperature.dart';

/// The existing daily list's surface, spacing and columns with hourly data.
class ForecastHourlyList extends StatelessWidget {
  const ForecastHourlyList({
    super.key,
    required this.hourly,
    this.referenceTime,
    this.timezone,
    this.timezoneOffset,
    this.latitude,
    this.longitude,
    this.errorMessage,
    this.weather,
    this.clock,
    this.onSeeAll,
    this.previewLimit = 12,
  });

  final List<HourlyForecast> hourly;
  final DateTime? referenceTime;
  final String? timezone;
  final int? timezoneOffset;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;
  final WeatherBundle? weather;
  final DateTime Function()? clock;
  final VoidCallback? onSeeAll;
  final int previewLimit;

  @override
  Widget build(BuildContext context) {
    final now = referenceTime ?? (clock ?? DateTime.now)();
    final zone = timezone ?? weather?.current.timezone;
    final offset = timezoneOffset ?? weather?.current.timezoneOffset;
    final items = HourlyForecastItem.fromForecast(hourly,
        now: now, timezone: zone, timezoneOffset: offset, limit: previewLimit);
    final colors = context.dmColors;
    return Column(
      key: const ValueKey('hourly-forecast-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DmApprovedSectionHeader(
          title: 'Hourly forecast',
          onAction: items.isEmpty
              ? null
              : onSeeAll ??
                  () => showForecastSheet(context,
                      title: 'Hourly forecast',
                      subtitle: zone == null && offset == null
                          ? 'Location time unavailable · times shown in UTC.'
                          : zone == null
                              ? 'Forecast times are local to this location, using the provider’s current UTC offset.'
                              : 'Forecast times are local to this location.',
                      bodyBuilder: (context, controller) =>
                          ForecastHourlyTimeline(
                            scrollController: controller,
                            hourly: hourly,
                            weather: weather,
                            timezone: zone,
                            timezoneOffset: offset,
                            clock: clock,
                          )),
        ),
        if (items.isEmpty)
          DmGlassCard(
            padding: const EdgeInsets.all(DMSpacing.md),
            borderRadius: DMRadius.large,
            shadows: const [],
            child: Text(errorMessage ?? 'Hourly forecast unavailable',
                textAlign: TextAlign.center),
          )
        else
          Container(
            key: const ValueKey('hourly-preview-list'),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.divider),
                ForecastHourlyRow(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  timezone: zone,
                  timezoneOffset: offset,
                  latitude: latitude ?? weather?.current.latitude,
                  longitude: longitude ?? weather?.current.longitude,
                  repeatedClockHour: items
                          .where((other) =>
                              forecastCalendarDate(other.localTime) ==
                                  forecastCalendarDate(items[i].localTime) &&
                              other.localTime.hour == items[i].localTime.hour &&
                              other.localTime.minute ==
                                  items[i].localTime.minute)
                          .length >
                      1,
                ),
              ],
            ]),
          ),
      ],
    );
  }
}

class ForecastHourlyRow extends StatelessWidget {
  const ForecastHourlyRow({
    super.key,
    required this.item,
    this.timezone,
    this.timezoneOffset,
    this.latitude,
    this.longitude,
    this.repeatedClockHour = false,
  });
  final HourlyForecastItem item;
  final String? timezone;
  final int? timezoneOffset;
  final double? latitude;
  final double? longitude;
  final bool repeatedClockHour;

  @override
  Widget build(BuildContext context) {
    final hour = item.forecast;
    final colors = context.dmColors;
    final knownTemperature =
        hour.temperatureKnown && hour.temperatureC.isFinite;
    final temperature = knownTemperature
        ? forecastTemperature(
            hour.temperatureC, forecastTemperatureUnit(context))
        : '—';
    final knownPrecipitation = hour.precipitationChanceKnown &&
        hour.precipitationChance >= 0 &&
        hour.precipitationChance <= 100;
    final precipitation =
        knownPrecipitation ? '${hour.precipitationChance}%' : '—';
    final label = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.localTime),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final offset = repeatedClockHour
        ? forecastUtcOffset(hour.time, timezone, timezoneOffset)
        : null;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final time =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      if (item.isCurrentHour)
        Text('Now', style: TextStyle(fontSize: 11, color: colors.link)),
      if (offset != null)
        Text(offset,
            style: TextStyle(fontSize: 10, color: colors.textSecondary)),
    ]);
    final icon = DaymakerWeatherIcon(
      key: ValueKey('${item.id}-icon'),
      conditionId: hour.weatherId,
      openWeatherIconCode: hour.weatherIcon,
      conditionMain: hour.weatherMain,
      conditionDescription: hour.condition,
      forecastTime: hour.time,
      forecastLocalTime:
          timezone == null && timezoneOffset == null ? null : item.localTime,
      latitude: latitude,
      longitude: longitude,
      size: 32,
      semanticLabel: hour.condition,
    );
    return Semantics(
      label:
          '$label${offset == null ? '' : ', $offset'}${item.isCurrentHour ? ', now' : ''}, '
          '${hour.condition}, ${knownTemperature ? temperature : 'temperature unavailable'}, '
          '${knownPrecipitation ? '$precipitation precipitation chance' : 'precipitation unavailable'}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(flex: 3, child: time),
              Expanded(
                  flex: largeText ? 2 : 3,
                  child: Align(alignment: Alignment.centerLeft, child: icon)),
              Expanded(
                  flex: largeText ? 3 : 2,
                  child: Text(temperature,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800))),
              if (!largeText)
                Expanded(
                    flex: 2,
                    child: Text(precipitation,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13, color: colors.textSecondary))),
            ]),
            if (largeText)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      knownPrecipitation
                          ? '$precipitation precipitation chance'
                          : 'Precipitation unavailable',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11, color: colors.textSecondary))),
          ]),
        ),
      ),
    );
  }
}
