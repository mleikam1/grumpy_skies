import 'package:flutter/foundation.dart';
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
  final saved = await showPlanCastSheet<bool>(
      context, _CalendarSelection(controller: controller));
  if (saved == true &&
      context.mounted &&
      controller.selectedCalendarIds.isNotEmpty &&
      needsOnboarding) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const PlanCastSettingsScreen(firstConnection: true)));
  }
}

class _CalendarSelection extends StatefulWidget {
  const _CalendarSelection({required this.controller});
  final PlanCastController controller;
  @override
  State<_CalendarSelection> createState() => _CalendarSelectionState();
}

class _CalendarSelectionState extends State<_CalendarSelection> {
  late final Set<String> _chosen = {...widget.controller.selectedCalendarIds};
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return PopScope(
            canPop: !_saving,
            child: PlanCastSheetContent(
              title: 'Manage calendars',
              subtitle:
                  'Choose which calendars appear in PlanCast. Read-only, always.',
              busy: _saving,
              footer: FilledButton(
                  key: const ValueKey('plancast-save-calendars'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Done')),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.calendars.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: DMSpacing.md),
                          child: Text(
                              'No accessible calendars found. You can keep using the weather app.')),
                    if (c.calendars.isNotEmpty)
                      DecoratedBox(
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context).colorScheme.outline),
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(children: [
                            for (final calendar in c.calendars)
                              Semantics(
                                  selected: _chosen.contains(calendar.id),
                                  child: CheckboxListTile(
                                    key: ValueKey(
                                        'plancast-calendar-${calendar.id}'),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: DMSpacing.sm,
                                        vertical: DMSpacing.xs),
                                    secondary: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: calendar.colorArgb == null
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                : Color(calendar.colorArgb!),
                                            border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline))),
                                    title: Text(calendar.name,
                                        style: DMTypography.labelLarge),
                                    subtitle: calendar.accountName == null
                                        ? null
                                        : Text(calendar.accountName!),
                                    value: _chosen.contains(calendar.id),
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(() {
                                              value == true
                                                  ? _chosen.add(calendar.id)
                                                  : _chosen.remove(calendar.id);
                                            }),
                                  )),
                          ])),
                    const SizedBox(height: DMSpacing.sm),
                    Text(
                        '${_chosen.length} ${_chosen.length == 1 ? 'calendar' : 'calendars'} selected',
                        style: Theme.of(context).textTheme.bodySmall),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Missing a calendar?',
                            style: DMTypography.label),
                        children: [
                          Text(
                              'Add the account in your device calendar settings and make its calendars visible. Then refresh PlanCast.',
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                    if (_error != null)
                      Text(_error!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ]),
            ));
      });

  Future<void> _save() async {
    if (setEquals(_chosen, widget.controller.selectedCalendarIds)) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.selectCalendars(_chosen);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Your calendar selection could not be saved. Please try again.';
        });
      }
    }
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
