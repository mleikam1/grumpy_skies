import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';

/// Forecast overlays live above the app shell so navigation cannot cover data.
Future<void> showForecastSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Widget> children,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.dmColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      clipBehavior: Clip.antiAlias,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .45,
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
                  child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                      children: children)),
            ])),
      ),
    );
