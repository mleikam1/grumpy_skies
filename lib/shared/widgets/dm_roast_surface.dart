import 'package:flutter/material.dart';

import '../../design/dm_theme.dart';

/// Static sky branding shared by compact and featured persona cards.
///
/// The caller retains its existing padding and child layout. Decorations paint
/// behind that child, add no semantics, and stay inside the rounded card.
class DmRoastSurface extends StatelessWidget {
  const DmRoastSurface({
    super.key,
    required this.child,
    this.colors,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.illuminationAlignment = const Alignment(-.78, -.26),
  });

  final Widget child;
  final DMRoastColors? colors;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Alignment illuminationAlignment;

  @override
  Widget build(BuildContext context) {
    final palette = colors ?? context.dmRoastColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        gradient: palette.gradient,
        border: Border.all(color: palette.border),
        borderRadius: borderRadius,
      ),
      child: CustomPaint(
        painter: _SkyAtmospherePainter(palette, illuminationAlignment),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _SkyAtmospherePainter extends CustomPainter {
  const _SkyAtmospherePainter(this.colors, this.illuminationAlignment);

  final DMRoastColors colors;
  final Alignment illuminationAlignment;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    if (colors.illuminationColor.a > 0) {
      // A single local shader lifts the portrait area without blur layers.
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: illuminationAlignment,
            radius: .8,
            colors: [
              colors.illuminationColor,
              colors.illuminationColor.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }
    if (colors.cloudColor.a > 0) {
      // Two faint, abstract silhouettes at the edges keep the copy area quiet.
      canvas.save();
      canvas.scale(size.width, size.height);
      final clouds = Path()
        ..moveTo(-.08, .49)
        ..cubicTo(-.01, .42, .05, .45, .07, .46)
        ..cubicTo(.10, .36, .21, .37, .24, .46)
        ..cubicTo(.31, .44, .36, .49, .37, .54)
        ..cubicTo(.20, .57, .04, .58, -.08, .56)
        ..close()
        ..moveTo(.79, .04)
        ..cubicTo(.81, -.02, .88, -.01, .91, .02)
        ..cubicTo(.96, -.03, 1.04, -.01, 1.06, .04)
        ..lineTo(1.06, .10)
        ..cubicTo(.94, .13, .85, .11, .76, .09)
        ..cubicTo(.76, .06, .77, .05, .79, .04)
        ..close();
      canvas.drawPath(clouds, Paint()..color = colors.cloudColor);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SkyAtmospherePainter oldDelegate) =>
      colors != oldDelegate.colors ||
      illuminationAlignment != oldDelegate.illuminationAlignment;
}
