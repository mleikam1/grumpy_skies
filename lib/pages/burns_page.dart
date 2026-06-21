import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/persona.dart';
import '../models/weather_models.dart';
import '../config/app_routes.dart';
import '../repositories/weather_repository.dart';
import '../services/persona_roast_service.dart';
import '../services/weather_location_controller.dart';
import '../widgets/persona_roast_bubble.dart';

class BurnsPage extends StatefulWidget {
  const BurnsPage({super.key});

  @override
  State<BurnsPage> createState() => _BurnsPageState();
}

class _BurnsPageState extends State<BurnsPage> {
  WeatherBundle? _weather;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = context.read<WeatherRepository>();
      final location =
          context.read<WeatherLocationController>().selectedLocation;
      if (location == null) {
        setState(() {
          _error = 'Choose a location to load weather roasts.';
          _loading = false;
        });
        return;
      }

      final data = await repo.getWeather(
        latitude: location.latitude,
        longitude: location.longitude,
        location: location,
      );
      setState(() {
        _weather = data;
        _loading = false;
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[GrumpySkies] burns weather load failed: $error');
      }
      setState(() {
        _error =
            'Weather roasts are unavailable. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roastService = context.read<PersonaRoastService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Burns')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _weather == null
                  ? const Center(child: Text('No weather loaded yet.'))
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
