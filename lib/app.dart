import 'package:flutter/material.dart';

import 'config/app_routes.dart';
import 'pages/splash_page.dart';
import 'pages/home_page.dart';
import 'pages/meme_generator_page.dart';
import 'pages/about_page.dart';

class GrumpySkiesApp extends StatelessWidget {
  const GrumpySkiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grumpy Skies',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
        brightness: Brightness.light,
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashPage(),
        AppRoutes.home: (_) => const HomePage(),
        AppRoutes.radar: (_) => const HomePage(initialTab: 2),
        AppRoutes.burns: (_) => const HomePage(initialTab: 1),
        AppRoutes.memeGenerator: (_) => const MemeGeneratorPage(),
        AppRoutes.settings: (_) => const HomePage(initialTab: 4),
        AppRoutes.about: (_) => const AboutPage(),
      },
    );
  }
}
