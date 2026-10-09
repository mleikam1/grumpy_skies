import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../design/dm_theme.dart';
import '../../shared/assets/dm_assets.dart';
import '../../shared/widgets/dm_asset_image.dart';

/// The welcome screen uses the same geometry and artwork in both appearances.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dmColors;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: colors.heroGradient),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1024;
            final mascot = Semantics(
              image: true,
              label: 'Happy DayMaker sun mascot',
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: wide ? 300 : 184,
                  child: DmAssetImage(
                    assetPath: DmAssets.mascots.happy,
                    fit: BoxFit.contain,
                    placeholderIcon: Icons.wb_sunny_rounded,
                  ),
                ),
              ),
            );
            final panel = Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: colors.border),
                boxShadow: colors.cardShadows,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('daymaker.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontSize: 38)),
                  const SizedBox(height: 12),
                  Text('Weather that brightens your day.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: colors.textSecondary)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.forecast),
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text('Let’s make today amazing',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 920 : 520),
                      child: wide
                          ? Row(children: [
                              mascot,
                              const SizedBox(width: 40),
                              Expanded(child: panel)
                            ])
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              mascot,
                              const SizedBox(height: 24),
                              panel
                            ]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
