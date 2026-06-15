import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_routes.dart';
import '../features/forecast/forecast_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/roasts/models/persona.dart';
import '../features/roasts/roasts_screen.dart';
import '../features/roasts/services/roast_engine.dart';
import '../features/roasts/widgets/roast_reveal_fog.dart';
import '../features/roasts/widgets/roast_reveal_scratch.dart';
import '../pages/about_page.dart';
import '../pages/home_page.dart';
import '../pages/meme_generator_page.dart';
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
              builder: (context, state) => const _AdvancedRoastRevealPage(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.radar,
          name: 'radar',
          builder: (context, state) => const HomePage.routeTab(tabIndex: 2),
        ),
        GoRoute(
          path: AppRoutes.fun,
          name: 'fun',
          builder: (context, state) => const HomePage.routeTab(tabIndex: 3),
          routes: [
            GoRoute(
              path: 'meme',
              name: 'memeGenerator',
              builder: (context, state) => const MemeGeneratorPage(),
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

class _AdvancedRoastRevealPage extends StatefulWidget {
  const _AdvancedRoastRevealPage();

  @override
  State<_AdvancedRoastRevealPage> createState() =>
      _AdvancedRoastRevealPageState();
}

class _AdvancedRoastRevealPageState extends State<_AdvancedRoastRevealPage> {
  final RoastEngine _roastEngine = const RoastEngine();
  var _selectedPersona = samplePersonas.first;
  var _useScratch = true;

  @override
  Widget build(BuildContext context) {
    final roast = _roastEngine.generateDailyRoast(_selectedPersona);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Roast Reveal'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<Persona>(
              initialValue: _selectedPersona,
              decoration: const InputDecoration(
                labelText: 'Persona',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final persona in samplePersonas)
                  DropdownMenuItem(
                    value: persona,
                    child: Text(persona.name),
                  ),
              ],
              onChanged: (persona) {
                if (persona == null) return;
                setState(() => _selectedPersona = persona);
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.gesture),
                  label: Text('Scratch'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.foggy),
                  label: Text('Fog'),
                ),
              ],
              selected: {_useScratch},
              onSelectionChanged: (selection) {
                setState(() => _useScratch = selection.first);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_useScratch)
            RoastRevealScratch(roast: roast)
          else
            RoastRevealFog(roast: roast),
        ],
      ),
    );
  }
}
