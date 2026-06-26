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
    required this.max,
    required this.divisions,
    required this.timeLabel,
    required this.startLabel,
    required this.endLabel,
    required this.onChanged,
    required this.onPlayPause,
    required this.onLatest,
    this.framed = true,
  });

  final bool playing;
  final double value;
  final double max;
  final int divisions;
  final String timeLabel;
  final String startLabel;
  final String endLabel;
  final ValueChanged<double> onChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final timeline = _TimelineTrack(
          value: value,
          max: max,
          divisions: divisions,
          startLabel: startLabel,
          endLabel: endLabel,
          onChanged: onChanged,
        );
        final header = _TimelineHeader(
          playing: playing,
          timeLabel: timeLabel,
          onPlayPause: onPlayPause,
          onLatest: onLatest,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: DMSpacing.xs),
              timeline,
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 300, child: header),
            const SizedBox(width: DMSpacing.md),
            Expanded(child: timeline),
          ],
        );
      },
    );

    if (!framed) {
      return Semantics(
        container: true,
        label: 'Radar timeline scrubber',
        child: content,
      );
    }

    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.md),
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      semanticLabel: 'Radar timeline scrubber',
      child: content,
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.playing,
    required this.timeLabel,
    required this.onPlayPause,
    required this.onLatest,
  });

  final bool playing;
  final String timeLabel;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;

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
        const SizedBox(width: DMSpacing.xs),
        DmPillButton(
          label: 'Latest',
          semanticLabel: 'Show latest radar frame',
          variant: DmPillButtonVariant.glass,
          padding: const EdgeInsets.symmetric(
            horizontal: DMSpacing.md,
            vertical: DMSpacing.xs,
          ),
          onPressed: onLatest,
        ),
      ],
    );
  }
}

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    required this.value,
    required this.max,
    required this.divisions,
    required this.startLabel,
    required this.endLabel,
    required this.onChanged,
  });

  final double value;
  final double max;
  final int divisions;
  final String startLabel;
  final String endLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
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
            max: max,
            divisions: divisions,
            label: '${value.round()}',
            semanticFormatterCallback: (value) {
              return 'Radar timeline frame ${value.round() + 1}';
            },
            onChanged: onChanged,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                startLabel,
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelSmall.copyWith(
                  color: DMColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '10 min steps',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelSmall.copyWith(
                  color: DMColors.sunriseYellow,
                ),
              ),
            ),
            Expanded(
              child: Text(
                endLabel,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelSmall.copyWith(
                  color: DMColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
