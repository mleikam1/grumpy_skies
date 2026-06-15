import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_spacing.dart';
import '../../../shared/assets/dm_assets.dart';
import '../../../shared/widgets/daymaker_components.dart';

class ForecastHeroAtmosphere extends StatelessWidget {
  const ForecastHeroAtmosphere({
    super.key,
    this.expanded = false,
  });

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: EdgeInsets.zero,
      borderColor: DMColors.opacity(DMColors.cloudWhite, 0.28),
      child: SizedBox(
        height: expanded ? 316 : 192,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DmAssetImage(
              assetPath: DmAssets.mascots.idle,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              semanticLabel: 'DayMaker sun and cloud mascot',
              placeholderGradient: DMGradients.clearSky,
              placeholderIcon: Icons.wb_sunny_outlined,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DMColors.opacity(DMColors.deepNavy, 0.06),
                    Colors.transparent,
                    DMColors.opacity(DMColors.deepNavy, 0.2),
                  ],
                ),
              ),
            ),
            Positioned(
              right: DMSpacing.md,
              bottom: DMSpacing.md,
              child: Container(
                width: expanded ? 72 : 56,
                height: expanded ? 72 : 56,
                decoration: BoxDecoration(
                  color: DMColors.opacity(DMColors.cloudWhite, 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: DMColors.glassBorderStrong),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: DMColors.cloudWhite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
