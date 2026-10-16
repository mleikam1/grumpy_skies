import 'package:flutter/material.dart';
import '../../../design/dm_metric_colors.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastSunTimes extends StatelessWidget {
  const ForecastSunTimes({super.key, required this.weather});
  final CurrentWeather weather;

  @override
  Widget build(BuildContext context) {
    final sky = [
      _MetricSpec(Icons.wb_twilight_rounded, 'Sunrise',
          _formatTime(weather.sunrise), DMMetricTone.warm),
      _MetricSpec(Icons.wb_twilight_outlined, 'Sunset',
          _formatTime(weather.sunset), DMMetricTone.warm),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sunrise & sunset',
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
        final columns = constraints.maxWidth >= 300 * scale ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final metric in metrics)
            SizedBox(
                width: width,
                child: DmMetricChip(
                    icon: metric.icon,
                    label: metric.label,
                    value: metric.value,
                    available: metric.value != 'Unavailable',
                    tone: metric.tone)),
        ]);
      });
}

class _MetricSpec {
  const _MetricSpec(this.icon, this.label, this.value, this.tone);
  final IconData icon;
  final String label;
  final String value;
  final DMMetricTone tone;
}
