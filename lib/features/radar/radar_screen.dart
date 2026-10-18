import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/dm_theme.dart';
import '../../models/weather_models.dart';
import '../../repositories/fake_weather_repository.dart';
import '../../repositories/weather_repository.dart';
import '../../services/chaos_score_service.dart';
import '../../services/open_weather_backend_client.dart';
import '../../services/weather_location_controller.dart';
import '../../shared/widgets/weather_location_selector.dart';
import 'radar_expansion_notification.dart';
import 'radar_playback_controller.dart';
import 'radar_presentation.dart';
import 'radar_session.dart';
import 'widgets/open_weather_radar_map.dart';
import 'widgets/radar_control_dock.dart';
import 'widgets/radar_color_scale.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key, this.tileProvider, this.controller, this.now});

  /// Existing offline preview/test boundaries; production uses live providers.
  final TileProvider? tileProvider;
  final RadarPlaybackController? controller;
  final DateTime Function()? now;
  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with WidgetsBindingObserver {
  final _mapController = MapController();
  final _chromeChanges = ValueNotifier<int>(0);
  final _dockKey = GlobalKey();
  final _dockScroll = ScrollController();
  WeatherLocationController? _location;
  WeatherRepository? _repository;
  OpenWeatherBackendClient? _client;
  RadarPlaybackController? _radar;
  WeatherBundle? _chaosWeather;
  SharedPreferences? _preferences;
  bool _ownsLocation = false;
  bool _ownsRadar = false;
  bool _expanded = false;
  bool _panelOpen = false;
  bool _overlayVisible = true;
  bool _basemapIssue = false;
  bool _frameLoading = false;
  bool _foreground = true;
  bool _tickerEnabled = true;
  bool _followingLocation = true;
  bool _mapReady = false;
  bool _deactivated = false;
  double _opacity = .65;
  String? _tileIssue;
  String? _locationKey;
  int _chaosSerial = 0;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_location == null) {
      WidgetsBinding.instance.addObserver(this);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      _repository =
          context.read<WeatherRepository?>() ?? const FakeWeatherRepository();
      _location = context.read<WeatherLocationController?>();
      _ownsLocation = _location == null;
      _location ??= WeatherLocationController(repository: _repository!);
      _client = context.read<OpenWeatherBackendClient?>() ??
          OpenWeatherBackendClient();
      _location!.addListener(_locationChanged);
      _locationChanged();
      unawaited(_restoreOpacity());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _radar?.setActive(_foreground && _tickerEnabled);
    });
  }

  Future<void> _restoreOpacity() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _preferences = preferences;
      final value = preferences.getDouble('radar.overlayOpacity.v1');
      if (value != null && value.isFinite) {
        setState(() => _opacity = value.clamp(.1, 1));
      }
    } catch (_) {/* A local preference failure never fetches remotely. */}
  }

  void _locationChanged() {
    final location = _location?.selectedLocation;
    if (location == null) return;
    final key = '${location.lat}:${location.lon}';
    if (key == _locationKey) {
      final loaded = _location!.currentWeather;
      if (loaded != null && !identical(loaded, _chaosWeather)) {
        _chaosWeather = loaded;
        if (mounted) setState(() {});
      }
      return;
    }
    _locationKey = key;
    _tileIssue = null;
    _basemapIssue = false;
    _chaosWeather = _location!.currentWeather;
    if (_radar == null) {
      final session = context.read<RadarSession?>();
      _ownsRadar = widget.controller == null && session == null;
      _radar = widget.controller ??
          session?.obtain(
              client: _client!, location: location, now: widget.now) ??
          RadarPlaybackController(
              client: _client!, location: location, now: widget.now);
      // A location may have changed on Today while this retained controller
      // was inactive. Apply that location before resuming any metadata work.
      unawaited(_radar!.setLocation(location));
      _radar!.setActive(_foreground && _tickerEnabled);
      _radar!.addListener(_radarChanged);
      unawaited(_radar!.initialize());
    } else {
      unawaited(_radar!.setLocation(location));
    }
    unawaited(_loadChaosWeather(location));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mapReady) _recenter();
    });
    if (mounted) setState(() {});
  }

  Future<void> _loadChaosWeather(LocationCandidate location) async {
    final serial = ++_chaosSerial;
    if (_chaosWeather != null) return;
    try {
      // Same existing once-per-location weather path, reused when already loaded.
      final weather = await _repository!.getWeather(
          latitude: location.lat, longitude: location.lon, location: location);
      if (!mounted || serial != _chaosSerial) return;
      setState(() => _chaosWeather = weather);
    } catch (_) {/* No invented score when the weather is unavailable. */}
  }

  void _radarChanged() {
    if (mounted && !_deactivated) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _radar?.setActive(_foreground && _tickerEnabled);
    if (mounted) setState(() {});
  }

  @override
  void deactivate() {
    _deactivated = true;
    _radar?.setActive(false, notify: false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _deactivated = false;
    _radar?.setActive(_foreground && _tickerEnabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _location?.removeListener(_locationChanged);
    if (_ownsLocation) _location?.dispose();
    _radar?.removeListener(_radarChanged);
    if (_ownsRadar) _radar?.dispose();
    _mapController.dispose();
    _dockScroll.dispose();
    _chromeChanges.dispose();
    super.dispose();
  }

  RadarPresentation get _presentation => RadarPresentation(
        mode: _radar!.mode,
        frames: _radar!.frames,
        frame: _radar!.selectedFrame,
        now: _now,
        timezone: _chaosWeather?.current.timezone,
        timezoneOffset: _chaosWeather?.current.timezoneOffset,
        refreshedAt: _radar!.lastSuccessfulRefresh,
      );

  ChaosScore? get _chaos {
    final weather = _chaosWeather;
    final sourceTime = weather?.current.sourceUpdatedAt;
    if (!_radar!.isLatest ||
        _radar!.mode == RadarMode.futureCast ||
        weather == null ||
        weather.isOfflineCache ||
        sourceTime == null ||
        !weather.current.temperatureKnown ||
        !weather.current.windKnown ||
        !weather.current.precipitationChanceKnown ||
        _now.difference(sourceTime) > const Duration(minutes: 30) ||
        sourceTime.isAfter(_now.add(const Duration(minutes: 2)))) {
      return null;
    }
    return ChaosScoreService.evaluate(weather);
  }

  void _changeChrome(VoidCallback change) {
    setState(change);
    _chromeChanges.value++;
  }

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    _changeChrome(() => _expanded = value);
    RadarExpansionNotification(value).dispatch(context);
  }

  void _zoom(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3, 12));
  }

  void _recenter() {
    final location = _location?.selectedLocation;
    if (location == null || !_mapReady) return;
    final box = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    final bottom = (box?.hasSize == true ? box!.size.height : 170.0) + 36;
    final top = MediaQuery.paddingOf(context).top + (_expanded ? 88 : 132);
    _followingLocation = true;
    _mapController.move(LatLng(location.lat, location.lon), radarCityZoom,
        offset: Offset(0, (top - bottom) / 2));
  }

  Future<void> _showPanel(
      String title, Widget Function(BuildContext) body) async {
    if (_panelOpen || !mounted) return;
    _panelOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (sheetContext) => AnimatedBuilder(
            animation: Listenable.merge([_radar!, _chromeChanges]),
            builder: (context, _) => ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .82,
                      maxWidth: 640),
                  child: SafeArea(
                      top: false,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                            child: Row(children: [
                              Expanded(
                                  child: Text(title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge)),
                              IconButton(
                                  tooltip: 'Close $title',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop()),
                            ])),
                        Flexible(
                            child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                child: body(context))),
                      ])),
                )),
      );
    } finally {
      _panelOpen = false;
    }
  }

  void _showLocation() => _showPanel(
      'Radar location',
      (context) => WeatherLocationSelector(
          controller: _location!,
          title: 'Choose a location',
          onLocationSelected: (_) =>
              Navigator.of(context, rootNavigator: true).pop()));

  void _showChaos() {
    final score = _chaos;
    if (score == null) return;
    _showPanel('Chaos Meter', (context) => _chaosDetails(context, score));
  }

  Widget _chaosDetails(BuildContext context, ChaosScore score) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Chaos ${score.value} · ${score.label}',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(score.explanation),
        const SizedBox(height: 12),
        const Text(
            'A snapshot of current and upcoming weather signals for this location. '
            'It is not a warning or a measurement of the selected radar image.'),
      ]);

  void _showLayers() => _showPanel(
      'Layers',
      (context) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_radar!.mode.label,
                style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Weather overlay'),
                value: _overlayVisible,
                onChanged: (value) =>
                    _changeChrome(() => _overlayVisible = value)),
            Text('Weather opacity · ${(_opacity * 100).round()}%'),
            Slider(
                value: _opacity,
                min: .1,
                max: 1,
                divisions: 18,
                semanticFormatterCallback: (value) =>
                    '${(value * 100).round()} percent weather opacity',
                label: '${(_opacity * 100).round()}%',
                onChanged: (value) => _changeChrome(() => _opacity = value),
                onChangeEnd: (value) {
                  unawaited(_preferences?.setDouble(
                      'radar.overlayOpacity.v1', value));
                }),
            const Divider(),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: () => _zoom(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Zoom in')),
              OutlinedButton.icon(
                  onPressed: () => _zoom(-1),
                  icon: const Icon(Icons.remove),
                  label: const Text('Zoom out')),
              OutlinedButton.icon(
                  onPressed: _recenter,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Recenter')),
            ]),
            const SizedBox(height: 12),
            Text(
                _followingLocation
                    ? 'Centered on the selected location.'
                    : 'Map moved. Recenter returns to the selected location.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            const Text(
                'Pinch to zoom and drag to explore. Map appearance follows your app theme.'),
          ]));

  void _showDetails() => _showPanel('Radar details', (context) {
        final p = _presentation;
        final chaos = _chaos;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.sourceLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Selected frame: ${p.frameTimeLabel}'),
          const SizedBox(height: 8),
          Text(p.subtitle),
          if (p.refreshedTimeLabel != null) ...[
            const SizedBox(height: 8),
            Text('Last successful metadata refresh: ${p.refreshedTimeLabel}'),
          ],
          if (_radar!.mode == RadarMode.futureCast) ...[
            const SizedBox(height: 8),
            Text('Forecast issue time: ${p.forecastIssueTimeLabel}'),
          ],
          const SizedBox(height: 12),
          Text(_location!.selectedLocation!.displayName),
          const Divider(),
          _legendDetails(context),
          const Divider(),
          if (chaos != null) ...[
            _chaosDetails(context, chaos),
            const Divider(),
          ],
          Wrap(spacing: 8, children: [
            TextButton.icon(
                onPressed: _radar!.loading ? null : () => _radar!.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh radar')),
            TextButton.icon(
                onPressed:
                    _radar!.canJumpToNow ? _radar!.jumpToLatestOrNow : null,
                icon: const Icon(Icons.schedule),
                label: Text(_radar!.mode == RadarMode.futureCast
                    ? 'Nearest forecast to now'
                    : 'Latest observation')),
          ]),
          const Text(
              'Playback uses the available frames at the existing 0.9-second cadence. '
              'Missing images are unavailable data, not confirmed clear weather.'),
          const SizedBox(height: 8),
          RadarMapAttribution(
              source:
                  _radar!.selectedFrame?.source ?? _radar!.mode.sourceParam),
        ]);
      });

  Widget _legendDetails(BuildContext context) {
    final source = _radar!.selectedFrame?.source ?? _radar!.mode.sourceParam;
    final noaa = source == 'noaa_mrms';
    final global = source == 'openweather_global';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RadarColorScale(source: source, compact: false),
      const SizedBox(height: 12),
      Text(noaa || global
          ? 'The map retains the provider’s reflectivity colors. Reflectivity is measured in dBZ; it is not a direct rainfall-rate measurement.'
          : 'The map retains OpenWeather’s US forecast radar colors. Its available metadata and product guide do not specify numeric color thresholds.'),
      if (!global) ...[
        const SizedBox(height: 6),
        const Text(
            'Open the provider guide for interpretation. Missing imagery does not confirm clear weather.'),
      ],
      TextButton.icon(
          onPressed: () => launchUrl(
              Uri.parse(noaa
                  ? 'https://radar.weather.gov/'
                  : global
                      ? 'https://openweathermap.org/api/global-precipitation-map-forecast'
                      : 'https://openweathermap.org/api/us-precipitation-map-forecast'),
              mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(noaa ? 'NOAA radar guide' : 'OpenWeather radar guide')),
    ]);
  }

  void _showLegend() => _showPanel('Color scale', _legendDetails);

  String? get _notice {
    if (_basemapIssue) {
      return 'Base map tiles could not load. Check your connection and try moving the map.';
    }
    if (_radar!.loading && _radar!.selectedFrame == null) {
      return 'Loading radar frames…';
    }
    if (_tileIssue != null) return _tileMessage(_tileIssue!);
    if (_radar!.message != null) return _radar!.message;
    if (!_overlayVisible) return 'Weather overlay hidden';
    if (_frameLoading) return 'Loading selected image…';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final location = _location?.selectedLocation;
    if (location == null || _radar == null) {
      return Scaffold(
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_location != null)
          WeatherLocationSelector(
              controller: _location!, title: 'Choose a radar location'),
      ])));
    }
    final radar = _radar!;
    return PopScope<void>(
      canPop: !_expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _expanded) _setExpanded(false);
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent()
        },
        child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
                if (_expanded) _setExpanded(false);
                return null;
              }),
            },
            child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape &&
                      _expanded &&
                      !_panelOpen) {
                    _setExpanded(false);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Scaffold(
                  backgroundColor: context.dmColors.appBackground,
                  body: LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 700;
                    final short = constraints.maxHeight < 450 && wide;
                    final inset = wide ? 24.0 : 12.0;
                    final top = MediaQuery.paddingOf(context).top + 12;
                    final bottom = _expanded
                        ? MediaQuery.paddingOf(context).bottom + 12
                        : 6.0;
                    final large =
                        MediaQuery.textScalerOf(context).scale(14) > 21;
                    final chaos = _chaos;
                    final frameKey =
                        '${radar.mode}:${radar.selectedFrame?.timestamp}';
                    return Stack(fit: StackFit.expand, children: [
                      OpenWeatherRadarMap(
                        key: const ValueKey('persistent-radar-map'),
                        tileProvider: widget.tileProvider,
                        client: _client!,
                        mapController: _mapController,
                        location: location,
                        mode: radar.mode,
                        frame: radar.selectedFrame,
                        opacity: _opacity,
                        overlayVisible: _overlayVisible,
                        active: _foreground && _tickerEnabled,
                        recenterOnLocationChange: false,
                        onMapReady: () {
                          _mapReady = true;
                          _recenter();
                        },
                        onPositionChanged: (_, hasGesture) {
                          _mapReady = true;
                          if (hasGesture) _followingLocation = false;
                        },
                        onFrameLoading: (loading) {
                          if (mounted &&
                              frameKey ==
                                  '${radar.mode}:${radar.selectedFrame?.timestamp}' &&
                              _frameLoading != loading) {
                            setState(() => _frameLoading = loading);
                          }
                        },
                        onTileIssue: (issue) {
                          if (mounted &&
                              frameKey ==
                                  '${radar.mode}:${radar.selectedFrame?.timestamp}' &&
                              _tileIssue != issue) {
                            setState(() => _tileIssue = issue);
                          }
                        },
                        onBasemapIssue: (issue) {
                          if (mounted && _basemapIssue != issue) {
                            setState(() => _basemapIssue = issue);
                          }
                        },
                      ),
                      Positioned(
                          top: top,
                          left: inset,
                          right: inset,
                          child: Align(
                              alignment: short
                                  ? Alignment.topLeft
                                  : Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: short
                                        ? constraints.maxWidth * .4
                                        : 900),
                                child: _expanded
                                    ? _expandedHeader(location)
                                    : _header(location),
                              ))),
                      if (!_expanded &&
                          !large &&
                          !short &&
                          (chaos != null || radar.mode == RadarMode.futureCast))
                        Positioned(
                            top: top + (large ? 108 : 80),
                            left: inset,
                            right: inset + 64,
                            child: Align(
                                alignment: Alignment.topLeft,
                                child: RadarSurface(
                                    borderRadius: 28,
                                    child: InkWell(
                                        onTap:
                                            chaos == null ? null : _showChaos,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        minHeight: 32),
                                                child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                          chaos == null
                                                              ? Icons.timeline
                                                              : Icons
                                                                  .bubble_chart_outlined,
                                                          size: 22),
                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                          child: Text(
                                                              chaos == null
                                                                  ? 'Forecast view'
                                                                  : 'Chaos ${chaos.value} · ${chaos.label}',
                                                              style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700))),
                                                      if (chaos != null)
                                                        const Icon(
                                                            Icons.expand_more,
                                                            size: 20),
                                                    ]))))))),
                      Positioned(
                          right: short ? null : inset,
                          left: short ? inset : null,
                          top: short
                              ? top + 90
                              : large
                                  ? top + 132
                                  : math.max(
                                      top + 162, constraints.maxHeight * .25),
                          child: Flex(
                              direction: (short || large)
                                  ? Axis.horizontal
                                  : Axis.vertical,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RadarSurface(
                                    borderRadius: 28,
                                    child: IconButton(
                                        tooltip: 'Recenter radar map',
                                        onPressed: _recenter,
                                        icon: const Icon(Icons.my_location,
                                            size: 26))),
                                const SizedBox(height: 10, width: 10),
                                RadarSurface(
                                    borderRadius: 28,
                                    child: IconButton(
                                        tooltip: 'Radar layers',
                                        onPressed: _showLayers,
                                        icon: const Icon(Icons.layers_outlined,
                                            size: 26))),
                              ])),
                      Positioned(
                          left: short ? constraints.maxWidth * .46 : inset,
                          right: inset,
                          bottom: bottom,
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: wide ? 700 : 600,
                                    maxHeight: math.max(
                                        80,
                                        constraints.maxHeight -
                                            top -
                                            (short
                                                ? 8
                                                : large
                                                    ? 196
                                                    : _expanded
                                                        ? 104
                                                        : 146))),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                          child: Scrollbar(
                                              controller: _dockScroll,
                                              thumbVisibility: large || short,
                                              child: SingleChildScrollView(
                                                  controller: _dockScroll,
                                                  child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (_expanded)
                                                          Align(
                                                              alignment: Alignment
                                                                  .centerLeft,
                                                              child: RadarSurface(
                                                                  borderRadius:
                                                                      20,
                                                                  child: TextButton.icon(
                                                                      onPressed:
                                                                          _showLegend,
                                                                      icon: const Icon(
                                                                          Icons
                                                                              .gradient,
                                                                          size:
                                                                              18),
                                                                      label: Text(
                                                                          radar.mode == RadarMode.futureCast
                                                                              ? 'Forecast · Color scale'
                                                                              : 'Reflectivity · dBZ',
                                                                          style:
                                                                              const TextStyle(fontSize: 12))))),
                                                        RadarControlDock(
                                                            key: _dockKey,
                                                            controller: radar,
                                                            presentation:
                                                                _presentation,
                                                            expanded: _expanded,
                                                            onDetails:
                                                                _showDetails,
                                                            onLegend:
                                                                _showLegend,
                                                            status: _notice,
                                                            loading: radar
                                                                    .loading ||
                                                                _frameLoading),
                                                      ])))),
                                      const SizedBox(height: 2),
                                      RadarMapAttribution(
                                          source: radar.selectedFrame?.source ??
                                              radar.mode.sourceParam),
                                    ]),
                              ))),
                    ]);
                  }),
                ))),
      ),
    );
  }

  Widget _header(LocationCandidate location) => RadarSurface(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.radar, size: 28),
            const SizedBox(width: 12),
            Expanded(
                child: InkWell(
                    onTap: _showLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Radar',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              Semantics(
                                  button: true,
                                  onTap: _showLocation,
                                  label:
                                      'Choose radar location, ${location.displayName}',
                                  child: ExcludeSemantics(
                                      child: Row(children: [
                                    Flexible(
                                        child: Text(_shortLocation(location),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: context
                                                    .dmColors.textSecondary))),
                                    Icon(Icons.expand_more,
                                        size: 20,
                                        color: context.dmColors.textSecondary),
                                  ]))),
                            ])))),
            IconButton(
                tooltip: 'Expand map',
                onPressed: () => _setExpanded(true),
                icon: const Icon(Icons.fullscreen_rounded, size: 28)),
          ])));

  Widget _expandedHeader(LocationCandidate location) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                      child: RadarSurface(
                          borderRadius: 28,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        _radar!.mode == RadarMode.futureCast
                                            ? Icons.timeline
                                            : Icons.radar,
                                        size: 24),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: Text(
                                            _radar!.mode == RadarMode.futureCast
                                                ? 'FutureCast'
                                                : 'Live Radar',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700))),
                                  ])))),
                  const SizedBox(width: 12),
                  RadarSurface(
                      borderRadius: 28,
                      child: TextButton.icon(
                          onPressed: () => _setExpanded(false),
                          icon: const Icon(Icons.fullscreen_exit),
                          label: const Text('Done'),
                          style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16)))),
                ]),
            const SizedBox(height: 6),
            RadarSurface(
                borderRadius: 18,
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(_shortLocation(location),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.dmColors.textSecondary)))),
          ]);
}

String _shortLocation(LocationCandidate location) {
  final name = location.displayName.trim();
  return name.replaceFirst(RegExp(r',\s*(US|United States)$'), '');
}

String _tileMessage(String code) => switch (code) {
      'openweather_radar_access_denied' ||
      'openweather_key_rejected' ||
      'OPENWEATHER_API_KEY_UNAVAILABLE' ||
      'OPENWEATHER_API_KEY_MISSING' ||
      'futurecast_unavailable' =>
        'This radar layer is not available from the weather service.',
      'noaa_tile_empty' ||
      'openweather_tile_empty' ||
      'openweather_not_found' ||
      'radar_frame_unavailable' =>
        'Selected image unavailable. Clear conditions cannot be confirmed.',
      'noaa_unavailable' ||
      'noaa_timeout' ||
      'noaa_rate_limited' ||
      'noaa_request_failed' ||
      'noaa_tile_invalid_content' =>
        'Radar source unavailable; base map still usable.',
      _ => 'Radar temporarily unavailable. The base map is still usable.',
    };
