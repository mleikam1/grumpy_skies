import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/guidance_preferences.dart';
import '../../../services/settings_controller.dart';

class GuidancePreferencesTile extends StatelessWidget {
  const GuidancePreferencesTile({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Material(
        color: Colors.transparent,
        child: ListTile(
          leading: const Icon(Icons.lightbulb_outline_rounded),
          title: const Text('Wingman tips'),
          subtitle: Text(settings.guidance.enabled
              ? 'Practical advice for your weather and optional activities.'
              : 'Tips are off.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => ChangeNotifierProvider.value(
                value: settings, child: const _GuidancePreferencesSheet()),
          ),
        ));
  }
}

class _GuidancePreferencesSheet extends StatelessWidget {
  const _GuidancePreferencesSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final p = settings.guidance;
    void update(GuidancePreferences value) =>
        settings.setGuidancePreferences(value);
    Future<void> time(bool start) async {
      final minutes = start ? p.commuteStartMinute : p.commuteEndMinute;
      final result = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
      if (result == null) return;
      final value = result.hour * 60 + result.minute;
      update(start
          ? settings.guidance.copyWith(commuteStartMinute: value)
          : settings.guidance.copyWith(commuteEndMinute: value));
    }

    String clock(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
    return FractionallySizedBox(
      heightFactor: .86,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(children: [
            Expanded(
                child: Text('Wingman tips',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close tip preferences',
                icon: const Icon(Icons.close)),
          ]),
          SwitchListTile.adaptive(
              title: const Text('Show weather tips'),
              subtitle: const Text('Uses the forecast already on your device.'),
              value: p.enabled,
              onChanged: (v) => update(p.copyWith(enabled: v))),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  'Optional interests help tailor advice. They do not mean '
                  'you have an outing planned. These choices stay on this device.')),
          SwitchListTile.adaptive(
              title: const Text('Dog walking'),
              value: p.dogWalking,
              onChanged: (v) => update(p.copyWith(dogWalking: v))),
          SwitchListTile.adaptive(
              title: const Text('Cycling'),
              value: p.cycling,
              onChanged: (v) => update(p.copyWith(cycling: v))),
          SwitchListTile.adaptive(
              title: const Text('Walking or running'),
              value: p.walking,
              onChanged: (v) => update(p.copyWith(walking: v))),
          SwitchListTile.adaptive(
              title: const Text('Driving to work'),
              value: p.driving,
              onChanged: (v) => update(p.copyWith(driving: v))),
          ListTile(
              title: const Text('Outing duration'),
              subtitle: Text('${p.outingMinutes} minutes'),
              trailing: DropdownButton<int>(
                  value: [15, 30, 45, 60, 90, 120].contains(p.outingMinutes)
                      ? p.outingMinutes
                      : null,
                  hint: Text('${p.outingMinutes} min'),
                  items: [15, 30, 45, 60, 90, 120]
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) update(p.copyWith(outingMinutes: v));
                  })),
          if (p.driving) ...[
            const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Commute days')),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 6, children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun'
                      ][i]),
                      selected: p.commutesOn(i + 1),
                      onSelected: (selected) => update(p.copyWith(
                          commuteDaysMask: selected
                              ? p.commuteDaysMask | (1 << i)
                              : p.commuteDaysMask & ~(1 << i))),
                    ),
                ])),
            const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Commute window · forecast location time\n'
                    'Weather for the area you are viewing; no route or traffic data.')),
            ListTile(
                title: const Text('Window starts'),
                trailing: Text(clock(p.commuteStartMinute)),
                onTap: () => time(true)),
            ListTile(
                title: const Text('Window ends'),
                subtitle: p.commuteEndMinute <= p.commuteStartMinute
                    ? const Text('Ends the following day')
                    : null,
                trailing: Text(clock(p.commuteEndMinute)),
                onTap: () => time(false)),
          ],
        ],
      ),
    );
  }
}
