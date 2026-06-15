import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_buttons.dart';
import '../../../shared/widgets/dm_glass_card.dart';

class RadarTimelineScrubber extends StatelessWidget {
  const RadarTimelineScrubber({
    super.key,
    required this.playing,
    required this.value,
    required this.onChanged,
    required this.onPlayPause,
  });

  static const _labels = ['-60m', 'Now', '+60m', '+120m'];

  final bool playing;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onPlayPause;

  String get _timeLabel {
    return switch (value.round()) {
      0 => 'Past hour',
      1 => 'Now - storm edge ETA 24 min',
      2 => '+60m FutureCast',
      _ => '+120m FutureCast',
    };
  }

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      semanticLabel: 'Radar timeline scrubber',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final timeline = _TimelineTrack(
            value: value,
            labels: _labels,
            onChanged: onChanged,
          );
          final header = _TimelineHeader(
            playing: playing,
            timeLabel: _timeLabel,
            onPlayPause: onPlayPause,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: DMSpacing.sm),
                timeline,
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 220, child: header),
              const SizedBox(width: DMSpacing.md),
              Expanded(child: timeline),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.playing,
    required this.timeLabel,
    required this.onPlayPause,
  });

  final bool playing;
  final String timeLabel;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DmIconButton(
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          semanticLabel:
              playing ? 'Pause radar timeline' : 'Play radar timeline',
          tooltip: playing ? 'Pause' : 'Play',
          variant: DmIconButtonVariant.filled,
          onPressed: onPlayPause,
        ),
        const SizedBox(width: DMSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Timeline',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.label.copyWith(
                  color: DMColors.textMuted,
                ),
              ),
              const SizedBox(height: DMSpacing.xxs),
              Text(
                timeLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final double value;
  final List<String> labels;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeLabel = labels[value.round().clamp(0, labels.length - 1)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: DMColors.skyBlue,
            inactiveTrackColor: DMColors.glassStrong,
            thumbColor: DMColors.sunriseYellow,
            overlayColor: DMColors.opacity(DMColors.sunriseYellow, 0.18),
            valueIndicatorColor: DMColors.surfaceRaised,
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
            activeTickMarkColor: DMColors.deepNavy,
            inactiveTickMarkColor: DMColors.textMuted,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 3,
            divisions: 3,
            label: activeLabel,
            semanticFormatterCallback: (value) {
              final label = labels[value.round().clamp(0, labels.length - 1)];
              return 'Radar timeline $label';
            },
            onChanged: onChanged,
          ),
        ),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: label == activeLabel
                        ? DMColors.sunriseYellow
                        : DMColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
