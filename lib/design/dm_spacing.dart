import 'package:flutter/widgets.dart';

import 'dm_breakpoints.dart';

abstract final class DMSpacing {
  const DMSpacing._();

  static const double grid = 4;

  static const double none = 0;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double x2 = 32;
  static const double x3 = 40;
  static const double x4 = 48;
  static const double x5 = 64;
  static const double x6 = 80;
  static const double x7 = 96;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double tapTarget = 48;

  static const EdgeInsets zero = EdgeInsets.zero;
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets roomyScreenPadding = EdgeInsets.all(xl);

  static EdgeInsets all(double value) => EdgeInsets.all(value);

  static EdgeInsets horizontal(double value) {
    return EdgeInsets.symmetric(horizontal: value);
  }

  static EdgeInsets vertical(double value) {
    return EdgeInsets.symmetric(vertical: value);
  }

  static EdgeInsets symmetric({
    double horizontal = none,
    double vertical = none,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return pagePaddingForWidth(MediaQuery.sizeOf(context).width);
  }

  static EdgeInsets pagePaddingForWidth(double width) {
    return switch (DMBreakpoints.fromWidth(width)) {
      DMBreakpoint.compact => const EdgeInsets.all(md),
      DMBreakpoint.medium => const EdgeInsets.symmetric(
          horizontal: xl,
          vertical: md,
        ),
      DMBreakpoint.expanded => const EdgeInsets.symmetric(
          horizontal: x2,
          vertical: xl,
        ),
    };
  }
}
