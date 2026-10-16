import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../models/weather_models.dart';
import '../plancast_controller.dart';
import '../screens/plancast_time_format.dart';

String planCastScopeSummary(List<PlanCastEventWeather> items) {
  final weather = items.where((e) => e.assessment.usable).length;
  final automatic =
      items.where((e) => e.automaticLocation && !e.isOnline).length;
  final online = items.where((e) => e.isOnline).length;
  final unavailable =
      items.where((e) => !e.isOnline && !e.assessment.usable).length;
  return [
    '$weather with weather',
    if (automatic > 0) '$automatic automatically located',
    if (online > 0) '$online online',
    if (unavailable > 0) '$unavailable without weather',
  ].join(' · ');
}

class PlanCastLocationRow extends StatelessWidget {
  const PlanCastLocationRow({super.key, required this.item});
  final PlanCastEventWeather item;
  @override
  Widget build(BuildContext context) {
    final location = item.resolvedLocation;
    final text = item.isOnline
        ? 'Online · no venue weather needed'
        : location == null
            ? item.venue?.displayName ?? 'Choose a weather area'
            : '${location.sourceLabel} · ${location.displayLabel}${location.provisional ? ' · provisional' : ''}';
    return InkWell(
      key: ValueKey('plancast-location-${item.event.id}'),
      onTap: () => changePlanCastLocation(context, item),
      borderRadius: BorderRadius.circular(DMSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(item.isOnline ? Icons.videocam_outlined : Icons.place_outlined,
              size: 18),
          const SizedBox(width: DMSpacing.xs),
          Expanded(child: Text(text, style: DMTypography.bodySmall)),
          const SizedBox(width: DMSpacing.xs),
          const Text('Change', style: DMTypography.label),
        ]),
      ),
    );
  }
}

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .85),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(DMSpacing.md), child: child),
              ),
            ));

Future<void> changePlanCastLocation(
        BuildContext context, PlanCastEventWeather item) =>
    _sheet<void>(
        context,
        _LocationChoices(
            controller: context.read<PlanCastController>(), item: item));

class _LocationChoices extends StatefulWidget {
  const _LocationChoices({required this.controller, required this.item});
  final PlanCastController controller;
  final PlanCastEventWeather item;
  @override
  State<_LocationChoices> createState() => _LocationChoicesState();
}

class _LocationChoicesState extends State<_LocationChoices> {
  LocationRuleScope _scope = LocationRuleScope.occurrence;
  LocationChoice? _choice;
  String? _choiceLabel;
  bool _saving = false;
  String? _message;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final count =
            c.locationChoiceAffected(widget.item.event, _scope).length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Weather location', style: DMTypography.headingSmall),
          Text(widget.item.event.displayTitle),
          const SizedBox(height: DMSpacing.sm),
          const Text(
              'Changes stay in PlanCast. The calendar appointment and its time stay unchanged.',
              style: DMTypography.bodySmall),
          const SizedBox(height: DMSpacing.sm),
          Wrap(spacing: DMSpacing.xs, children: [
            _scopeChip('This event', LocationRuleScope.occurrence),
            if (widget.item.event.isRecurring)
              _scopeChip('Missing-location events in this series',
                  LocationRuleScope.seriesMissing),
            _scopeChip('Calendar default', LocationRuleScope.calendarDefault),
          ]),
          if (_scope != LocationRuleScope.occurrence)
            Text(
                '$count currently loaded ${count == 1 ? 'plan' : 'plans'} affected. Stronger calendar destinations are kept.',
                style: DMTypography.bodySmall),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location),
              title: const Text('Current area'),
              subtitle: Text(c.currentArea?.displayName ??
                  'Use the device’s area when available'),
              onTap: _saving
                  ? null
                  : () async {
                      await c.useCurrentArea();
                      if (!mounted) return;
                      setState(() {
                        _choice = const LocationChoice.currentArea();
                        _choiceLabel = 'Current area';
                        _message = c.locationPermissionMessage;
                      });
                    }),
          for (final place in c.savedPlaces)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_border),
                title: Text(place.label),
                subtitle: Text(place.candidate.displayName),
                onTap: () => setState(() {
                      _choice = LocationChoice.savedPlace(place.id);
                      _choiceLabel = place.label;
                    })),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: const Text('Search for a city'),
              subtitle: Text(c.locationMatchingCapability),
              onTap: () async {
                final place = await choosePlanCastArea(context, c);
                if (mounted && place != null) {
                  setState(() {
                    _choice = LocationChoice.place(place);
                    _choiceLabel = place.displayName;
                  });
                }
              }),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Online'),
              subtitle: const Text('No venue weather needed'),
              onTap: () => setState(() {
                    _choice = const LocationChoice.online();
                    _choiceLabel = 'Online';
                  })),
          TextButton.icon(
              icon: const Icon(Icons.pin_drop_outlined),
              label: const Text('Set exact venue coordinates'),
              onPressed: () async {
                final place = await _exactCoordinates(context);
                if (mounted && place != null) {
                  setState(() {
                    _choice = LocationChoice.place(place);
                    _choiceLabel = place.displayName;
                  });
                }
              }),
          if (_message != null) Text(_message!, style: DMTypography.bodySmall),
          if (_choiceLabel != null)
            Text('Use: $_choiceLabel', style: DMTypography.labelLarge),
          const SizedBox(height: DMSpacing.sm),
          FilledButton(
              onPressed: _choice == null || _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await c.setLocationChoice(widget.item.event, _choice!,
                            scope: _scope);
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _saving = false;
                            _message =
                                'That choice could not be saved. Please try again.';
                          });
                        }
                      }
                    },
              child: Text(_saving ? 'Saving…' : 'Use this choice')),
        ]);
      });
  Widget _scopeChip(String label, LocationRuleScope scope) => ChoiceChip(
      label: Text(label),
      selected: _scope == scope,
      onSelected: _saving ? null : (_) => setState(() => _scope = scope));
}

Future<LocationCandidate?> _exactCoordinates(BuildContext context) async {
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  String? error;
  final result = await showDialog<LocationCandidate>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const Text('Exact venue coordinates'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Known venue coordinates go only to the weather service. The source calendar stays unchanged.'),
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
                  if (error != null) Text(error!),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final lat = double.tryParse(latitude.text.trim());
                        final lon = double.tryParse(longitude.text.trim());
                        if (lat == null ||
                            lon == null ||
                            !LocationCandidate.hasValidCoordinatePair(
                                lat, lon)) {
                          update(() => error =
                              'Enter valid latitude and longitude values.');
                        } else {
                          Navigator.pop(
                              context,
                              LocationCandidate(
                                  name: 'Confirmed venue',
                                  country: '',
                                  lat: lat,
                                  lon: lon,
                                  source: 'user-confirmed-coordinates'));
                        }
                      },
                      child: const Text('Use these coordinates'))
                ],
              )));
  latitude.dispose();
  longitude.dispose();
  return result;
}

class PlanCastSmartLocationSettings extends StatelessWidget {
  const PlanCastSmartLocationSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanCastController>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Smart locations', style: DMTypography.headingSmall),
      const Text(
          'Plans without a stronger destination use your area automatically. Browsing another city in Today does not move your plans.',
          style: DMTypography.bodySmall),
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.my_location),
          title: const Text('Current area'),
          subtitle: Text(c.currentArea?.displayName ??
              c.locationPermissionMessage ??
              'No current area available'),
          onTap: () => c.useCurrentArea()),
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Default city'),
          subtitle: Text(c.defaultArea?.displayName ??
              'One fallback for all plans without a location'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final place = await choosePlanCastArea(context, c);
            if (place != null) await c.setDefaultArea(place);
          }),
      if (c.defaultArea != null)
        TextButton(
            onPressed: () => c.setDefaultArea(null),
            child: const Text('Reset default city')),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Optional online location matching'),
          subtitle: Text(
              'Send only locally extracted city, venue or address queries to the location service. Full event titles, descriptions, dates, guests and meeting links stay on this device. ${c.locationMatchingCapability} Current-area weather works with this off.'),
          value: c.onlineLocationMatchingEnabled,
          onChanged: c.setOnlineLocationMatching),
      const SizedBox(height: DMSpacing.sm),
      const Text('Saved places', style: DMTypography.labelLarge),
      for (final place in c.savedPlaces)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(place.label),
            subtitle: Text(place.candidate.displayName),
            onTap: () => _savePlace(context, c, existing: place),
            trailing: IconButton(
                tooltip: 'Remove saved place ${place.label}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => c.removeSavedPlace(place.id))),
      TextButton.icon(
          onPressed: () => _savePlace(context, c),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add saved place')),
      if (c.locationRules.isNotEmpty) ...[
        const SizedBox(height: DMSpacing.sm),
        const Text('Your location rules', style: DMTypography.labelLarge),
        for (final rule in c.locationRules)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: DMSpacing.xs),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.locationRuleLabel(rule)),
                    Wrap(spacing: DMSpacing.sm, children: [
                      TextButton(
                          onPressed: () async {
                            final choice = await _editRule(context, c);
                            if (choice != null) {
                              await c.updateLocationRule(rule.id, choice);
                            }
                          },
                          child: const Text('Edit rule')),
                      TextButton(
                          onPressed: () => c.removeLocationRule(rule.id),
                          child: const Text('Reset rule')),
                    ]),
                  ])),
      ],
      for (final trip in c.smartLocations.trips) ...[
        Text('Trip area · ${trip.label}', style: DMTypography.labelLarge),
        Text(
            '${planCastTimestamp(context, trip.startUtc)} – ${planCastTimestamp(context, trip.endUtc)}',
            style: DMTypography.bodySmall),
        Wrap(spacing: DMSpacing.sm, children: [
          TextButton(
              onPressed: () => c.removeTripArea(trip.id),
              child: const Text('Reset trip area')),
        ]),
      ],
      if (c.canUndoLocationChange)
        TextButton.icon(
            onPressed: c.undoLocationChange,
            icon: const Icon(Icons.undo),
            label: const Text('Undo location change')),
    ]);
  }
}

Future<LocationChoice?> _editRule(BuildContext context, PlanCastController c) =>
    _sheet<LocationChoice>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit location rule', style: DMTypography.headingSmall),
          const Text(
              'This keeps the rule’s existing event, series or calendar scope.'),
          ListTile(
              title: const Text('Current area'),
              onTap: () =>
                  Navigator.pop(context, const LocationChoice.currentArea())),
          for (final place in c.savedPlaces)
            ListTile(
                title: Text(place.label),
                subtitle: Text(place.candidate.displayName),
                onTap: () => Navigator.pop(
                    context, LocationChoice.savedPlace(place.id))),
          ListTile(
              title: const Text('Choose another city'),
              onTap: () async {
                final place = await choosePlanCastArea(context, c);
                if (place != null && context.mounted) {
                  Navigator.pop(context, LocationChoice.place(place));
                }
              }),
          ListTile(
              title: const Text('Online'),
              onTap: () =>
                  Navigator.pop(context, const LocationChoice.online())),
        ]));

Future<void> _savePlace(BuildContext context, PlanCastController c,
    {SavedPlanCastPlace? existing}) async {
  final candidate = existing?.candidate ?? await choosePlanCastArea(context, c);
  if (candidate == null || !context.mounted) return;
  final name = TextEditingController(text: existing?.label ?? candidate.name);
  final aliases =
      TextEditingController(text: existing?.aliases.join(', ') ?? '');
  final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title:
                Text(existing == null ? 'Save this place' : 'Edit saved place'),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(candidate.displayName),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'Name, such as Home or Work')),
              TextField(
                  controller: aliases,
                  decoration: const InputDecoration(
                      labelText: 'Exact calendar location aliases (optional)',
                      helperText:
                          'Separate aliases with commas. Only location fields are matched.')),
            ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save place'))
            ],
          ));
  if (saved == true) {
    await c.savePlace(SavedPlanCastPlace(
        id: existing?.id ??
            planCastId(
                'saved|${c.clock().microsecondsSinceEpoch}|${candidate.lat}|${candidate.lon}'),
        label: name.text.trim().isEmpty ? candidate.name : name.text.trim(),
        candidate: candidate,
        createdAt: existing?.createdAt ?? c.clock(),
        aliases: aliases.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        provider: existing?.provider ?? candidate.source,
        providerPlaceId: existing?.providerPlaceId,
        providerExpiresAt: existing?.providerExpiresAt));
  }
  name.dispose();
  aliases.dispose();
}

Future<LocationCandidate?> choosePlanCastArea(
        BuildContext context, PlanCastController controller) =>
    _sheet<LocationCandidate>(context, _AreaSearch(controller: controller));

class _AreaSearch extends StatefulWidget {
  const _AreaSearch({required this.controller});
  final PlanCastController controller;
  @override
  State<_AreaSearch> createState() => _AreaSearchState();
}

class _AreaSearchState extends State<_AreaSearch> {
  final _query = TextEditingController();
  List<LocationCandidate> _results = const [];
  bool _loading = false;
  String? _message;
  int _revision = 0;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Choose a weather area', style: DMTypography.headingSmall),
        Text(widget.controller.locationMatchingCapability,
            style: DMTypography.bodySmall),
        const Text(
            'Only the city or ZIP you enter is sent to the location service. Calendar titles, dates and guests are not sent.',
            style: DMTypography.bodySmall),
        const SizedBox(height: DMSpacing.sm),
        TextField(
            key: const ValueKey('plancast-city-query'),
            controller: _query,
            decoration: const InputDecoration(labelText: 'City or ZIP code'),
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              _revision++;
              setState(() {
                _results = const [];
                _loading = false;
              });
            },
            onSubmitted: (_) => _search()),
        TextButton.icon(
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.search),
            label: const Text('Find city')),
        if (_loading) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        for (final place in _results)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(place.displayName),
              subtitle: const Text('Use city-level weather'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, place)),
      ]);
  Future<void> _search() async {
    final revision = ++_revision;
    if (_query.text.trim().length < 2) {
      setState(() => _message = 'Enter a city or ZIP code.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
      _results = const [];
    });
    try {
      final result = await widget.controller.searchVenues(_query.text.trim());
      if (!mounted || revision != _revision) return;
      setState(() {
        _results = result;
        _message = result.isEmpty
            ? 'No city matched. Try a city and state or country.'
            : 'Choose the correct area.';
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _message =
            'City search is unavailable. Your existing weather areas are unchanged.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }
}

class PlanCastLocationNotice extends StatelessWidget {
  const PlanCastLocationNotice({super.key, required this.items});
  final List<PlanCastEventWeather> items;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanCastController>();
    final travel = c.travelNotice;
    final home = c.savedPlaces
        .where((place) =>
            place.label.trim().toLowerCase() == 'home' &&
            place.candidate.hasValidCoordinates)
        .firstOrNull;
    final needsDefault = c.currentArea == null &&
        c.defaultArea == null &&
        items.any((e) {
          if (e.isOnline || !e.needsLocation) return false;
          final evidence = c.locationResolver.extractor.extract(e.event);
          return !evidence.hasDestinationEvidence && !evidence.virtualOnly;
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.showSmartLocationExplanation) ...[
        const Text(
            'Plans without a location can use your current area automatically. Confirmed destinations stay put.',
            style: DMTypography.bodySmall),
        TextButton(
            onPressed: c.acknowledgeSmartLocations,
            child: const Text('Got it')),
      ],
      if (needsDefault) ...[
        const Text(
            'Choose one default city for plans without a location. Known destinations keep their own weather.'),
        TextButton(
            onPressed: () async {
              final place = await choosePlanCastArea(context, c);
              if (place != null) await c.setDefaultArea(place);
            },
            child: const Text('Choose default city')),
      ],
      if (travel != null) ...[
        Text(travel.message, style: DMTypography.bodySmall),
        Text(
            '${planCastTimestamp(context, travel.windowStart)} – ${planCastTimestamp(context, travel.windowEnd)}',
            style: DMTypography.bodySmall),
        Wrap(spacing: DMSpacing.xs, children: [
          TextButton(
              onPressed: () => reviewPlanCastBatch(context, c, travel.area,
                  start: travel.windowStart,
                  end: travel.windowEnd,
                  calendarIds: travel.calendarIds),
              child: const Text('Keep this area')),
          TextButton(
              onPressed: () async {
                final place = await choosePlanCastArea(context, c);
                if (place != null && context.mounted) {
                  await reviewPlanCastBatch(context, c, place,
                      start: travel.windowStart,
                      end: travel.windowEnd,
                      calendarIds: travel.calendarIds);
                }
              },
              child: const Text('Use another area')),
          if (home != null)
            TextButton(
                onPressed: () => reviewPlanCastBatch(context, c, home.candidate,
                    start: travel.windowStart,
                    end: travel.windowEnd,
                    calendarIds: travel.calendarIds),
                child: const Text('Use Home')),
          TextButton(
              onPressed: () => reviewPlanCastBatch(context, c, travel.area,
                  start: travel.windowStart,
                  end: travel.windowEnd,
                  calendarIds: travel.calendarIds),
              child: Text('Review ${travel.affectedCount} plans')),
        ]),
      ],
      if (c.canUndoLocationChange)
        TextButton.icon(
            onPressed: c.undoLocationChange,
            icon: const Icon(Icons.undo),
            label: const Text('Undo location change')),
    ]);
  }
}

Future<void> reviewPlanCastBatch(BuildContext context,
        PlanCastController controller, LocationCandidate area,
        {DateTime? start, DateTime? end, Set<String>? calendarIds}) =>
    _sheet<void>(
        context,
        _BatchArea(
            controller: controller,
            area: area,
            start: start,
            end: end,
            calendarIds: calendarIds));

class _BatchArea extends StatefulWidget {
  const _BatchArea(
      {required this.controller,
      required this.area,
      this.start,
      this.end,
      this.calendarIds});
  final PlanCastController controller;
  final LocationCandidate area;
  final DateTime? start, end;
  final Set<String>? calendarIds;
  @override
  State<_BatchArea> createState() => _BatchAreaState();
}

class _BatchAreaState extends State<_BatchArea> {
  late DateTime _start = widget.start ?? widget.controller.clock();
  late DateTime _end = widget.end ?? _start.add(const Duration(hours: 48));
  late final Set<String> _calendars = {
    ...(widget.calendarIds ?? widget.controller.selectedCalendarIds)
  };
  bool _saving = false;
  String? _message;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final affected = widget.controller
            .batchAffected(start: _start, end: _end, calendarIds: _calendars);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Use an area for these plans',
              style: DMTypography.headingSmall),
          Text(widget.area.displayName, style: DMTypography.labelLarge),
          const SizedBox(height: DMSpacing.sm),
          Text(
              '${planCastTimestamp(context, _start)} – ${planCastTimestamp(context, _end)}'),
          TextButton.icon(
              onPressed: _saving ? null : _dates,
              icon: const Icon(Icons.date_range),
              label: const Text('Change date range')),
          for (final calendar in widget.controller.calendars.where(
              (c) => widget.controller.selectedCalendarIds.contains(c.id)))
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(calendar.name),
                value: _calendars.contains(calendar.id),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          value == true
                              ? _calendars.add(calendar.id)
                              : _calendars.remove(calendar.id);
                        })),
          Text(
              '${affected.length} ${affected.length == 1 ? 'plan' : 'plans'} without a stronger location will use this area.',
              style: DMTypography.labelLarge),
          const Text(
              'Confirmed destinations and fixed home/work choices stay unchanged. This area expires at the end of the selected window.',
              style: DMTypography.bodySmall),
          for (final item in affected)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.event.displayTitle),
                subtitle: Text(planCastEventTime(context, item.event,
                    now: widget.controller.clock()))),
          if (_message != null) Text(_message!),
          FilledButton(
              onPressed: _saving || affected.isEmpty
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.controller.applyTripArea(widget.area,
                            start: _start, end: _end, calendarIds: _calendars);
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _saving = false;
                            _message =
                                'That area could not be saved. Please try again.';
                          });
                        }
                      }
                    },
              child: Text(_saving
                  ? 'Saving…'
                  : 'Apply to ${affected.length} ${affected.length == 1 ? 'plan' : 'plans'}')),
        ]);
      });
  Future<void> _dates() async {
    final now = widget.controller.clock().toLocal();
    final result = await showDateRangePicker(
        context: context,
        firstDate: _start.isBefore(now)
            ? DateTime(_start.toLocal().year, _start.toLocal().month,
                _start.toLocal().day)
            : DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 1, now.month, now.day),
        initialDateRange: DateTimeRange(
            start: _start.toLocal(),
            end: _end.subtract(const Duration(microseconds: 1)).toLocal()));
    if (result != null && mounted) {
      setState(() {
        _start =
            DateTime(result.start.year, result.start.month, result.start.day);
        _end = DateTime(result.end.year, result.end.month, result.end.day + 1);
      });
    }
  }
}
