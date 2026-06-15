import 'package:flutter/material.dart';

import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_motion.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_shadows.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';

class DmBottomNavItem {
  const DmBottomNavItem({
    required this.label,
    required this.icon,
    IconData? selectedIcon,
    String? semanticLabel,
  })  : selectedIcon = selectedIcon ?? icon,
        semanticLabel = semanticLabel ?? label;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String semanticLabel;
}

class DmBottomNav extends StatelessWidget {
  const DmBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.items = defaultItems,
  }) : assert(items.length == 5, 'DmBottomNav expects exactly 5 tabs.');

  static const List<DmBottomNavItem> defaultItems = [
    DmBottomNavItem(
      label: 'Forecast',
      icon: Icons.wb_cloudy_outlined,
      selectedIcon: Icons.wb_cloudy,
      semanticLabel: 'Forecast tab',
    ),
    DmBottomNavItem(
      label: 'Roasts',
      icon: Icons.local_fire_department_outlined,
      selectedIcon: Icons.local_fire_department,
      semanticLabel: 'Roasts tab',
    ),
    DmBottomNavItem(
      label: 'Radar',
      icon: Icons.radar,
      semanticLabel: 'Radar tab',
    ),
    DmBottomNavItem(
      label: 'Fun',
      icon: Icons.emoji_emotions_outlined,
      selectedIcon: Icons.emoji_emotions,
      semanticLabel: 'Fun tab',
    ),
    DmBottomNavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      semanticLabel: 'Settings tab',
    ),
  ];

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DmBottomNavItem> items;

  static double reservedHeightFor(BuildContext context, double width) {
    final breakpoint = DMBreakpoints.fromWidth(width);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return bottomInset + (breakpoint.isCompact ? 88.0 : 96.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final breakpoint = DMBreakpoints.fromWidth(width);
        final maxWidth = breakpoint.isCompact ? double.infinity : 720.0;
        final horizontalPadding =
            breakpoint.isCompact ? DMSpacing.xs : DMSpacing.md;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              DMSpacing.xs,
              horizontalPadding,
              breakpoint.isCompact ? DMSpacing.xs : DMSpacing.md,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Semantics(
                  container: true,
                  label: 'Primary navigation',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DMColors.glassNavy,
                      borderRadius: DMRadius.full,
                      border: Border.all(color: DMColors.glassBorder),
                      boxShadow: DMShadows.floating,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DMSpacing.xxs),
                      child: Row(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: _DmBottomNavTile(
                                item: items[index],
                                selected: currentIndex == index,
                                onTap: () => onDestinationSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DmBottomNavTile extends StatefulWidget {
  const _DmBottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DmBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DmBottomNavTile> createState() => _DmBottomNavTileState();
}

class _DmBottomNavTileState extends State<_DmBottomNavTile> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final duration = DMMotion.resolve(context, DMMotion.fast);
    final foreground = widget.selected ? DMColors.deepNavy : DMColors.textMuted;
    final background = widget.selected ? DMColors.skyBlue : Colors.transparent;

    final tile = LayoutBuilder(
      builder: (context, constraints) {
        final tight =
            constraints.maxWidth.isFinite && constraints.maxWidth < 72;
        final labelStyle =
            (tight ? DMTypography.labelSmall : DMTypography.label)
                .copyWith(color: foreground);

        return AnimatedContainer(
          duration: duration,
          curve: DMMotion.easeOut,
          constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
          padding: EdgeInsets.symmetric(
            horizontal: tight ? DMSpacing.xxs : DMSpacing.xs,
            vertical: DMSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: DMRadius.full,
            border: _focused
                ? Border.all(color: DMColors.sunriseYellow, width: 2)
                : null,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: DMColors.opacity(DMColors.sunriseYellow, 0.28),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.selected ? widget.item.selectedIcon : widget.item.icon,
                color: foreground,
                size: tight ? DMSpacing.iconMd : DMSpacing.iconLg,
              ),
              const SizedBox(height: DMSpacing.xxs),
              Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ),
        );
      },
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            focusColor: DMColors.opacity(DMColors.sunriseYellow, 0.16),
            hoverColor: DMColors.opacity(DMColors.cloudWhite, 0.08),
            onFocusChange: (focused) => setState(() => _focused = focused),
            onTap: widget.onTap,
            child: tile,
          ),
        ),
      ),
    );
  }
}
