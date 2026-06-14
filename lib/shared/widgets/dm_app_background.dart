import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';

class DmAppBackground extends StatelessWidget {
  const DmAppBackground({
    super.key,
    required this.child,
    this.gradient = DMGradients.appBackground,
    this.color = DMColors.deepNavy,
    this.image,
    this.foreground,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Gradient? gradient;
  final Color color;
  final DecorationImage? image;
  final Widget? foreground;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        image: image,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
          if (foreground != null)
            Positioned.fill(
              child: IgnorePointer(child: foreground),
            ),
        ],
      ),
    );
  }
}
