import 'package:flutter/material.dart';

import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastDailyGrid extends StatelessWidget {
  const ForecastDailyGrid({
    super.key,
    required this.daily,
    this.sunrise,
    this.sunset,
  });

  final List<DailyForecast> daily;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    final days = daily.take(7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: '7-day forecast'),
        const SizedBox(height: DMSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: days.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: DMSpacing.sm),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 118,
                      child: _DailyTile(
                        day: days[index],
                        index: index,
                        sunrise: sunrise,
                        sunset: sunset,
                      ),
                    );
                  },
                ),
              );
            }

            final columns = constraints.maxWidth >= 960 ? 7 : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: DMSpacing.sm,
                mainAxisSpacing: DMSpacing.sm,
                childAspectRatio: columns == 7 ? 0.86 : 1.18,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                return _DailyTile(
                  day: days[index],
                  index: index,
                  sunrise: sunrise,
                  sunset: sunset,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({
    required this.day,
    required this.index,
    this.sunrise,
    this.sunset,
  });

  final DailyForecast day;
  final int index;
  final DateTime? sunrise;
  final DateTime? sunset;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.sm),
      borderRadius: DMRadius.large,
      shadows: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index == 0 ? 'Today' : _weekday(day.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.labelLarge,
          ),
          const Spacer(),
          DaymakerWeatherIcon(
            conditionId: day.weatherId,
            openWeatherIconCode: day.weatherIcon,
            conditionMain: day.weatherMain,
            conditionDescription: day.condition,
            forecastTime:
                DateTime(day.date.year, day.date.month, day.date.day, 12),
            sunrise: sunrise,
            sunset: sunset,
            size: 30,
            semanticLabel: day.condition,
          ),
          const SizedBox(height: DMSpacing.xs),
          Text(
            '${day.maxTempF.round()}° / ${day.minTempF.round()}°',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.labelLarge,
          ),
          const SizedBox(height: DMSpacing.xxs),
          Text(
            day.condition,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _weekday(DateTime date) {
    const labels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return labels[date.weekday - 1];
  }
}
