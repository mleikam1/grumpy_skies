import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_spacing.dart';
import '../../models/weather_models.dart';
import '../../repositories/fake_weather_repository.dart';
import '../../repositories/weather_repository.dart';
import '../../services/open_weather_backend_client.dart';
import '../../services/weather_location_controller.dart';
import '../../shared/widgets/daymaker_components.dart';
import '../../shared/widgets/weather_location_selector.dart';
import '../../utils/radar_time.dart';
import 'widgets/open_weather_radar_map.dart';
import 'widgets/radar_alert_cards.dart';
import 'widgets/radar_header_card.dart';
import 'widgets/radar_map_controls.dart';
import 'widgets/radar_timeline_scrubber.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final _mapController = MapController();

  WeatherLocationController? _locationController;
  OpenWeatherBackendClient? _client;
  Timer? _playTimer;
  Timer? _boundaryTimer;
  List<int> _timelineSteps = const [];
  var _lightningEnabled = false;
  var _futureCastEnabled = true;
  var _playing = false;
  var _timelineIndex = 0;
  var _loadedDependencies = false;
  var _tileError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDependencies) return;

    _locationController = _readLocationController() ??
        WeatherLocationController(
          repository: _readWeatherRepository() ?? const FakeWeatherRepository(),
          initialLocation: WeatherLocationController.fallbackLocation,
        );
    _client = _readClient() ?? OpenWeatherBackendClient();
    _locationController!.addListener(_handleLocationChanged);
    _rebuildTimeline(keepSelectedTimestamp: false);
    _startBoundaryTimer();
    _loadedDependencies = true;
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _boundaryTimer?.cancel();
    _locationController?.removeListener(_handleLocationChanged);
    super.dispose();
  }

  WeatherLocationController? _readLocationController() {
    try {
      return context.read<WeatherLocationController>();
    } catch (_) {
      return null;
    }
  }

  OpenWeatherBackendClient? _readClient() {
    try {
      return context.read<OpenWeatherBackendClient>();
    } catch (_) {
      return null;
    }
  }

  WeatherRepository? _readWeatherRepository() {
    try {
      return context.read<WeatherRepository>();
    } catch (_) {
      return null;
    }
  }

  void _handleLocationChanged() {
    _tileError = false;
    _rebuildTimeline(keepSelectedTimestamp: false);
    if (mounted) setState(() {});
  }

  void _startBoundaryTimer() {
    _boundaryTimer?.cancel();
    _boundaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _timelineSteps.isEmpty) return;
      final selectedTimestamp = _selectedTimestamp;
      final latest = roundToNearestPastTenMinuteUnix();
      final wasLatest = selectedTimestamp == latest;
      _rebuildTimeline(keepSelectedTimestamp: !wasLatest);
      if (wasLatest) _jumpToLatest();
    });
  }

  void _togglePlayback() {
    setState(() => _playing = !_playing);
    _playTimer?.cancel();
    if (!_playing) return;

    _playTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted || _timelineSteps.isEmpty) return;
      setState(() {
        _timelineIndex = (_timelineIndex + 1) % _timelineSteps.length;
        _tileError = false;
      });
    });
  }

  void _rebuildTimeline({required bool keepSelectedTimestamp}) {
    final previous = keepSelectedTimestamp ? _selectedTimestamp : null;
    final location = _locationController?.selectedLocation;
    final mode = _modeFor(location);
    final latest = roundToNearestPastTenMinuteUnix();
    final min = latest - radarHistorySeconds;
    final max = mode == RadarMode.usForecast && _futureCastEnabled
        ? latest + radarUsForecastSeconds
        : latest;

    final steps = <int>[];
    for (var value = min; value <= max; value += radarStepSeconds) {
      steps.add(value);
    }

    _timelineSteps = steps;
    final target = previous ?? latest;
    _timelineIndex = _nearestIndexFor(target);
  }

  int _nearestIndexFor(int timestamp) {
    if (_timelineSteps.isEmpty) return 0;
    var bestIndex = 0;
    var bestDistance = (timestamp - _timelineSteps.first).abs();
    for (var index = 1; index < _timelineSteps.length; index++) {
      final distance = (timestamp - _timelineSteps[index]).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  int get _selectedTimestamp {
    if (_timelineSteps.isEmpty) return roundToNearestPastTenMinuteUnix();
    return _timelineSteps[_timelineIndex.clamp(0, _timelineSteps.length - 1)];
  }

  RadarMode _modeFor(LocationCandidate? location) {
    return (location?.isUs ?? true) ? RadarMode.usForecast : RadarMode.global;
  }

  void _jumpToLatest() {
    final latest = roundToNearestPastTenMinuteUnix();
    setState(() {
      _timelineIndex = _nearestIndexFor(latest);
      _tileError = false;
    });
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3, 12));
  }

  Future<void> _locate() async {
    await _locationController?.useCurrentLocation();
  }

  void _showLayersMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Precipitation radar layer is active.'),
        ),
      );
  }

  void _showTileError() {
    if (_tileError || !mounted) return;
    setState(() => _tileError = true);
  }

  @override
  Widget build(BuildContext context) {
    final location = _locationController?.selectedLocation;
    final client = _client;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: DMGradients.storm,
        color: DMColors.deepNavy,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final breakpoint = DMBreakpoints.fromWidth(width);

            if (location == null || client == null) {
              return _RadarLocationPrompt(
                controller: _locationController!,
                onSelected: (_) => setState(() {}),
              );
            }

            final mode = _modeFor(location);
            final futureAvailable = mode == RadarMode.usForecast;

            return Stack(
              fit: StackFit.expand,
              children: [
                OpenWeatherRadarMap(
                  client: client,
                  mapController: _mapController,
                  location: location,
                  mode: mode,
                  timestamp: _selectedTimestamp,
                  onTileError: _showTileError,
                ),
                if (_tileError)
                  const Positioned(
                    left: DMSpacing.md,
                    right: DMSpacing.md,
                    bottom: 104,
                    child: _RadarTileErrorBanner(),
                  ),
                if (breakpoint.isExpanded)
                  _ExpandedRadarChrome(
                    location: location,
                    mode: mode,
                    selectedTimestamp: _selectedTimestamp,
                    timelineIndex: _timelineIndex,
                    timelineCount: _timelineSteps.length,
                    lightningEnabled: _lightningEnabled,
                    futureCastEnabled: _futureCastEnabled,
                    futureCastAvailable: futureAvailable,
                    playing: _playing,
                    onTimelineChanged: _onTimelineChanged,
                    onPlayPause: _togglePlayback,
                    onLatest: _jumpToLatest,
                    onLightningChanged: (enabled) {
                      setState(() => _lightningEnabled = enabled);
                    },
                    onFutureCastChanged: (enabled) {
                      setState(() {
                        _futureCastEnabled = enabled;
                        _rebuildTimeline(keepSelectedTimestamp: true);
                      });
                    },
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                    onLocate: _locate,
                    onLayers: _showLayersMessage,
                  )
                else
                  _CompactRadarChrome(
                    location: location,
                    mode: mode,
                    selectedTimestamp: _selectedTimestamp,
                    timelineIndex: _timelineIndex,
                    timelineCount: _timelineSteps.length,
                    lightningEnabled: _lightningEnabled,
                    futureCastEnabled: _futureCastEnabled,
                    futureCastAvailable: futureAvailable,
                    playing: _playing,
                    onTimelineChanged: _onTimelineChanged,
                    onPlayPause: _togglePlayback,
                    onLatest: _jumpToLatest,
                    onLightningChanged: (enabled) {
                      setState(() => _lightningEnabled = enabled);
                    },
                    onFutureCastChanged: (enabled) {
                      setState(() {
                        _futureCastEnabled = enabled;
                        _rebuildTimeline(keepSelectedTimestamp: true);
                      });
                    },
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                    onLocate: _locate,
                    onLayers: _showLayersMessage,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onTimelineChanged(double value) {
    setState(() {
      _timelineIndex = value.round().clamp(0, _timelineSteps.length - 1);
      _tileError = false;
    });
  }
}

class _RadarLocationPrompt extends StatelessWidget {
  const _RadarLocationPrompt({
    required this.controller,
    required this.onSelected,
  });

  final WeatherLocationController controller;
  final ValueChanged<LocationCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding:
            DMSpacing.pagePaddingForWidth(MediaQuery.sizeOf(context).width),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: WeatherLocationSelector(
                controller: controller,
                title: 'Choose a radar location',
                onLocationSelected: onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRadarChrome extends StatelessWidget {
  const _CompactRadarChrome({
    required this.location,
    required this.mode,
    required this.selectedTimestamp,
    required this.timelineIndex,
    required this.timelineCount,
    required this.lightningEnabled,
    required this.futureCastEnabled,
    required this.futureCastAvailable,
    required this.playing,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLatest,
    required this.onLightningChanged,
    required this.onFutureCastChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.onLayers,
  });

  final LocationCandidate location;
  final RadarMode mode;
  final int selectedTimestamp;
  final int timelineIndex;
  final int timelineCount;
  final bool lightningEnabled;
  final bool futureCastEnabled;
  final bool futureCastAvailable;
  final bool playing;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final ValueChanged<bool> onLightningChanged;
  final ValueChanged<bool> onFutureCastChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapBreathingRoom =
              (constraints.maxHeight * 0.16).clamp(84.0, 156.0).toDouble();

          return SingleChildScrollView(
            padding: DMSpacing.pagePaddingForWidth(constraints.maxWidth)
                .copyWith(bottom: DMSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RadarHeaderCard(
                  locationName: location.displayName,
                  modeLabel: mode.label,
                  timeLabel: _formatRadarTime(selectedTimestamp),
                  lastUpdatedLabel:
                      'Updated ${_formatRadarTime(roundToNearestPastTenMinuteUnix())}',
                ),
                const SizedBox(height: DMSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: RadarMapControls(
                    compact: true,
                    lightningEnabled: lightningEnabled,
                    futureCastEnabled: futureCastAvailable && futureCastEnabled,
                    futureCastAvailable: futureCastAvailable,
                    onLightningChanged: onLightningChanged,
                    onFutureCastChanged: onFutureCastChanged,
                    onZoomIn: onZoomIn,
                    onZoomOut: onZoomOut,
                    onLocate: onLocate,
                    onLayers: onLayers,
                  ),
                ),
                SizedBox(height: mapBreathingRoom),
                RadarTimelineScrubber(
                  playing: playing,
                  value: timelineIndex.toDouble(),
                  max: (timelineCount - 1).toDouble(),
                  divisions: timelineCount - 1,
                  timeLabel: _formatRadarTime(selectedTimestamp),
                  startLabel: '-48h',
                  endLabel: futureCastAvailable && futureCastEnabled
                      ? '+5h'
                      : 'Latest',
                  onChanged: onTimelineChanged,
                  onPlayPause: onPlayPause,
                  onLatest: onLatest,
                ),
                const SizedBox(height: DMSpacing.sm),
                RadarAlertCards(
                  layout: RadarAlertCardsLayout.compact,
                  modeLabel: mode.label,
                  timeLabel: _formatRadarTime(selectedTimestamp),
                  locationName: location.displayName,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpandedRadarChrome extends StatelessWidget {
  const _ExpandedRadarChrome({
    required this.location,
    required this.mode,
    required this.selectedTimestamp,
    required this.timelineIndex,
    required this.timelineCount,
    required this.lightningEnabled,
    required this.futureCastEnabled,
    required this.futureCastAvailable,
    required this.playing,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLatest,
    required this.onLightningChanged,
    required this.onFutureCastChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.onLayers,
  });

  final LocationCandidate location;
  final RadarMode mode;
  final int selectedTimestamp;
  final int timelineIndex;
  final int timelineCount;
  final bool lightningEnabled;
  final bool futureCastEnabled;
  final bool futureCastAvailable;
  final bool playing;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final ValueChanged<bool> onLightningChanged;
  final ValueChanged<bool> onFutureCastChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: DMSpacing.pagePaddingForWidth(MediaQuery.sizeOf(context).width)
            .copyWith(bottom: DMSpacing.lg),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final controlsBelowHeader = constraints.maxWidth < 780;

                      return Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SizedBox(
                              width: 386,
                              child: RadarHeaderCard(
                                locationName: location.displayName,
                                modeLabel: mode.label,
                                timeLabel: _formatRadarTime(selectedTimestamp),
                                lastUpdatedLabel:
                                    'Updated ${_formatRadarTime(roundToNearestPastTenMinuteUnix())}',
                              ),
                            ),
                          ),
                          Positioned(
                            top: controlsBelowHeader ? 152 : 0,
                            right: 0,
                            child: RadarMapControls(
                              compact: false,
                              lightningEnabled: lightningEnabled,
                              futureCastEnabled:
                                  futureCastAvailable && futureCastEnabled,
                              futureCastAvailable: futureCastAvailable,
                              onLightningChanged: onLightningChanged,
                              onFutureCastChanged: onFutureCastChanged,
                              onZoomIn: onZoomIn,
                              onZoomOut: onZoomOut,
                              onLocate: onLocate,
                              onLayers: onLayers,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            left: 0,
                            child: RadarTimelineScrubber(
                              playing: playing,
                              value: timelineIndex.toDouble(),
                              max: (timelineCount - 1).toDouble(),
                              divisions: timelineCount - 1,
                              timeLabel: _formatRadarTime(selectedTimestamp),
                              startLabel: '-48h',
                              endLabel: futureCastAvailable && futureCastEnabled
                                  ? '+5h'
                                  : 'Latest',
                              onChanged: onTimelineChanged,
                              onPlayPause: onPlayPause,
                              onLatest: onLatest,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: DMSpacing.xl),
                SizedBox(
                  width: 344,
                  child: RadarAlertCards(
                    layout: RadarAlertCardsLayout.expanded,
                    modeLabel: mode.label,
                    timeLabel: _formatRadarTime(selectedTimestamp),
                    locationName: location.displayName,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarTileErrorBanner extends StatelessWidget {
  const _RadarTileErrorBanner();

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.sm),
      borderColor: DMColors.sunriseYellow,
      child: Row(
        children: [
          const Icon(Icons.layers_clear_outlined,
              color: DMColors.sunriseYellow),
          const SizedBox(width: DMSpacing.sm),
          Expanded(
            child: Text(
              'Radar tiles are unavailable for this frame. Weather data can still refresh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DMColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRadarTime(int timestamp) {
  final time = dateTimeFromUnixSeconds(timestamp);
  final now = roundToNearestPastTenMinuteUnix();
  if (timestamp == now) return 'Latest';

  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '${time.month}/${time.day} $hour:$minute $suffix';
}
