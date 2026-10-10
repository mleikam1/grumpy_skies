import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_theme.dart';
import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../models/weather_safety.dart';
import '../../../services/settings_controller.dart';
import '../../../shared/widgets/active_viewport.dart';
import '../../../shared/widgets/daymaker_weather_icon.dart';
import '../../../shared/widgets/dm_approved_components.dart';
import '../../roasts/controllers/local_roast_controller.dart';
import '../../roasts/content/roast_context_adapter.dart';
import '../../roasts/content/weather_roast_models.dart';
import '../../roasts/models/roast_persona.dart';
import '../models/hourly_timeline.dart';
import 'forecast_temperature.dart';

/// The draggable sheet owns scrolling; this timeline only builds visible rows.
class ForecastHourlyTimeline extends StatefulWidget {
  const ForecastHourlyTimeline({
    super.key,
    required this.scrollController,
    required this.hourly,
    this.weather,
    this.roasts,
    this.personaId,
    this.timezone,
    this.timezoneOffset,
    this.clock,
  });

  final ScrollController scrollController;
  final List<HourlyForecast> hourly;
  final WeatherBundle? weather;
  final LocalRoastController? roasts;
  final String? personaId;
  final String? timezone;
  final int? timezoneOffset;
  final DateTime Function()? clock;

  @override
  State<ForecastHourlyTimeline> createState() => _ForecastHourlyTimelineState();
}

class _ForecastHourlyTimelineState extends State<ForecastHourlyTimeline>
    with WidgetsBindingObserver {
  LocalRoastController? _roasts;
  SettingsController? _settings;
  Timer? _freshnessTimer;
  List<HourlyForecast> _hours = [];
  List<HourlyTimelineRoast> _jokes = [];
  List<_TimelineEntry> _entries = [];
  final _seen = <String>{};
  late DateTime _now;
  TemperatureUnit _unit = TemperatureUnit.fahrenheit;
  String _persona = RoastPersonas.defaultPersona.id;

  DateTime get _clock => (widget.clock ?? DateTime.now)();
  WeatherBundle? get _weather => _roasts?.weather ?? widget.weather;
  String? get _timezone => _weather?.current.timezone ?? widget.timezone;
  int? get _offset => _weather?.current.timezoneOffset ?? widget.timezoneOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roasts = widget.roasts ?? context.read<LocalRoastController?>();
    final settings = context.read<SettingsController?>();
    if (!identical(_roasts, roasts)) {
      _roasts?.removeListener(_changed);
      _roasts = roasts;
      _roasts?.addListener(_changed);
    }
    if (!identical(_settings, settings)) {
      _settings?.removeListener(_changed);
      _settings = settings;
      _settings?.addListener(_changed);
    }
    _prepare();
  }

  @override
  void didUpdateWidget(ForecastHourlyTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepare();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _changed();
  }

  void _changed() {
    if (!mounted) return;
    setState(_prepare);
  }

  void _prepare() {
    _now = _clock;
    _unit = _settings?.temperatureUnit ?? TemperatureUnit.fahrenheit;
    _persona = _settings?.selectedPersonaId ??
        widget.personaId ??
        RoastPersonas.defaultPersona.id;
    _hours = forecastTimelineHours(_weather?.hourly ?? widget.hourly, _now);
    _jokes = _roasts?.selectHourlyTimeline(
          persona: _persona,
          hours: _hours,
          bundle: _weather,
          now: _now,
          unit: _unit,
        ) ??
        const [];
    final jokesByTime = {
      for (final joke in _jokes)
        joke.targetTime.toUtc().millisecondsSinceEpoch: joke
    };
    _entries = [];
    String? previousDate;
    for (final hour in _hours) {
      final date = forecastDateKey(hour.time, _timezone, _offset);
      if (date != previousDate) {
        _entries.add(_TimelineEntry.date(hour.time));
        previousDate = date;
      }
      final joke = jokesByTime[hour.time.toUtc().millisecondsSinceEpoch];
      if (joke != null) _entries.add(_TimelineEntry.roast(joke));
      _entries.add(_TimelineEntry.hour(hour));
    }
  }

  void _activityChanged(bool active) {
    _freshnessTimer?.cancel();
    if (active) {
      _changed();
      _freshnessTimer =
          Timer.periodic(const Duration(minutes: 1), (_) => _changed());
    }
  }

  void _expose(HourlyTimelineRoast joke, bool active) {
    if (!active || _roasts == null) return;
    final selection = joke.selection;
    final key =
        selection.selectionId ?? '${joke.targetTime.toUtc()}:${selection.id}';
    if (_seen.contains(key)) return;
    if (!_roasts!.isSelectionEligible(selection,
        bundle: _weather, now: _clock, unit: _unit)) {
      _changed();
      return;
    }
    _seen.add(key);
    _roasts!.commitDisplayed(selection);
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    _roasts?.removeListener(_changed);
    _settings?.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    final safety = weather == null ? null : weatherSafetyStatus(weather, _now);
    final alerts =
        weather?.alerts.where((alert) => alert.isRelevantAt(_now)).toList() ??
            const <WeatherAlert>[];
    final safetyMessage = safety == WeatherSafetyStatus.activeAlert
        ? '${alerts.map((alert) => alert.event).join(' · ')}. Read the official alert details on Today and follow local guidance.'
        : weather != null &&
                WeatherRoastContext.fromWeatherBundle(weather, now: _now)
                    .requiresSafetyMessage
            ? 'Weather conditions need attention. Check the weather details and available official alerts.'
            : null;
    return ActiveViewport(
      onActiveChanged: _activityChanged,
      child: ListView.builder(
        key: const ValueKey('hourly-timeline-list'),
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
        itemCount: _entries.length + (safetyMessage == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (safetyMessage != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(liveRegion: true, child: Text(safetyMessage)),
            );
          }
          final entry = _entries[index - (safetyMessage == null ? 0 : 1)];
          if (entry.date != null) {
            return Padding(
              key: ValueKey(
                  'hourly-date-${entry.date!.toUtc().millisecondsSinceEpoch}'),
              padding: const EdgeInsets.only(top: 16, bottom: 5),
              child: Text(forecastDateLabel(entry.date!, _timezone, _offset),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.dmColors.textSecondary)),
            );
          }
          final joke = entry.joke;
          if (joke != null) {
            return ActiveViewport(
              key: ValueKey(
                  'hourly-roast-${joke.targetTime.toUtc().millisecondsSinceEpoch}-${joke.selection.selectionId ?? joke.selection.id}'),
              minimumVisibleFraction: .5,
              onActiveChanged: (active) => _expose(joke, active),
              child: _HourlyRoastCard(
                  joke: joke,
                  timeLabel:
                      forecastHourLabel(joke.targetTime, _timezone, _offset)),
            );
          }
          final hour = entry.hour!;
          final label = forecastHourLabel(hour.time, _timezone, _offset);
          final repeated = _hours
                  .where((other) =>
                      forecastDateKey(other.time, _timezone, _offset) ==
                          forecastDateKey(hour.time, _timezone, _offset) &&
                      forecastHourLabel(other.time, _timezone, _offset) ==
                          label)
                  .length >
              1;
          return _HourlyDetailRow(
            key: ValueKey(
                'hourly-row-${hour.time.toUtc().millisecondsSinceEpoch}'),
            hour: hour,
            current: forecastIsCurrentHour(hour.time, _now),
            label: label,
            offsetLabel: repeated
                ? forecastUtcOffset(hour.time, _timezone, _offset)
                : null,
            localTime: _timezone == null && _offset == null
                ? null
                : forecastLocalTime(hour.time, _timezone, _offset),
            unit: _unit,
            latitude: weather?.current.latitude,
            longitude: weather?.current.longitude,
          );
        },
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry.hour(this.hour)
      : date = null,
        joke = null;
  const _TimelineEntry.date(this.date)
      : hour = null,
        joke = null;
  const _TimelineEntry.roast(this.joke)
      : hour = null,
        date = null;
  final HourlyForecast? hour;
  final DateTime? date;
  final HourlyTimelineRoast? joke;
}

class _HourlyDetailRow extends StatelessWidget {
  const _HourlyDetailRow(
      {super.key,
      required this.hour,
      required this.label,
      required this.current,
      required this.unit,
      this.offsetLabel,
      this.localTime,
      this.latitude,
      this.longitude});
  final HourlyForecast hour;
  final String label;
  final bool current;
  final TemperatureUnit unit;
  final String? offsetLabel;
  final DateTime? localTime;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final colors = context.dmColors;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final temperature = hour.temperatureKnown && hour.temperatureC.isFinite
        ? forecastTemperature(hour.temperatureC, unit)
        : '—';
    final severe = roastWeatherTags(
      code: hour.weatherId,
      tempF: hour.temperatureKnown && hour.temperatureC.isFinite
          ? hour.temperatureF.round()
          : null,
    ).contains(WeatherRoastTag.severe);
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(hour.condition.isEmpty ? 'Condition unavailable' : hour.condition,
          style: TextStyle(
              fontSize: 13, height: 1.35, color: colors.textSecondary)),
      if (severe)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'Conditions need attention. Check available official alerts.',
                style: TextStyle(
                    fontSize: 12, height: 1.35, color: colors.textPrimary))),
      if (hour.precipitationChanceKnown &&
          hour.precipitationChance >= 0 &&
          hour.precipitationChance <= 100)
        Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('${hour.precipitationChance}% precipitation chance',
                style:
                    TextStyle(fontSize: 11, height: 1.35, color: colors.link))),
    ]);
    return Container(
      decoration: BoxDecoration(
        color: current ? colors.surfaceSecondary : null,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
              width: largeText ? 94 : 64,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    if (current)
                      Text('Now',
                          style: TextStyle(fontSize: 11, color: colors.link)),
                    if (offsetLabel != null)
                      Text(offsetLabel!,
                          style: TextStyle(
                              fontSize: 10, color: colors.textSecondary)),
                  ])),
          DaymakerWeatherIcon(
              conditionId: hour.weatherId,
              openWeatherIconCode: hour.weatherIcon,
              conditionMain: hour.weatherMain,
              conditionDescription: hour.condition,
              forecastTime: hour.time,
              forecastLocalTime: localTime,
              latitude: latitude,
              longitude: longitude,
              size: 42,
              semanticLabel: hour.condition),
          const SizedBox(width: 10),
          Expanded(child: largeText ? const SizedBox.shrink() : details),
          const SizedBox(width: 8),
          Text(temperature,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
        if (largeText)
          Padding(padding: const EdgeInsets.only(top: 8), child: details),
      ]),
    );
  }
}

class _HourlyRoastCard extends StatelessWidget {
  const _HourlyRoastCard({required this.joke, required this.timeLabel});
  final HourlyTimelineRoast joke;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final selection = joke.selection;
    final colors = context.dmColors;
    final name = RoastPersonas.byId(selection.persona).displayName;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DmPersonaPortrait(
            personaId: selection.persona,
            mood: selection.mood,
            width: 38,
            height: 42,
            cacheHeight: (42 * MediaQuery.devicePixelRatioOf(context)).ceil(),
            filterQuality: FilterQuality.medium),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$name’s take · $timeLabel',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary)),
          const SizedBox(height: 4),
          Text(selection.renderedText,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}
