import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../shared/assets/dm_assets.dart';
import '../../../shared/widgets/daymaker_components.dart';

class FunWheelVisual extends StatelessWidget {
  const FunWheelVisual({
    super.key,
    this.assetPath,
    this.size = 152,
  });

  final String? assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: DMColors.opacity(DMColors.cloudWhite, 0.66),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: DMColors.opacity(DMColors.playfulPink, 0.34),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(DMSpacing.xs),
          child: ClipOval(
            child: DmAssetImage(
              // TODO(assets): Add the generated Crazy Day Predictor wheel at
              // DmAssets.fun.crazyDayWheel.
              assetPath: assetPath ?? DmAssets.fun.crazyDayWheel,
              width: size,
              height: size,
              fit: BoxFit.cover,
              semanticLabel: 'Crazy Day Predictor wheel',
              placeholderIcon: Icons.cyclone_outlined,
              placeholderGradient: const SweepGradient(
                colors: [
                  DMColors.skyBlue,
                  DMColors.sunriseYellow,
                  DMColors.playfulPink,
                  DMColors.mintGreen,
                  DMColors.lavenderDeep,
                  DMColors.skyBlue,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
