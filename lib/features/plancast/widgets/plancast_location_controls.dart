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
    final label = item.isOnline
        ? 'Online'
        : location?.candidate?.name ??
            item.venue?.name ??
            'Choose a weather area';
    final source = item.isOnline
        ? 'No venue weather needed'
        : location?.sourceLabel ?? 'Weather location';
    return Semantics(
      excludeSemantics: true,
      button: true,
      label: '$label. $source. Change weather location',
      child: InkWell(
        key: ValueKey('plancast-location-${item.event.id}'),
        onTap: () => changePlanCastLocation(context, item),
        borderRadius: BorderRadius.circular(DMSpacing.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
            child: Row(children: [
              Icon(
                  item.isOnline
                      ? Icons.videocam_outlined
                      : Icons.place_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: DMSpacing.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: DMTypography.labelLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Text(source, style: Theme.of(context).textTheme.bodySmall),
                  ])),
              const SizedBox(width: DMSpacing.sm),
              Text('Change',
                  style: DMTypography.label.copyWith(
                      color: Theme.of(context).colorScheme.secondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shared modal shell keeps the action reachable while long content scrolls.
Future<T?> showPlanCastSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * .88 -
                          MediaQuery.viewInsetsOf(context).bottom)
                      .clamp(160.0, 900.0)),
              child: child,
            )),
      ),
    );

class PlanCastSheetContent extends StatelessWidget {
  const PlanCastSheetContent(
      {super.key,
      required this.title,
      required this.child,
      this.subtitle,
      this.footer,
      this.busy = false});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
                padding:
                    const EdgeInsets.fromLTRB(DMSpacing.md, 0, DMSpacing.sm, 0),
                child: Row(children: [
                  Expanded(
                      child: Text(title, style: DMTypography.headingSmall)),
                  IconButton(
                      tooltip: 'Close',
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ])),
            if (subtitle != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DMSpacing.md, 0, DMSpacing.md, DMSpacing.sm),
                  child: Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall)),
            Flexible(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        DMSpacing.md, 0, DMSpacing.md, DMSpacing.md),
                    child: child)),
            if (footer != null)
              Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DMSpacing.md, DMSpacing.sm, DMSpacing.md, DMSpacing.md),
                  child: footer),
          ]);
}

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showPlanCastSheet<T>(
        context,
        SingleChildScrollView(
            padding: const EdgeInsets.all(DMSpacing.md), child: child));

Future<void> changePlanCastLocation(
        BuildContext context, PlanCastEventWeather item) =>
    showPlanCastSheet<void>(
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
  String _selection = 'automatic';
  bool _dirty = false, _saving = false, _reset = false;
  String? _message;
  late final LocationCandidate? _invite;
  late final bool _manual;

  @override
  void initState() {
    super.initState();
    final c = widget.controller, item = widget.item;
    // This only reads already resolved local evidence; opening a sheet never
    // starts a place lookup, location request or forecast load.
    final invite = c.locationResolver.resolve(
        event: item.event,
        now: c.clock(),
        state: const SmartLocationState(),
        lookupResults: c.locationLookup.cachedResults);
    _invite =
        invite.location.hasWeatherBasis ? invite.location.candidate : null;
    final rules = c.locationRules.where((r) => r.enabled).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final occurrence = rules
        .where((r) =>
            r.targetId == item.event.id &&
            {LocationRuleScope.occurrence, LocationRuleScope.legacy}
                .contains(r.scope))
        .firstOrNull;
    final evidence = c.locationResolver.extractor.extract(item.event);
    final series = rules
        .where((r) =>
            r.scope == LocationRuleScope.seriesMissing &&
            item.event.isRecurring &&
            r.targetId == item.event.seriesKey)
        .firstOrNull;
    final legacy = occurrence?.useAutomatic == true ||
            (!evidence.fromCalendarField && series != null)
        ? null
        : rules
            .where((r) =>
                r.scope == LocationRuleScope.legacy &&
                item.event.matchesLegacyRecurringKey(r.targetId) &&
                (r.choice.kind != LocationChoiceKind.online || item.isOnline))
            .firstOrNull;
    _manual = occurrence?.useAutomatic != true &&
        (occurrence != null ||
            legacy != null ||
            item.resolvedLocation?.source == LocationSource.userOverride);
    final inherited = switch (item.resolvedLocation?.source) {
      LocationSource.recurringRule => legacy ?? series,
      LocationSource.calendarDefault => rules
          .where((r) =>
              r.scope == LocationRuleScope.calendarDefault &&
              r.targetId == item.event.calendarId)
          .firstOrNull,
      _ => null,
    };
    _choice = occurrence?.useAutomatic == true
        ? null
        : occurrence?.choice ?? legacy?.choice ?? inherited?.choice;
    if (_choice != null) {
      _selection = switch (_choice!.kind) {
        LocationChoiceKind.currentArea => 'current',
        LocationChoiceKind.online => 'online',
        LocationChoiceKind.savedPlace => 'saved:${_choice!.savedPlaceId}',
        LocationChoiceKind.place => 'chosen',
      };
    } else if (item.isOnline) {
      _selection = 'online';
      _choice = const LocationChoice.online();
    } else if ({LocationSource.currentArea, LocationSource.lastKnownArea}
        .contains(item.resolvedLocation?.source)) {
      _selection = 'current';
      _choice = const LocationChoice.currentArea();
    } else if (_invite != null && _samePlace(_invite, item.venue)) {
      _selection = 'invite';
      _choice = LocationChoice.place(_invite!);
    } else if (item.venue != null) {
      final saved = c.savedPlaces
          .where((p) => _samePlace(p.candidate, item.venue))
          .firstOrNull;
      _selection = saved == null ? 'chosen' : 'saved:${saved.id}';
      _choice = saved == null
          ? LocationChoice.place(item.venue!)
          : LocationChoice.savedPlace(saved.id);
    }
  }

  bool _samePlace(LocationCandidate? a, LocationCandidate? b) =>
      a != null &&
      b != null &&
      (a.lat - b.lat).abs() < .00001 &&
      (a.lon - b.lon).abs() < .00001;

  void _select(String id, LocationChoice? choice, {bool reset = false}) {
    setState(() {
      _selection = id;
      _choice = choice;
      _dirty = true;
      _reset = reset;
      _message = null;
      if (reset) _scope = LocationRuleScope.occurrence;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final count =
            c.locationChoiceAffected(widget.item.event, _scope).length;
        return PopScope(
            canPop: !_saving,
            child: PlanCastSheetContent(
              title: 'Set event location',
              subtitle: 'Choose where to get weather for this event.',
              busy: _saving,
              footer: FilledButton(
                key: const ValueKey('plancast-save-location'),
                onPressed:
                    _saving || (_choice == null && !_reset) ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(20)),
                        child: Column(children: [
                          _option(
                              'current',
                              Icons.my_location,
                              'Current area',
                              c.currentArea?.displayName ??
                                  'Use your device’s area when available',
                              () => _select('current',
                                  const LocationChoice.currentArea())),
                          if (_invite != null)
                            _option(
                                'invite',
                                Icons.place_outlined,
                                'Location from invite',
                                _invite!.displayName,
                                () => _select(
                                    'invite', LocationChoice.place(_invite!))),
                          for (final place in c.savedPlaces)
                            _option(
                                'saved:${place.id}',
                                Icons.bookmark_border,
                                place.label,
                                place.candidate.displayName,
                                () => _select('saved:${place.id}',
                                    LocationChoice.savedPlace(place.id))),
                          if (_selection == 'chosen' &&
                              _choice?.candidate != null)
                            _option(
                                'chosen',
                                Icons.place_outlined,
                                _choice!.candidate!.name,
                                'Selected weather location',
                                () {}),
                          _option(
                              'search', Icons.search, 'Search for a city', null,
                              () async {
                            final place = await choosePlanCastArea(context, c);
                            if (mounted && place != null) {
                              _select('chosen', LocationChoice.place(place));
                            }
                          }, disclosure: true),
                          _option(
                              'online',
                              Icons.videocam_outlined,
                              'Online',
                              'No venue weather needed',
                              () => _select(
                                  'online', const LocationChoice.online())),
                        ])),
                    if (_manual || _reset)
                      TextButton.icon(
                          key: const ValueKey('plancast-automatic-location'),
                          icon: Icon(
                              _reset
                                  ? Icons.check_circle_outline
                                  : Icons.auto_awesome_outlined,
                              size: 18),
                          onPressed: _saving
                              ? null
                              : () => _select('automatic', null, reset: true),
                          label: const Text('Use automatic location')),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Apply to…',
                            style: DMTypography.labelLarge),
                        subtitle: Text(_scopeLabel(_scope)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _saving || _reset ? null : _chooseScope),
                    if (_scope != LocationRuleScope.occurrence)
                      Text(
                          '$count currently loaded ${count == 1 ? 'plan' : 'plans'} affected. Confirmed destinations stay unchanged.',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (_reset)
                      Text(
                          'This event returns to automatic location. Series and calendar rules stay in place.',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (_message != null)
                      Padding(
                          padding: const EdgeInsets.only(top: DMSpacing.sm),
                          child: Text(_message!,
                              style: Theme.of(context).textTheme.bodySmall)),
                    const SizedBox(height: DMSpacing.sm),
                    Text(
                        'Changes stay in PlanCast. Your calendar is read-only.',
                        style: Theme.of(context).textTheme.bodySmall),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title:
                            const Text('Advanced', style: DMTypography.label),
                        children: [
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.pin_drop_outlined),
                              title: const Text('Exact venue coordinates'),
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final place =
                                          await _exactCoordinates(context);
                                      if (mounted && place != null) {
                                        _select('chosen',
                                            LocationChoice.place(place));
                                      }
                                    })
                        ]),
                  ]),
            ));
      });

  Widget _option(String id, IconData icon, String title, String? subtitle,
      VoidCallback onTap,
      {bool disclosure = false}) {
    final selected = _selection == id;
    return Semantics(
        selected: selected,
        button: true,
        child: ListTile(
          key: ValueKey('plancast-location-choice-$id'),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: DMSpacing.sm, vertical: DMSpacing.xs),
          leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          title: Text(title, style: DMTypography.labelLarge),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: Icon(
              disclosure
                  ? Icons.chevron_right
                  : selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
              color: selected
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.onSurfaceVariant),
          onTap: _saving ? null : onTap,
        ));
  }

  String _scopeLabel(LocationRuleScope scope) => switch (scope) {
        LocationRuleScope.occurrence => 'This event',
        LocationRuleScope.seriesMissing =>
          'Missing-location events in this series',
        LocationRuleScope.calendarDefault =>
          'Missing-location events in this calendar',
        LocationRuleScope.legacy => 'This event',
      };

  Future<void> _chooseScope() async {
    final scope = await showPlanCastSheet<LocationRuleScope>(
        context,
        PlanCastSheetContent(
            title: 'Apply location to…',
            subtitle: 'Known destinations keep their own weather.',
            child: Column(children: [
              for (final scope in [
                LocationRuleScope.occurrence,
                if (widget.item.event.isRecurring)
                  LocationRuleScope.seriesMissing,
                LocationRuleScope.calendarDefault
              ])
                ListTile(
                    title: Text(_scopeLabel(scope)),
                    trailing: Icon(_scope == scope
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                    onTap: () => Navigator.pop(context, scope)),
            ])));
    if (scope != null && mounted) {
      setState(() {
        _scope = scope;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    if (!_reset && _choice == null) return;
    setState(() => _saving = true);
    try {
      final c = widget.controller;
      if (_reset) {
        await c.resetEventLocation(widget.item.event);
      } else {
        final freshDeviceArea = c.deviceAreaService.failure == null &&
            c.locationResolver.policy
                .accepts(c.deviceAreaService.sample, c.clock(), current: true);
        if (_choice!.kind == LocationChoiceKind.currentArea &&
            !freshDeviceArea) {
          await c.useCurrentArea();
          if (!mounted) return;
          if (c.currentArea == null) {
            setState(() {
              _saving = false;
              _message = c.locationPermissionMessage ??
                  'Your current area is unavailable. Choose a city or try again.';
            });
            return;
          }
        }
        await c.setLocationChoice(widget.item.event, _choice!, scope: _scope);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = 'That choice could not be saved. Please try again.';
        });
      }
    }
  }
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
    final needsDefault = c.currentArea == null &&
        c.defaultArea == null &&
        items.any((e) {
          if (e.isOnline || !e.needsLocation) return false;
          final evidence = c.locationResolver.extractor.extract(e.event);
          return !evidence.hasDestinationEvidence && !evidence.virtualOnly;
        });
    if (travel == null &&
        !needsDefault &&
        !c.showSmartLocationExplanation &&
        !c.canUndoLocationChange) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('plancast-location-notice'),
      padding: const EdgeInsets.fromLTRB(
          DMSpacing.sm, DMSpacing.sm, DMSpacing.xs, 0),
      decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: DMSpacing.xs),
              child:
                  Icon(Icons.my_location, size: 18, color: colors.secondary)),
          const SizedBox(width: DMSpacing.sm),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    travel != null
                        ? travel.message
                        : needsDefault
                            ? 'Choose one default city for plans without a location.'
                            : c.showSmartLocationExplanation
                                ? 'Plans without a location use your area. Known destinations stay put.'
                                : 'Location updated.',
                    style: DMTypography.bodySmall),
                if (travel != null)
                  Text('Until ${planCastTimestamp(context, travel.windowEnd)}',
                      style: Theme.of(context).textTheme.bodySmall),
              ])),
          if (travel != null || c.showSmartLocationExplanation && !needsDefault)
            IconButton(
                tooltip: 'Dismiss location notice',
                onPressed: travel != null
                    ? c.dismissTravelNotice
                    : c.acknowledgeSmartLocations,
                icon: const Icon(Icons.close, size: 18)),
        ]),
        Wrap(spacing: DMSpacing.xs, children: [
          if (travel != null)
            TextButton(
                onPressed: () => _changeTravelArea(context, c),
                child: const Text('Change')),
          if (needsDefault && travel == null)
            TextButton(
                onPressed: () async {
                  final place = await choosePlanCastArea(context, c);
                  if (place != null) await c.setDefaultArea(place);
                },
                child: const Text('Choose default city')),
          if (c.canUndoLocationChange)
            TextButton.icon(
                onPressed: c.undoLocationChange,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Undo')),
        ]),
      ]),
    );
  }
}

Future<void> _changeTravelArea(
    BuildContext context, PlanCastController c) async {
  final travel = c.travelNotice;
  if (travel == null) return;
  final home = c.savedPlaces
      .where((p) =>
          p.label.trim().toLowerCase() == 'home' &&
          p.candidate.hasValidCoordinates)
      .firstOrNull;
  final area = await showPlanCastSheet<LocationCandidate>(
      context,
      PlanCastSheetContent(
          title: 'Change area for these plans',
          subtitle:
              '${travel.affectedCount} plans · until ${planCastTimestamp(context, travel.windowEnd)}',
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Keep this area'),
                subtitle: Text(travel.area.displayName),
                onTap: () => Navigator.pop(context, travel.area)),
            if (home != null)
              ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Use Home'),
                  subtitle: Text(home.candidate.displayName),
                  onTap: () => Navigator.pop(context, home.candidate)),
            ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search for a city'),
                onTap: () async {
                  final place = await choosePlanCastArea(context, c);
                  if (context.mounted && place != null) {
                    Navigator.pop(context, place);
                  }
                }),
          ])));
  if (area != null && context.mounted) {
    await reviewPlanCastBatch(context, c, area,
        start: travel.windowStart,
        end: travel.windowEnd,
        calendarIds: travel.calendarIds);
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
