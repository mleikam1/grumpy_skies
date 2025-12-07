import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../progression/models/achievement.dart';
import '../../progression/services/achievement_service.dart';
import '../../progression/services/xp_service.dart';
import '../../progression/widgets/achievement_badge.dart';
import '../../progression/widgets/streak_indicator.dart';
import '../models/persona.dart';
import '../models/roast.dart';
import '../services/roast_engine.dart';
import '../widgets/extra_roasts_section.dart';
import '../widgets/persona_carousel.dart';
import '../widgets/roast_reveal_fog.dart';
import '../widgets/roast_reveal_scratch.dart';
import '../widgets/time_of_day_roasts.dart';
import '../widgets/what_weather_says_card.dart';

class RoastsPage extends StatefulWidget {
  const RoastsPage({super.key});

  @override
  State<RoastsPage> createState() => _RoastsPageState();
}

class _RoastsPageState extends State<RoastsPage> {
  late Persona _selectedPersona;
  final RoastEngine _roastEngine = const RoastEngine();
  final List<bool> _toggleSelections = [true, false];
  late Future<List<Achievement>> _achievementsFuture;

  @override
  void initState() {
    super.initState();
    _selectedPersona = samplePersonas.first;
    _achievementsFuture = Future.value([]);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final xpService = context.read<XpService>();
      final achievementService = context.read<AchievementService>();
      await xpService.markAppOpened();
      final achievements = achievementService.evaluate(xpService.state);
      setState(() {
        _achievementsFuture = Future.value(achievements);
      });
    });
  }

  void _onPersonaSelected(Persona persona) {
    setState(() {
      _selectedPersona = persona;
    });
  }

  void _onToggleChanged(int index) {
    setState(() {
      for (var i = 0; i < _toggleSelections.length; i++) {
        _toggleSelections[i] = i == index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final xpService = context.watch<XpService>();
    final xpState = xpService.state;
    final achievementService = context.read<AchievementService>();
    final dailyRoast = _roastEngine.generateDailyRoast(_selectedPersona);
    final useScratch = _toggleSelections.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roasts'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${xpState.level}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${xpState.currentXp} XP earned',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  StreakIndicator(streakCount: xpState.streakCount),
                ],
              ),
            ),
            PersonaCarousel(
              personas: samplePersonas,
              onPersonaSelected: _onPersonaSelected,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ToggleButtons(
                isSelected: _toggleSelections,
                onPressed: _onToggleChanged,
                borderRadius: BorderRadius.circular(12),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Scratch'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Fog'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (useScratch)
              RoastRevealScratch(
                roast: dailyRoast,
                onRevealed: () => _handleRoastReveal(
                  xpService,
                  achievementService,
                  dailyRoast,
                ),
              )
            else
              RoastRevealFog(
                roast: dailyRoast,
                onRevealed: () => _handleRoastReveal(
                  xpService,
                  achievementService,
                  dailyRoast,
                ),
              ),
            ExtraRoastsSection(
              persona: _selectedPersona,
              roastEngine: _roastEngine,
            ),
            TimeOfDayRoasts(
              persona: _selectedPersona,
              roastEngine: _roastEngine,
              onViewed: (period) => _handleTimeOfDayViewed(
                xpService,
                achievementService,
                period,
              ),
            ),
            const WhatWeatherSaysCard(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: FutureBuilder<List<Achievement>>(
                future: _achievementsFuture,
                builder: (context, snapshot) {
                  final achievements = snapshot.data;
                  if (achievements == null) {
                    return const SizedBox.shrink();
                  }

                  final unlocked =
                      achievements.where((a) => a.unlocked).take(3).toList();
                  final locked =
                      achievements.where((a) => !a.unlocked).take(3).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievements',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          ...unlocked.map(
                            (a) => AchievementBadge(
                              achievement: a,
                              icon: Icons.emoji_events,
                            ),
                          ),
                          ...locked.map(
                            (a) => AchievementBadge(
                              achievement: a,
                              icon: Icons.lock_outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRoastReveal(
    XpService xpService,
    AchievementService achievementService,
    Roast roast,
  ) async {
    await xpService.addXp(20);
    final achievements = achievementService.evaluate(xpService.state, recentRoast: roast);
    setState(() {
      _achievementsFuture = Future.value(achievements);
    });
  }

  Future<void> _handleTimeOfDayViewed(
    XpService xpService,
    AchievementService achievementService,
    String period,
  ) async {
    switch (period) {
      case 'morning':
        await xpService.markViewedMorning();
        break;
      case 'afternoon':
        await xpService.markViewedAfternoon();
        break;
      case 'night':
        await xpService.markViewedNight();
        break;
    }

    final achievements = achievementService.evaluate(xpService.state);
    setState(() {
      _achievementsFuture = Future.value(achievements);
    });
  }
}
