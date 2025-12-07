import 'package:flutter/material.dart';

import '../models/persona.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedPersona = samplePersonas.first;
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
              RoastRevealScratch(roast: dailyRoast)
            else
              RoastRevealFog(roast: dailyRoast),
            ExtraRoastsSection(
              persona: _selectedPersona,
              roastEngine: _roastEngine,
            ),
            TimeOfDayRoasts(
              persona: _selectedPersona,
              roastEngine: _roastEngine,
            ),
            const WhatWeatherSaysCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
