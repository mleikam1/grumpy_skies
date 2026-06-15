import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../shared/widgets/dm_bottom_nav.dart';

class DaymakerShell extends StatelessWidget {
  const DaymakerShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const _bottomNavReserve = 96.0;

  static const tabLocations = <String>[
    AppRoutes.forecast,
    AppRoutes.roasts,
    AppRoutes.radar,
    AppRoutes.fun,
    AppRoutes.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = indexForLocation(location);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            bottom: _bottomNavReserve,
            left: 0,
            child: child,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            child: DmBottomNav(
              currentIndex: currentIndex,
              onDestinationSelected: (index) {
                final destination = tabLocations[index];
                if (location == destination) return;
                context.go(destination);
              },
            ),
          ),
        ],
      ),
    );
  }

  static int indexForLocation(String location) {
    if (location.startsWith(AppRoutes.roasts)) return 1;
    if (location.startsWith(AppRoutes.radar)) return 2;
    if (location.startsWith(AppRoutes.fun)) return 3;
    if (location.startsWith(AppRoutes.settings)) return 4;
    return 0;
  }
}
