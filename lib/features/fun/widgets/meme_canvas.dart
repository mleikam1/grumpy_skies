import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_shadows.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/dm_asset_image.dart';
import '../../../shared/widgets/dm_glass_card.dart';
import 'meme_style.dart';

class MemeCanvas extends StatelessWidget {
  const MemeCanvas({
    super.key,
    required this.topText,
    required this.bottomText,
    required this.style,
    required this.background,
    this.boundaryKey,
  });

  final String topText;
  final String bottomText;
  final MemeVisualStyle style;
  final MemeBackgroundPreset background;
  final GlobalKey? boundaryKey;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.xs),
      borderRadius: DMRadius.large,
      borderColor: DMColors.glassBorderStrong,
      shadows: DMShadows.floating,
      semanticLabel: 'Meme preview canvas',
      child: AspectRatio(
        aspectRatio: 1,
        child: RepaintBoundary(
          key: boundaryKey,
          child: ClipRRect(
            borderRadius: DMRadius.medium,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MemeImagePlaceholder(
                  background: background,
                  accentColor: style.accentColor,
                ),
                const _MemeCanvasShade(),
                Positioned(
                  top: DMSpacing.md,
                  right: DMSpacing.md,
                  left: DMSpacing.md,
                  child: _MemeText(
                    text: topText,
                    alignment: Alignment.topCenter,
                    style: style,
                  ),
                ),
                Positioned(
                  right: DMSpacing.md,
                  bottom: DMSpacing.x5,
                  left: DMSpacing.md,
                  child: _MemeText(
                    text: bottomText,
                    alignment: Alignment.bottomCenter,
                    style: style,
                  ),
                ),
                const Positioned(
                  right: DMSpacing.md,
                  bottom: DMSpacing.md,
                  child: _DayMakerWatermark(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemeImagePlaceholder extends StatelessWidget {
  const _MemeImagePlaceholder({
    required this.background,
    required this.accentColor,
  });

  final MemeBackgroundPreset background;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DmAssetImage(
      // TODO(assets): Add generated meme backgrounds at DmAssets.memeBackgrounds
      // paths; captions and stickers stay Flutter-rendered.
      assetPath: background.assetPath,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      placeholderBuilder: (_) => _MemeGeneratedFallback(
        background: background,
        accentColor: accentColor,
      ),
    );
  }
}

class _MemeGeneratedFallback extends StatelessWidget {
  const _MemeGeneratedFallback({
    required this.background,
    required this.accentColor,
  });

  final MemeBackgroundPreset background;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: background.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -42,
            right: -36,
            child: _GlowOrb(
              size: 150,
              color: background.accentColor,
              opacity: 0.28,
            ),
          ),
          Positioned(
            bottom: -56,
            left: -36,
            child: _GlowOrb(
              size: 190,
              color: accentColor,
              opacity: 0.2,
            ),
          ),
          Center(
            child: Icon(
              background.icon,
              size: 132,
              color: DMColors.opacity(DMColors.cloudWhite, 0.14),
            ),
          ),
          const Positioned(
            top: 52,
            left: 24,
            right: 88,
            child: _CloudStreak(opacity: 0.18),
          ),
          const Positioned(
            right: 22,
            bottom: 102,
            left: 96,
            child: _CloudStreak(opacity: 0.13),
          ),
          Positioned(
            right: 20,
            bottom: 22,
            child: Text(
              background.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelSmall.copyWith(
                color: DMColors.opacity(DMColors.cloudWhite, 0.58),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemeCanvasShade extends StatelessWidget {
  const _MemeCanvasShade();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DMColors.opacity(Colors.black, 0.3),
            Colors.transparent,
            DMColors.opacity(Colors.black, 0.38),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
    );
  }
}

class _MemeText extends StatelessWidget {
  const _MemeText({
    required this.text,
    required this.alignment,
    required this.style,
  });

  final String text;
  final Alignment alignment;
  final MemeVisualStyle style;

  @override
  Widget build(BuildContext context) {
    final normalizedText = text.trim().toUpperCase();
    if (normalizedText.isEmpty) {
      return const SizedBox.shrink();
    }

    final textStyle = DMTypography.headingLarge.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      height: 1.04,
      letterSpacing: 0,
    );

    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                normalizedText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 5
                    ..strokeJoin = StrokeJoin.round
                    ..color = DMColors.opacity(style.strokeColor, 0.92),
                ),
              ),
              Text(
                normalizedText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textStyle.copyWith(
                  color: style.textFill,
                  shadows: [
                    Shadow(
                      color: DMColors.opacity(Colors.black, 0.42),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayMakerWatermark extends StatelessWidget {
  const _DayMakerWatermark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DMRadius.full,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DMColors.opacity(DMColors.deepNavy, 0.54),
            borderRadius: DMRadius.full,
            border: Border.all(
              color: DMColors.opacity(DMColors.cloudWhite, 0.34),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DMSpacing.sm,
              vertical: DMSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: DMSpacing.iconSm,
                  color: DMColors.sunriseYellow,
                ),
                const SizedBox(width: DMSpacing.xxs),
                Text(
                  'DayMaker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: DMColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: DMColors.opacity(color, opacity),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _CloudStreak extends StatelessWidget {
  const _CloudStreak({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.cloudWhite, opacity),
        borderRadius: DMRadius.full,
      ),
      child: const SizedBox(height: 18),
    );
  }
}
