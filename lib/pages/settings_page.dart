import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../features/settings/settings_screen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class SettingsContent extends StatelessWidget {
  const SettingsContent({
    super.key,
    this.initialPersona,
    this.onPersonaChanged,
    this.showAboutTile = false,
  });

  final PersonaType? initialPersona;
  final ValueChanged<PersonaType>? onPersonaChanged;
  final bool showAboutTile;

  @override
  Widget build(BuildContext context) => const SettingsScreenBody();
}
