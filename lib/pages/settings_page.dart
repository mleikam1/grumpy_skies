import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../config/app_routes.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PersonaType _persona = PersonaType.karen;
  bool _adsEnabled = true; // TODO: connect to real IAP later

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Persona'),
            subtitle: Text('Choose who roasts your weather'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: PersonaType.values.map((p) {
                return ChoiceChip(
                  label: Text(p.displayName),
                  selected: p == _persona,
                  onSelected: (_) {
                    setState(() {
                      _persona = p;
                    });
                    // TODO: save to shared_preferences
                  },
                );
              }).toList(),
            ),
          ),
          SwitchListTile(
            title: const Text('Show ads'),
            subtitle: const Text('Turn off with premium upgrade'),
            value: _adsEnabled,
            onChanged: (val) {
              setState(() {
                _adsEnabled = val;
              });
              // TODO: connect to IAP flow
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.about),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, AppRoutes.home);
              break;
            case 1:
              Navigator.pushReplacementNamed(context, AppRoutes.radar);
              break;
            case 2:
              Navigator.pushReplacementNamed(context, AppRoutes.burns);
              break;
            case 3:
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
