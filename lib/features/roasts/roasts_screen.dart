import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../design/dm_theme.dart';
import '../../models/temperature_unit.dart';
import '../../models/weather_models.dart';
import '../../repositories/pack_roast_repository.dart';
import '../../repositories/roast_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/weather_repository.dart';
import '../../services/settings_controller.dart';
import '../../services/weather_location_controller.dart';
import '../../shared/widgets/dm_approved_components.dart';
import '../fun/meme/meme_weather.dart';
import 'models/roast_persona.dart';
import 'services/displayed_roast_share.dart';
import 'services/roast_safety.dart';
import 'widgets/daymaker_persona_carousel.dart';
import 'widgets/featured_roast_card.dart';

class RoastsScreen extends StatefulWidget {
  const RoastsScreen(
      {super.key,
      this.roastRepository,
      this.settingsRepository,
      this.initialWeather,
      this.isSample = false,
      this.clock});
  final RoastRepository? roastRepository;
  final SettingsRepository? settingsRepository;

  /// Explicit fixture injection only. Production obtains the selected location.
  final WeatherBundle? initialWeather;
  final bool isSample;
  final DateTime Function()? clock;
  @override
  State<RoastsScreen> createState() => _RoastsScreenState();
}

class _RoastsScreenState extends State<RoastsScreen>
    with WidgetsBindingObserver {
  Timer? _contextTimer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contextTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _foreground) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && mounted) {
      setState(() {}); // Local truth/daypart revalidation only.
    }
  }

  late RoastRepository _repository;
  SettingsRepository? _settingsRepository;
  SettingsController? _settings;
  WeatherLocationController? _location;
  bool _initialized = false;
  bool _loading = true;
  bool _anotherLoading = false;
  bool _showAll = false;
  Object? _error;
  WeatherBundle? _weather;
  String? _locationKey;
  int _loadGeneration = 0;
  TemperatureUnit? _loadedUnit;
  List<Persona> _personas = const [];
  Map<String, Roast> _roasts = const {};
  List<Roast> _history = const [];
  String _selectedId = RoastPersonas.defaultPersona.id;
  final _sources = <String, DisplayedRoastSnapshot>{};
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  TemperatureUnit get _unit =>
      _settings?.temperatureUnit ?? TemperatureUnit.fahrenheit;
  String? get _selectedLocationKey => _location?.selectedLocation == null
      ? null
      : '${_location!.selectedLocation!.lat},${_location!.selectedLocation!.lon}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _repository = widget.roastRepository ?? context.read<RoastRepository>();
    _settingsRepository =
        widget.settingsRepository ?? context.read<SettingsRepository?>();
    _settings = context.read<SettingsController?>();
    _location = context.read<WeatherLocationController?>();
    _selectedId =
        _settings?.selectedPersonaId ?? RoastPersonas.defaultPersona.id;
    _locationKey = _selectedLocationKey;
    _location?.addListener(_onLocationChanged);
    _settings?.addListener(_onSettingsChanged);
    unawaited(_load());
  }

  void _onSettingsChanged() {
    if (_loadedUnit != null &&
        _loadedUnit != _unit &&
        _repository is PackRoastRepository) {
      _loadedUnit = _unit;
      unawaited(_load());
    }
    final selected = _settings?.selectedPersonaId;
    if (selected != null && selected != _selectedId) {
      setState(() => _selectedId = selected);
      _rememberDisplayed();
    }
  }

  void _onLocationChanged() {
    final key = _selectedLocationKey;
    if (key != _locationKey) {
      _locationKey = key;
      _weather = null;
      _roasts = {};
      unawaited(_load());
    } else if (_location?.currentWeather != null && mounted) {
      // Safety may update without changing location; never refetch from a theme.
      if (!identical(_weather, _location!.currentWeather) && !_loading) {
        unawaited(_load()); // Reuses currentWeather; this branch cannot fetch.
      } else {
        setState(() => _weather = _location!.currentWeather);
      }
    }
  }

  @override
  void dispose() {
    _contextTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _location?.removeListener(_onLocationChanged);
    _settings?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var weather = widget.initialWeather ?? _location?.currentWeather;
      final location = _location?.selectedLocation;
      if (weather == null && location != null) {
        weather = await context.read<WeatherRepository>().getWeather(
            latitude: location.lat,
            longitude: location.lon,
            location: location);
        if (!mounted || generation != _loadGeneration) return;
        final latitude = weather.current.latitude;
        final longitude = weather.current.longitude;
        if ((latitude != null && (latitude - location.lat).abs() > .02) ||
            (longitude != null && (longitude - location.lon).abs() > .02)) {
          throw StateError('Weather does not match the selected location.');
        }
        _location?.updateWeatherSafety(weather, location);
      }
      if (!mounted || generation != _loadGeneration) return;
      if (weather == null) {
        setState(() => _weather = null);
        return;
      }
      final personas = await _repository.getPersonas();
      if (_settings == null) {
        final saved = await _settingsRepository?.loadSettings();
        if (saved != null) _selectedId = saved.selectedPersonaId;
      }
      if (_repository case final PackRoastRepository repository) {
        repository.setWeather(weather, _unit);
      }
      final snapshotId = weather.snapshot?.id ??
          'weather-${weather.current.displayUpdatedAt.millisecondsSinceEpoch}';
      final roasts = await Future.wait(personas.map((persona) =>
          _repository.getDailyRoast(
              personaId: persona.id, weatherSnapshotId: snapshotId)));
      final history = await _repository.getRoastHistory();
      if (!mounted || generation != _loadGeneration) return;
      const order = [
        'karen',
        'frat_bro',
        'politician',
        'grandpa',
        'two_year_old'
      ];
      setState(() {
        _weather = weather;
        _loadedUnit = _unit;
        _personas = [...personas]
          ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));
        _roasts = {
          for (var i = 0; i < personas.length; i++) personas[i].id: roasts[i]
        };
        _history = history;
        if (!_personas.any((p) => p.id == _selectedId) &&
            _personas.isNotEmpty) {
          _selectedId = _personas.first.id;
        }
      });
      _rememberDisplayed();
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _alertsActive =>
      _weather?.current.alertIds.isNotEmpty == true ||
      _weather?.alerts.any((alert) => alert.isRelevantAt(_now)) == true ||
      roastHumorBlocked(_weather, now: _now);

  void _rememberDisplayed() {
    final roast = _roasts[_selectedId];
    final weather = _weather;
    if (roast == null || weather == null || _alertsActive) return;
    bool stillShown() =>
        mounted &&
        !_alertsActive &&
        identical(_weather, weather) &&
        _selectedId == roast.personaId &&
        _roasts[_selectedId]?.text == roast.text &&
        identical(_roasts[_selectedId]?.selection, roast.selection);
    final source = DisplayedRoastSnapshot(
      id: roast.id,
      text: roast.text,
      personaId: roast.personaId,
      mood: roast.resolvedMood,
      selection: roast.selection,
      sourceKey: 'roasts',
      sourceLabel: 'Roasts',
      isSample: widget.isSample,
      weatherSnapshot: MemeWeather.freeze(weather,
          temperatureUnit: _unit, isSample: widget.isSample, now: _now),
      capturedAt: _now,
    );
    _sources[_sourceKey(roast)] = source;
    if (_repository case final PackRoastRepository repository) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (stillShown()) {
          repository.recordDisplayed(roast);
        }
      });
      _history = [
        roast,
        ..._history.where((r) => r.id != roast.id || r.text != roast.text)
      ].take(50).toList();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (stillShown()) {
        context
            .read<DisplayedRoastRegistry?>()
            ?.publish(source, weather: weather);
      }
    });
  }

  void _select(Persona persona) {
    setState(() => _selectedId = persona.id);
    if (_settings != null) {
      _settings!.setSelectedPersonaId(persona.id);
    } else {
      unawaited(_saveSelection(persona.id));
    }
    _rememberDisplayed();
  }

  Future<void> _saveSelection(String personaId) async {
    try {
      await _settingsRepository?.updateSettings(
          (settings) => settings.copyWith(selectedPersonaId: personaId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your persona selection could not be saved.')));
      }
    }
  }

  Future<void> _another() async {
    if (_anotherLoading || _alertsActive) return;
    final requestedId = _selectedId;
    final current = _roasts[requestedId];
    if (current == null) return;
    setState(() => _anotherLoading = true);
    try {
      final Roast next;
      if (_repository case final PackRoastRepository repository) {
        next = await repository.nextRoast(
            personaId: requestedId,
            weatherSnapshotId: current.weatherSnapshotId);
      } else {
        // Fixture repositories can expose alternatives through their history.
        final candidates =
            await _repository.getRoastHistory(personaId: requestedId);
        next = candidates.where((r) => r.text != current.text).firstOrNull ??
            await _repository.getDailyRoast(
                personaId: requestedId,
                weatherSnapshotId: current.weatherSnapshotId);
      }
      if (!mounted) return;
      setState(() {
        _roasts = {..._roasts, requestedId: next};
      });
      if (_selectedId == requestedId) _rememberDisplayed();
      final history = await _repository.getRoastHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Another roast could not be loaded. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _anotherLoading = false);
    }
  }

  String _sourceKey(Roast roast) => roast.selection == null
      ? '${roast.id}|${roast.text}|${roast.createdAt.toUtc().toIso8601String()}'
      : DisplayedRoastRegistry.selectionKey(roast.selection!);

  Future<void> _share(Roast roast) async {
    final source = context
            .read<DisplayedRoastRegistry?>()
            ?.forSelection(roast.selection) ??
        _sources[_sourceKey(roast)] ??
        DisplayedRoastSnapshot(
            id: roast.id,
            text: roast.text,
            personaId: roast.personaId,
            mood: roast.resolvedMood,
            selection: roast.selection,
            sourceKey: 'history',
            sourceLabel: 'Roast history',
            isSample: widget.isSample,
            capturedAt: roast.createdAt);
    if (_alertsActive) return;
    await showDisplayedRoastShareSheet(context, source);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsController?>();
    if (_repository case final PackRoastRepository repository) {
      final weather = _weather;
      if (weather != null) {
        _roasts = {
          for (final persona in _personas)
            persona.id: PackRoastRepository.fromSelection(
                repository.controller.select(
                    persona: persona.id,
                    bundle: weather,
                    unit: _unit,
                    now: _now),
                weatherSnapshotId: weather.snapshot?.id ??
                    'weather-${weather.current.displayUpdatedAt.millisecondsSinceEpoch}')
        };
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _rememberDisplayed();
        });
      }
    }
    final colors = context.dmColors;
    return Scaffold(
        body: SafeArea(
            child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DmPageHeader(title: 'Roasts'),
                        const SizedBox(height: 20),
                        Text('YOUR FORECAST. THEIR OPINION.',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: colors.link)),
                        const SizedBox(height: 8),
                        const Text('Same weather.\nDifferent takes.',
                            style: TextStyle(
                                fontSize: 33,
                                height: 1.08,
                                letterSpacing: -1,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 22),
                        if (_loading && _weather == null)
                          const Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(child: CircularProgressIndicator()))
                        else if (_weather == null)
                          _status(
                              context,
                              _error == null
                                  ? 'Choose your forecast location'
                                  : 'Roasts unavailable',
                              _error == null
                                  ? 'Open Today to choose a location and load your weather.'
                                  : 'Weather could not be loaded. Your saved choices are unchanged.',
                              _error == null ? 'Choose location' : 'Retry',
                              _error == null
                                  ? () => context.go(AppRoutes.forecast)
                                  : _load)
                        else if (_alertsActive)
                          _status(
                              context,
                              _weather!.alerts
                                          .any((a) => a.isRelevantAt(_now)) ||
                                      _weather!.current.alertIds.isNotEmpty
                                  ? 'Weather alerts take priority'
                                  : 'Weather safety takes priority',
                              'Roasts are paused for these conditions. Check the current weather and official guidance.',
                              'View weather',
                              () => context.go(AppRoutes.forecast))
                        else if (_roasts[_selectedId] == null)
                          _status(
                              context,
                              'Roasts unavailable',
                              'The local roast collection could not be loaded.',
                              'Retry',
                              _load)
                        else ...[
                          DaymakerPersonaCarousel(
                              personas: _personas,
                              selectedPersonaId: _selectedId,
                              onPersonaSelected: _select),
                          const SizedBox(height: 10),
                          FeaturedRoastCard(
                              persona: _personas
                                  .firstWhere((p) => p.id == _selectedId),
                              roast: _roasts[_selectedId]!,
                              weather: _weather!,
                              temperatureUnit: _unit),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                                child: DmApprovedAction(
                                    label: _anotherLoading
                                        ? 'Loading…'
                                        : 'Another roast',
                                    icon: Icons.refresh,
                                    primary: true,
                                    onPressed:
                                        _anotherLoading ? null : _another)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Semantics(
                                    label:
                                        'Share featured roast from ${RoastPersonas.byId(_selectedId).displayName}',
                                    child: DmApprovedAction(
                                        label: 'Share',
                                        icon: Icons.ios_share,
                                        onPressed: () =>
                                            _share(_roasts[_selectedId]!)))),
                          ]),
                          const SizedBox(height: 20),
                          DmApprovedSectionHeader(
                              title: 'More from the crew',
                              action: _showAll ? 'Show less' : 'View all',
                              onAction: () =>
                                  setState(() => _showAll = !_showAll)),
                          for (final roast in _crew.take(_showAll ? 5 : 1))
                            _crewRow(context, roast),
                          const SizedBox(height: 18),
                          Text(
                              widget.isSample
                                  ? 'Synthetic design fixture · Sample weather'
                                  : _weatherStatus,
                              style: TextStyle(
                                  fontSize: 11, color: colors.textMuted)),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                              onPressed: () => context.push(
                                  AppRoutes.roastReveal,
                                  extra: _sources[
                                      '${_roasts[_selectedId]!.id}|${_roasts[_selectedId]!.text}']),
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('Explore roast reveals')),
                          if (!widget.isSample && _history.length > 1) ...[
                            const SizedBox(height: 18),
                            const DmApprovedSectionHeader(
                                title: 'Roast history'),
                            for (final roast in _history.take(5))
                              _crewRow(context, roast),
                          ],
                        ],
                      ],
                    ))),
          ]),
    )));
  }

  Iterable<Roast> get _crew => widget.isSample && _history.isNotEmpty
      ? _history.where((r) => r.personaId != _selectedId)
      : _personas
          .where((p) => p.id != _selectedId)
          .map((p) => _roasts[p.id])
          .whereType<Roast>();

  String get _weatherStatus {
    final weather = _weather!;
    final age =
        _now.toUtc().difference(weather.current.displayUpdatedAt.toUtc());
    final status = weather.isOfflineCache
        ? 'Cached weather'
        : age.isNegative
            ? 'Observation time is ahead of device clock'
            : age.inMinutes < 1
                ? 'Observed just now'
                : age.inHours < 1
                    ? 'Observed ${age.inMinutes} min ago'
                    : 'Observed ${age.inHours} hours ago';
    return 'Weather data © OpenWeather · $status${!age.isNegative && age.inMinutes > 30 ? ' · Stale' : ''}';
  }

  String _ageLabel(DateTime createdAt) {
    final age = _now.difference(createdAt);
    if (age.isNegative || age.inMinutes < 1) return 'Just now';
    if (age.inHours < 1) return '${age.inMinutes}m ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  Widget _crewRow(BuildContext context, Roast roast) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: context.dmColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: context.dmColors.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              _roasts = {..._roasts, roast.personaId: roast};
              _select(_personas.firstWhere((p) => p.id == roast.personaId));
            },
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  SizedBox(
                      width: 44,
                      height: 52,
                      child: DmPersonaPortrait(
                          personaId: roast.personaId,
                          mood: roast.resolvedMood)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('“${roast.text}”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                            '${RoastPersonas.byId(roast.personaId).displayName} · ${roast.resolvedMood.label} · ${_ageLabel(roast.createdAt)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: context.dmColors.textMuted)),
                      ])),
                  const Icon(Icons.chevron_right, size: 20),
                ])),
          ),
        ),
      );

  Widget _status(BuildContext context, String title, String message,
          String action, VoidCallback onPressed) =>
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: context.dmColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.dmColors.border)),
          child: Column(children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(action))
          ]));
}
