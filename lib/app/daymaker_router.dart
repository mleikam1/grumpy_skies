import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../features/forecast/forecast_screen.dart';
import '../features/fun/meme_generator_screen.dart';
import '../features/fun/fun_zone_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/roasts/advanced_roast_reveal_screen.dart';
import '../features/roasts/roasts_screen.dart';
import '../pages/about_page.dart';
import '../pages/home_page.dart';
import 'daymaker_shell.dart';

final daymakerRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) => AppRoutes.splash,
    ),
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return DaymakerShell(
          location: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: AppRoutes.forecast,
          name: 'forecast',
          builder: (context, state) => const ForecastScreen(),
        ),
        GoRoute(
          path: AppRoutes.roasts,
          name: 'roasts',
          builder: (context, state) => const RoastsScreen(),
          routes: [
            GoRoute(
              path: 'reveal',
              name: 'roastReveal',
              builder: (context, state) => const AdvancedRoastRevealScreen(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.radar,
          name: 'radar',
          builder: (context, state) => const RadarScreen(),
        ),
        GoRoute(
          path: AppRoutes.fun,
          name: 'fun',
          builder: (context, state) => const FunZoneScreen(),
          routes: [
            GoRoute(
              path: 'meme',
              name: 'memeGenerator',
              builder: (context, state) => const MemeGeneratorScreen(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) => const HomePage.routeTab(tabIndex: 4),
          routes: [
            GoRoute(
              path: 'about',
              name: 'about',
              builder: (context, state) => const AboutPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/home',
      redirect: (_, __) => AppRoutes.forecast,
    ),
    GoRoute(
      path: '/burns',
      redirect: (_, __) => AppRoutes.roasts,
    ),
    GoRoute(
      path: '/meme-generator',
      redirect: (_, __) => AppRoutes.memeGenerator,
    ),
    GoRoute(
      path: '/about',
      redirect: (_, __) => AppRoutes.about,
    ),
  ],
);
