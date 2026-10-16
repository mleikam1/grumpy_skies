import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/temperature_unit.dart';
import '../../../models/weather_models.dart';
import '../../../services/settings_controller.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../roasts/content/roast_context_adapter.dart';
import '../plancast_controller.dart';
import 'plancast_settings_screen.dart';

const planCastPrivacyExplanation =
    'PlanCast reads only the device calendars you select. Accounts must be available to the operating system; a standalone calendar app may not expose its events. '
    'We never create, edit, or delete source events or their reminders. On iOS, full calendar access is required to read existing events, even though PlanCast is read-only.\n\n'
    'Calendar processing and briefings stay on this device. Only venue text or coordinates go to the existing location and weather services—not titles, descriptions, guests, or meeting links. '
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
                        })),
            ]),
            const SizedBox(height: DMSpacing.md),
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
                    _briefingSection('Your day', briefing.yourDay),
                    _briefingSection('Worth watching', briefing.worthWatching),
                    _briefingSection('Before you go', briefing.beforeYouGo),
                    if (briefing.tomorrow != null)
                      _briefingSection('Tomorrow', briefing.tomorrow!),
                    if (briefing.personaLine != null)
                      _briefingSection(
                          'One last opinion', briefing.personaLine!),
                    Text(
                        '${briefing.usableWeatherCount} with usable weather · ${briefing.needsLocationCount} need a location',
                        style: DMTypography.bodySmall),
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

  Widget _briefingSection(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: DMSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: DMTypography.labelLarge),
        const SizedBox(height: DMSpacing.xs),
        Text(body),
      ]));
}

String planCastTimestamp(BuildContext context, DateTime time) {
  final local = time.toLocal();
  return '${MaterialLocalizations.of(context).formatShortDate(local)} ${TimeOfDay.fromDateTime(local).format(context)}';
}

String planCastEventTime(BuildContext context, CalendarEvent event) {
  final l10n = MaterialLocalizations.of(context);
  if (event.isAllDay) {
    final first = event.allDayStart!;
    final last = event.allDayEnd!.subtract(const Duration(days: 1));
    return 'All day · ${l10n.formatShortDate(first)}${last == first ? '' : ' – ${l10n.formatShortDate(last)}'}';
  }
  final zonedStart = roastLocalTime(event.startUtc, event.timeZone, null);
  final start = zonedStart ?? event.startUtc;
  final end =
      roastLocalTime(event.endUtc, event.timeZone, null) ?? event.endUtc;
  String offset(DateTime time) {
    final minutes = time.timeZoneOffset.inMinutes;
    return 'UTC${minutes < 0 ? '−' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
  }

  final zone =
      zonedStart == null ? 'UTC (event time zone unavailable)' : event.timeZone;
  final endDate = start.day == end.day && start.month == end.month
      ? ''
      : '${l10n.formatShortDate(end)} ';
  return '${l10n.formatShortDate(start)} · ${TimeOfDay.fromDateTime(start).format(context)} ${offset(start)}${event.hasDuration ? ' – $endDate${TimeOfDay.fromDateTime(end).format(context)} ${offset(end)}' : ''} · $zone';
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
    return InkWell(
        onTap: () => openPlanCastEvent(context, item),
        borderRadius: BorderRadius.circular(DMSpacing.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (assessment.usable)
                Padding(
                    padding: const EdgeInsets.only(right: DMSpacing.sm),
                    child: DaymakerWeatherIcon(
                      key: ValueKey('plancast-icon-${event.id}'),
                      conditionDescription: assessment.condition,
                      openWeatherIconCode: assessment.weatherIcon,
                      forecastTime: event.startUtc,
                      size: 36,
                      semanticLabel: assessment.condition,
                    ))
              else
                const Padding(
                    padding: EdgeInsets.only(right: DMSpacing.sm),
                    child: Icon(Icons.event_outlined)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(event.displayTitle,
                        maxLines: compact ? 2 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: DMTypography.labelLarge),
                    Text(planCastEventTime(context, event),
                        style: DMTypography.bodySmall),
                    if (event.tentative)
                      const Text('Tentative invitation',
                          style: DMTypography.bodySmall),
                  ])),
              const Icon(Icons.chevron_right),
            ]),
            if (!compact) ...[
              const SizedBox(height: DMSpacing.sm),
              Text(
                  item.environment == EventEnvironment.online
                      ? 'Online · no travel weather'
                      : item.venue?.displayName ??
                          (item.needsLocation
                              ? 'Location needed — choose a physical venue'
                              : 'Location unavailable'),
                  style: DMTypography.bodySmall),
              const SizedBox(height: DMSpacing.xs),
              Text(assessment.impact.label, style: DMTypography.label),
              Text(assessment.explanation),
              if (assessment.usable)
                Text(planCastWeatherValues(context, assessment),
                    style: DMTypography.bodySmall),
              if (assessment.advice.isNotEmpty) Text(assessment.advice),
              Text(
                  assessment.forecastUpdatedAt == null
                      ? 'No forecast update available'
                      : 'Last checked ${planCastTimestamp(context, assessment.forecastUpdatedAt!)}',
                  style: DMTypography.bodySmall),
            ] else
              Text(
                  assessment.usable
                      ? assessment.advice
                      : assessment.explanation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.bodySmall),
          ]),
        ));
  }
}

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

class _EventDetails extends StatefulWidget {
  const _EventDetails({required this.initial});
  final PlanCastEventWeather initial;
  @override
  State<_EventDetails> createState() => _EventDetailsState();
}

class _EventDetailsState extends State<_EventDetails> {
  final _query = TextEditingController();
  List<LocationCandidate> _results = [];
  bool _searching = false;
  bool _recurring = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _query.text = widget.initial.event.locationText;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlanCastController>();
    final item = controller.currentEvents
        .where((e) => e.event.id == widget.initial.event.id)
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
                      Text(planCastEventTime(context, item.event)),
                      const SizedBox(height: DMSpacing.md),
                      Text(assessment.impact.label,
                          style: DMTypography.labelLarge),
                      Text(assessment.explanation),
                      if (assessment.usable) ...[
                        DaymakerWeatherIcon(
                            conditionDescription: assessment.condition,
                            openWeatherIconCode: assessment.weatherIcon,
                            forecastTime: item.event.startUtc,
                            size: 64,
                            semanticLabel: assessment.condition),
                        Text(planCastWeatherValues(context, assessment)),
                      ],
                      if (assessment.advice.isNotEmpty) Text(assessment.advice),
                      for (final issue in assessment.uncertainties)
                        Text(issue, style: DMTypography.bodySmall),
                      if (assessment.arrival != null)
                        _window('Arrival buffer', assessment.arrival!),
                      if (assessment.leaving != null)
                        _window('Leaving buffer', assessment.leaving!),
                      Text(
                          'Planning buffers: ${controller.preferences.bufferMinutes} minutes before and after. These are not calculated travel times.',
                          style: DMTypography.bodySmall),
                      if (assessment.forecastUpdatedAt != null)
                        Text(
                            'Forecast checked ${planCastTimestamp(context, assessment.forecastUpdatedAt!)}',
                            style: DMTypography.bodySmall),
                      for (final alert in assessment.alerts)
                        DmGlassCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(alert.event, style: DMTypography.labelLarge),
                              Text(alert.senderName),
                              if (alert.start != null)
                                Text(
                                    'Issued / valid from ${planCastTimestamp(context, alert.start!)}'),
                              if (alert.end != null)
                                Text(
                                    'Until ${planCastTimestamp(context, alert.end!)}'),
                              Text(alert.description),
                            ])),
                      const SizedBox(height: DMSpacing.lg),
                      const Text('Where is this happening?',
                          style: DMTypography.headingSmall),
                      Text(item.event.locationText.isEmpty
                          ? 'No physical location on the source event.'
                          : item.event.locationText),
                      Text(item.venue == null
                          ? 'Choose a venue to get location-specific weather.'
                          : 'Weather for ${item.venue!.displayName}'),
                      Wrap(spacing: DMSpacing.sm, children: [
                        for (final value in EventEnvironment.values)
                          ChoiceChip(
                              label: Text(_environmentLabel(value)),
                              selected: item.environment == value,
                              onSelected: (_) => controller.setEventOverride(
                                  item.event,
                                  environment: value)),
                      ]),
                      if (item.environment != EventEnvironment.online) ...[
                        const SizedBox(height: DMSpacing.md),
                        TextField(
                            controller: _query,
                            decoration: const InputDecoration(
                                labelText: 'Venue city or locality',
                                helperText:
                                    'Place search resolves cities, not street-level addresses. Only this text is sent.'),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(controller)),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                                onPressed: _searching
                                    ? null
                                    : () => _search(controller),
                                icon: const Icon(Icons.search),
                                label: const Text('Find venue'))),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                _coordinates(controller, item.event),
                            icon: const Icon(Icons.pin_drop_outlined),
                            label: const Text('Set exact venue coordinates'),
                          ),
                        ),
                        if (_searching) const LinearProgressIndicator(),
                        if (_message != null) Text(_message!),
                        if (item.event.recurringId != null)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _recurring,
                              onChanged: (value) =>
                                  setState(() => _recurring = value ?? false),
                              title:
                                  const Text('Reuse for this recurring venue'),
                              subtitle: const Text(
                                  'Only when the recurring event keeps the same location.')),
                        for (final result in _results)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(result.displayName),
                              subtitle: const Text(
                                  'Confirm this location for event weather'),
                              trailing: const Icon(Icons.check_circle_outline),
                              onTap: () async {
                                await controller.setEventOverride(item.event,
                                    venue: result, recurringVenue: _recurring);
                                if (mounted) {
                                  setState(() {
                                    _results = [];
                                    _message =
                                        'Venue confirmed for PlanCast. The source calendar is unchanged.';
                                  });
                                }
                              }),
                      ],
                      const SizedBox(height: DMSpacing.md),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Event heads-ups'),
                          subtitle: const Text(
                              'Requires PlanCast notification permission and respects your quiet hours.'),
                          value: item.remindersEnabled,
                          onChanged: (value) => controller.setEventOverride(
                              item.event,
                              remindersEnabled: value)),
                      const Text(
                          'All corrections and reminder choices belong to PlanCast. Your source calendar event is never edited.',
                          style: DMTypography.bodySmall),
                    ]))));
  }

  Widget _window(String label, EventWeatherAssessment value) => Padding(
      padding: const EdgeInsets.only(top: DMSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: DMTypography.labelLarge),
        Text(value.explanation),
        if (value.advice.isNotEmpty) Text(value.advice)
      ]));
  Future<void> _search(PlanCastController controller) async {
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final results = await controller.searchVenues(_query.text);
      if (mounted) {
        setState(() {
          _results = results;
          _message = results.isEmpty
              ? 'No reliable location found. Try the venue’s city or locality. Meeting links and room numbers are not locations.'
              : 'Choose the correct venue; PlanCast never assumes the nearest match.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Location lookup is unavailable. Try again when connected.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _coordinates(
      PlanCastController controller, CalendarEvent event) async {
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    String? message;
    final venue = await showDialog<LocationCandidate>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('Exact venue coordinates'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Use known coordinates for the physical venue. These are sent only to the weather service; your source event is unchanged.'),
                    TextField(
                        controller: latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                            labelText: 'Latitude (−90 to 90)')),
                    TextField(
                        controller: longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: const InputDecoration(
                            labelText: 'Longitude (−180 to 180)')),
                    if (message != null) Text(message!),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          final lat = double.tryParse(latitude.text.trim());
                          final lon = double.tryParse(longitude.text.trim());
                          if (lat == null ||
                              lon == null ||
                              !LocationCandidate.hasValidCoordinatePair(
                                  lat, lon)) {
                            update(() => message =
                                'Enter valid latitude and longitude values.');
                            return;
                          }
                          Navigator.pop(
                              dialogContext,
                              LocationCandidate(
                                  name: 'Confirmed venue',
                                  country: '',
                                  lat: lat,
                                  lon: lon,
                                  source: 'user-confirmed-coordinates'));
                        },
                        child: const Text('Use these coordinates')),
                  ],
                )));
    latitude.dispose();
    longitude.dispose();
    if (venue != null) {
      await controller.setEventOverride(event,
          venue: venue, recurringVenue: _recurring);
    }
  }

  String _environmentLabel(EventEnvironment value) => switch (value) {
        EventEnvironment.indoor => 'Indoor',
        EventEnvironment.outdoor => 'Outdoor',
        EventEnvironment.online => 'Online',
        EventEnvironment.unknown => 'Unknown'
      };
}
