import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';

/// Forecast overlays live above the app shell so navigation cannot cover data.
Future<void> showForecastSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  List<Widget>? children,
  Widget Function(BuildContext, ScrollController)? bodyBuilder,
}) {
  assert((children == null) != (bodyBuilder == null));
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.dmColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    clipBehavior: Clip.antiAlias,
    builder: (context) => LayoutBuilder(builder: (context, constraints) {
      // Keep the header and a usable piece of timeline visible even on a small
      // phone with large accessibility text, including after dragging downward.
      double textHeight(String text, TextStyle style, double width) {
        final painter = TextPainter(
          text: TextSpan(
              text: text,
              style: DefaultTextStyle.of(context).style.merge(style)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: width);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final headerHeight = 10 +
          4 +
          12 +
          math.max(
              48,
              textHeight(
                  title,
                  const TextStyle(
                      fontSize: 22, height: 1.15, fontWeight: FontWeight.w800),
                  constraints.maxWidth - 76)) +
          textHeight(subtitle, const TextStyle(fontSize: 13, height: 1.35),
              constraints.maxWidth - 40) +
          16 +
          1;
      final minimum =
          ((headerHeight + MediaQuery.paddingOf(context).bottom + 72) /
                  constraints.maxHeight)
              .clamp(.45, .95);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: math.max(.78, minimum),
        minChildSize: minimum,
        maxChildSize: .95,
        builder: (context, controller) => SafeArea(
            top: false,
            child: Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.dmColors.textMuted,
                      borderRadius: BorderRadius.circular(8))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: context.dmColors.textPrimary))),
                    IconButton(
                        tooltip: 'Close forecast',
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded)),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(subtitle,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: context.dmColors.textSecondary)))),
              Divider(height: 1, color: context.dmColors.divider),
              Expanded(
                  child: bodyBuilder?.call(context, controller) ??
                      ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                          children: children!)),
            ])),
      );
    }),
  );
}
