import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_theme.dart';
import '../../../design/dm_typography.dart';
import '../../../models/temperature_unit.dart';
import '../../../services/settings_controller.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../plancast_controller.dart';
import '../widgets/plancast_event_card.dart';
import '../widgets/plancast_location_controls.dart';
import '../widgets/plancast_presentation.dart';
import 'plancast_settings_screen.dart';
import 'plancast_time_format.dart';

export 'plancast_time_format.dart';
export '../widgets/plancast_event_card.dart';

const planCastPrivacyExplanation =
    'PlanCast reads only the device calendars you select. Accounts must be available to the operating system; a standalone calendar app may not expose its events. '
    'We never create, edit, or delete source events or their reminders. On iOS, full calendar access is required to read existing events, even though PlanCast is read-only.\n\n'
    'Calendar processing and briefings stay on this device. Coordinates go to the weather service. Optional online location matching sends only a locally extracted city, venue or address query—not full titles, descriptions, dates, guests, or meeting links. '
    'No calendar data is sent to ads, analytics, or AI services. Notifications are a separate, optional choice.';

class PlanCastScreen extends StatefulWidget {
  const PlanCastScreen({super.key, this.eventId, this.day});
  final String? eventId;
  final DateTime? day;

  @override
  State<PlanCastScreen> createState() => _PlanCastScreenState();
}

class _PlanCastScreenState extends State<PlanCastScreen> {
  int _view = 0;
  bool _changedView = false;
  String? _feedCalendarId;
  String? _speechMessage;
  DateTime? _speakingDay;
  int _speechRequest = 0;
  bool _openedLink = false;
  PlanCastController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<PlanCastController?>();
  }

  @override
  void dispose() {
    _speechRequest++;
    unawaited(_controller?.stopSpeaking());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanCastController?>();
    return Scaffold(
      appBar: AppBar(title: const Text('PlanCast'), actions: [
        if (c?.supported == true) ...[
          IconButton(
              tooltip: 'Manage calendars',
              onPressed: () => selectPlanCastCalendars(context, c!),
              icon: const Icon(Icons.calendar_month_outlined)),
          IconButton(
              tooltip: 'PlanCast settings',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PlanCastSettingsScreen())),
              icon: const Icon(Icons.tune)),
        ],
      ]),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: c == null
                ? const Padding(
                    padding: EdgeInsets.all(DMSpacing.lg),
                    child: Text(
                        'PlanCast is unavailable in this session. Your weather forecast is still available.'))
                : _body(context, c),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PlanCastController c) {
    if (!c.supported) {
      return const Padding(
          padding: EdgeInsets.all(DMSpacing.lg),
          child: Text(
              'Device calendars are supported in the Android and iOS app. Web browsers cannot connect to your device calendars.'));
    }
    if (!c.connected) return _connect(c);
    final now = c.clock().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = _changedView ? null : widget.day;
    final week = _view == 2 && requestedDay == null;
    final day = requestedDay ??
        DateTime(today.year, today.month, today.day + (_view == 1 ? 1 : 0));
    final calendarId = c.selectedCalendarIds.contains(_feedCalendarId)
        ? _feedCalendarId
        : null;
    final filter = calendarId == null ? null : {calendarId};
    final settings = context.watch<SettingsController?>();
    final persona = settings?.selectedPersonaId ?? 'karen';
    final unit = settings?.temperatureUnit ?? TemperatureUnit.fahrenheit;
    final range =
        week ? c.summaryForRange(today, calendarFilter: filter) : null;
    final summary = week ? null : c.summaryForDay(day, calendarFilter: filter);
    final items = range?.events ?? summary!.events;
    final linked = widget.eventId == null
        ? null
        : c.currentEvents
            .where((e) => e.event.id == widget.eventId)
            .firstOrNull;
    if (linked != null && !_openedLink && !c.loading) {
      _openedLink = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openPlanCastEvent(context, linked);
      });
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        key: PageStorageKey(
            'plancast-$_view-${calendarId ?? 'all'}-${requestedDay ?? ''}'),
        padding: const EdgeInsets.all(DMSpacing.md),
        children: [
          _daySelectors(requestedDay),
          const SizedBox(height: DMSpacing.sm),
          if (summary != null) _persona(c, summary, persona, unit, filter),
          if (range != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DMSpacing.xs),
              child: Text(
                  'This week · ${MaterialLocalizations.of(context).formatMediumDate(today)} – ${MaterialLocalizations.of(context).formatMediumDate(DateTime(today.year, today.month, today.day + 6))}',
                  style: DMTypography.headingSmall),
            ),
          const SizedBox(height: DMSpacing.sm),
          if (summary != null)
            PlanCastSummaryRow(
                summary: summary,
                calendarCount: c.selectedCalendarIds.length,
                onCalendars: () => selectPlanCastCalendars(context, c))
          else
            PlanCastSummaryRow.fromItems(
                items: range!.events,
                calendarCount: c.selectedCalendarIds.length,
                onCalendars: () => selectPlanCastCalendars(context, c)),
          if (_speechMessage != null)
            Padding(
                padding: const EdgeInsets.only(top: DMSpacing.xs),
                child: Text(_speechMessage!, style: DMTypography.bodySmall)),
          if (c.loading) ...[
            const SizedBox(height: DMSpacing.sm),
            const LinearProgressIndicator(
                semanticsLabel: 'Updating calendars and weather'),
            if (items.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: DMSpacing.sm),
                  child: Text('Loading your selected calendars…')),
          ],
          if (c.error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
                child: Text(c.error!,
                    semanticsLabel: 'PlanCast status. ${c.error}')),
          if (widget.eventId != null && linked == null && !c.loading)
            const Text(
                'That plan has changed or is no longer available. Here is your latest PlanCast.'),
          PlanCastLocationNotice(items: items),
          LayoutBuilder(builder: (context, constraints) {
            final heading = Text(
                week
                    ? 'Daily agenda'
                    : requestedDay != null
                        ? MaterialLocalizations.of(context).formatFullDate(day)
                        : planCastDate(context, day, now: now),
                style: DMTypography.headingSmall);
            final filterControl = _feedFilter(c, calendarId);
            if (MediaQuery.textScalerOf(context).scale(14) > 19) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    Align(
                        alignment: Alignment.centerRight, child: filterControl),
                  ]);
            }
            return Row(children: [Expanded(child: heading), filterControl]);
          }),
          if (range != null)
            for (final daily in range.days) ...[
              const SizedBox(height: DMSpacing.sm),
              Text(MaterialLocalizations.of(context).formatFullDate(daily.day),
                  style: DMTypography.labelLarge),
              const SizedBox(height: DMSpacing.xs),
              _persona(c, daily, persona, unit, filter, compact: true),
              const SizedBox(height: DMSpacing.sm),
              ..._agenda(daily, c.loading),
            ]
          else
            ..._agenda(summary!, c.loading),
          const SizedBox(height: DMSpacing.sm),
          Text(
              c.calendarSyncedAt == null
                  ? 'Calendars have not synced yet.'
                  : 'Calendars synced ${planCastTimestamp(context, c.calendarSyncedAt!)}.',
              style: DMTypography.bodySmall),
          const Text('Weather data © OpenWeather',
              style: DMTypography.bodySmall),
          TextButton.icon(
              onPressed: c.loading ? null : c.refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh calendars and weather')),
        ],
      ),
    );
  }

  Widget _daySelectors(DateTime? requestedDay) =>
      LayoutBuilder(builder: (context, constraints) {
        final chips = [
          for (final entry
              in ['Today', 'Tomorrow', 'This week'].asMap().entries)
            ChoiceChip(
                label: Text(entry.value),
                selected: requestedDay == null && _view == entry.key,
                showCheckmark: false,
                selectedColor: context.dmColors.primary,
                backgroundColor: context.dmColors.surface,
                side: BorderSide(color: context.dmColors.border),
                labelStyle: DMTypography.label.copyWith(
                    color: requestedDay == null && _view == entry.key
                        ? context.dmColors.onPrimary
                        : context.dmColors.textPrimary),
                onSelected: (_) => setState(() {
                      _view = entry.key;
                      _changedView = true;
                    })),
        ];
        if (MediaQuery.textScalerOf(context).scale(14) > 19) {
          return Wrap(
              spacing: DMSpacing.xs,
              runSpacing: DMSpacing.xxs,
              children: chips);
        }
        return Row(children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i != 0) const SizedBox(width: DMSpacing.xs),
            Expanded(child: chips[i]),
          ]
        ]);
      });

  Widget _feedFilter(PlanCastController c, String? selected) {
    final calendars = c.calendars
        .where((cal) => c.selectedCalendarIds.contains(cal.id))
        .toList();
    final selectionLabel = calendars
            .where((calendar) => calendar.id == selected)
            .firstOrNull
            ?.name ??
        'All selected calendars';
    return PopupMenuButton<String>(
      key: const ValueKey('plancast-agenda-filter'),
      tooltip: 'Filter this agenda: $selectionLabel',
      initialValue: selected ?? '__all__',
      onSelected: (id) =>
          setState(() => _feedCalendarId = id == '__all__' ? null : id),
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: '__all__', child: Text('All selected calendars')),
        for (final calendar in calendars)
          PopupMenuItem(value: calendar.id, child: Text(calendar.name)),
      ],
      child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: DMSpacing.xs, vertical: DMSpacing.md),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.filter_list, size: 18),
            const SizedBox(width: DMSpacing.xxs),
            Text(selected == null ? 'Filter' : 'Filtered',
                style: DMTypography.label),
          ])),
    );
  }

  Widget _persona(PlanCastController c, PlanCastDaySummary summary,
      String persona, TemperatureUnit unit, Set<String>? filter,
      {bool compact = false}) {
    final readout = c.readoutForDay(summary.day,
        personaId: persona,
        temperatureUnit: unit,
        calendarFilter: filter,
        summary: summary);
    return PlanCastPersonaCard(
        key: ValueKey('persona-${summary.day}-${filter?.join(',') ?? 'all'}'),
        readout: readout,
        compact: compact,
        contextLabel: compact
            ? null
            : planCastDate(context, summary.day, now: c.clock().toLocal()),
        listening: _speakingDay == summary.day,
        onListen: () => _listen(c, summary, persona, unit, filter),
        expandedContent: Text(readout.fullText, style: DMTypography.body));
  }

  List<Widget> _agenda(PlanCastDaySummary summary, bool loading) => [
        if (summary.events.isEmpty && !loading)
          DmGlassCard(
              child: Text(switch (summary.state) {
            PlanCastDayState.completed =>
              'Your plans for this day have finished.',
            PlanCastDayState.filteredEmpty =>
              'No plans in this agenda filter. Choose All calendars to see the rest.',
            PlanCastDayState.noCalendars =>
              'Choose calendars to see your plans here.',
            _ => 'No plans in your selected calendars for this day.',
          })),
        for (final item in summary.events)
          Padding(
              padding: const EdgeInsets.only(bottom: DMSpacing.sm),
              child: DmGlassCard(
                  child: PlanCastEventTile(
                      key: ValueKey(
                          'agenda-${summary.day.toIso8601String()}-${item.event.id}'),
                      item: item,
                      day: summary.day))),
      ];

  Future<void> _listen(PlanCastController c, PlanCastDaySummary summary,
      String persona, TemperatureUnit unit, Set<String>? filter) async {
    final request = ++_speechRequest;
    final stopping = _speakingDay == summary.day;
    if (_speakingDay != null) await c.stopSpeaking();
    if (!mounted || request != _speechRequest) return;
    if (stopping) {
      setState(() {
        _speakingDay = null;
        _speechMessage = 'Reading stopped.';
      });
      return;
    }
    setState(() {
      _speakingDay = summary.day;
      _speechMessage = 'Preparing an offline device voice…';
    });
    try {
      final spoken = c.readoutForDay(summary.day,
          personaId: persona,
          temperatureUnit: unit,
          calendarFilter: filter,
          summary: summary,
          privateTitles: !c.preferences.spokenPrivateTitles);
      final available = await c.speakBriefing(spoken.fullText);
      if (!mounted || request != _speechRequest) return;
      if (!available) throw StateError('offline_voice_unavailable');
      setState(() => _speechMessage =
          'Speaking with an offline device voice. Stop at any time.');
    } catch (_) {
      if (mounted && request == _speechRequest) {
        setState(() {
          _speakingDay = null;
          _speechMessage =
              'An offline voice is unavailable for the device language. Your text briefing is still available; nothing was sent to cloud speech.';
        });
      }
    }
  }

  Widget _connect(PlanCastController c) =>
      ListView(padding: const EdgeInsets.all(DMSpacing.lg), children: [
        const Text('Your plans. The sky’s opinion.',
            style: DMTypography.headingSmall),
        const SizedBox(height: DMSpacing.md),
        const Text(planCastPrivacyExplanation),
        const SizedBox(height: DMSpacing.md),
        if (c.error != null) Text(c.error!),
        FilledButton(
            onPressed: c.loading
                ? null
                : () async {
                    await c.connect();
                    if (mounted && c.calendarPermission == 'authorized') {
                      await selectPlanCastCalendars(context, c);
                    }
                  },
            child: const Text('Connect calendars')),
        if ({'denied', 'restricted', 'writeOnly'}
            .contains(c.calendarPermission))
          const Padding(
              padding: EdgeInsets.only(top: DMSpacing.md),
              child: Text(
                  'Calendar reading is not permitted. You can change access in device Settings. Write-only access cannot show your plans.')),
        if (c.loading) const LinearProgressIndicator(),
      ]);
}
