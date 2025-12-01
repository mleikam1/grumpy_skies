import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/persona.dart';
import '../models/weather_models.dart';
import '../repositories/weather_repository.dart';
import '../services/persona_roast_service.dart';
import '../widgets/persona_roast_bubble.dart';
import '../config/app_routes.dart';

class BurnsPage extends StatefulWidget {
  const BurnsPage({super.key});

  @override
  State<BurnsPage> createState() => _BurnsPageState();
}

class _BurnsPageState extends State<BurnsPage> {
  WeatherBundle? _weather;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<WeatherRepository>();
    const lat = 37.7749;
    const lon = -122.4194;
    final data = await repo.getWeather(latitude: lat, longitude: lon);
    setState(() {
      _weather = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roastService = context.read<PersonaRoastService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Burns')),
      body: _loading || _weather == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          const SizedBox(height: 8),
          ...PersonaType.values.map((persona) {
            final roast = roastService.getRoast(
              persona: persona,
              weather: _weather!,
            );
            return PersonaRoastBubble(
              personaName: persona.displayName,
              roast: roast,
            );
          }),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, AppRoutes.home);
              break;
            case 1:
              Navigator.pushReplacementNamed(context, AppRoutes.radar);
              break;
            case 2:
              break;
            case 3:
              Navigator.pushReplacementNamed(context, AppRoutes.settings);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.whatshot), label: 'Burns'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
