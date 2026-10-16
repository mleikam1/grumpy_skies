import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../plancast_controller.dart';
import 'plancast_screen.dart';
import '../widgets/plancast_location_controls.dart';

Future<void> selectPlanCastCalendars(
    BuildContext context, PlanCastController controller) async {
  final needsOnboarding = controller.selectedCalendarIds.isEmpty;
  final chosen = controller.selectedCalendarIds.toSet();
  final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: const Text('Choose calendars'),
                content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                              'Only calendars you select are read. Add missing accounts to your device calendar settings, make their calendars visible, then refresh PlanCast.'),
                          if (controller.calendars.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: DMSpacing.md),
                                child: Text(
                                    'No accessible calendars found. You can keep using the weather app.')),
                          for (final calendar in controller.calendars)
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(calendar.name),
                                value: chosen.contains(calendar.id),
                                onChanged: (value) => setState(() {
                                      if (value == true) {
                                        chosen.add(calendar.id);
                                      } else {
                                        chosen.remove(calendar.id);
                                      }
                                    })),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Use selected calendars')),
                ],
              )));
  if (saved != true) return;
  await controller.selectCalendars(chosen);
  if (context.mounted && chosen.isNotEmpty && needsOnboarding) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const PlanCastSettingsScreen(firstConnection: true)));
  }
}

class PlanCastSettingsScreen extends StatelessWidget {
  const PlanCastSettingsScreen({super.key, this.firstConnection = false});
  final bool firstConnection;
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlanCastController>();
    final prefs = controller.preferences;
    void update(PlanCastPreferences value) =>
        controller.updatePreferences(value);
    return Scaffold(
        appBar: AppBar(
            title: Text(firstConnection
                ? 'Your briefing preferences'
                : 'PlanCast settings')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                        padding: const EdgeInsets.all(DMSpacing.md),
                        children: [
                          if (firstConnection) ...[
                            const Text('Connected on your terms',
                                style: DMTypography.headingSmall),
                            const Text(
                                'Your text briefing is ready. Reading aloud and notifications are optional. You can finish without enabling either.'),
                            const SizedBox(height: DMSpacing.md),
                          ],
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Selected calendars'),
                              subtitle: Text(
                                  '${controller.selectedCalendarIds.length} selected · ${controller.calendarPermission}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  selectPlanCastCalendars(context, controller)),
                          TextButton.icon(
                              onPressed: controller.loading
                                  ? null
                                  : controller.refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                  'Refresh / find missing calendars')),
                          const Divider(),
                          const PlanCastSmartLocationSettings(),
                          const Divider(),
                          const Text('Briefing and event heads-ups',
                              style: DMTypography.headingSmall),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('PlanCast notifications'),
                              subtitle: Text(
                                  'Separate from weather alerts · ${controller.notificationPermission}'),
                              value: prefs.notifications,
                              onChanged: (value) async {
                                if (value) {
                                  await controller.requestNotifications();
                                } else {
                                  await controller.updatePreferences(
                                      prefs.copyWith(notifications: false));
                                }
                              }),
                          if (controller.error != null) Text(controller.error!),
                          _time(
                              context,
                              'Morning briefing',
                              prefs.morningMinute,
                              (minute) =>
                                  update(prefs.copyWith(morningMinute: minute)),
                              subtitle:
                                  'Device-local time. One morning briefing by default.'),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Weather-affected event heads-ups'),
                              subtitle: const Text(
                                  'Only material weather impacts. At most two additional routine notices per day.'),
                              value: prefs.eventHeadsUp,
                              onChanged: (value) =>
                                  update(prefs.copyWith(eventHeadsUp: value))),
                          _choices<int>(
                              'How far ahead?',
                              prefs.eventLeadMinutes,
                              const {
                                30: '30 min',
                                60: '1 hour',
                                120: '2 hours',
                                240: '4 hours'
                              },
                              (value) => update(
                                  prefs.copyWith(eventLeadMinutes: value))),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Optional day-before heads-up'),
                              value: prefs.dayBefore,
                              onChanged: (value) =>
                                  update(prefs.copyWith(dayBefore: value))),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Evening “Tomorrow” briefing'),
                              value: prefs.evening,
                              onChanged: (value) =>
                                  update(prefs.copyWith(evening: value))),
                          if (prefs.evening)
                            _time(
                                context,
                                'Evening briefing',
                                prefs.eveningMinute,
                                (minute) => update(
                                    prefs.copyWith(eveningMinute: minute))),
                          const Divider(),
                          const Text('Quiet hours',
                              style: DMTypography.headingSmall),
                          _time(
                              context,
                              'Quiet hours start',
                              prefs.quietStartMinute,
                              (minute) => update(
                                  prefs.copyWith(quietStartMinute: minute))),
                          _time(
                              context,
                              'Quiet hours end',
                              prefs.quietEndMinute,
                              (minute) => update(
                                  prefs.copyWith(quietEndMinute: minute)),
                              subtitle:
                                  'Routine notices wait until quiet hours end and are skipped if no longer useful. Matching start and end disables quiet hours.'),
                          const Divider(),
                          const Text('Privacy controls',
                              style: DMTypography.headingSmall),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title:
                                  const Text('Detailed lock-screen previews'),
                              subtitle: const Text(
                                  'Off by default. Turning on allows event titles and weather details in PlanCast notifications.'),
                              value: prefs.detailedNotificationPreviews,
                              onChanged: (value) => update(prefs.copyWith(
                                  detailedNotificationPreviews: value))),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Speak private event titles'),
                              subtitle: const Text(
                                  'Off by default. Spoken briefings use an offline system voice in the device language. Always started by you; never autoplayed.'),
                              value: prefs.spokenPrivateTitles,
                              onChanged: (value) => update(
                                  prefs.copyWith(spokenPrivateTitles: value))),
                          const Divider(),
                          _choices<int>(
                              'Arrival and leaving buffer',
                              prefs.bufferMinutes,
                              const {
                                0: 'None',
                                15: '15 min',
                                30: '30 min',
                                60: '1 hour'
                              },
                              (value) =>
                                  update(prefs.copyWith(bufferMinutes: value))),
                          const Text(
                              'These are planning buffers around your event, not travel estimates. PlanCast does not calculate a route, assume an origin, or make routing calls.',
                              style: DMTypography.bodySmall),
                          const SizedBox(height: DMSpacing.lg),
                          const Text('How timely are notifications?',
                              style: DMTypography.headingSmall),
                          const Text(
                              'Notifications are scheduled on this device. A scheduled notice does not refresh the weather when it arrives. Background work is best-effort; the operating system can delay or prevent it. Weather-specific text is used only within a short freshness window and includes when it was checked. Otherwise a generic reminder invites you to open PlanCast.\n\nCalendar changes while the app cannot run may not appear until the next sync. Device restart and time-zone changes can also require opening PlanCast. Notifications do not guarantee fresh weather, exact delivery, or continuous monitoring.'),
                          const SizedBox(height: DMSpacing.lg),
                          const Text('Your calendar data',
                              style: DMTypography.headingSmall),
                          const Text(planCastPrivacyExplanation),
                          const SizedBox(height: DMSpacing.md),
                          const Text(
                              'Snapshots stay in memory. Intentional location choices use protected app-local storage. Temporary provider responses and trip contexts expire separately. Disconnect removes PlanCast data and cancels only its notices. Permission revocation is checked when the app or background maintenance can run; cleanup cannot execute while the OS has suspended the app.',
                              style: DMTypography.bodySmall),
                          TextButton.icon(
                              icon: const Icon(Icons.link_off),
                              label: const Text(
                                  'Disconnect and delete calendar data'),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Disconnect PlanCast?'),
                                            content: const Text(
                                                'Delete this feature’s stored choices and venue overrides, clear its calendar data, and cancel its pending notices. Source calendar events are unchanged.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text(
                                                      'Keep connected')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text(
                                                      'Disconnect and delete'))
                                            ]));
                                if (confirmed == true) {
                                  await controller.disconnect();
                                  if (context.mounted) Navigator.pop(context);
                                }
                              }),
                          if (firstConnection)
                            FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('View my PlanCast')),
                        ])))));
  }

  Widget _time(BuildContext context, String title, int minute,
          ValueChanged<int> changed, {String? subtitle}) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: Text(TimeOfDay(hour: minute ~/ 60, minute: minute % 60)
              .format(context)),
          onTap: () async {
            final result = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
            if (result != null) changed(result.hour * 60 + result.minute);
          });
  Widget _choices<T>(String title, T selected, Map<T, String> choices,
          ValueChanged<T> changed) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: DMTypography.labelLarge),
            const SizedBox(height: DMSpacing.xs),
            Wrap(spacing: DMSpacing.sm, children: [
              for (final choice in choices.entries)
                ChoiceChip(
                    label: Text(choice.value),
                    selected: selected == choice.key,
                    onSelected: (_) => changed(choice.key))
            ])
          ]));
}
