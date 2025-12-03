import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/persona.dart';
import '../config/app_routes.dart';
import '../models/temperature_unit.dart';
import '../services/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const SettingsContent(showAboutTile: true),
    );
  }
}

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key, this.initialPersona, this.onPersonaChanged, this.showAboutTile = false});

  final PersonaType? initialPersona;
  final ValueChanged<PersonaType>? onPersonaChanged;
  final bool showAboutTile;

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  late PersonaType _persona;
  bool _adsEnabled = true; // TODO: connect to real IAP later

  @override
  void initState() {
    super.initState();
    _persona = widget.initialPersona ?? PersonaType.karen;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const ListTile(
          title: Text('Temperature units'),
          subtitle: Text('Default is Fahrenheit'),
        ),
        ...TemperatureUnit.values.map(
          (unit) => RadioListTile<TemperatureUnit>(
            title: Text(unit.label),
            value: unit,
            groupValue: settings.temperatureUnit,
            onChanged: (value) {
              if (value != null) {
                settings.setTemperatureUnit(value);
              }
            },
          ),
        ),
        const Divider(),
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
                  widget.onPersonaChanged?.call(p);
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
        if (widget.showAboutTile)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => Navigator.pushNamed(context, AppRoutes.about),
          ),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('Feedback'),
          subtitle: const Text('Complain here… we probably won’t read it.'),
          onTap: () {},
        ),
      ],
    );
  }
}
