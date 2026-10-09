import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../design/dm_theme.dart';
import '../../shared/assets/dm_assets.dart';
import '../../shared/widgets/dm_asset_image.dart';
import 'privacy_information.dart';
import 'widgets/dm_settings_row.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dmColors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      IconButton(
                        tooltip: 'Back to Settings',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.settings),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('About DayMaker',
                              style:
                                  Theme.of(context).textTheme.headlineLarge)),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: colors.heroGradient,
                        border: Border.all(color: colors.border),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(children: [
                        DmAssetImage(
                          assetPath: DmAssets.mascots.idle,
                          width: 160,
                          height: 140,
                          fit: BoxFit.contain,
                          semanticLabel: 'DayMaker sun mascot',
                          placeholderIcon: Icons.wb_sunny_rounded,
                        ),
                        const SizedBox(height: 16),
                        Text('DayMaker',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 8),
                        Text('Weather with personality.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Text(
                            'A personality-driven weather app that brightens your forecast '
                            'instead of politely whispering it.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: colors.textSecondary)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    _heading(context, 'Live Data Sources'),
                    const DmSettingsRow(
                      icon: Icons.cloud_queue_rounded,
                      title: 'OpenWeather',
                      subtitle: 'Weather data © OpenWeather',
                    ),
                    const SizedBox(height: 8),
                    const DmSettingsRow(
                      icon: Icons.wb_cloudy_rounded,
                      title: 'One Call API 4.0',
                      subtitle: 'Forecast and current conditions',
                    ),
                    const SizedBox(height: 8),
                    const DmSettingsRow(
                      icon: Icons.radar_rounded,
                      title: 'US Precipitation Map Forecast',
                      subtitle: 'Radar layers and precipitation frames',
                    ),
                    const SizedBox(height: 24),
                    const DmSettingsRow(
                      icon: Icons.new_releases_outlined,
                      title: 'Version 0.1.0',
                    ),
                    const SizedBox(height: 24),
                    _heading(context, 'Legal'),
                    DmSettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy information',
                      subtitle: 'How this development build handles data',
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showPrivacyInformation(context),
                    ),
                    const SizedBox(height: 8),
                    const DmSettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Terms of Use',
                      subtitle:
                          'Publisher terms are not yet available in this build.',
                    ),
                    const SizedBox(height: 8),
                    DmSettingsRow(
                      icon: Icons.library_books_outlined,
                      title: 'Licenses',
                      subtitle: 'Open-source notices',
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showLicensePage(
                          context: context, applicationName: 'DayMaker'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      );
}
