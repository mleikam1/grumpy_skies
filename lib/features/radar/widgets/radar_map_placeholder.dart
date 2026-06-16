import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_motion.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/assets/dm_assets.dart';
import '../../../shared/widgets/dm_asset_image.dart';

class RadarMapPlaceholder extends StatelessWidget {
  const RadarMapPlaceholder({
    super.key,
    required this.lightningEnabled,
    required this.futureCastEnabled,
    required this.scanActive,
    required this.timelineIndex,
  });

  final bool lightningEnabled;
  final bool futureCastEnabled;
  final bool scanActive;
  final int timelineIndex;

  @override
  Widget build(BuildContext context) {
    final decorativeScanActive =
        scanActive && !DMMotion.shouldReduceMotion(context);

    // Provider-ready placeholder: replace the base CustomPaint layer with a
    // real radar/map provider later, keeping these branded overlays and state
    // inputs as the integration surface. Reduced-motion users keep a static
    // radar treatment instead of decorative scan/pulse loops.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RadarMapBasePainter(
              futureCastEnabled: futureCastEnabled,
              timelineIndex: timelineIndex,
            ),
          ),
          DmAssetImage(
            // TODO(assets): Add the generated neutral radar base map at
            // DmAssets.backgrounds.radar.map.
            assetPath: DmAssets.backgrounds.radar.map,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            placeholderBuilder: (_) => const SizedBox.shrink(),
          ),
          DmAssetImage(
            // TODO(assets): Add transparent generated radar overlays at
            // DmAssets.radar paths; these sit above the fallback map.
            assetPath: DmAssets.radar.precipitationModerate,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            placeholderBuilder: (_) => const SizedBox.shrink(),
          ),
          if (futureCastEnabled)
            DmAssetImage(
              assetPath: DmAssets.radar.stormCells,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              placeholderBuilder: (_) => const SizedBox.shrink(),
            ),
          if (lightningEnabled)
            DmAssetImage(
              assetPath: DmAssets.radar.lightning,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              placeholderBuilder: (_) => const SizedBox.shrink(),
            ),
          CustomPaint(
            painter: _RadarRingsPainter(
              scanActive: decorativeScanActive,
              timelineIndex: timelineIndex,
            ),
          ),
          if (lightningEnabled) ...const [
            _RadarLightningMarker(
              alignment: Alignment(0.48, -0.36),
              size: 42,
            ),
            _RadarLightningMarker(
              alignment: Alignment(-0.58, 0.18),
              size: 36,
            ),
            _RadarLightningMarker(
              alignment: Alignment(0.22, 0.46),
              size: 34,
            ),
          ],
          Center(child: _LocationPulse(active: decorativeScanActive)),
          const Positioned(
            left: DMSpacing.md,
            bottom: DMSpacing.md,
            child: _ProviderReadyBadge(),
          ),
        ],
      ),
    );
  }
}

class _RadarMapBasePainter extends CustomPainter {
  const _RadarMapBasePainter({
    required this.futureCastEnabled,
    required this.timelineIndex,
  });

  final bool futureCastEnabled;
  final int timelineIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DMColors.deepNavy,
          DMColors.stormNavy,
          DMColors.twilightNavy,
          DMColors.deepNavy,
        ],
        stops: [0, 0.34, 0.72, 1],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    _drawRadarGrid(canvas, size);
    _drawSchematicMapLines(canvas, size);
    _drawStormCells(canvas, size);
    if (futureCastEnabled) {
      _drawFutureCast(canvas, size);
    }
  }

  void _drawRadarGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = DMColors.opacity(DMColors.skyBlueSoft, 0.06)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = DMColors.opacity(DMColors.skyBlueSoft, 0.1)
      ..strokeWidth = 1.2;

    const minorStep = 44.0;
    const majorStep = 132.0;

    for (var x = -minorStep; x < size.width + minorStep; x += minorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }
    for (var y = -minorStep; y < size.height + minorStep; y += minorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }
    for (var x = 0.0; x < size.width + majorStep; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }
    for (var y = 0.0; y < size.height + majorStep; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }
  }

  void _drawSchematicMapLines(Canvas canvas, Size size) {
    final bayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = DMColors.opacity(DMColors.rainTeal, 0.1);

    final bayPath = Path()
      ..moveTo(size.width * 0.72, -20)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.22,
        size.width * 0.82,
        size.height * 0.42,
        size.width * 0.68,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.6,
        size.height * 0.82,
        size.width * 0.68,
        size.height,
        size.width * 0.54,
        size.height + 20,
      );
    canvas.drawPath(bayPath, bayPaint);

    final roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = DMColors.opacity(DMColors.cloudWhite, 0.12);

    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.18 + i * 0.12);
      final path = Path()
        ..moveTo(-20, y)
        ..quadraticBezierTo(
          size.width * 0.38,
          y - 38 + i * 8,
          size.width + 20,
          y + 24 - i * 3,
        );
      canvas.drawPath(path, roadPaint);
    }

    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = DMColors.opacity(DMColors.lavenderGlass, 0.1);

    for (var i = 0; i < 4; i++) {
      final rect = Rect.fromCenter(
        center: Offset(size.width * 0.28, size.height * (0.3 + i * 0.12)),
        width: size.width * (0.32 + i * 0.08),
        height: size.height * (0.12 + i * 0.04),
      );
      canvas.drawOval(rect, contourPaint);
    }
  }

  void _drawStormCells(Canvas canvas, Size size) {
    final drift = (timelineIndex - 1) * size.width * 0.035;

    _drawStormCell(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.34 + drift, size.height * 0.42),
        width: size.width * 0.58,
        height: size.height * 0.36,
      ),
      [
        DMColors.opacity(DMColors.alertRed, 0.44),
        DMColors.opacity(DMColors.alertOrange, 0.36),
        DMColors.opacity(DMColors.sunriseYellow, 0.24),
        Colors.transparent,
      ],
    );

    _drawStormCell(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.64 + drift, size.height * 0.64),
        width: size.width * 0.46,
        height: size.height * 0.3,
      ),
      [
        DMColors.opacity(DMColors.rainTeal, 0.34),
        DMColors.opacity(DMColors.mintGreen, 0.24),
        DMColors.opacity(DMColors.skyBlue, 0.16),
        Colors.transparent,
      ],
    );

    _drawStormCell(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width * 0.18 + drift, size.height * 0.75),
        width: size.width * 0.34,
        height: size.height * 0.26,
      ),
      [
        DMColors.opacity(DMColors.stormViolet, 0.32),
        DMColors.opacity(DMColors.skyBlue, 0.2),
        Colors.transparent,
      ],
    );
  }

  void _drawFutureCast(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = DMColors.opacity(DMColors.sunriseYellow, 0.36);
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          DMColors.opacity(DMColors.sunriseYellow, 0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.72, size.height * 0.3),
          radius: size.shortestSide * 0.28,
        ),
      );

    final target = Rect.fromCenter(
      center: Offset(size.width * 0.72, size.height * 0.3),
      width: size.width * 0.3,
      height: size.height * 0.22,
    );
    canvas.drawOval(target.inflate(size.shortestSide * 0.12), fill);

    const dashCount = 18;
    for (var i = 0; i < dashCount; i += 2) {
      final start = i * 2 * math.pi / dashCount;
      canvas.drawArc(target, start, math.pi / dashCount, false, paint);
    }
  }

  void _drawStormCell(
    Canvas canvas,
    Rect rect,
    List<Color> colors,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(colors: colors).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _RadarMapBasePainter oldDelegate) {
    return oldDelegate.futureCastEnabled != futureCastEnabled ||
        oldDelegate.timelineIndex != timelineIndex;
  }
}

class _RadarRingsPainter extends CustomPainter {
  const _RadarRingsPainter({
    required this.scanActive,
    required this.timelineIndex,
  });

  final bool scanActive;
  final int timelineIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = DMColors.opacity(DMColors.skyBlueSoft, 0.22);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, ringPaint);
    }

    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = DMColors.opacity(DMColors.skyBlueSoft, 0.16);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      axisPaint,
    );

    final sweepAngle = -math.pi / 2 + timelineIndex * math.pi / 8;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + math.pi / 2.7,
        colors: [
          DMColors.opacity(DMColors.skyBlue, scanActive ? 0.0 : 0.02),
          DMColors.opacity(DMColors.skyBlue, scanActive ? 0.24 : 0.1),
          DMColors.opacity(DMColors.sunriseYellow, scanActive ? 0.18 : 0.06),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        sweepAngle,
        math.pi / 2.7,
        false,
      )
      ..close();
    canvas.drawPath(sweepPath, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarRingsPainter oldDelegate) {
    return oldDelegate.scanActive != scanActive ||
        oldDelegate.timelineIndex != timelineIndex;
  }
}

class _RadarLightningMarker extends StatelessWidget {
  const _RadarLightningMarker({
    required this.alignment,
    required this.size,
  });

  final Alignment alignment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Semantics(
        label: 'Lightning marker',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DMColors.opacity(DMColors.deepNavy, 0.72),
            shape: BoxShape.circle,
            border: Border.all(
              color: DMColors.opacity(DMColors.sunriseYellow, 0.64),
            ),
            boxShadow: [
              BoxShadow(
                color: DMColors.opacity(DMColors.sunriseYellow, 0.3),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: size,
            child: const Icon(
              Icons.bolt,
              color: DMColors.sunriseYellow,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationPulse extends StatelessWidget {
  const _LocationPulse({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final glowColor = active ? DMColors.skyBlue : DMColors.textMuted;

    return Semantics(
      label: 'Centered San Francisco location pulse',
      child: SizedBox.square(
        dimension: 136,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _PulseRing(size: 136, color: glowColor, opacity: 0.14),
            _PulseRing(size: 94, color: glowColor, opacity: 0.22),
            const _PulseRing(
              size: 56,
              color: DMColors.sunriseYellow,
              opacity: 0.24,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: DMColors.skyBlue,
                shape: BoxShape.circle,
                border: Border.all(color: DMColors.cloudWhite, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: DMColors.opacity(DMColors.skyBlue, 0.5),
                    blurRadius: 24,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const SizedBox.square(
                dimension: 30,
                child: Icon(
                  Icons.my_location,
                  color: DMColors.deepNavy,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
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
        border: Border.all(color: DMColors.opacity(color, opacity + 0.12)),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _ProviderReadyBadge extends StatelessWidget {
  const _ProviderReadyBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.deepNavy, 0.62),
        borderRadius: DMRadius.full,
        border: Border.all(color: DMColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.sm,
          vertical: DMSpacing.xs,
        ),
        child: Text(
          'Provider-ready placeholder',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
