import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../monetization/monetization_controller.dart';

import '../config/app_routes.dart';
import '../shared/widgets/dm_bottom_nav.dart';
import '../shared/widgets/weather_safety_banner.dart';

class DaymakerShell extends StatefulWidget {
  const DaymakerShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const tabLocations = <String>[
    AppRoutes.forecast,
    AppRoutes.planCast,
    AppRoutes.radar,
    AppRoutes.fun,
  ];

  @override
  State<DaymakerShell> createState() => _DaymakerShellState();

  static int indexForLocation(String location) {
    if (location.startsWith(AppRoutes.planCast)) return 1;
    if (location.startsWith(AppRoutes.radar)) return 2;
    if (location.startsWith(AppRoutes.fun)) return 3;
    if (location.startsWith(AppRoutes.settings)) return -1;
    return 0;
  }
}

class _DaymakerShellState extends State<DaymakerShell> {
  void _syncRoute() {
    context
        .read<MonetizationController?>()
        ?.setRoute(widget.location, deferNotification: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRoute();
  }

  @override
  void didUpdateWidget(DaymakerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRoute();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final child = widget.child;
    final currentIndex = DaymakerShell.indexForLocation(location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final showNavigation = !location.startsWith(AppRoutes.settings) &&
            !location.startsWith(AppRoutes.memeGenerator);
        final bottomReserve = showNavigation
            ? DmBottomNav.reservedHeightFor(context, width)
            : 0.0;

        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: bottomReserve,
                left: 0,
                child: Column(children: [
                  if (location != AppRoutes.forecast)
                    const WeatherSafetyBanner(),
                  Expanded(child: child),
                ]),
              ),
              if (showNavigation)
                Positioned(
                  right: 0,
                  bottom: 0,
                  left: 0,
                  child: DmBottomNav(
                    currentIndex: currentIndex,
                    onDestinationSelected: (index) {
                      final destination = DaymakerShell.tabLocations[index];
                      if (location == destination) return;
                      context
                          .read<MonetizationController?>()
                          ?.setRoute(destination);
                      context.go(destination);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
