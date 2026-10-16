import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/temperature_unit.dart';
import '../../../services/settings_controller.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../roasts/content/roast_context_adapter.dart';
import '../plancast_controller.dart';
import '../plancast_event_copy.dart';
import 'plancast_settings_screen.dart';
import 'plancast_time_format.dart';
import '../widgets/plancast_location_controls.dart';

export 'plancast_time_format.dart';

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
  bool _briefingExpanded = false;
  String? _speechMessage;
  bool _speaking = false;
  int _speechRequest = 0;
  bool _openedLink = false;
  PlanCastController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<PlanCastController?>();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    unawaited(_controller?.stopSpeaking());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlanCastController?>();
    return Scaffold(
      appBar: AppBar(title: const Text('PlanCast'), actions: [
        if (controller?.supported == true) ...[
          IconButton(
              tooltip: 'Refresh calendars and weather',
              onPressed: controller!.loading ? null : controller.refresh,
              icon: const Icon(Icons.refresh)),
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
                constraints: const BoxConstraints(maxWidth: 900),
                child: controller == null
                    ? const Padding(
                        padding: EdgeInsets.all(DMSpacing.lg),
                        child: Text(
                            'PlanCast is unavailable in this session. Your weather forecast is still available.'))
                    : _body(context, controller),
              ))),
    );
  }

  Widget _body(BuildContext context, PlanCastController controller) {
    if (!controller.supported) {
      return const Padding(
          padding: EdgeInsets.all(DMSpacing.lg),
          child: Text(
              'Device calendars are supported in the Android and iOS app. Web browsers cannot connect to your device calendars.'));
    }
    if (!controller.connected) {
      return ListView(padding: const EdgeInsets.all(DMSpacing.lg), children: [
        const Text('Your plans. The sky’s opinion.',
            style: DMTypography.headingSmall),
        const SizedBox(height: DMSpacing.md),
        const Text(planCastPrivacyExplanation),
        const SizedBox(height: DMSpacing.md),
        if (controller.error != null) Text(controller.error!),
        FilledButton(
          onPressed: controller.loading
              ? null
              : () async {
                  await controller.connect();
                  if (context.mounted &&
                      controller.calendarPermission == 'authorized') {
                    await selectPlanCastCalendars(context, controller);
                  }
                },
          child: const Text('Connect calendars'),
        ),
        if (controller.calendarPermission == 'denied' ||
            controller.calendarPermission == 'restricted' ||
            controller.calendarPermission == 'writeOnly')
          const Padding(
              padding: EdgeInsets.only(top: DMSpacing.md),
              child: Text(
                  'Calendar reading is not permitted. You can change access in device Settings. Write-only access cannot show your plans.')),
        if (controller.loading) const LinearProgressIndicator(),
      ]);
    }
    final now = controller.clock().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = _changedView ? null : widget.day;
    final day = requestedDay ??
        (_view == 1 ? DateTime(today.year, today.month, today.day + 1) : today);
    final items = _view == 2 && requestedDay == null
        ? controller.currentEvents
            .where((e) => e.event.isAllDay
                ? e.event.allDayEnd!.isAfter(
                        DateTime.utc(today.year, today.month, today.day)) &&
                    e.event.allDayStart!.isBefore(
                        DateTime.utc(today.year, today.month, today.day + 7))
                : e.event.endUtc.isAfter(today.toUtc()) &&
                    e.event.startUtc.isBefore(
                        DateTime(today.year, today.month, today.day + 7)
                            .toUtc()))
            .toList()
        : controller.eventsForDay(day);
    final settings = context.watch<SettingsController?>();
    final persona = settings?.selectedPersonaId;
    final unit = settings?.temperatureUnit ?? TemperatureUnit.fahrenheit;
    final briefing =
        controller.briefingForDay(day, persona: persona, temperatureUnit: unit);
    final linked = widget.eventId == null
        ? null
        : controller.currentEvents
            .where((e) => e.event.id == widget.eventId)
            .firstOrNull;
    if (linked != null && !_openedLink && !controller.loading) {
      _openedLink = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openPlanCastEvent(context, linked);
      });
    }
    return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.all(DMSpacing.md),
          children: [
            const Text('Your plans. The sky’s opinion.',
                style: DMTypography.bodyLarge),
            const SizedBox(height: DMSpacing.md),
            Wrap(spacing: DMSpacing.sm, children: [
              for (final entry
                  in ['Today', 'Tomorrow', 'This week'].asMap().entries)
                ChoiceChip(
                    label: Text(entry.value),
                    selected: requestedDay == null && _view == entry.key,
                    onSelected: (_) => setState(() {
                          _view = entry.key;
                          _changedView = true;
                          _briefingExpanded = false;
                        })),
            ]),
            const SizedBox(height: DMSpacing.md),
            Text(
                _view == 2 && requestedDay == null
                    ? 'This week · ${MaterialLocalizations.of(context).formatMediumDate(today)} – ${MaterialLocalizations.of(context).formatMediumDate(DateTime(today.year, today.month, today.day + 6))}'
                    : planCastDate(context, day, now: now),
                style: DMTypography.labelLarge),
            Text(planCastScopeSummary(items), style: DMTypography.bodySmall),
            PlanCastLocationNotice(items: items),
            if (controller.loading) const LinearProgressIndicator(),
            if (controller.error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
                  child: Text(controller.error!,
                      semanticsLabel: 'PlanCast status. ${controller.error}')),
            if (widget.eventId != null && linked == null && !controller.loading)
              const Text(
                  'That plan has changed or is no longer available. Here is your latest PlanCast.'),
            if (requestedDay != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: DMSpacing.sm),
                  child: Text(
                      MaterialLocalizations.of(context)
                          .formatFullDate(requestedDay),
                      style: DMTypography.headingSmall)),
            if (_view != 2 || requestedDay != null)
              DmGlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _briefingSection('Your day', _briefingLead(items)),
                    if (_briefingExpanded) ...[
                      _briefingSection(
                          'Worth watching', briefing.worthWatching),
                      _briefingSection('Before you go', briefing.beforeYouGo),
                      if (briefing.tomorrow != null)
                        _briefingSection('Tomorrow', briefing.tomorrow!),
                      if (briefing.personaLine != null)
                        _briefingSection(
                            'One last opinion', briefing.personaLine!),
                    ],
                    Wrap(spacing: DMSpacing.sm, children: [
                      TextButton.icon(
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('Read my day'),
                          onPressed: () async {
                            final request = ++_speechRequest;
                            setState(() {
                              _speaking = true;
                              _speechMessage =
                                  'Preparing an offline device voice…';
                            });
                            try {
                              final spokenBriefing = controller.briefingForDay(
                                  day,
                                  persona: persona,
                                  temperatureUnit: unit,
                                  privateTitles: !controller
                                      .preferences.spokenPrivateTitles);
                              final available = await controller
                                  .speakBriefing(spokenBriefing.text);
                              if (!mounted || request != _speechRequest) return;
                              if (!available) {
                                throw StateError('offline_voice_unavailable');
                              }
                              if (mounted && request == _speechRequest) {
                                setState(() {
                                  _speaking = true;
                                  _speechMessage =
                                      'Speaking with an offline device voice. Stop at any time.';
                                });
                              }
                            } catch (_) {
                              if (mounted && request == _speechRequest) {
                                setState(() {
                                  _speaking = false;
                                  _speechMessage =
                                      'An offline voice is unavailable for the device language. Your text briefing is still available; nothing was sent to cloud speech.';
                                });
                              }
                            }
                          }),
                      TextButton.icon(
                          icon: Icon(_briefingExpanded
                              ? Icons.expand_less
                              : Icons.expand_more),
                          label: Text(_briefingExpanded
                              ? 'Hide briefing'
                              : 'Full briefing'),
                          onPressed: () => setState(() {
                                _briefingExpanded = !_briefingExpanded;
                              })),
                      if (_speaking)
                        TextButton.icon(
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop reading'),
                            onPressed: () async {
                              _speechRequest++;
                              await controller.stopSpeaking();
                              if (mounted) {
                                setState(() {
                                  _speaking = false;
                                  _speechMessage = 'Reading stopped.';
                                });
                              }
                            }),
                    ]),
                    if (_speechMessage != null)
                      Text(_speechMessage!, style: DMTypography.bodySmall),
                  ])),
            const SizedBox(height: DMSpacing.md),
            if (items.isEmpty && !controller.loading)
              const DmGlassCard(
                  child: Text(
                      'No plans in your selected calendars for this view. Missing a calendar? Check that its account is added to your device, then refresh or change your calendar selection.')),
            for (final item in items)
              Padding(
                  padding: const EdgeInsets.only(bottom: DMSpacing.sm),
                  child: DmGlassCard(
                      child: PlanCastEventTile(
                          key: ValueKey(item.event.id), item: item))),
            const SizedBox(height: DMSpacing.sm),
            Text(
                controller.calendarSyncedAt == null
                    ? 'Calendars have not synced yet.'
                    : 'Calendars synced ${planCastTimestamp(context, controller.calendarSyncedAt!)}. Weather data © OpenWeather.',
                style: DMTypography.bodySmall),
            TextButton(
                onPressed: () => selectPlanCastCalendars(context, controller),
                child: const Text('Choose calendars / missing calendar help')),
          ],
        ));
  }

  String _briefingLead(List<PlanCastEventWeather> items) {
    final alerts = items
        .where((item) => !item.isOnline && item.assessment.alerts.isNotEmpty);
    if (alerts.isNotEmpty) {
      return '${alerts.first.assessment.alerts.first.event}. Review the affected plan and official guidance below.';
    }
    final available =
        items.where((item) => !item.isOnline && item.assessment.usable).toList()
          ..sort((a, b) {
            final impact =
                b.assessment.impact.index.compareTo(a.assessment.impact.index);
            return impact != 0
                ? impact
                : a.event.startUtc.compareTo(b.event.startUtc);
          });
    if (available.isEmpty) {
      if (items.isEmpty) return 'No event forecasts to review for this day.';
      if (items.every((item) => item.isOnline)) {
        return 'Your online plans do not need venue weather.';
      }
      return 'Event forecasts are not available yet. Review each plan’s status below.';
    }
    final item = available.first;
    final assessment = item.assessment;
    if (assessment.segments.isNotEmpty) {
      return 'Your stay has dated outlooks. Review each available segment below.';
    }
    final condition = assessment.condition.trim();
    final weather = [
      if (condition.isNotEmpty && condition.toLowerCase() != 'unknown')
        condition,
      if (assessment.peakPrecipitationChance != null)
        '${assessment.peakPrecipitationChance}% precipitation chance',
    ].join(' · ');
    final scope = assessment.isDaily
        ? 'Broad day outlook'
        : assessment.coverage == ForecastCoverage.partial
            ? 'Partial event forecast'
            : 'Event forecast';
    return '$scope: ${weather.isEmpty ? 'weather data available' : weather}. ${PlanCastEventCopy.interval(item)}.';
  }

  Widget _briefingSection(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: DMSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: DMTypography.labelLarge),
        const SizedBox(height: DMSpacing.xs),
        Text(body),
      ]));
}

class PlanCastEventTile extends StatelessWidget {
  const PlanCastEventTile(
      {super.key, required this.item, this.compact = false});
  final PlanCastEventWeather item;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final event = item.event;
    final assessment = item.assessment;
    final now = context.watch<PlanCastController?>()?.clock();
    final segmented = assessment.segments.isNotEmpty;
    return InkWell(
      onTap: () => openPlanCastEvent(context, item),
      borderRadius: BorderRadius.circular(DMSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(right: DMSpacing.sm),
                child: _hasCondition(assessment) && !segmented
                    ? _weatherIcon(item, assessment, event.startUtc, 36)
                    : Icon(item.isOnline
                        ? Icons.videocam_outlined
                        : Icons.event_outlined)),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(event.displayTitle,
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: DMTypography.labelLarge),
                  Text(
                      '${planCastEventTime(context, event, now: now)}${planCastCalendarTimeDiffers(event) ? ' · calendar time' : ''}',
                      style: DMTypography.bodySmall),
                  if (event.tentative)
                    const Text('Tentative invitation',
                        style: DMTypography.bodySmall),
                ])),
            const Icon(Icons.chevron_right),
          ]),
          PlanCastLocationRow(item: item),
          if (segmented)
            Text('${assessment.segments.length} dated outlooks for your stay',
                style: DMTypography.bodySmall)
          else if (!item.isOnline) ...[
            Text(assessment.explanation, style: DMTypography.bodySmall),
            if (assessment.usable)
              Text(planCastWeatherValues(context, assessment),
                  style: DMTypography.bodySmall),
            if (assessment.usable && assessment.advice.isNotEmpty)
              Text(assessment.advice, style: DMTypography.bodySmall),
          ],
        ]),
      ),
    );
  }
}

bool _hasCondition(EventWeatherAssessment value) =>
    value.usable &&
    (value.weatherIcon?.isNotEmpty == true ||
        !{'', 'unknown', 'unavailable'}
            .contains(value.condition.trim().toLowerCase()));

Widget _weatherIcon(PlanCastEventWeather item,
        EventWeatherAssessment assessment, DateTime instant, double size) =>
    DaymakerWeatherIcon(
        key: ValueKey(
            'plancast-icon-${item.event.id}-${instant.millisecondsSinceEpoch}'),
        conditionDescription: assessment.condition,
        openWeatherIconCode: assessment.weatherIcon,
        forecastTime: instant,
        forecastLocalTime: roastLocalTime(
            instant, item.venueTimeZone, item.venueTimeZoneOffset,
            forecast: true),
        latitude: item.venue?.lat,
        longitude: item.venue?.lon,
        size: size,
        semanticLabel: assessment.condition);

String planCastWeatherValues(
    BuildContext context, EventWeatherAssessment value) {
  final unit = context.watch<SettingsController?>()?.temperatureUnit ??
      TemperatureUnit.fahrenheit;
  String temperature(double? celsius) => celsius == null || !celsius.isFinite
      ? '—'
      : '${(unit == TemperatureUnit.celsius ? celsius : celsius * 9 / 5 + 32).round()}°${unit.suffix}';
  final wind = value.maxWindKph == null
      ? 'Wind unavailable'
      : 'Wind up to ${(unit == TemperatureUnit.celsius ? value.maxWindKph! : value.maxWindKph! / 1.609344).round()} ${unit == TemperatureUnit.celsius ? 'km/h' : 'mph'}';
  return '${temperature(value.minTemperatureC)} – ${temperature(value.maxTemperatureC)} · ${value.peakPrecipitationChance == null ? 'Precipitation unavailable' : '${value.precipitationLabel}: ${value.peakPrecipitationChance}%'} · $wind';
}

Future<void> openPlanCastEvent(
        BuildContext context, PlanCastEventWeather item) =>
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _EventDetails(initial: item)));

class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.initial});
  final PlanCastEventWeather initial;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanCastController>();
    final item = c.currentEvents
        .where((e) => e.event.id == initial.event.id)
        .firstOrNull;
    if (item == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Plan changed')),
          body: const Padding(
              padding: EdgeInsets.all(DMSpacing.lg),
              child: Text(
                  'This event was removed, moved, or its calendar is no longer selected. Return to PlanCast for your latest plans.')));
    }
    final assessment = item.assessment;
    final location = item.resolvedLocation;
    final trip = c.tripSuggestion(item);
    final venueZone = item.venueTimeZone;
    final venueTime = venueZone == null
        ? null
        : planCastEventTime(context, item.event,
            now: c.clock(), timeZone: venueZone);
    final calendarTime = planCastEventTime(context, item.event, now: c.clock());
    return Scaffold(
        appBar: AppBar(title: const Text('Your plan')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                    padding: const EdgeInsets.all(DMSpacing.lg),
                    children: [
                      Text(item.event.displayTitle,
                          style: DMTypography.headingSmall),
                      Text(
                          '$calendarTime${planCastCalendarTimeDiffers(item.event) ? ' · calendar time' : ''}'),
                      if (planCastCalendarTimeDiffers(item.event))
                        Text(
                            'Your time: ${planCastEventTime(context, item.event, now: c.clock(), deviceTime: true)}',
                            style: DMTypography.bodySmall),
                      if (!item.event.isAllDay &&
                          venueTime != null &&
                          venueTime != calendarTime)
                        Text(
                            '${location?.venueConfirmed == true ? 'Venue time' : 'Area time'}: $venueTime',
                            style: DMTypography.bodySmall),
                      PlanCastLocationRow(item: item),
                      const SizedBox(height: DMSpacing.sm),
                      if (assessment.segments.isEmpty) ...[
                        if (_hasCondition(assessment))
                          Align(
                              alignment: Alignment.centerLeft,
                              child: _weatherIcon(
                                  item, assessment, item.event.startUtc, 64)),
                        Text(assessment.explanation),
                        if (assessment.usable)
                          Text(planCastWeatherValues(context, assessment)),
                        if (assessment.advice.isNotEmpty)
                          Text(assessment.advice),
                      ] else ...[
                        const Text('Weather through your stay',
                            style: DMTypography.headingSmall),
                        for (final segment in assessment.segments)
                          Padding(
                              padding: const EdgeInsets.only(top: DMSpacing.sm),
                              child: DmGlassCard(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(segment.label,
                                        style: DMTypography.labelLarge),
                                    Text(_segmentTime(context, segment, item),
                                        style: DMTypography.bodySmall),
                                    if (_hasCondition(segment.assessment))
                                      _weatherIcon(item, segment.assessment,
                                          segment.startUtc, 40),
                                    Text(segment.assessment.explanation),
                                    if (segment.assessment.usable)
                                      Text(planCastWeatherValues(
                                          context, segment.assessment)),
                                    if (segment.assessment.advice.isNotEmpty)
                                      Text(segment.assessment.advice),
                                  ]))),
                      ],
                      if (trip != null)
                        TextButton.icon(
                            icon: const Icon(Icons.luggage_outlined),
                            label: const Text(
                                'Use this trip area for other plans during these dates'),
                            onPressed: () => reviewPlanCastBatch(
                                context, c, trip,
                                start: item.event.startUtc,
                                end: item.event.endUtc,
                                calendarIds: {item.event.calendarId})),
                      for (final issue in assessment.uncertainties)
                        Text(issue, style: DMTypography.bodySmall),
                      if (assessment.arrival != null)
                        _window('Arrival buffer', assessment.arrival!),
                      if (assessment.leaving != null)
                        _window('Leaving buffer', assessment.leaving!),
                      if (!item.isOnline)
                        Text(
                            'Planning buffers: ${c.preferences.bufferMinutes} minutes before and after. These are not calculated travel times.',
                            style: DMTypography.bodySmall),
                      for (final alert in assessment.alerts)
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: DMSpacing.sm),
                            child: DmGlassCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(alert.event,
                                      style: DMTypography.labelLarge),
                                  Text(alert.senderName),
                                  if (alert.start != null)
                                    Text(
                                        'Valid from ${planCastTimestamp(context, alert.start!)}'),
                                  if (alert.end != null)
                                    Text(
                                        'Until ${planCastTimestamp(context, alert.end!)}'),
                                  Text(alert.description),
                                ]))),
                      const SizedBox(height: DMSpacing.md),
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Why this location?'),
                          children: [
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.isOnline
                                          ? 'You are participating online; no venue weather is needed.'
                                          : location?.reason ??
                                              'Weather uses the available calendar location or your confirmed choice.'),
                                      if (location?.areaAssumed == true)
                                        const Text(
                                            'This is an area forecast, not a confirmed venue.'),
                                      if (location?.reviewSuggested == true)
                                        const Text(
                                            'You can optionally refine this location with Change.'),
                                      if (location?.observedAt != null)
                                        Text(
                                            'Area observed ${planCastTimestamp(context, location!.observedAt!)}'),
                                      if (location != null)
                                        Text(
                                            'Location resolved ${planCastTimestamp(context, location.resolvedAt)}'),
                                      if (assessment.forecastUpdatedAt != null)
                                        Text(
                                            'Forecast updated ${planCastTimestamp(context, assessment.forecastUpdatedAt!)}'),
                                      if (location != null)
                                        Text(
                                            'Location source: ${location.provider}',
                                            style: DMTypography.bodySmall),
                                      if (!item.event.isAllDay)
                                        const Text(
                                            'Calendar times are preserved. Changing a weather area never changes the appointment time.',
                                            style: DMTypography.bodySmall),
                                    ])),
                          ]),
                      const SizedBox(height: DMSpacing.sm),
                      if (!item.isOnline)
                        Wrap(spacing: DMSpacing.sm, children: [
                          for (final environment in [
                            EventEnvironment.unknown,
                            EventEnvironment.indoor,
                            EventEnvironment.outdoor
                          ])
                            ChoiceChip(
                                label: Text(switch (environment) {
                                  EventEnvironment.indoor => 'Indoor',
                                  EventEnvironment.outdoor => 'Outdoor',
                                  _ => 'Not specified'
                                }),
                                selected: item.environment == environment,
                                onSelected: (_) => c.setEventOverride(
                                    item.event,
                                    environment: environment)),
                        ]),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Event heads-ups'),
                          subtitle: const Text(
                              'Requires PlanCast notification permission and respects your quiet hours.'),
                          value: item.remindersEnabled,
                          onChanged: (value) => c.setEventOverride(item.event,
                              remindersEnabled: value)),
                      const Text(
                          'All corrections and reminder choices belong to PlanCast. Your source calendar event is never edited.',
                          style: DMTypography.bodySmall),
                      if (c.canUndoLocationChange)
                        TextButton.icon(
                            onPressed: c.undoLocationChange,
                            icon: const Icon(Icons.undo),
                            label: const Text('Undo location change')),
                    ]))));
  }

  Widget _window(String title, EventWeatherAssessment value) => Padding(
      padding: const EdgeInsets.only(top: DMSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: DMTypography.labelLarge),
        Text(value.explanation),
      ]));
  String _segmentTime(BuildContext context, EventWeatherSegment segment,
      PlanCastEventWeather item) {
    final start = item.event.isAllDay
        ? segment.startUtc
        : roastLocalTime(segment.startUtc, item.venueTimeZone, null) ??
            segment.startUtc.toLocal();
    final end = item.event.isAllDay
        ? segment.endUtc
        : roastLocalTime(segment.endUtc, item.venueTimeZone, null) ??
            segment.endUtc.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(start);
    if (segment.assessment.isDaily) return '$date · Day outlook';
    bool isMidnight(DateTime time) =>
        time.hour == 0 &&
        time.minute == 0 &&
        time.second == 0 &&
        time.millisecond == 0 &&
        time.microsecond == 0;
    final startDate = DateTime.utc(start.year, start.month, start.day);
    final endDate = DateTime.utc(end.year, end.month, end.day);
    final endsNextDay =
        endDate == DateTime.utc(start.year, start.month, start.day + 1);
    if (isMidnight(start) && isMidnight(end) && endsNextDay) {
      return '$date · Full day';
    }
    final endLabel = isMidnight(end) && endsNextDay
        ? 'midnight'
        : '${endDate != startDate ? '${localizations.formatMediumDate(end)} · ' : ''}${TimeOfDay.fromDateTime(end).format(context)}';
    return '$date · ${TimeOfDay.fromDateTime(start).format(context)}–$endLabel';
  }
}
