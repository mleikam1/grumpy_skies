import 'package:flutter/material.dart';

abstract final class DMMotion {
  const DMMotion._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration ambient = Duration(milliseconds: 1200);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve playful = Curves.easeOutBack;
  static const Curve settle = Curves.easeOutQuart;

  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration resolve(
    BuildContext context,
    Duration duration,
  ) {
    return shouldReduceMotion(context) ? Duration.zero : duration;
  }
}
