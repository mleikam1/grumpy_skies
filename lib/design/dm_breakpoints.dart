import 'package:flutter/widgets.dart';

enum DMBreakpoint {
  compact,
  medium,
  expanded,
}

abstract final class DMBreakpoints {
  const DMBreakpoints._();

  static const double compactMax = 599;
  static const double mediumMin = 600;
  static const double mediumMax = 1023;
  static const double expandedMin = 1024;

  static DMBreakpoint fromWidth(double width) {
    if (width < mediumMin) {
      return DMBreakpoint.compact;
    }

    if (width < expandedMin) {
      return DMBreakpoint.medium;
    }

    return DMBreakpoint.expanded;
  }

  static DMBreakpoint of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static bool isCompact(double width) {
    return fromWidth(width).isCompact;
  }

  static bool isMedium(double width) {
    return fromWidth(width).isMedium;
  }

  static bool isExpanded(double width) {
    return fromWidth(width).isExpanded;
  }

  static double maxContentWidth(DMBreakpoint breakpoint) {
    return switch (breakpoint) {
      DMBreakpoint.compact => double.infinity,
      DMBreakpoint.medium => 840,
      DMBreakpoint.expanded => 1180,
    };
  }
}

extension DMBreakpointX on DMBreakpoint {
  bool get isCompact => this == DMBreakpoint.compact;

  bool get isMedium => this == DMBreakpoint.medium;

  bool get isExpanded => this == DMBreakpoint.expanded;

  T when<T>({
    required T compact,
    required T medium,
    required T expanded,
  }) {
    return switch (this) {
      DMBreakpoint.compact => compact,
      DMBreakpoint.medium => medium,
      DMBreakpoint.expanded => expanded,
    };
  }
}
