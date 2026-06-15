import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../models/temperature_unit.dart';
import '../../services/settings_controller.dart';
import '../../shared/assets/dm_assets.dart';
import '../../shared/widgets/dm_app_background.dart';
import '../../shared/widgets/dm_asset_image.dart';
import '../../shared/widgets/dm_segmented_control.dart';
import 'widgets/dm_settings_row.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: DMGradients.appBackground,
        color: DMColors.deepNavy,
        child: SafeArea(
          child: SettingsScreenBody(),
        ),
      ),
    );
  }
}

class SettingsScreenBody extends StatelessWidget {
  const SettingsScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final breakpoint = DMBreakpoints.fromWidth(width);
        final maxWidth = switch (breakpoint) {
          DMBreakpoint.compact => double.infinity,
          DMBreakpoint.medium => 760.0,
          DMBreakpoint.expanded => 1040.0,
        };
        final gap = breakpoint.isExpanded ? DMSpacing.xl : DMSpacing.md;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: DMSpacing.pagePaddingForWidth(width).copyWith(
            bottom: DMSpacing.x2,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SettingsHeader(),
                    SizedBox(height: gap),
                    if (breakpoint.isExpanded)
                      _ExpandedSettingsLayout(settings: settings, gap: gap)
                    else
                      _StackedSettingsLayout(settings: settings, gap: gap),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StackedSettingsLayout extends StatelessWidget {
  const _StackedSettingsLayout({
    required this.settings,
    required this.gap,
  });

  final SettingsController settings;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreferencesColumn(settings: settings, gap: gap),
        SizedBox(height: gap),
        _AppColumn(gap: gap),
      ],
    );
  }
}

class _ExpandedSettingsLayout extends StatelessWidget {
  const _ExpandedSettingsLayout({
    required this.settings,
    required this.gap,
  });

  final SettingsController settings;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PreferencesColumn(settings: settings, gap: gap),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _AppColumn(gap: gap),
        ),
      ],
    );
  }
}

class _PreferencesColumn extends StatelessWidget {
  const _PreferencesColumn({
    required this.settings,
    required this.gap,
  });

  final SettingsController settings;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSection(
          title: 'Temperature Units',
          child: DmSettingsRow(
            icon: Icons.thermostat_rounded,
            accentColor: DMColors.sunriseAmber,
            title: 'Forecast temperature',
            subtitle: 'Choose how DayMaker shows every dramatic degree.',
            child: DmSegmentedControl<TemperatureUnit>(
              semanticLabel: 'Temperature unit selector',
              selectedValue: settings.temperatureUnit,
              onChanged: settings.setTemperatureUnit,
              segments: const [
                DmSegment(
                  value: TemperatureUnit.fahrenheit,
                  label: '°F Fahrenheit',
                ),
                DmSegment(
                  value: TemperatureUnit.celsius,
                  label: '°C Celsius',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: gap),
        const _SettingsSection(
          title: 'Default Persona',
          child: DmSettingsRow(
            leading: _KarenAvatar(),
            title: 'Karen, ROAST QUEEN',
            subtitle:
                'Your default forecast voice. Polished, pointed, and absolutely ready to complain about humidity.',
            trailing: _Chevron(),
            semanticLabel: 'Default persona Karen Roast Queen',
          ),
        ),
        SizedBox(height: gap),
        _SettingsSection(
          title: 'Notifications',
          child: DmSettingsRow(
            icon: Icons.notifications_active_outlined,
            accentColor: DMColors.playfulPink,
            title: 'Daily weather nudges',
            subtitle: settings.notificationsEnabled
                ? 'On, so the forecast can interrupt with purpose.'
                : 'Off, for a quieter sky check.',
            trailing: Switch.adaptive(
              value: settings.notificationsEnabled,
              activeThumbColor: DMColors.sunriseYellow,
              activeTrackColor: DMColors.opacity(DMColors.sunriseYellow, 0.34),
              onChanged: settings.setNotificationsEnabled,
            ),
            onTap: () => settings.setNotificationsEnabled(
              !settings.notificationsEnabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppColumn extends StatelessWidget {
  const _AppColumn({
    required this.gap,
  });

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsSection(
          title: 'Show Ads / Premium',
          child: DmSettingsRow(
            icon: Icons.workspace_premium_rounded,
            accentColor: DMColors.sunriseYellow,
            title: 'Premium Active',
            subtitle: 'Ads are hidden and DayMaker is all yours.',
            trailing: const _Chevron(),
            onTap: () => _showSnackBar(
              context,
              'Premium settings are coming soon.',
            ),
          ),
        ),
        SizedBox(height: gap),
        _SettingsSection(
          title: 'Data Sources',
          child: DmSettingsRow(
            icon: Icons.cloud_sync_outlined,
            accentColor: DMColors.rainTeal,
            title: 'Weather data sources',
            subtitle: 'Review forecast, radar, and air quality providers.',
            trailing: const _Chevron(),
            onTap: () => _showSnackBar(
              context,
              'Data source details are coming soon.',
            ),
          ),
        ),
        SizedBox(height: gap),
        _SettingsSection(
          title: 'About',
          child: DmSettingsRow(
            icon: Icons.info_outline_rounded,
            accentColor: DMColors.skyBlue,
            title: 'About DayMaker',
            subtitle: 'Version, credits, and the fine print.',
            trailing: const _Chevron(),
            onTap: () => context.go(AppRoutes.about),
          ),
        ),
        SizedBox(height: gap),
        _SettingsSection(
          title: 'Feedback',
          child: DmSettingsRow(
            icon: Icons.feedback_outlined,
            accentColor: DMColors.mintGreen,
            title: 'Send feedback',
            subtitle: 'Tell us what should be sharper, calmer, or funnier.',
            onTap: () => _showSnackBar(
              context,
              'Feedback flow is coming soon.',
            ),
          ),
        ),
      ],
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = DMBreakpoints.isCompact(width);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DMColors.opacity(DMColors.cloudWhite, 0.18),
            DMColors.opacity(DMColors.skyBlue, 0.10),
          ],
        ),
        borderRadius: DMRadius.card,
        border: Border.all(color: DMColors.glassBorder),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? DMSpacing.lg : DMSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DayMaker',
              style: DMTypography.labelLarge.copyWith(
                color: DMColors.sunriseYellow,
              ),
            ),
            const SizedBox(height: DMSpacing.xs),
            Text(
              'Settings',
              style: (compact
                      ? DMTypography.headingLarge
                      : DMTypography.brandDisplay)
                  .copyWith(color: DMColors.textPrimary),
            ),
            const SizedBox(height: DMSpacing.xs),
            Text(
              'Customize your experience.',
              style: DMTypography.bodyLarge.copyWith(
                color: DMColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: DMSpacing.xs,
            bottom: DMSpacing.xs,
          ),
          child: Text(
            title,
            style: DMTypography.label.copyWith(
              color: DMColors.textMuted,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _KarenAvatar extends StatelessWidget {
  const _KarenAvatar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: DMGradients.sunrise,
        borderRadius: DMRadius.full,
        border: Border.all(color: DMColors.glassBorderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DMSpacing.xxs),
        child: DmAssetImage(
          assetPath: DmAssets.personas.karen,
          width: 56,
          height: 56,
          borderRadius: DMRadius.full,
          semanticLabel: 'Karen avatar',
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      color: DMColors.textMuted,
      size: 28,
    );
  }
}
