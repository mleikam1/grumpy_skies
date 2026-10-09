import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../design/dm_theme.dart';
import '../../features/roasts/models/roast_persona.dart';

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
        if (title == null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: context.dmColors.primary, shape: BoxShape.circle),
            child: Icon(Icons.wb_sunny_outlined,
                size: 25, color: context.dmColors.onPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text('daymaker.',
                  style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: context.dmColors.textPrimary))),
        ] else
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

class DmPersonaPortrait extends StatelessWidget {
  const DmPersonaPortrait(
      {super.key, required this.personaId, this.width, this.height});
  final String personaId;
  final double? width;
  final double? height;

  static String pathFor(String id) =>
      'assets/approved_v1/personas/${RoastPersonas.normalizeId(id)}_portrait.png';

  @override
  Widget build(BuildContext context) => Image.asset(
        pathFor(personaId),
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
        semanticLabel: '${RoastPersonas.byId(personaId).displayName} portrait',
        errorBuilder: (_, __, ___) => SizedBox(
            width: width,
            height: height,
            child: Center(
                child: Text('Portrait pending',
                    style: TextStyle(
                        fontSize: 11, color: context.dmColors.textSecondary),
                    textAlign: TextAlign.center))),
      );
}

class DmApprovedAction extends StatelessWidget {
  const DmApprovedAction(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor:
              primary ? context.dmColors.primary : Colors.transparent,
          foregroundColor: primary
              ? context.dmColors.onPrimary
              : context.dmColors.textPrimary,
          side: BorderSide(
              color: primary
                  ? Colors.transparent
                  : context.dmColors.outlineVariant),
          textStyle: const TextStyle(
              fontFamily: 'DaymakerSans',
              fontSize: 13,
              fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
