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
import '../../shared/widgets/daymaker_components.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DmResponsiveScaffold(
      applyPagePadding: false,
      centerContent: false,
      useSafeArea: false,
      backgroundColor: DMColors.skyBlueSoft,
      backgroundGradient: _SplashGradients.sunriseSky,
      bodyBuilder: (context, breakpoint) {
        return DmAppBackground(
          color: DMColors.skyBlueSoft,
          gradient: _SplashGradients.sunriseSky,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _SplashBackgroundImage(),
              const _SplashAtmosphere(),
              SafeArea(
                child: _SplashBody(
                  breakpoint: breakpoint,
                  onCtaPressed: () => context.go(AppRoutes.forecast),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody({
    required this.breakpoint,
    required this.onCtaPressed,
  });

  final DMBreakpoint breakpoint;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _SplashMetrics.forBreakpoint(breakpoint);
        final useWideLayout =
            breakpoint.isExpanded && constraints.maxWidth >= 1100;

        final content = useWideLayout
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _MascotStage(size: metrics.mascotSize),
                    ),
                  ),
                  const SizedBox(width: DMSpacing.x5),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _SplashGlassPanel(
                        metrics: metrics,
                        textAlign: TextAlign.left,
                        buttonExpanded: true,
                        onCtaPressed: onCtaPressed,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MascotStage(size: metrics.mascotSize),
                  SizedBox(height: metrics.contentGap),
                  _SplashGlassPanel(
                    metrics: metrics,
                    textAlign: TextAlign.center,
                    buttonExpanded: true,
                    onCtaPressed: onCtaPressed,
                  ),
                ],
              );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: metrics.screenPadding,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: metrics.maxContentWidth),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SplashGlassPanel extends StatelessWidget {
  const _SplashGlassPanel({
    required this.metrics,
    required this.textAlign,
    required this.buttonExpanded,
    required this.onCtaPressed,
  });

  final _SplashMetrics metrics;
  final TextAlign textAlign;
  final bool buttonExpanded;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    const textColor = DMColors.deepNavy;

    return DmGlassCard(
      padding: metrics.cardPadding,
      borderRadius: DMRadius.card,
      borderColor: DMColors.opacity(DMColors.cloudWhite, 0.72),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DMColors.opacity(DMColors.cloudWhite, 0.72),
          DMColors.opacity(DMColors.cloudBlue, 0.42),
          DMColors.opacity(DMColors.sunrisePeach, 0.34),
        ],
      ),
      shadows: const [
        BoxShadow(
          color: Color(0x33395C84),
          blurRadius: 34,
          offset: Offset(0, 18),
        ),
        BoxShadow(
          color: Color(0x2EFFFFFF),
          blurRadius: 18,
          offset: Offset(0, -4),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: textAlign == TextAlign.left
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: textAlign == TextAlign.left
                ? Alignment.centerLeft
                : Alignment.center,
            child: Text(
              'DayMaker',
              textAlign: textAlign,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: DMTypography.brandDisplay.copyWith(
                color: textColor,
                fontSize: metrics.titleSize,
                shadows: const [
                  Shadow(
                    color: Color(0x66FFFFFF),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DMSpacing.sm),
          Text(
            'Weather that brightens your day.',
            textAlign: textAlign,
            style: DMTypography.bodyLarge.copyWith(
              color: DMColors.opacity(textColor, 0.74),
              fontSize: metrics.subtitleSize,
              height: 1.36,
            ),
          ),
          SizedBox(height: metrics.ctaTopGap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.buttonMaxWidth),
            child: DmPillButton(
              label: 'Let’s make today amazing',
              semanticLabel: 'Let’s make today amazing. Open the forecast.',
              leading: const _WeatherAssetIcon(size: 22),
              variant: DmPillButtonVariant.primary,
              expand: buttonExpanded,
              padding: EdgeInsets.symmetric(
                horizontal: metrics.buttonHorizontalPadding,
                vertical: DMSpacing.md,
              ),
              onPressed: onCtaPressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotStage extends StatelessWidget {
  const _MascotStage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Happy DayMaker sun mascot',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _SplashGradients.mascotGlow,
                    boxShadow: DMShadows.sunGlow,
                    border: Border.all(
                      color: DMColors.opacity(DMColors.cloudWhite, 0.62),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.09),
                  child: ClipOval(
                    child: DmAssetImage(
                      assetPath: DmAssets.mascots.happy,
                      fit: BoxFit.cover,
                      placeholderGradient: DMGradients.sunrise,
                      placeholderIcon: Icons.wb_sunny_rounded,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: size * 0.04,
                bottom: size * 0.08,
                child: _MascotWeatherBadge(size: size * 0.24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MascotWeatherBadge extends StatelessWidget {
  const _MascotWeatherBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.cloudWhite, 0.72),
        shape: BoxShape.circle,
        border: Border.all(color: DMColors.opacity(DMColors.cloudWhite, 0.8)),
        boxShadow: DMShadows.soft,
      ),
      child: Center(
        child: _WeatherAssetIcon(size: size * 0.58),
      ),
    );
  }
}

class _WeatherAssetIcon extends StatelessWidget {
  const _WeatherAssetIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        DmAssets.icons.weather.partlyCloudyDay,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const _FallbackSunCloudIcon();
        },
      ),
    );
  }
}

class _FallbackSunCloudIcon extends StatelessWidget {
  const _FallbackSunCloudIcon();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: Icon(
            Icons.wb_sunny_rounded,
            color: DMColors.sunriseAmber,
            size: 17,
          ),
        ),
        Positioned(
          right: -1,
          bottom: 0,
          child: Icon(
            Icons.cloud_rounded,
            color: DMColors.cloudWhite,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _SplashBackgroundImage extends StatelessWidget {
  const _SplashBackgroundImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      DmAssets.backgrounds.splash.day,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        return const _SunriseGradientFallback();
      },
    );
  }
}

class _SunriseGradientFallback extends StatelessWidget {
  const _SunriseGradientFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8FE6FF),
            Color(0xFFFFD76A),
            Color(0xFFFFB188),
            Color(0xFF2F8EDB),
          ],
          stops: [0, 0.38, 0.68, 1],
        ),
      ),
    );
  }
}

class _SplashAtmosphere extends StatelessWidget {
  const _SplashAtmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DMColors.opacity(DMColors.cloudWhite, 0.10),
                Colors.transparent,
                DMColors.opacity(DMColors.deepNavy, 0.24),
              ],
              stops: const [0, 0.52, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    DMColors.opacity(DMColors.cloudWhite, 0.20),
                    DMColors.opacity(DMColors.deepNavy, 0.30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashMetrics {
  const _SplashMetrics({
    required this.maxContentWidth,
    required this.screenPadding,
    required this.cardPadding,
    required this.mascotSize,
    required this.titleSize,
    required this.subtitleSize,
    required this.contentGap,
    required this.ctaTopGap,
    required this.buttonMaxWidth,
    required this.buttonHorizontalPadding,
  });

  final double maxContentWidth;
  final EdgeInsets screenPadding;
  final EdgeInsets cardPadding;
  final double mascotSize;
  final double titleSize;
  final double subtitleSize;
  final double contentGap;
  final double ctaTopGap;
  final double buttonMaxWidth;
  final double buttonHorizontalPadding;

  static _SplashMetrics forBreakpoint(DMBreakpoint breakpoint) {
    return switch (breakpoint) {
      DMBreakpoint.compact => const _SplashMetrics(
          maxContentWidth: 460,
          screenPadding: EdgeInsets.symmetric(
            horizontal: DMSpacing.md,
            vertical: DMSpacing.xl,
          ),
          cardPadding: EdgeInsets.all(DMSpacing.lg),
          mascotSize: 184,
          titleSize: 44,
          subtitleSize: 16,
          contentGap: DMSpacing.lg,
          ctaTopGap: DMSpacing.xl,
          buttonMaxWidth: double.infinity,
          buttonHorizontalPadding: DMSpacing.lg,
        ),
      DMBreakpoint.medium => const _SplashMetrics(
          maxContentWidth: 620,
          screenPadding: EdgeInsets.symmetric(
            horizontal: DMSpacing.x2,
            vertical: DMSpacing.x3,
          ),
          cardPadding: EdgeInsets.all(DMSpacing.xl),
          mascotSize: 236,
          titleSize: 56,
          subtitleSize: 18,
          contentGap: DMSpacing.x2,
          ctaTopGap: DMSpacing.x2,
          buttonMaxWidth: 360,
          buttonHorizontalPadding: DMSpacing.xl,
        ),
      DMBreakpoint.expanded => const _SplashMetrics(
          maxContentWidth: 1040,
          screenPadding: EdgeInsets.symmetric(
            horizontal: DMSpacing.x4,
            vertical: DMSpacing.x4,
          ),
          cardPadding: EdgeInsets.all(DMSpacing.x2),
          mascotSize: 320,
          titleSize: 66,
          subtitleSize: 20,
          contentGap: DMSpacing.x3,
          ctaTopGap: DMSpacing.x2,
          buttonMaxWidth: 380,
          buttonHorizontalPadding: DMSpacing.x2,
        ),
    };
  }
}

abstract final class _SplashGradients {
  const _SplashGradients._();

  static const LinearGradient sunriseSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF74D9FF),
      Color(0xFFFFD76A),
      Color(0xFFFFA47E),
      Color(0xFF246FBE),
    ],
    stops: [0, 0.42, 0.72, 1],
  );

  static const RadialGradient mascotGlow = RadialGradient(
    center: Alignment(-0.28, -0.34),
    radius: 0.86,
    colors: [
      Color(0xFFFFF6B0),
      DMColors.sunriseYellow,
      DMColors.sunriseAmber,
      DMColors.playfulPink,
    ],
    stops: [0, 0.44, 0.76, 1],
  );
}
