import 'package:flutter/widgets.dart';

abstract final class DMRadius {
  const DMRadius._();

  static const double none = 0;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double sheet = 36;
  static const double pill = 999;

  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusXl = Radius.circular(xl);
  static const Radius radiusXxl = Radius.circular(xxl);
  static const Radius radiusPill = Radius.circular(pill);

  static const BorderRadius small = BorderRadius.all(radiusSm);
  static const BorderRadius medium = BorderRadius.all(radiusMd);
  static const BorderRadius large = BorderRadius.all(radiusLg);
  static const BorderRadius card = BorderRadius.all(radiusXl);
  static const BorderRadius modal = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius full = BorderRadius.all(radiusPill);

  static BorderRadius all(double value) {
    return BorderRadius.all(Radius.circular(value));
  }

  static BorderRadius top(double value) {
    final radius = Radius.circular(value);
    return BorderRadius.only(topLeft: radius, topRight: radius);
  }

  static BorderRadius bottom(double value) {
    final radius = Radius.circular(value);
    return BorderRadius.only(bottomLeft: radius, bottomRight: radius);
  }
}
