import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_glass_card.dart';

enum RadarAlertCardsLayout {
  compact,
  expanded,
}

class RadarAlertCards extends StatelessWidget {
  const RadarAlertCards({
    super.key,
    required this.layout,
  });

  final RadarAlertCardsLayout layout;

  static const _alerts = [
    _RadarAlertData(
      icon: Icons.auto_graph,
      title: 'Chaos Meter',
      value: '82% chance of drama',
      detail: 'Storm cell is getting theatrical.',
      color: DMColors.alertOrange,
      progress: 0.82,
    ),
    _RadarAlertData(
      icon: Icons.bolt,
      title: 'Lightning nearby',
      value: 'within 8 miles',
      detail: 'Outdoor plans are on thin ice.',
      color: DMColors.sunriseYellow,
    ),
    _RadarAlertData(
      icon: Icons.water_drop,
      title: 'Rain',
      value: 'in 24 min',
      detail: 'Umbrella betrayal window opens soon.',
      color: DMColors.rainTeal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final alert in _alerts) _RadarAlertCard(data: alert),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: layout == RadarAlertCardsLayout.compact
          ? MainAxisSize.min
          : MainAxisSize.max,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: DMSpacing.sm),
          children[index],
        ],
      ],
    );
  }
}

class _RadarAlertData {
  const _RadarAlertData({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color color;
  final double? progress;
}

class _RadarAlertCard extends StatelessWidget {
  const _RadarAlertCard({required this.data});

  final _RadarAlertData data;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      semanticLabel: '${data.title}, ${data.value}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DMColors.opacity(data.color, 0.2),
                  borderRadius: DMRadius.medium,
                  border: Border.all(color: DMColors.opacity(data.color, 0.46)),
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(data.icon, color: data.color),
                ),
              ),
              const SizedBox(width: DMSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.label.copyWith(
                        color: DMColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: DMSpacing.xxs),
                    Text(
                      data.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.title,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.sm),
          Text(
            data.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.bodySmall,
          ),
          if (data.progress != null) ...[
            const SizedBox(height: DMSpacing.sm),
            ClipRRect(
              borderRadius: DMRadius.full,
              child: LinearProgressIndicator(
                minHeight: 7,
                value: data.progress,
                backgroundColor: DMColors.glassStrong,
                color: data.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
