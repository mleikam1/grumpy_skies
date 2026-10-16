import 'package:flutter/material.dart';
import '../../design/dm_theme.dart';

class DmBottomNavItem {
  const DmBottomNavItem(
      {required this.label,
      required this.icon,
      IconData? selectedIcon,
      String? semanticLabel})
      : selectedIcon = selectedIcon ?? icon,
        semanticLabel = semanticLabel ?? label;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String semanticLabel;
}

class DmBottomNav extends StatelessWidget {
  static const _barRadius = 30.0;
  static const _barInset = 4.0;

  const DmBottomNav(
      {super.key,
      required this.currentIndex,
      required this.onDestinationSelected,
      this.items = defaultItems})
      : assert(items.length == 4,
            'DmBottomNav expects exactly four destinations.');
  static const List<DmBottomNavItem> defaultItems = [
    DmBottomNavItem(
        label: 'Today',
        icon: Icons.wb_sunny_outlined,
        semanticLabel: 'Today tab'),
    DmBottomNavItem(
        label: 'Radar', icon: Icons.radar, semanticLabel: 'Radar tab'),
    DmBottomNavItem(
        label: 'Roasts',
        icon: Icons.local_fire_department_outlined,
        semanticLabel: 'Roasts tab'),
    DmBottomNavItem(
        label: 'Fun',
        icon: Icons.emoji_emotions_outlined,
        semanticLabel: 'Fun tab'),
  ];
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DmBottomNavItem> items;

  static double reservedHeightFor(BuildContext context, double width) =>
      MediaQuery.paddingOf(context).bottom +
      70 +
      (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0, 22);

  BorderRadius _itemRadius(int index, TextDirection direction) {
    // Keep the end selection concentric with the bar's inset rounded edge.
    const outer = Radius.circular(_barRadius - _barInset);
    const inner = Radius.circular(21);
    return BorderRadiusDirectional.horizontal(
      start: index == 0 ? outer : inner,
      end: index == items.length - 1 ? outer : inner,
    ).resolve(direction);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dmColors;
    final direction = Directionality.of(context);
    return Semantics(
        container: true,
        label: 'Primary navigation',
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Material(
                        color: colors.navSurface,
                        elevation: 3,
                        shadowColor: colors.shadow,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_barRadius),
                            side: BorderSide(color: colors.border)),
                        child: Padding(
                            padding: const EdgeInsets.all(_barInset),
                            child: Row(children: [
                              for (var index = 0; index < items.length; index++)
                                Expanded(
                                    child: Semantics(
                                  selected: index == currentIndex,
                                  button: true,
                                  label: items[index].semanticLabel,
                                  child: ExcludeSemantics(
                                      child: InkWell(
                                    borderRadius: _itemRadius(index, direction),
                                    onTap: () => onDestinationSelected(index),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 52),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: index == currentIndex
                                              ? colors.navSelected
                                              : Colors.transparent,
                                          borderRadius:
                                              _itemRadius(index, direction)),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                index == currentIndex
                                                    ? items[index].selectedIcon
                                                    : items[index].icon,
                                                size: 24,
                                                color: index == currentIndex
                                                    ? colors
                                                        .navSelectedForeground
                                                    : colors.navInactive),
                                            const SizedBox(height: 3),
                                            Text(items[index].label,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    height: 1.2,
                                                    fontWeight:
                                                        index == currentIndex
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                    color: index == currentIndex
                                                        ? colors
                                                            .navSelectedForeground
                                                        : colors.navInactive)),
                                          ]),
                                    ),
                                  )),
                                )),
                            ])),
                      ))),
            )));
  }
}
