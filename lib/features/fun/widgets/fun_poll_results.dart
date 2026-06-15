import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';

class FunPollOption {
  const FunPollOption({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;
}

class FunPollResults extends StatelessWidget {
  const FunPollResults({
    super.key,
    required this.options,
  });

  final List<FunPollOption> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options) ...[
          _PollResultRow(option: option),
          if (option != options.last) const SizedBox(height: DMSpacing.sm),
        ],
      ],
    );
  }
}

class _PollResultRow extends StatelessWidget {
  const _PollResultRow({required this.option});

  final FunPollOption option;

  @override
  Widget build(BuildContext context) {
    final value = option.percent / 100;

    return Semantics(
      label: '${option.label} ${option.percent} percent',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${option.label} ${option.percent}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelLarge,
            ),
            const SizedBox(height: DMSpacing.xs),
            ClipRRect(
              borderRadius: DMRadius.full,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DMColors.glass,
                  borderRadius: DMRadius.full,
                  border: Border.all(color: DMColors.glassBorder),
                ),
                child: SizedBox(
                  height: 10,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0).toDouble(),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: option.color,
                          borderRadius: DMRadius.full,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
