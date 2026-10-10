import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../design/dm_theme.dart';
import '../../services/weather_location_controller.dart';
import '../fun/meme/meme_weather.dart';
import 'models/roast_persona.dart';
import 'services/displayed_roast_share.dart';
import 'services/roast_safety.dart';
import 'widgets/advanced_roast_reveal_card.dart';

/// Reveal is a presentation of an already displayed roast, never a new request.
class AdvancedRoastRevealScreen extends StatefulWidget {
  const AdvancedRoastRevealScreen({super.key, this.initialRoast});
  final DisplayedRoastSnapshot? initialRoast;

  @override
  State<AdvancedRoastRevealScreen> createState() =>
      _AdvancedRoastRevealScreenState();
}

class _AdvancedRoastRevealScreenState extends State<AdvancedRoastRevealScreen> {
  bool _initialized = false;
  bool _revealed = false;
  DisplayedRoastSnapshot? _source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // Read once. Later source updates, theme changes, and units cannot reroll or
    // replace the text waiting behind the reveal card.
    _source = widget.initialRoast ??
        context.read<DisplayedRoastRegistry?>()?.choices.firstOrNull;
  }

  void _goBack() {
    final router = GoRouter.maybeOf(context);
    if (router?.canPop() == true) {
      router!.pop();
    } else {
      router?.go(AppRoutes.roasts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final location = context.watch<WeatherLocationController?>();
    final officialAlert =
        location?.safetyStatus == WeatherSafetyStatus.activeAlert;
    final alert = officialAlert ||
        roastHumorBlocked(location?.currentWeather,
            selection: source?.selection);
    final persona =
        source == null ? null : RoastPersonas.byId(source.personaId);
    final city = source?.weatherSnapshot?['city'];
    return Scaffold(
      body: SafeArea(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    IconButton(
                        tooltip: 'Back to Roasts',
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Roast reveal',
                            style: Theme.of(context).textTheme.headlineLarge)),
                  ]),
                  const SizedBox(height: 18),
                  if (alert)
                    _state(context,
                        title: officialAlert
                            ? 'Weather alerts take priority'
                            : 'Weather safety takes priority',
                        message:
                            'Roasts are paused for these conditions. Check the current weather and official guidance.',
                        action: 'View weather',
                        onAction: () => context.go(AppRoutes.forecast))
                  else if (source == null)
                    _state(context,
                        title: 'Choose a roast to reveal',
                        message:
                            'Open Roasts to choose a voice and a weather take.',
                        action: 'Open Roasts',
                        onAction: () => context.go(AppRoutes.roasts))
                  else ...[
                    Text('A little suspense. The same forecast.',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        city is String && city.isNotEmpty
                            ? '$city · ${source.sourceLabel}'
                            : source.sourceLabel,
                        style:
                            TextStyle(color: context.dmColors.textSecondary)),
                    const SizedBox(height: 18),
                    AdvancedRoastRevealCard(
                      revealed: _revealed,
                      personaName: persona!.displayName,
                      avatarAsset: persona.assetPath,
                      personaId: source.personaId,
                      mood: source.mood,
                      roastText: source.text,
                      xpReward: 0,
                      onToggleReveal: () =>
                          setState(() => _revealed = !_revealed),
                      onRevealGesture: () {
                        if (!_revealed) setState(() => _revealed = true);
                      },
                      onShare: () =>
                          showDisplayedRoastShareSheet(context, source),
                    ),
                    const SizedBox(height: 16),
                    // The gesture has a real focusable control and a meaningful 48dp
                    // target for keyboard/screen-reader users.
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _revealed = !_revealed),
                      icon: Icon(_revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      label: Text(_revealed ? 'Hide roast' : 'Reveal roast'),
                    ),
                    const SizedBox(height: 12),
                    Text('Tap or drag the card, or use the reveal button.',
                        style:
                            TextStyle(color: context.dmColors.textSecondary)),
                    const SizedBox(height: 12),
                    Text(MemeWeather.statusLabel(source.weatherSnapshot),
                        style: TextStyle(
                            fontSize: 12, color: context.dmColors.textMuted)),
                  ],
                ]),
          ))
        ],
      )),
    );
  }

  Widget _state(BuildContext context,
          {required String title,
          required String message,
          required String action,
          required VoidCallback onAction}) =>
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: context.dmColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.dmColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(action)),
        ]),
      );
}
