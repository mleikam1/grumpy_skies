import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';

class MemeTextField extends StatelessWidget {
  const MemeTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.maxLength,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final int maxLength;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelLarge,
              ),
            ),
            const SizedBox(width: DMSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return Text(
                  '${value.text.length}/$maxLength',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: value.text.length >= maxLength
                        ? DMColors.sunriseYellow
                        : DMColors.textMuted,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: DMSpacing.xs),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          style: DMTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
