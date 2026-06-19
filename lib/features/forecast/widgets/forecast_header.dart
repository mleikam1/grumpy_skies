import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastHeader extends StatelessWidget {
  const ForecastHeader({
    super.key,
    required this.location,
    required this.onNotificationsPressed,
    required this.onChangeLocation,
  });

  final String location;
  final VoidCallback onNotificationsPressed;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: DMSpacing.tapTarget,
          height: DMSpacing.tapTarget,
          decoration: BoxDecoration(
            color: DMColors.glass,
            shape: BoxShape.circle,
            border: Border.all(color: DMColors.glassBorder),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: DMColors.sunriseYellow,
          ),
        ),
        const SizedBox(width: DMSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelSmall,
              ),
              const SizedBox(height: DMSpacing.xxs),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.headingSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: DMSpacing.sm),
        DmIconButton(
          icon: const Icon(Icons.edit_location_alt_outlined),
          semanticLabel: 'Change location',
          tooltip: 'Change location',
          onPressed: onChangeLocation,
        ),
        const SizedBox(width: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          semanticLabel: 'Notifications',
          onPressed: onNotificationsPressed,
        ),
      ],
    );
  }
}
