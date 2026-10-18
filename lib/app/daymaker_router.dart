import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../features/plancast/screens/plancast_screen.dart';
import '../features/forecast/forecast_screen.dart';
import '../features/fun/meme_generator_screen.dart';
import '../features/fun/fun_zone_screen.dart';
import '../features/radar/radar_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import 'daymaker_shell.dart';
import '../monetization/ad_modal_observer.dart';

final daymakerRouter = createDaymakerRouter();

GoRouter createDaymakerRouter({String initialLocation = AppRoutes.splash}) =>
    GoRouter(
      initialLocation: initialLocation,
      redirect: (_, state) => AppRoutes.retiredRedirect(state.uri),
      observers: [AdModalObserver()],
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
          observers: [AdModalObserver()],
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
              path: AppRoutes.planCast,
              name: 'plancast',
              builder: (context, state) => PlanCastScreen(
                eventId: state.uri.queryParameters['event'],
                day: DateTime.tryParse(state.uri.queryParameters['day'] ?? ''),
              ),
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
                  builder: (context, state) => MemeGeneratorScreen(
                    initialTemplateId: state.uri.queryParameters['template'],
                    initialDocumentId: state.uri.queryParameters['document'],
                  ),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.settings,
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'about',
                  name: 'about',
                  builder: (context, state) => const AboutScreen(),
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
          redirect: (_, __) => AppRoutes.forecast,
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
