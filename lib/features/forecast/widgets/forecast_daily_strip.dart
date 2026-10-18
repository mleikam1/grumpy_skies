import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../models/forecast_view_models.dart';
import 'forecast_details_sheet.dart';
import 'forecast_temperature.dart';

/// The existing hourly tile treatment, now presenting seven civil dates.
class ForecastDailyStrip extends StatelessWidget {
  const ForecastDailyStrip({
    super.key,
    required this.daily,
    this.weather,
    this.clock,
    this.referenceTime,
    this.timezone,
    this.timezoneOffset,
    this.latitude,
    this.longitude,
    this.errorMessage,
    this.onSeeAll,
  });

  final List<DailyForecast> daily;
  final WeatherBundle? weather;
  final DateTime Function()? clock;
  final DateTime? referenceTime;
  final String? timezone;
  final int? timezoneOffset;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final now = referenceTime ?? DateTime.now();
    final window = DailyForecastWindow.fromForecast(daily,
        now: now, timezone: timezone, timezoneOffset: timezoneOffset);
    final allDays = DailyForecastWindow.fromForecast(daily,
        now: now,
        timezone: timezone,
        timezoneOffset: timezoneOffset,
        horizonDays: null);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width =
        (((MediaQuery.sizeOf(context).width - 56) / 4).clamp(88, 104) *
                scale.clamp(1, 2))
            .toDouble();
    final texts = [
      for (final item in window.items)
        _DailyTileText.fromItem(context, item, window.today),
    ];
    // Measure all displayed strings at the actual width/font/text scale. This
    // preserves the compact tile while allowing high/low and unknowns to wrap.
    var height = 128.0;
    for (final text in texts) {
      height = math.max(height, text.height(context, width - 8));
    }
    return Column(
      key: const ValueKey('daily-forecast-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DmApprovedSectionHeader(
          title: '7-day forecast',
          onAction: allDays.items.isEmpty
              ? null
              : onSeeAll ??
                  () => showDailyForecastSheet(context,
                      daily: daily,
                      weather: weather,
                      clock: clock,
                      referenceTime: now,
                      timezone: timezone,
                      timezoneOffset: timezoneOffset,
                      latitude: latitude,
                      longitude: longitude),
        ),
        if (!window.complete && window.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${window.coveredDays} of 7 forecast days available',
                style: TextStyle(
                    fontSize: 11, color: context.dmColors.textSecondary)),
          ),
        if (window.items.isEmpty)
          DmGlassCard(
            padding: const EdgeInsets.all(DMSpacing.md),
            borderRadius: DMRadius.large,
            shadows: const [],
            child: Text(errorMessage ?? '7-day forecast unavailable',
                textAlign: TextAlign.center),
          )
        else
          SizedBox(
            height: height.ceilToDouble(),
            child: ListView.separated(
              key: const PageStorageKey('daily-forecast-strip'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none,
              itemCount: window.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) => ForecastDailyTile(
                key: ValueKey(window.items[index].id),
                item: window.items[index],
                today: window.today,
                width: width,
                timezone: timezone,
                timezoneOffset: timezoneOffset,
                latitude: latitude,
                longitude: longitude,
              ),
            ),
          ),
      ],
    );
  }
}

String forecastDayLabel(BuildContext context, DateTime date, DateTime today) =>
    date == today
        ? 'Today'
        : DateFormat.E(Localizations.localeOf(context).toLanguageTag())
            .format(date);

class _DailyTileText {
  const _DailyTileText(this.label, this.high, this.low, this.precipitation);
  final String label;
  final String high;
  final String low;
  final String precipitation;

  static const labelStyle =
      TextStyle(fontSize: 12, height: 1.1, fontWeight: FontWeight.w800);
  static const temperatureStyle =
      TextStyle(fontSize: 16, height: 1.1, fontWeight: FontWeight.w800);
  static const precipitationStyle = TextStyle(fontSize: 10, height: 1.1);

  factory _DailyTileText.fromItem(
      BuildContext context, DailyForecastItem item, DateTime today) {
    final day = item.forecast;
    final unit = forecastTemperatureUnit(context);
    final known =
        day.temperatureKnown && day.maxTempC.isFinite && day.minTempC.isFinite;
    return _DailyTileText(
      forecastDayLabel(context, item.date, today),
      'High ${known ? forecastTemperature(day.maxTempC, unit) : '—'}',
      'Low ${known ? forecastTemperature(day.minTempC, unit) : '—'}',
      day.precipitationChanceKnown &&
              day.precipitationChance >= 0 &&
              day.precipitationChance <= 100
          ? '${day.precipitationChance}% precip.'
          : 'Precip. —',
    );
  }

  double height(BuildContext context, double width) {
    double measure(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
            text: value,
            style: DefaultTextStyle.of(context).style.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    return 16 +
        36 +
        6 +
        4 +
        4 +
        4 +
        measure(label, labelStyle) +
        measure(high, temperatureStyle) +
        measure(low, temperatureStyle) +
        measure(precipitation, precipitationStyle) +
        2;
  }
}

class ForecastDailyTile extends StatelessWidget {
  const ForecastDailyTile({
    super.key,
    required this.item,
    required this.today,
    required this.width,
    this.timezone,
    this.timezoneOffset,
    this.latitude,
    this.longitude,
  });
  final DailyForecastItem item;
  final DateTime today;
  final double width;
  final String? timezone;
  final int? timezoneOffset;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final day = item.forecast;
    final text = _DailyTileText.fromItem(context, item, today);
    final colors = context.dmColors;
    return Semantics(
      label: '${MaterialLocalizations.of(context).formatFullDate(item.date)}, '
          '${day.condition}, '
          '${day.temperatureKnown && day.maxTempC.isFinite && day.minTempC.isFinite ? '${text.high}, ${text.low}' : 'temperature unavailable'}, '
          '${text.precipitation == 'Precip. —' ? 'precipitation unavailable' : '${day.precipitationChance}% precipitation chance'}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: DmGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            borderRadius: DMRadius.large,
            shadows: const [],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(text.label,
                    textAlign: TextAlign.center,
                    style: _DailyTileText.labelStyle
                        .copyWith(color: colors.textPrimary)),
                const SizedBox(height: 6),
                DaymakerWeatherIcon(
                  key: ValueKey('${item.id}-icon'),
                  conditionId: day.weatherId,
                  openWeatherIconCode: day.weatherIcon,
                  conditionMain: day.weatherMain,
                  conditionDescription: day.condition,
                  forecastTime: item.noonInstant(timezone, timezoneOffset),
                  forecastLocalTime: item.date.add(const Duration(hours: 12)),
                  latitude: latitude,
                  longitude: longitude,
                  size: 36,
                  semanticLabel: day.condition,
                ),
                const SizedBox(height: 4),
                Text(text.high,
                    textAlign: TextAlign.center,
                    style: _DailyTileText.temperatureStyle),
                const SizedBox(height: 4),
                Text(text.low,
                    textAlign: TextAlign.center,
                    style: _DailyTileText.temperatureStyle
                        .copyWith(color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text(text.precipitation,
                    textAlign: TextAlign.center,
                    style: _DailyTileText.precipitationStyle
                        .copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
