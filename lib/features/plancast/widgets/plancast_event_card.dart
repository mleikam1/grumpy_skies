import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_theme.dart';
import '../../../design/dm_typography.dart';
import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../services/settings_controller.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../../models/weather_time.dart';
import '../plancast_controller.dart';
import '../screens/plancast_time_format.dart';
import 'plancast_location_controls.dart';

/// A row inside the Today card or an agenda card. Source event data is unchanged.
class PlanCastEventTile extends StatelessWidget {
  const PlanCastEventTile(
      {super.key, required this.item, this.compact = false, this.day});
  final PlanCastEventWeather item;
  final bool compact;
  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanCastController?>();
    final now = c?.clock() ?? DateTime.now();
    final selectedDay = day ?? now.toLocal();
    final segment = _segmentForDay(item, selectedDay);
    final segmented = item.assessment.segments.isNotEmpty;
    final weather = segmented ? segment?.assessment : item.assessment;
    final calendar = c?.calendars
        .where((cal) => cal.id == item.event.calendarId)
        .firstOrNull;
    final color = calendar?.colorArgb == null
        ? context.dmColors.insightIcon
        : Color(calendar!.colorArgb!);
    final localNow = now.toLocal();
    final civilToday =
        DateTime.utc(localNow.year, localNow.month, localNow.day);
    final ongoing = item.event.isAllDay
        ? item.event.allDayStart!.isBefore(civilToday) &&
            item.event.allDayEnd!.isAfter(civilToday)
        : item.event.startUtc.isBefore(now) && item.event.endUtc.isAfter(now);
    final caption = _locationCaption(item);
    final weatherView = weather != null && weather.usable && !item.isOnline
        ? _InlineWeather(
            item: item,
            assessment: weather,
            instant: segment?.startUtc ?? item.event.startUtc,
            dayLabel: compact && segmented
                ? '${planCastDate(context, selectedDay, now: now.toLocal())} outlook'
                : null,
            compact: compact)
        : null;
    return Semantics(
      container: true,
      button: true,
      label:
          '${item.event.displayTitle}${calendar == null ? '' : ', calendar ${calendar.name}'}',
      child: InkWell(
        onTap: () => openPlanCastEvent(context, item),
        borderRadius: BorderRadius.circular(DMSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: compact ? DMSpacing.xs : DMSpacing.xxs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CategoryIcon(item: item, size: compact ? 34 : 42),
              const SizedBox(width: DMSpacing.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!compact && calendar != null) ...[
                            Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle))),
                            const SizedBox(width: DMSpacing.xxs),
                          ],
                          Expanded(
                              child: Text(item.event.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: (compact
                                      ? DMTypography.labelLarge
                                      : DMTypography.title))),
                          const SizedBox(width: DMSpacing.xxs),
                          Icon(Icons.chevron_right,
                              size: 20, color: context.dmColors.textSecondary),
                        ]),
                    const SizedBox(height: DMSpacing.xxs),
                    Text(
                        '${ongoing ? 'Ongoing · ' : ''}${planCastEventTime(context, item.event, now: now)}',
                        style: DMTypography.bodySmall
                            .copyWith(color: context.dmColors.textSecondary)),
                    const SizedBox(height: DMSpacing.xxs),
                    LayoutBuilder(builder: (context, constraints) {
                      final place =
                          Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            item.isOnline
                                ? Icons.videocam_outlined
                                : Icons.place_outlined,
                            size: 14,
                            color: context.dmColors.textSecondary),
                        const SizedBox(width: DMSpacing.xxs),
                        Flexible(
                            child: Text(caption,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: DMTypography.bodySmall.copyWith(
                                    color: context.dmColors.textSecondary))),
                      ]);
                      if (weatherView == null) return place;
                      if (constraints.maxWidth < 200 ||
                          MediaQuery.textScalerOf(context).scale(13) > 18) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [place, weatherView]);
                      }
                      return Row(children: [
                        Expanded(child: place),
                        const SizedBox(width: DMSpacing.xs),
                        weatherView
                      ]);
                    }),
                    if (!compact && !item.isOnline) ...[
                      const SizedBox(height: DMSpacing.xs),
                      Text(
                          segmented && segment == null
                              ? 'No forecast for this day yet.'
                              : '${segment == null ? '' : '${segment.label} · '}${_weatherLine(weather!, localFlight: _isFlight(item) && item.automaticLocation)}',
                          style: DMTypography.bodySmall
                              .copyWith(color: context.dmColors.textSecondary)),
                    ],
                    if (item.event.tentative)
                      const Text('Tentative invitation',
                          style: DMTypography.bodySmall),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }
}

String _locationCaption(PlanCastEventWeather item) {
  if (item.isOnline) return 'Online · No venue weather needed';
  final location = item.resolvedLocation;
  if (location == null || !location.hasWeatherBasis) {
    return item.needsLocation
        ? 'Location needs review'
        : 'Weather location unavailable';
  }
  final source = switch (location.source) {
    LocationSource.currentArea => 'Your area',
    LocationSource.lastKnownArea => 'Last known area',
    LocationSource.defaultArea => 'Default area',
    LocationSource.inferredCity => 'From invite',
    LocationSource.calendarCoordinates => 'From invite',
    _ => location.sourceLabel,
  };
  final area = {LocationPrecision.city, LocationPrecision.area}
          .contains(location.precision)
      ? location.candidate?.name
      : null;
  if (_isFlight(item) && location.areaAssumed) {
    return '${area == null ? '' : '$area · '}Local area forecast';
  }
  return area == null || area.isEmpty ? source : '$area · $source';
}

bool _isFlight(PlanCastEventWeather item) =>
    RegExp(r'\b(flight|airport|boarding)\b', caseSensitive: false)
        .hasMatch(item.event.title);

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.item, this.size = 44});
  final PlanCastEventWeather item;
  final double size;
  @override
  Widget build(BuildContext context) {
    final title = item.event.title.toLowerCase();
    final colors = context.dmColors;
    final (icon, background) = item.isOnline
        ? (Icons.computer_outlined, colors.surfaceSecondary)
        : item.assessment.segments.isNotEmpty ||
                RegExp(r'\b(hotel|check-in|check-out|resort|motel|lodging)\b')
                    .hasMatch(title)
            ? (Icons.hotel_outlined, colors.karenSurface)
            : _isFlight(item)
                ? (Icons.flight, colors.surfaceSecondary)
                : RegExp(r'\b(lunch|dinner|breakfast|restaurant)\b')
                        .hasMatch(title)
                    ? (Icons.restaurant, colors.karenSurface)
                    : RegExp(r'\b(workout|gym|run|running|walk|yoga|training)\b')
                            .hasMatch(title)
                        ? (Icons.fitness_center, colors.templateStorm)
                        : (Icons.event_outlined, colors.surfaceSecondary);
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: size * .55, color: colors.link));
  }
}

EventWeatherSegment? _segmentForDay(PlanCastEventWeather item, DateTime day) {
  final civil = DateTime.utc(day.year, day.month, day.day);
  EventWeatherSegment? firstMatch;
  for (final segment in item.assessment.segments) {
    final start = _localSegmentTime(item, segment.startUtc);
    final end = _localSegmentTime(item, segment.endUtc);
    final first = DateTime.utc(start.year, start.month, start.day);
    final last = DateTime.utc(end.year, end.month, end.day);
    if (!civil.isBefore(first) &&
        (civil.isBefore(last) || civil == last && !_midnight(end))) {
      if (segment.assessment.usable) return segment;
      firstMatch ??= segment;
    }
  }
  return firstMatch;
}

bool _hasCondition(EventWeatherAssessment value) =>
    value.usable &&
    (value.weatherIcon?.isNotEmpty == true ||
        !{'', 'unknown', 'unavailable'}
            .contains(value.condition.trim().toLowerCase()));

Widget _weatherIcon(PlanCastEventWeather item,
        EventWeatherAssessment assessment, DateTime instant, double size) =>
    DaymakerWeatherIcon(
        key: ValueKey(
            'plancast-icon-${item.event.id}-${instant.millisecondsSinceEpoch}'),
        conditionDescription: assessment.condition,
        openWeatherIconCode: assessment.weatherIcon,
        forecastTime: instant,
        forecastLocalTime: weatherLocalTime(
            instant, item.venueTimeZone, item.venueTimeZoneOffset,
            forecast: true),
        latitude: item.venue?.lat,
        longitude: item.venue?.lon,
        size: size,
        semanticLabel: assessment.condition);

String _temperature(BuildContext context, double celsius,
    {bool unitLabel = false}) {
  final unit = context.watch<SettingsController?>()?.temperatureUnit ??
      TemperatureUnit.fahrenheit;
  final degrees =
      (unit == TemperatureUnit.celsius ? celsius : celsius * 9 / 5 + 32)
          .round();
  return '$degrees°${unitLabel ? unit.suffix : ''}';
}

String? planCastTemperatureRange(
    BuildContext context, EventWeatherAssessment value,
    {bool unitLabel = false}) {
  final low = value.minTemperatureC?.isFinite == true
      ? _temperature(context, value.minTemperatureC!, unitLabel: unitLabel)
      : null;
  final high = value.maxTemperatureC?.isFinite == true
      ? _temperature(context, value.maxTemperatureC!, unitLabel: unitLabel)
      : null;
  if (low == null) return high;
  if (high == null || low == high) return low;
  return '$low–$high';
}

String _weatherLine(EventWeatherAssessment value, {bool localFlight = false}) {
  if (!value.usable) {
    return switch (value.coverage) {
      ForecastCoverage.loading => 'Forecast loading…',
      ForecastCoverage.deferred => 'Forecast queued for a later refresh.',
      ForecastCoverage.stale => 'Forecast needs an update.',
      ForecastCoverage.tooEarly => 'Outside the available forecast.',
      ForecastCoverage.needsLocation => 'Choose a weather area in details.',
      ForecastCoverage.online => 'Online · No venue weather needed',
      _ => 'Forecast currently unavailable.',
    };
  }
  if (value.alerts.isNotEmpty) return value.alerts.first.event;
  if (value.serious) return 'Weather disruption possible. Review details.';
  final condition = {'', 'unknown', 'unavailable'}
          .contains(value.condition.trim().toLowerCase())
      ? null
      : value.condition;
  final context = value.isDaily
      ? 'Day outlook'
      : value.coverage == ForecastCoverage.partial
          ? 'Partial forecast'
          : localFlight
              ? 'Local weather'
              : 'Event forecast';
  return condition == null ? '$context available.' : '$context · $condition';
}

class _InlineWeather extends StatelessWidget {
  const _InlineWeather(
      {required this.item,
      required this.assessment,
      required this.instant,
      this.compact = false,
      this.dayLabel});
  final PlanCastEventWeather item;
  final EventWeatherAssessment assessment;
  final DateTime instant;
  final bool compact;
  final String? dayLabel;
  @override
  Widget build(BuildContext context) {
    final temperature = planCastTemperatureRange(context, assessment);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (dayLabel != null) Text(dayLabel!, style: DMTypography.bodySmall),
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (_hasCondition(assessment))
          _weatherIcon(item, assessment, instant, compact ? 28 : 32),
        if (temperature != null) ...[
          const SizedBox(width: DMSpacing.xxs),
          Text(temperature, style: DMTypography.labelLarge),
        ],
      ]),
    ]);
  }
}

String planCastWeatherValues(
    BuildContext context, EventWeatherAssessment value) {
  final unit = context.watch<SettingsController?>()?.temperatureUnit ??
      TemperatureUnit.fahrenheit;
  final temperature = planCastTemperatureRange(context, value, unitLabel: true);
  return [
    if (temperature != null) temperature,
    if (value.peakPrecipitationChance != null)
      '${value.precipitationLabel}: ${value.peakPrecipitationChance}%',
    if (value.maxWindKph?.isFinite == true)
      'Wind up to ${(unit == TemperatureUnit.celsius ? value.maxWindKph! : value.maxWindKph! / 1.609344).round()} ${unit == TemperatureUnit.celsius ? 'km/h' : 'mph'}',
  ].join(' · ');
}

Future<void> openPlanCastEvent(
        BuildContext context, PlanCastEventWeather item) =>
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _EventDetails(initial: item)));

class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.initial});
  final PlanCastEventWeather initial;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanCastController>();
    final item = c.currentEvents
        .where((e) => e.event.id == initial.event.id)
        .firstOrNull;
    if (item == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Plan changed')),
          body: const Padding(
              padding: EdgeInsets.all(DMSpacing.lg),
              child: Text(
                  'This event was removed, moved, or its calendar is no longer selected. Return to PlanCast for your latest plans.')));
    }
    final assessment = item.assessment;
    final location = item.resolvedLocation;
    final calendar =
        c.calendars.where((cal) => cal.id == item.event.calendarId).firstOrNull;
    final calendarTime = planCastEventTime(context, item.event, now: c.clock());
    final venueTime = item.venueTimeZone == null
        ? null
        : planCastEventTime(context, item.event,
            now: c.clock(), timeZone: item.venueTimeZone);
    final trip = c.tripSuggestion(item);
    final hours =
        item.isOnline ? <HourlyForecast>[] : c.cachedHoursForEvent(item);
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(DMSpacing.md), children: [
          DmGlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _CategoryIcon(item: item, size: 48),
                  const SizedBox(width: DMSpacing.sm),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.event.displayTitle,
                            style: DMTypography.headingSmall),
                        const SizedBox(height: DMSpacing.xxs),
                        Text(
                            '$calendarTime${planCastCalendarTimeDiffers(item.event) ? ' · calendar time' : ''}',
                            style: DMTypography.bodySmall),
                        if (calendar != null)
                          Text(calendar.name,
                              style: DMTypography.bodySmall.copyWith(
                                  color: context.dmColors.textSecondary)),
                      ])),
                ]),
                if (planCastCalendarTimeDiffers(item.event))
                  Padding(
                      padding: const EdgeInsets.only(top: DMSpacing.xs),
                      child: Text(
                          'Your time: ${planCastEventTime(context, item.event, now: c.clock(), deviceTime: true)}',
                          style: DMTypography.bodySmall)),
                if (!item.event.isAllDay &&
                    venueTime != null &&
                    venueTime != calendarTime)
                  Text(
                      '${location?.venueConfirmed == true ? 'Venue time' : 'Area time'}: $venueTime',
                      style: DMTypography.bodySmall),
                const SizedBox(height: DMSpacing.sm),
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: context.dmColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: DMSpacing.sm),
                        child: PlanCastLocationRow(item: item))),
              ])),
          const SizedBox(height: DMSpacing.sm),
          if (item.isOnline)
            const DmGlassCard(child: Text('Online · No venue weather needed'))
          else if (assessment.segments.isEmpty) ...[
            _WeatherPanel(
                item: item,
                assessment: assessment,
                instant: item.event.startUtc,
                heading: _isFlight(item) && location?.areaAssumed == true
                    ? 'Local area forecast'
                    : null),
            if (hours.isNotEmpty) ...[
              const SizedBox(height: DMSpacing.sm),
              _HourStrip(item: item, hours: hours),
            ],
            if (assessment.usable && assessment.advice.trim().isNotEmpty) ...[
              const SizedBox(height: DMSpacing.sm),
              DmGlassCard(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Icon(Icons.info_outline,
                        color: context.dmColors.insightIcon, size: 22),
                    const SizedBox(width: DMSpacing.sm),
                    Expanded(child: Text(assessment.advice)),
                  ])),
            ],
          ] else ...[
            const Text('Weather through your stay',
                style: DMTypography.headingSmall),
            for (final segment in assessment.segments) ...[
              const SizedBox(height: DMSpacing.sm),
              _WeatherPanel(
                  item: item,
                  assessment: segment.assessment,
                  instant: segment.startUtc,
                  heading: segment.label,
                  date: _segmentTime(context, segment, item)),
            ],
          ],
          for (final alert in assessment.alerts) ...[
            const SizedBox(height: DMSpacing.sm),
            _AlertCard(alert: alert),
          ],
          if (!item.isOnline) ...[
            const SizedBox(height: DMSpacing.sm),
            const Text('Weather data © OpenWeather',
                style: DMTypography.bodySmall),
          ],
          if (trip != null)
            TextButton.icon(
                icon: const Icon(Icons.luggage_outlined),
                label: const Text(
                    'Use this trip area for other plans during these dates'),
                onPressed: () => reviewPlanCastBatch(context, c, trip,
                    start: item.event.startUtc,
                    end: item.event.endUtc,
                    calendarIds: {item.event.calendarId})),
          const SizedBox(height: DMSpacing.sm),
          DmGlassCard(
              child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    key: ValueKey('plancast-more-${item.event.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text('More details',
                        style: DMTypography.labelLarge),
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.event.locationText.trim().isNotEmpty)
                                  Text(
                                      'Invite location: ${item.event.locationText}'),
                                if (location != null) ...[
                                  Text(location.reason),
                                  if (location.areaAssumed)
                                    const Text(
                                        'This is an area forecast, not a confirmed venue.'),
                                  if (location.observedAt != null)
                                    Text(
                                        'Area observed ${planCastTimestamp(context, location.observedAt!)}'),
                                  Text(
                                      'Location resolved ${planCastTimestamp(context, location.resolvedAt)}'),
                                  Text('Location source: ${location.provider}'),
                                ],
                                if (!item.event.isAllDay)
                                  Text(
                                      'Calendar timezone: ${item.event.timeZone}. Appointment times remain unchanged.'),
                                if (assessment.forecastUpdatedAt != null)
                                  Text(
                                      'Forecast updated ${planCastTimestamp(context, assessment.forecastUpdatedAt!)}'),
                                if (assessment.explanation.isNotEmpty)
                                  Text(assessment.explanation),
                                for (final issue in assessment.uncertainties)
                                  Text(issue),
                                if (!item.isOnline) ...[
                                  Text(
                                      'Planning buffers: ${c.preferences.bufferMinutes} minutes before and after. These are not calculated travel times.'),
                                  if (assessment.arrival != null)
                                    Text(
                                        'Arrival buffer: ${assessment.arrival!.explanation}'),
                                  if (assessment.leaving != null)
                                    Text(
                                        'Leaving buffer: ${assessment.leaving!.explanation}'),
                                  Wrap(spacing: DMSpacing.xs, children: [
                                    for (final environment in [
                                      EventEnvironment.unknown,
                                      EventEnvironment.indoor,
                                      EventEnvironment.outdoor
                                    ])
                                      ChoiceChip(
                                          label: Text(switch (environment) {
                                            EventEnvironment.indoor => 'Indoor',
                                            EventEnvironment.outdoor =>
                                              'Outdoor',
                                            _ => 'Not specified'
                                          }),
                                          selected:
                                              item.environment == environment,
                                          onSelected: (_) => c.setEventOverride(
                                              item.event,
                                              environment: environment)),
                                  ]),
                                ],
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Event heads-ups'),
                                    subtitle: const Text(
                                        'Requires notification permission and respects your quiet hours.'),
                                    value: item.remindersEnabled,
                                    onChanged: (value) => c.setEventOverride(
                                        item.event,
                                        remindersEnabled: value)),
                                const Text(
                                    'Corrections belong to PlanCast. Your source calendar is never edited.',
                                    style: DMTypography.bodySmall),
                              ])),
                    ],
                  ))),
          if (c.canUndoLocationChange)
            TextButton.icon(
                onPressed: c.undoLocationChange,
                icon: const Icon(Icons.undo),
                label: const Text('Undo location change')),
        ]),
      ))),
    );
  }
}

class _WeatherPanel extends StatelessWidget {
  const _WeatherPanel(
      {required this.item,
      required this.assessment,
      required this.instant,
      this.heading,
      this.date});
  final PlanCastEventWeather item;
  final EventWeatherAssessment assessment;
  final DateTime instant;
  final String? heading, date;
  @override
  Widget build(BuildContext context) {
    final temperature = assessment.usable
        ? planCastTemperatureRange(context, assessment, unitLabel: true)
        : null;
    final hasCondition = _hasCondition(assessment);
    final unit = context.watch<SettingsController?>()?.temperatureUnit ??
        TemperatureUnit.fahrenheit;
    return DmGlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (heading != null) Text(heading!, style: DMTypography.labelLarge),
      if (date != null) Text(date!, style: DMTypography.bodySmall),
      if (heading != null || date != null) const SizedBox(height: DMSpacing.sm),
      if (!assessment.usable)
        Text(_weatherLine(assessment))
      else ...[
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (hasCondition) ...[
            _weatherIcon(item, assessment, instant, 72),
            const SizedBox(width: DMSpacing.md)
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (temperature != null)
                  Text(temperature, style: DMTypography.numeral),
                if (hasCondition &&
                    assessment.condition.toLowerCase() != 'unknown')
                  Text(assessment.condition, style: DMTypography.labelLarge),
                if (assessment.isDaily)
                  const Text('Day outlook · event hours unavailable',
                      style: DMTypography.bodySmall)
                else if (assessment.coverage == ForecastCoverage.partial)
                  const Text('Partial event coverage',
                      style: DMTypography.bodySmall),
              ])),
        ]),
        const SizedBox(height: DMSpacing.sm),
        Wrap(spacing: DMSpacing.md, runSpacing: DMSpacing.xs, children: [
          if (assessment.peakPrecipitationChance != null)
            _Metric(
                icon: Icons.water_drop_outlined,
                label: '${assessment.peakPrecipitationChance}% precip.',
                semantics:
                    '${assessment.precipitationLabel}: ${assessment.peakPrecipitationChance}%'),
          if (assessment.maxWindKph?.isFinite == true)
            _Metric(
                icon: Icons.air,
                label:
                    '${(unit == TemperatureUnit.celsius ? assessment.maxWindKph! : assessment.maxWindKph! / 1.609344).round()} ${unit == TemperatureUnit.celsius ? 'km/h' : 'mph'} wind'),
        ]),
      ],
    ]));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, this.semantics});
  final IconData icon;
  final String label;
  final String? semantics;
  @override
  Widget build(BuildContext context) => Semantics(
      label: semantics,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: context.dmColors.textSecondary),
        const SizedBox(width: DMSpacing.xxs),
        Text(label, style: DMTypography.bodySmall),
      ]));
}

class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.item, required this.hours});
  final PlanCastEventWeather item;
  final List<HourlyForecast> hours;
  DateTime _local(DateTime instant) =>
      weatherLocalTime(instant, item.venueTimeZone, item.venueTimeZoneOffset) ??
      instant.toLocal();
  bool get _crossesDay {
    final first = _local(hours.first.time), last = _local(hours.last.time);
    return first.year != last.year ||
        first.month != last.month ||
        first.day != last.day;
  }

  @override
  Widget build(BuildContext context) => DmGlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'Hourly forecast${item.resolvedLocation?.areaAssumed == true ? ' · area weather' : ''}',
            style: DMTypography.labelLarge),
        const SizedBox(height: DMSpacing.sm),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final hour in hours)
                Padding(
                    padding: const EdgeInsets.only(right: DMSpacing.xs),
                    child: Container(
                      width:
                          78 * MediaQuery.textScalerOf(context).scale(13) / 13,
                      padding: const EdgeInsets.all(DMSpacing.xs),
                      decoration: BoxDecoration(
                          color: context.dmColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.dmColors.border)),
                      child: Column(children: [
                        if (_crossesDay)
                          Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(_local(hour.time)),
                              style: DMTypography.bodySmall,
                              textAlign: TextAlign.center),
                        Text(
                            TimeOfDay.fromDateTime(weatherLocalTime(
                                        hour.time,
                                        item.venueTimeZone,
                                        item.venueTimeZoneOffset) ??
                                    hour.time.toLocal())
                                .format(context),
                            style: DMTypography.bodySmall),
                        const SizedBox(height: DMSpacing.xs),
                        if (!{'', 'unknown', 'unavailable'}
                                .contains(hour.condition.toLowerCase()) ||
                            hour.weatherIcon?.isNotEmpty == true)
                          DaymakerWeatherIcon(
                              key: ValueKey(
                                  'event-hour-${item.event.id}-${hour.time.millisecondsSinceEpoch}'),
                              conditionDescription: hour.condition,
                              openWeatherIconCode: hour.weatherIcon,
                              forecastTime: hour.time,
                              forecastLocalTime: weatherLocalTime(hour.time,
                                  item.venueTimeZone, item.venueTimeZoneOffset,
                                  forecast: true),
                              latitude: item.venue?.lat,
                              longitude: item.venue?.lon,
                              size: 32),
                        if (hour.temperatureKnown && hour.temperatureC.isFinite)
                          Text(_temperature(context, hour.temperatureC),
                              style: DMTypography.labelLarge),
                        if (hour.precipitationChanceKnown)
                          Text('${hour.precipitationChance}%',
                              style: DMTypography.bodySmall),
                      ]),
                    )),
            ])),
      ]));
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final WeatherAlert alert;
  @override
  Widget build(BuildContext context) => DmGlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(alert.event, style: DMTypography.title),
        Text(alert.senderName, style: DMTypography.bodySmall),
        if (alert.start != null)
          Text('Valid from ${planCastTimestamp(context, alert.start!)}',
              style: DMTypography.bodySmall),
        if (alert.end != null)
          Text('Until ${planCastTimestamp(context, alert.end!)}',
              style: DMTypography.bodySmall),
        Text(alert.description),
        if (alert.instructions?.trim().isNotEmpty == true)
          Text(alert.instructions!),
      ]));
}

DateTime _localSegmentTime(PlanCastEventWeather item, DateTime instant) => item
        .event.isAllDay
    ? instant
    : weatherLocalTime(instant, item.venueTimeZone, item.venueTimeZoneOffset) ??
        instant.toLocal();
bool _midnight(DateTime time) =>
    time.hour == 0 &&
    time.minute == 0 &&
    time.second == 0 &&
    time.millisecond == 0 &&
    time.microsecond == 0;

String _segmentTime(BuildContext context, EventWeatherSegment segment,
    PlanCastEventWeather item) {
  final start = _localSegmentTime(item, segment.startUtc);
  final end = _localSegmentTime(item, segment.endUtc);
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(start);
  if (segment.assessment.isDaily) return '$date · Day outlook';
  final startDate = DateTime.utc(start.year, start.month, start.day);
  final endDate = DateTime.utc(end.year, end.month, end.day);
  final endsNextDay =
      endDate == DateTime.utc(start.year, start.month, start.day + 1);
  if (_midnight(start) && _midnight(end) && endsNextDay) {
    return '$date · Full day';
  }
  final endLabel = _midnight(end) && endsNextDay
      ? 'midnight'
      : '${endDate != startDate ? '${localizations.formatMediumDate(end)} · ' : ''}${TimeOfDay.fromDateTime(end).format(context)}';
  return '$date · ${TimeOfDay.fromDateTime(start).format(context)}–$endLabel';
}
