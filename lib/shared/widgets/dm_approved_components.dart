import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../config/wingman_brand.dart';
import '../../design/dm_theme.dart';
import 'wingman_logo.dart';

/// Shared geometry for the approved light layout and its dark surface treatment.
class DmPageHeader extends StatelessWidget {
  const DmPageHeader({super.key, this.title, this.back = false});
  final String? title;
  final bool back;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (back)
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.forecast),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        if (title == null)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const WingmanLogo(),
                const SizedBox(height: 4),
                Text(WingmanBrand.headerTagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: context.dmColors.textSecondary)),
              ],
            ),
          ))
        else
          Expanded(
              child: Text(title!,
                  style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7))),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push(AppRoutes.settings),
          style: IconButton.styleFrom(
              side: BorderSide(color: context.dmColors.border),
              minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.settings_outlined, size: 22),
        ),
      ]);
}

class DmApprovedSectionHeader extends StatelessWidget {
  const DmApprovedSectionHeader(
      {super.key, required this.title, this.action = 'See all', this.onAction});
  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.35))),
        if (onAction != null)
          TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 8),
                  minimumSize: const Size(48, 48)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action, style: const TextStyle(fontSize: 12)),
                const Icon(Icons.chevron_right, size: 18)
              ])),
      ]);
}

class DmApprovedAction extends StatelessWidget {
  const DmApprovedAction(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.primary = false,
      this.backgroundColor,
      this.foregroundColor,
      this.outlineColor});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? outlineColor;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: backgroundColor ??
              (primary ? context.dmColors.primary : Colors.transparent),
          foregroundColor: foregroundColor ??
              (primary
                  ? context.dmColors.onPrimary
                  : context.dmColors.textPrimary),
          side: BorderSide(
              color: outlineColor ??
                  (primary
                      ? Colors.transparent
                      : context.dmColors.outlineVariant)),
          textStyle: const TextStyle(
              fontFamily: 'DaymakerSans',
              fontSize: 13,
              fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
