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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final breakpoint = DMBreakpoints.fromWidth(width);
    final maxWidth = breakpoint.isCompact ? double.infinity : 720.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DMSpacing.md,
          DMSpacing.xs,
          DMSpacing.md,
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
  }
}

class _DmBottomNavTile extends StatelessWidget {
  const _DmBottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DmBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = DMMotion.resolve(context, DMMotion.fast);
    final foreground = selected ? DMColors.deepNavy : DMColors.textMuted;
    final background = selected ? DMColors.skyBlue : Colors.transparent;

    final tile = AnimatedContainer(
      duration: duration,
      curve: DMMotion.easeOut,
      constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.xs,
        vertical: DMSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: DMRadius.full,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? item.selectedIcon : item.icon,
            color: foreground,
            size: DMSpacing.iconLg,
          ),
          const SizedBox(height: DMSpacing.xxs),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.labelSmall.copyWith(color: foreground),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: tile,
          ),
        ),
      ),
    );
  }
}
