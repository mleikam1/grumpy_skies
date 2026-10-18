import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../design/dm_theme.dart';
import '../../../models/guidance_preferences.dart';
import '../../../models/temperature_unit.dart';
import '../../../services/settings_controller.dart';
import '../../../shared/widgets/active_viewport.dart';
import '../domain/guidance.dart';
import '../guidance_controller.dart';

/// One optional local selection. Visibility, not build(), records impressions.
class GuidanceView extends StatefulWidget {
  const GuidanceView(
      {super.key,
      required this.weather,
      required this.context,
      this.compact = true,
      this.fallback,
      this.heading,
      this.scopeKey,
      this.clock});
  final WeatherEvidence weather;
  final GuidanceContext context;
  final bool compact;
  final Widget? fallback;
  final String? heading, scopeKey;
  final DateTime Function()? clock;
  @override
  State<GuidanceView> createState() => _GuidanceViewState();
}

class _GuidanceViewState extends State<GuidanceView>
    with WidgetsBindingObserver {
  Timer? _boundary;
  bool _active = false;
  GuidanceController? _controller;
  GuidanceCandidate? _candidate;
  String? _scope;
  DateTime get _now => (widget.clock ?? _controller?.clock ?? DateTime.now)();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
    if (state != AppLifecycleState.resumed) {
      _boundary?.cancel();
      _boundary = null;
      unawaited(_controller?.flush());
    }
  }

  void _exposure(bool active) {
    _active = active;
    if (!active) {
      _boundary?.cancel();
      _boundary = null;
      return;
    }
    final candidate = _candidate;
    if (candidate != null && _scope != null) {
      _controller?.recordVisible(candidate, _scope!, now: _now);
    }
    if (_boundary != null) return;
    final now = _now;
    var delay =
        Duration(milliseconds: 60000 - now.millisecondsSinceEpoch % 60000);
    if (candidate != null) {
      final remaining = candidate.validUntil.difference(now);
      if (remaining > Duration.zero && remaining < delay) delay = remaining;
    }
    _boundary = Timer(delay, () {
      _boundary = null;
      if (mounted && _active) setState(() {});
    });
  }

  @override
  void dispose() {
    _boundary?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GuidanceController?>();
    _controller = controller;
    final settings = context.watch<SettingsController?>();
    final prefs = settings?.guidance ?? const GuidancePreferences();
    final result = controller?.select(
        weather: widget.weather,
        context: widget.context,
        preferences: prefs,
        scopeKey: widget.scopeKey,
        now: _now);
    if (_candidate?.validUntil != result?.validUntil) {
      _boundary?.cancel();
      _boundary = null;
    }
    _candidate = result;
    _scope = controller?.scopeFor(widget.context, widget.scopeKey, prefs);
    return ActiveViewport(
      minimumVisibleFraction: .5,
      onExposure: _exposure,
      observeParentWhenEmpty: true,
      child: result == null
          ? widget.fallback ?? const SizedBox.shrink()
          : Material(
              color: context.dmColors.insightSurface,
              borderRadius: BorderRadius.circular(widget.compact ? 12 : 20),
              child: InkWell(
                borderRadius: BorderRadius.circular(widget.compact ? 12 : 20),
                onTap: () => _showWhy(context, result,
                    settings?.temperatureUnit ?? TemperatureUnit.fahrenheit),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 12 : 16, vertical: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            result.serious
                                ? Icons.warning_amber_rounded
                                : Icons.lightbulb_outline_rounded,
                            size: 22,
                            color: context.dmColors.insightIcon),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  widget.heading ??
                                      _tipHeading(result, widget.context),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.dmColors.textSecondary)),
                              const SizedBox(height: 3),
                              Text(result.text,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600)),
                              if (result.comparisonWindow
                                  case final window?) ...[
                                const SizedBox(height: 5),
                                Text(
                                    _intervalLabel(
                                        context, window, result.location),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.dmColors.link)),
                              ],
                              if (result.location.assumed) ...[
                                const SizedBox(height: 4),
                                Text(
                                    'Using ${result.location.label} as an assumed area',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.dmColors.textSecondary)),
                              ],
                            ])),
                        const SizedBox(width: 6),
                        const Tooltip(
                            message: 'Why this tip?',
                            child: Icon(Icons.info_outline, size: 18)),
                      ]),
                ),
              ),
            ),
    );
  }

  void _showWhy(
      BuildContext context, GuidanceCandidate result, TemperatureUnit unit) {
    final controller = _controller;
    final scope = _scope;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .8,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            Expanded(
                child: Text('Why this tip?',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                tooltip: 'Close tip details',
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close)),
          ]),
          Text(_conditionalText(result, widget.context),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('${result.location.label} · ${result.location.precision}'
              '${result.location.assumed ? ' · assumed area' : ''}'),
          const SizedBox(height: 8),
          Text(result.reason),
          if (result.activity != GuidanceActivity.outdoor &&
              result.activity != GuidanceActivity.outdoorEvent)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'An optional interest helps choose this advice; it does not confirm an outing.')),
          if (result.alert case final alert?) ...[
            const Divider(height: 28),
            Text('${alert.event} · ${alert.issuer}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (alert.area != null) Text(alert.area!),
            Text(_intervalLabel(context, alert.interval, result.location)),
            Text(alert.description),
            if (alert.instructions != null) Text(alert.instructions!),
          ],
          for (final fact
              in result.supportedFacts.where((f) => f.available)) ...[
            const Divider(height: 24),
            Text(_factLabel(context, fact, unit),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(_intervalLabel(context, fact.interval, fact.location)),
            Text('${fact.provider} · ${fact.sourcePrecision}'),
            if (fact.sourceTime != null)
              Text(
                  '${fact.timestampMeaning}: ${_timeLabel(context, fact.sourceTime!, fact.location)}'),
            if (fact.fetchedAt != null)
              Text(
                  'Retrieved: ${_timeLabel(context, fact.fetchedAt!, fact.location)}'),
          ],
          const SizedBox(height: 16),
          const Text(
              'Uses already-loaded weather. Missing alert coverage is not an all-clear.'),
          if (!result.serious && controller != null && scope != null)
            TextButton(
                onPressed: () {
                  controller.dismiss(result, scope);
                  Navigator.pop(sheetContext);
                },
                child: const Text('Hide this tip for this situation')),
        ]),
      ),
    );
  }
}

String _timeLabel(
    BuildContext context, DateTime time, GuidanceLocation location) {
  final local = location.localTime(time) ?? time.toUtc();
  final locale = Localizations.localeOf(context).toString();
  return '${DateFormat.MMMd(locale).add_jm().format(local)} '
      '${location.timezone ?? 'UTC'}';
}

String _intervalLabel(BuildContext context, GuidanceInterval interval,
        GuidanceLocation location) =>
    '${_timeLabel(context, interval.start, location)} – ${_timeLabel(context, interval.end, location)}';
String _factLabel(
    BuildContext context, EvidenceField<Object> fact, TemperatureUnit unit) {
  final value = fact.value;
  final format =
      NumberFormat('0.#', Localizations.localeOf(context).toString());
  final name = switch (fact.field) {
    GuidanceField.temperatureC => 'Temperature',
    GuidanceField.lowTemperatureC => 'Low temperature',
    GuidanceField.feelsLikeC => 'Feels like',
    GuidanceField.humidityPercent => 'Humidity',
    GuidanceField.dewPointC => 'Dew point',
    GuidanceField.windKph => 'Wind',
    GuidanceField.gustKph => 'Gusts',
    GuidanceField.visibilityMeters => 'Visibility',
    GuidanceField.precipitationProbability => fact.unit.contains('day')
        ? 'Precipitation chance for this day'
        : 'Precipitation chance for this hour',
    GuidanceField.precipitationType => 'Precipitation type',
    GuidanceField.rainIntensity => 'Rain intensity',
    GuidanceField.rainMillimeters => 'Recent rain',
    GuidanceField.conditionCode => 'Provider condition code',
    GuidanceField.daylight => 'Daylight',
    GuidanceField.sunset => 'Sunset',
    GuidanceField.uvIndex => 'UV Index',
    GuidanceField.aqi => 'Air quality',
    GuidanceField.severeHazard => 'Hazard indicated',
  };
  if (value is num) {
    if (fact.field == GuidanceField.precipitationProbability) {
      return '$name: ${format.format(value * 100)}%';
    }
    if (fact.unit.startsWith('°C')) {
      final fahrenheit = unit == TemperatureUnit.fahrenheit;
      return '$name: ${format.format(fahrenheit ? value * 9 / 5 + 32 : value)}'
          '${fahrenheit ? '°F' : '°C'}${fact.unit.replaceFirst('°C', '')}';
    }
    return '$name: ${format.format(value)} ${fact.unit}';
  }
  if (value is DateTime) {
    return '$name: ${_timeLabel(context, value, fact.location)}';
  }
  final label = value is PrecipitationType
      ? switch (value) {
          PrecipitationType.liquidRain => 'liquid rain',
          PrecipitationType.freezing => 'freezing precipitation',
          _ => value.name,
        }
      : value is Enum
          ? value.name
          : value.toString();
  return '$name: $label';
}

String _conditionalText(GuidanceCandidate result, GuidanceContext context) {
  if (context.knownActivity || result.alert != null) return result.text;
  final prefix = switch (result.activity) {
    GuidanceActivity.dogWalking => 'If you’re walking the dog',
    GuidanceActivity.cycling => 'If you’re cycling',
    GuidanceActivity.walking => 'If you’re walking or running',
    GuidanceActivity.drivingCommute =>
      'If you’re driving in your commute window',
    _ => '',
  };
  return prefix.isEmpty ? result.text : '$prefix: ${result.text}';
}

String _tipHeading(GuidanceCandidate result, GuidanceContext context) {
  if (context.knownActivity || result.alert != null) return 'Wingman tip';
  final condition = switch (result.activity) {
    GuidanceActivity.dogWalking => 'If walking the dog',
    GuidanceActivity.cycling => 'If cycling',
    GuidanceActivity.walking => 'If walking or running',
    GuidanceActivity.drivingCommute => 'If commuting',
    _ => '',
  };
  return condition.isEmpty ? 'Wingman tip' : 'Wingman tip · $condition';
}
