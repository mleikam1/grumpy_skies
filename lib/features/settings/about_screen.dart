import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_shadows.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../shared/assets/dm_assets.dart';
import '../../shared/widgets/dm_app_background.dart';
import '../../shared/widgets/dm_asset_image.dart';
import '../../shared/widgets/dm_buttons.dart';
import '../../shared/widgets/dm_glass_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: _aboutGradient,
        color: DMColors.deepNavy,
        child: SafeArea(
          child: LayoutBuilder(
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
                          const _AboutHeader(),
                          SizedBox(height: gap),
                          if (breakpoint.isExpanded)
                            _ExpandedAboutLayout(gap: gap)
                          else
                            _StackedAboutLayout(gap: gap),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const _aboutGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    DMColors.skyBlueDeep,
    DMColors.twilightNavy,
    DMColors.deepNavy,
  ],
  stops: [0, 0.42, 1],
);

class _StackedAboutLayout extends StatelessWidget {
  const _StackedAboutLayout({
    required this.gap,
  });

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MascotHeroCard(),
        SizedBox(height: gap),
        const _AboutGlassCard(),
        SizedBox(height: gap),
        const _DataSourcesCard(),
        SizedBox(height: gap),
        const _VersionCard(),
        SizedBox(height: gap),
        const _LegalCard(),
      ],
    );
  }
}

class _ExpandedAboutLayout extends StatelessWidget {
  const _ExpandedAboutLayout({
    required this.gap,
  });

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MascotHeroCard(expanded: true),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              flex: 6,
              child: _AboutGlassCard(),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DataSourcesCard(),
                  SizedBox(height: gap),
                  const _VersionCard(),
                  SizedBox(height: gap),
                  const _LegalCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = DMBreakpoints.isCompact(width);

    return Row(
      children: [
        DmIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          semanticLabel: 'Back to Settings',
          onPressed: () => context.go(AppRoutes.settings),
        ),
        const SizedBox(width: DMSpacing.md),
        Expanded(
          child: Text(
            'About DayMaker',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? DMTypography.headingLarge
                    : DMTypography.brandDisplay)
                .copyWith(color: DMColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _MascotHeroCard extends StatelessWidget {
  const _MascotHeroCard({
    this.expanded = false,
  });

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = !expanded && constraints.maxWidth < 420;
        final height = expanded ? 300.0 : (narrow ? 216.0 : 232.0);
        final copyWidth = expanded ? 440.0 : (narrow ? 158.0 : 220.0);

        return DmGlassCard(
          padding: EdgeInsets.zero,
          borderColor: DMColors.opacity(DMColors.cloudWhite, 0.34),
          shadows: DMShadows.sunGlow,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DMColors.sunriseYellow,
              DMColors.sunrisePeach,
              DMColors.skyBlue,
            ],
          ),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DmAssetImage(
                    assetPath: DmAssets.mascots.idle,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    semanticLabel: 'DayMaker sun mascot',
                    placeholderGradient: DMGradients.sunrise,
                    placeholderIcon: Icons.wb_sunny_rounded,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          DMColors.opacity(DMColors.sunriseYellow, 0.88),
                          DMColors.opacity(DMColors.sunrisePeach, 0.48),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: narrow ? DMSpacing.lg : DMSpacing.xl,
                  top: DMSpacing.xl,
                  bottom: DMSpacing.xl,
                  child: _HeroCopy(
                    expanded: expanded,
                    maxWidth: copyWidth,
                    narrow: narrow,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.expanded,
    required this.maxWidth,
    required this.narrow,
  });

  final bool expanded;
  final double maxWidth;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Weather with personality.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: (expanded
                    ? DMTypography.headingLarge
                    : narrow
                        ? DMTypography.headingSmall
                        : DMTypography.headingMedium)
                .copyWith(color: DMColors.deepNavy),
          ),
          const SizedBox(height: DMSpacing.xs),
          Text(
            'Sunny enough to help, loud enough to notice.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.body.copyWith(
              color: DMColors.opacity(DMColors.deepNavy, 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutGlassCard extends StatelessWidget {
  const _AboutGlassCard();

  @override
  Widget build(BuildContext context) {
    return DmLightGlassCard(
      padding: const EdgeInsets.all(DMSpacing.xl),
      semanticLabel: 'About DayMaker app summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: DMGradients.sunrise,
                  borderRadius: DMRadius.large,
                  border: Border.all(color: DMColors.glassBorderStrong),
                  boxShadow: DMShadows.soft,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DMSpacing.xs),
                  child: DmAssetImage(
                    assetPath: DmAssets.brand.appIcon,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    borderRadius: DMRadius.medium,
                    semanticLabel: 'DayMaker app icon',
                    placeholderGradient: DMGradients.sunrise,
                    placeholderIcon: Icons.wb_sunny_rounded,
                  ),
                ),
              ),
              const SizedBox(width: DMSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DayMaker',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.headingMedium.copyWith(
                        color: DMColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: DMSpacing.xxs),
                    Text(
                      'Weather with personality.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.labelLarge.copyWith(
                        color: DMColors.sunriseYellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DMSpacing.lg),
          Text(
            'A personality-driven weather app that brightens your forecast '
            'instead of politely whispering it.',
            style: DMTypography.bodyLarge.copyWith(
              color: DMColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataSourcesCard extends StatelessWidget {
  const _DataSourcesCard();

  @override
  Widget build(BuildContext context) {
    return const _LinkSectionCard(
      title: 'Planned Data Sources',
      children: [
        _FutureLinkRow(
          icon: Icons.cloud_queue_rounded,
          accentColor: DMColors.skyBlue,
          title: 'Apple WeatherKit',
          subtitle: 'Forecast and current conditions',
          onTap: null,
        ),
        _FutureLinkRow(
          icon: Icons.wb_cloudy_rounded,
          accentColor: DMColors.sunriseYellow,
          title: 'AccuWeather',
          subtitle: 'Additional forecast coverage',
          onTap: null,
        ),
        _FutureLinkRow(
          icon: Icons.radar_rounded,
          accentColor: DMColors.rainTeal,
          title: 'RainViewer',
          subtitle: 'Radar layers and storm movement',
          onTap: null,
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard();

  @override
  Widget build(BuildContext context) {
    return DmDarkGlassCard(
      padding: const EdgeInsets.all(DMSpacing.lg),
      semanticLabel: 'Version 0.1.0',
      child: Row(
        children: [
          const _AccentIcon(
            icon: Icons.new_releases_outlined,
            color: DMColors.playfulPink,
          ),
          const SizedBox(width: DMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version',
                  style: DMTypography.label.copyWith(
                    color: DMColors.textMuted,
                  ),
                ),
                const SizedBox(height: DMSpacing.xxs),
                Text(
                  'Version 0.1.0',
                  style: DMTypography.title.copyWith(
                    color: DMColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context) {
    return const _LinkSectionCard(
      title: 'Legal',
      children: [
        _FutureLinkRow(
          icon: Icons.privacy_tip_outlined,
          accentColor: DMColors.lavenderGlass,
          title: 'Privacy Policy',
          subtitle: 'Future policy link',
          onTap: null,
        ),
        _FutureLinkRow(
          icon: Icons.description_outlined,
          accentColor: DMColors.mintGreen,
          title: 'Terms of Use',
          subtitle: 'Future terms link',
          onTap: null,
        ),
        _FutureLinkRow(
          icon: Icons.library_books_outlined,
          accentColor: DMColors.sunriseAmber,
          title: 'Licenses',
          subtitle: 'Future open-source notices',
          onTap: null,
        ),
      ],
    );
  }
}

class _LinkSectionCard extends StatelessWidget {
  const _LinkSectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DmDarkGlassCard(
      padding: const EdgeInsets.all(DMSpacing.lg),
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: DMTypography.headingSmall.copyWith(
              color: DMColors.textPrimary,
            ),
          ),
          const SizedBox(height: DMSpacing.md),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: DMSpacing.xs),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _FutureLinkRow extends StatelessWidget {
  const _FutureLinkRow({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        _AccentIcon(icon: icon, color: accentColor),
        const SizedBox(width: DMSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelLarge.copyWith(
                  color: DMColors.textPrimary,
                ),
              ),
              const SizedBox(height: DMSpacing.xxs),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.bodySmall.copyWith(
                  color: DMColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DMSpacing.sm),
        Icon(
          Icons.chevron_right_rounded,
          color: onTap == null ? DMColors.textDisabled : DMColors.textMuted,
          size: 24,
        ),
      ],
    );

    final row = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: onTap == null ? 0.78 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.sm,
          vertical: DMSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: DMColors.opacity(DMColors.cloudWhite, 0.07),
          borderRadius: DMRadius.medium,
          border: Border.all(color: DMColors.outlineVariant),
        ),
        child: content,
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DMRadius.medium,
          onTap: onTap,
          child: row,
        ),
      ),
    );
  }
}

class _AccentIcon extends StatelessWidget {
  const _AccentIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DMColors.opacity(color, 0.92),
            DMColors.opacity(DMColors.cloudWhite, 0.14),
          ],
        ),
        borderRadius: DMRadius.medium,
        border: Border.all(
          color: DMColors.opacity(DMColors.cloudWhite, 0.22),
        ),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(
          icon,
          color: DMColors.cloudWhite,
          size: DMSpacing.iconLg,
        ),
      ),
    );
  }
}
