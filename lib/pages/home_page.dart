import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../models/persona.dart';
import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';
import '../services/persona_roast_service.dart';
import '../widgets/persona_roast_bubble.dart';
import '../widgets/weather_summary_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WeatherBundle? _weather;
  bool _loading = false;
  String? _error;
  PersonaType _persona = PersonaType.karen;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<WeatherRepository>();
      // TODO: later: use real location
      const lat = 37.7749;
      const lon = -122.4194;
      final data = await repo.getWeather(
        latitude: lat,
        longitude: lon,
        forceRefresh: force,
      );
      setState(() {
        _weather = data;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load weather: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
      // Already here
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.radar);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.burns);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roastService = context.read<PersonaRoastService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grumpy Skies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.about);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadWeather(force: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
          children: [
            const SizedBox(height: 100),
            Center(child: Text(_error!)),
            const SizedBox(height: 8),
            Center(
              child: ElevatedButton(
                onPressed: () => _loadWeather(force: true),
                child: const Text('Retry'),
              ),
            ),
          ],
        )
            : _weather == null
            ? ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No data yet')),
          ],
        )
            : ListView(
          children: [
            WeatherSummaryCard(weather: _weather!),
            const SizedBox(height: 8),
            _buildPersonaSelector(),
            PersonaRoastBubble(
              personaName: _persona.displayName,
              roast: roastService.getRoast(
                persona: _persona,
                weather: _weather!,
              ),
            ),
            // TODO: hourly + daily sections
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.memeGenerator),
        label: const Text('Meme Maker'),
        icon: const Icon(Icons.mood),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.whatshot),
            label: 'Burns',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: PersonaType.values.map((persona) {
          final isSelected = persona == _persona;
          return ChoiceChip(
            label: Text(persona.displayName),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _persona = persona;
              });
            },
          );
        }).toList(),
      ),
    );
  }
}
