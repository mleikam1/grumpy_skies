import 'package:flutter/material.dart';
import '../../../design/dm_metric_colors.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../../shared/widgets/dm_approved_components.dart';

class ForecastExtraMetrics extends StatelessWidget {
  const ForecastExtraMetrics({super.key, required this.weather});
  final CurrentWeather weather;

  @override
  Widget build(BuildContext context) {
    final atmosphere = [
      _MetricSpec(
          Icons.wb_sunny_outlined,
          'UV',
          weather.uvIndex.isFinite && weather.uvIndex >= 0
              ? weather.uvIndex.toStringAsFixed(0)
              : 'Unavailable',
          DMMetricTone.warm,
          status: weather.uvCategory),
      _MetricSpec(
          Icons.opacity_rounded,
          'Humidity',
          weather.humidity >= 0 ? '${weather.humidity}%' : 'Unavailable',
          DMMetricTone.water),
      _MetricSpec(Icons.compress_rounded, 'Pressure', weather.pressureLabel,
          DMMetricTone.cool),
      _MetricSpec(Icons.visibility_outlined, 'Visibility',
          weather.visibilityLabel, DMMetricTone.cool),
      _MetricSpec(Icons.grain_rounded, 'Last hour',
          weather.rainSnowLastHourLabel, DMMetricTone.water),
    ];
    final sky = [
      _MetricSpec(Icons.wb_twilight_rounded, 'Sunrise',
          _formatTime(weather.sunrise), DMMetricTone.warm),
      _MetricSpec(Icons.wb_twilight_outlined, 'Sunset',
          _formatTime(weather.sunset), DMMetricTone.warm),
      _MetricSpec(Icons.dark_mode_outlined, 'Moonrise',
          _formatTime(weather.moonrise), DMMetricTone.lunar),
      _MetricSpec(Icons.bedtime_outlined, 'Moonset',
          _formatTime(weather.moonset), DMMetricTone.lunar),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DmApprovedSectionHeader(title: 'Details'),
      const SizedBox(height: 12),
      _MetricGrid(metrics: atmosphere),
      const SizedBox(height: 22),
      Text('Sun & moon',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.dmColors.textPrimary)),
      const SizedBox(height: 10),
      _MetricGrid(metrics: sky),
    ]);
  }

  String _formatTime(DateTime time) {
    if (time.millisecondsSinceEpoch <= 0) return 'Unavailable';
    final offset = weather.timezoneOffset;
    final local = offset == null
        ? time.toLocal()
        : DateTime.fromMillisecondsSinceEpoch(
            time.toUtc().millisecondsSinceEpoch + offset * 1000,
            isUtc: true);
    final hours = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<_MetricSpec> metrics;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 720 * scale
            ? 3
            : constraints.maxWidth >= 300 * scale
                ? 2
                : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final metric in metrics)
            SizedBox(
                width: metric.label == 'Last hour' && columns == 2
                    ? constraints.maxWidth
                    : width,
                child: DmMetricChip(
                    icon: metric.icon,
                    label: metric.label,
                    value: metric.value,
                    status: metric.status,
                    available: metric.value != 'Unavailable',
                    tone: metric.tone)),
        ]);
      });
}

class _MetricSpec {
  const _MetricSpec(this.icon, this.label, this.value, this.tone,
      {this.status});
  final IconData icon;
  final String label;
  final String value;
  final DMMetricTone tone;
  final String? status;
}
