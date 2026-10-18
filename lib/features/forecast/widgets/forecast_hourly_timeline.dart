import '../../guidance/forecast_guidance.dart';
import '../../guidance/domain/guidance.dart';
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
import '../models/hourly_timeline.dart';
import 'forecast_temperature.dart';

/// The draggable sheet owns scrolling; this timeline only builds visible rows.
class ForecastHourlyTimeline extends StatefulWidget {
  const ForecastHourlyTimeline({
    super.key,
    required this.scrollController,
    required this.hourly,
    this.weather,
    this.timezone,
    this.timezoneOffset,
    this.clock,
  });

  final ScrollController scrollController;
  final List<HourlyForecast> hourly;
  final WeatherBundle? weather;
  final String? timezone;
  final int? timezoneOffset;
  final DateTime Function()? clock;

  @override
  State<ForecastHourlyTimeline> createState() => _ForecastHourlyTimelineState();
}

class _ForecastHourlyTimelineState extends State<ForecastHourlyTimeline>
    with WidgetsBindingObserver {
  SettingsController? _settings;
  Timer? _freshnessTimer;
  List<HourlyForecast> _hours = [];
  List<_TimelineEntry> _entries = [];
  final Set<DateTime> _tipHours = {};
  late DateTime _now;
  TemperatureUnit _unit = TemperatureUnit.fahrenheit;

  DateTime get _clock => (widget.clock ?? DateTime.now)();
  WeatherBundle? get _weather => widget.weather;
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
    final settings = context.read<SettingsController?>();
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
    _hours = forecastTimelineHours(_weather?.hourly ?? widget.hourly, _now);
    _entries = [];
    _tipHours.clear();
    HourlyForecast? previous;
    DateTime? lastTip;
    for (final hour in _hours) {
      final changed = previous == null ||
          hour.weatherId != previous.weatherId ||
          hour.precipitationChance ~/ 30 != previous.precipitationChance ~/ 30;
      if (changed &&
          _tipHours.length < 4 &&
          (lastTip == null ||
              hour.time.difference(lastTip) >= const Duration(hours: 3))) {
        _tipHours.add(hour.time);
        lastTip = hour.time;
      }
      previous = hour;
    }
    String? previousDate;
    for (final hour in _hours) {
      final date = forecastDateKey(hour.time, _timezone, _offset);
      if (date != previousDate) {
        _entries.add(_TimelineEntry.date(hour.time));
        previousDate = date;
      }
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

  @override
  void dispose() {
    _freshnessTimer?.cancel();
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
        : weather != null && weatherNeedsAttention(weather, _now)
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
            guidance: weather != null && _tipHours.contains(hour.time)
                ? ForecastGuidanceView(
                    weather: weather,
                    surface: GuidanceSurface.hourlyDetail,
                    hour: hour.time,
                    clock: widget.clock)
                : null,
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
  const _TimelineEntry.hour(this.hour) : date = null;
  const _TimelineEntry.date(this.date) : hour = null;
  final HourlyForecast? hour;
  final DateTime? date;
}

class _HourlyDetailRow extends StatelessWidget {
  const _HourlyDetailRow(
      {super.key,
      required this.hour,
      this.guidance,
      required this.label,
      required this.current,
      required this.unit,
      this.offsetLabel,
      this.localTime,
      this.latitude,
      this.longitude});
  final HourlyForecast hour;
  final Widget? guidance;
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
    final severe = weatherConditionsNeedAttention(
      code: hour.weatherId,
      tempF: hour.temperatureKnown && hour.temperatureC.isFinite
          ? hour.temperatureF.round()
          : null,
    );
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
        if (guidance != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: guidance),
      ]),
    );
  }
}
