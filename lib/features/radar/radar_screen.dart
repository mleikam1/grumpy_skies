import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_shadows.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../models/weather_models.dart';
import '../../repositories/fake_weather_repository.dart';
import '../../repositories/weather_repository.dart';
import '../../services/open_weather_backend_client.dart';
import '../../services/weather_location_controller.dart';
import '../../shared/widgets/daymaker_components.dart';
import '../../shared/widgets/weather_location_selector.dart';
import '../../utils/radar_time.dart';
import 'widgets/open_weather_radar_map.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with WidgetsBindingObserver {
  final _mapController = MapController();

  WeatherLocationController? _locationController;
  OpenWeatherBackendClient? _client;
  Timer? _playTimer;
  Timer? _boundaryTimer;
  RadarMode _mode = RadarMode.usForecast;
  RadarFrame? _previousFrame;
  List<RadarFrame> _frames = const [];
  var _playing = false;
  var _sheetExpanded = false;
  var _timelineIndex = 0;
  var _loadedDependencies = false;
  var _loadingFrames = false;
  var _checkingFutureCast = false;
  var _futureCastAvailable = false;
  var _frameLoadSerial = 0;
  var _tileIssue = false;
  var _tileIssueUpdateQueued = false;
  var _tileIssueGeneration = 0;
  String? _frameLoadMessage;
  String? _futureCastMessage;
  String? _tileIssueCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDependencies) return;

    WidgetsBinding.instance.addObserver(this);
    _locationController = _readLocationController() ??
        WeatherLocationController(
          repository: _readWeatherRepository() ?? const FakeWeatherRepository(),
        );
    _client = _readClient() ?? OpenWeatherBackendClient();
    _locationController!.addListener(_handleLocationChanged);
    final location = _locationController!.selectedLocation;
    _mode = _defaultModeFor(location);
    _loadFrames(keepSelectedTimestamp: false);
    _refreshFutureCastAvailability();
    _startBoundaryTimer();
    _loadedDependencies = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playTimer?.cancel();
    _boundaryTimer?.cancel();
    _locationController?.removeListener(_handleLocationChanged);
    super.dispose();
  }

  @override
  void deactivate() {
    _playTimer?.cancel();
    _playing = false;
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_playing) _setPlayback(false);
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
    _clearTileIssue();
    _mode = _defaultModeFor(_locationController?.selectedLocation);
    _previousFrame = null;
    _loadFrames(keepSelectedTimestamp: false);
    _refreshFutureCastAvailability();
    _recenter();
    if (mounted) setState(() {});
  }

  void _startBoundaryTimer() {
    _boundaryTimer?.cancel();
    _boundaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _frames.isEmpty) return;
      final wasLatest = _selectedFrame.isLatest;
      _loadFrames(keepSelectedTimestamp: !wasLatest);
    });
  }

  void _togglePlayback() {
    _setPlayback(!_playing);
  }

  void _setPlayback(bool playing) {
    _playTimer?.cancel();
    if (!mounted) {
      _playing = playing;
      return;
    }

    setState(() => _playing = playing);
    if (!playing || _frames.isEmpty) return;

    _playTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted || _frames.isEmpty) return;
      final next = _nextRenderableIndex(_timelineIndex);
      if (next == _timelineIndex) return;
      _selectTimelineIndex(next);
    });
  }

  Future<void> _loadFrames({required bool keepSelectedTimestamp}) async {
    final location = _locationController?.selectedLocation;
    final client = _client;
    if (location == null || client == null) return;

    final mode = _effectiveModeFor(location);
    final previousTimestamp = keepSelectedTimestamp && _frames.isNotEmpty
        ? _selectedFrame.timestamp
        : null;
    final serial = ++_frameLoadSerial;
    setState(() {
      _loadingFrames = true;
      _frameLoadMessage = null;
      _tileIssue = false;
      _tileIssueCode = null;
      _tileIssueUpdateQueued = false;
      _tileIssueGeneration++;
    });

    try {
      final frameSet = await client.radarFrames(
        mode: mode,
        latitude: location.lat,
        longitude: location.lon,
        hours: 6,
      );
      if (!mounted || serial != _frameLoadSerial) return;
      final frames = frameSet.frames
          .where((frame) => frame.renderable)
          .toList(growable: false);
      final target = previousTimestamp ?? _preferredLatestTimestamp(frames);
      setState(() {
        _mode = mode;
        _frames = frames;
        _timelineIndex = frames.isEmpty ? 0 : _nearestIndexFor(target);
        _loadingFrames = false;
        _frameLoadMessage = frames.isEmpty
            ? frameSet.diagnosticMessage ??
                'Radar source temporarily unavailable.'
            : frameSet.diagnosticMessage;
        if (frameSet.futureCastAvailable) _futureCastAvailable = true;
      });
      _preloadUpcomingFrames();
    } on OpenWeatherBackendException catch (error) {
      if (!mounted || serial != _frameLoadSerial) return;
      setState(() {
        _loadingFrames = false;
        _frameLoadMessage = error.message;
        _frames = const [];
        _timelineIndex = 0;
      });
    }
  }

  int _nearestIndexFor(int timestamp) {
    if (_frames.isEmpty) return 0;
    var bestIndex = 0;
    var bestDistance = (timestamp - _frames.first.timestamp).abs();
    for (var index = 1; index < _frames.length; index++) {
      final distance = (timestamp - _frames[index].timestamp).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  RadarFrame get _selectedFrame {
    if (_frames.isEmpty) {
      final latest = roundToNearestPastRadarUnix(
        mode: _mode,
      );
      return RadarFrame(
        timestamp: latest,
        label: _mode == RadarMode.futureCast ? 'Now' : 'Latest',
        type: RadarFrameType.latest,
        isLatest: true,
        source: _mode.sourceParam,
      );
    }
    return _frames[_timelineIndex.clamp(0, _frames.length - 1)];
  }

  RadarMode _defaultModeFor(LocationCandidate? location) {
    if (location == null) return RadarMode.usForecast;
    if (location.isUs || _coordinateLooksUs(location.lat, location.lon)) {
      return RadarMode.usForecast;
    }
    return RadarMode.global;
  }

  RadarMode _effectiveModeFor(LocationCandidate location) {
    if (!(location.isUs || _coordinateLooksUs(location.lat, location.lon))) {
      return RadarMode.global;
    }
    return _mode == RadarMode.global ? RadarMode.usForecast : _mode;
  }

  void _jumpToLatest() {
    if (_frames.isEmpty) return;
    _selectTimelineIndex(_latestIndexForMode());
  }

  void _selectTimelineIndex(int index) {
    if (_frames.isEmpty) return;
    final nextIndex = index.clamp(0, _frames.length - 1);
    final nextFrame = _frames[nextIndex];
    setState(() {
      _previousFrame = _selectedFrame;
      _timelineIndex = nextIndex;
      _clearTileIssue();
      if (!nextFrame.renderable) {
        _tileIssue = true;
        _tileIssueCode = 'radar_frame_unavailable';
      }
    });
    _preloadUpcomingFrames();
  }

  int _latestIndexForMode() {
    if (_frames.isEmpty) return 0;
    final latestIndex = _frames.indexWhere((frame) => frame.isLatest);
    if (latestIndex >= 0) return latestIndex;
    return _mode == RadarMode.futureCast ? 0 : _frames.length - 1;
  }

  int _nextRenderableIndex(int startIndex) {
    if (_frames.length < 2) return startIndex;
    for (var step = 1; step <= _frames.length; step++) {
      final index = (startIndex + step) % _frames.length;
      if (_frames[index].renderable) return index;
    }
    return startIndex;
  }

  int _preferredLatestTimestamp(List<RadarFrame> frames) {
    if (frames.isEmpty) {
      return roundToNearestPastRadarUnix(mode: _mode);
    }
    for (final frame in frames) {
      if (frame.isLatest) return frame.timestamp;
    }
    return _mode == RadarMode.futureCast
        ? frames.first.timestamp
        : frames.last.timestamp;
  }

  void _setMode(RadarMode mode) {
    if (mode == _mode) return;
    if (mode == RadarMode.futureCast && !_futureCastAvailable) {
      setState(() {
        _tileIssue = true;
        _tileIssueCode = 'futurecast_unavailable';
      });
      return;
    }
    _setPlayback(false);
    _previousFrame = null;
    setState(() => _mode = mode);
    _loadFrames(keepSelectedTimestamp: false);
  }

  Future<void> _refreshFutureCastAvailability() async {
    final location = _locationController?.selectedLocation;
    final client = _client;
    if (location == null || client == null) return;
    if (!(location.isUs || _coordinateLooksUs(location.lat, location.lon))) {
      setState(() {
        _futureCastAvailable = false;
        _futureCastMessage = 'FutureCast is available for US locations.';
      });
      return;
    }
    if (_checkingFutureCast) return;
    _checkingFutureCast = true;
    try {
      final frameSet = await client.radarFrames(
        mode: RadarMode.futureCast,
        latitude: location.lat,
        longitude: location.lon,
        hours: 1,
      );
      if (!mounted) return;
      setState(() {
        _futureCastAvailable =
            frameSet.frames.isNotEmpty || frameSet.futureCastAvailable;
        _futureCastMessage = frameSet.diagnosticMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _futureCastAvailable = false;
        _futureCastMessage =
            'FutureCast requires OpenWeather precipitation forecast map access.';
      });
    } finally {
      _checkingFutureCast = false;
    }
  }

  void _preloadUpcomingFrames() {
    final location = _locationController?.selectedLocation;
    final client = _client;
    if (location == null || client == null || _frames.length < 2) return;
    for (var step = 1; step <= math.min(2, _frames.length - 1); step++) {
      final frame = _frames[(_timelineIndex + step) % _frames.length];
      client.radarTileHealth(
        mode: _mode,
        timestamp: frame.timestamp,
        latitude: location.lat,
        longitude: location.lon,
        source: frame.source,
      );
    }
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3, 12));
  }

  void _recenter() {
    final location = _locationController?.selectedLocation;
    if (location == null) return;
    final camera = _mapController.camera;
    final zoom = math.max(5.0, camera.zoom.clamp(3.0, 12.0));
    _mapController.move(LatLng(location.lat, location.lon), zoom);
  }

  void _openInfoSheet() {
    setState(() => _sheetExpanded = true);
  }

  void _toggleInfoSheet() {
    setState(() => _sheetExpanded = !_sheetExpanded);
  }

  void _handleTileIssue(String? code) {
    if (code == null) {
      if (!_tileIssue && _tileIssueCode == null) return;
      setState(() {
        _tileIssue = false;
        _tileIssueCode = null;
        _tileIssueUpdateQueued = false;
        _tileIssueGeneration++;
      });
      return;
    }
    _showTileIssue(code);
  }

  void _showTileIssue(String code) {
    if (_tileIssueUpdateQueued || !mounted) return;
    if (_tileIssue && _tileIssueCode == code) return;

    final generation = _tileIssueGeneration;
    _tileIssueUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _tileIssueGeneration) return;
      _tileIssueUpdateQueued = false;
      if (_tileIssue && _tileIssueCode == code) return;
      setState(() {
        _tileIssue = true;
        _tileIssueCode = code;
      });
    });
  }

  void _clearTileIssue() {
    _tileIssue = false;
    _tileIssueCode = null;
    _tileIssueUpdateQueued = false;
    _tileIssueGeneration++;
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

            if (location == null || client == null) {
              return _RadarLocationPrompt(
                controller: _locationController!,
                onSelected: (_) => setState(() {}),
              );
            }

            final mode = _effectiveModeFor(location);
            final frame = _selectedFrame;
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            final horizontal = width < 600 ? DMSpacing.sm : DMSpacing.xl;
            const collapsedSheetHeight = 112.0;
            final expandedSheetHeight = math.min(
              constraints.maxHeight * (width < 700 ? 0.48 : 0.44),
              width < 700 ? 360.0 : 340.0,
            );
            final sheetHeight =
                _sheetExpanded ? expandedSheetHeight : collapsedSheetHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                OpenWeatherRadarMap(
                  client: client,
                  mapController: _mapController,
                  location: location,
                  mode: mode,
                  frame: frame,
                  previousFrame: _previousFrame,
                  onTileIssue: _handleTileIssue,
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + DMSpacing.sm,
                  left: horizontal,
                  right: 88,
                  child: _RadarStatusStack(
                    locationName: _locationLabel(location),
                    frameLabel: frame.label,
                    modeLabel: mode.modeChipLabel,
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + DMSpacing.sm,
                  right: horizontal,
                  child: _RadarFloatingControls(
                    playing: _playing,
                    onPlayPause: _togglePlayback,
                    onLatest: _jumpToLatest,
                    onRecenter: _recenter,
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                    onLayers: _openInfoSheet,
                    onInfo: _toggleInfoSheet,
                  ),
                ),
                if (_tileIssue || _frameLoadMessage != null || _loadingFrames)
                  Positioned(
                    left: horizontal,
                    right: horizontal,
                    bottom: sheetHeight + bottomInset + DMSpacing.x2,
                    child: _RadarNoticeBanner(
                      message: _loadingFrames
                          ? 'Loading radar frames...'
                          : _tileIssue
                              ? _tileIssueMessage(_tileIssueCode)
                              : _frameLoadMessage!,
                    ),
                  ),
                Positioned(
                  left: horizontal,
                  right: horizontal,
                  bottom: bottomInset + DMSpacing.sm,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _RadarBottomSheet(
                        expanded: _sheetExpanded,
                        height: sheetHeight,
                        frame: frame,
                        frames: _frames,
                        timelineIndex: _timelineIndex,
                        playing: _playing,
                        mode: mode,
                        locationName: _locationLabel(location),
                        futureCastAvailable: _futureCastAvailable,
                        futureCastMessage: _futureCastMessage,
                        onModeChanged: _setMode,
                        onTimelineChanged: _onTimelineChanged,
                        onPlayPause: _togglePlayback,
                        onLatest: _jumpToLatest,
                        onToggleExpanded: _toggleInfoSheet,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onTimelineChanged(double value) {
    _selectTimelineIndex(value.round());
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

class _RadarStatusStack extends StatelessWidget {
  const _RadarStatusStack({
    required this.locationName,
    required this.frameLabel,
    required this.modeLabel,
  });

  final String locationName;
  final String frameLabel;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: _RadarStatusPill(
        locationName: locationName,
        frameLabel: frameLabel,
        modeLabel: modeLabel,
      ),
    );
  }
}

class _RadarStatusPill extends StatelessWidget {
  const _RadarStatusPill({
    required this.locationName,
    required this.frameLabel,
    required this.modeLabel,
  });

  final String locationName;
  final String frameLabel;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.sm,
        vertical: DMSpacing.xs,
      ),
      borderRadius: DMRadius.full,
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorderStrong,
      shadows: DMShadows.floating,
      semanticLabel: 'Radar, $locationName, $modeLabel, $frameLabel',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Icon(
              Icons.radar,
              color: DMColors.skyBlue,
              size: DMSpacing.iconMd,
            ),
            const SizedBox(width: DMSpacing.xs),
            const Text(
              'Radar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelLarge,
            ),
            const SizedBox(width: DMSpacing.xs),
            Expanded(
              flex: 2,
              child: Text(
                locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.label.copyWith(
                  color: DMColors.skyBlueSoft,
                ),
              ),
            ),
            const SizedBox(width: DMSpacing.xs),
            Flexible(
              child: _RadarFrameBadge(label: frameLabel),
            ),
            const SizedBox(width: DMSpacing.xs),
            Flexible(
              child: _RadarModeBadge(label: modeLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarModeBadge extends StatelessWidget {
  const _RadarModeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.skyBlue, 0.18),
        borderRadius: DMRadius.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.xs,
          vertical: DMSpacing.xxs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.skyBlueSoft,
          ),
        ),
      ),
    );
  }
}

class _RadarFrameBadge extends StatelessWidget {
  const _RadarFrameBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.sunriseYellow, 0.18),
        borderRadius: DMRadius.full,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.xs,
          vertical: DMSpacing.xxs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.sunriseYellow,
          ),
        ),
      ),
    );
  }
}

class _RadarFloatingControls extends StatelessWidget {
  const _RadarFloatingControls({
    required this.playing,
    required this.onPlayPause,
    required this.onLatest,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLayers,
    required this.onInfo,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLayers;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DmIconButton(
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          semanticLabel:
              playing ? 'Pause radar timeline' : 'Play radar timeline',
          tooltip: playing ? 'Pause' : 'Play',
          variant: DmIconButtonVariant.filled,
          onPressed: onPlayPause,
        ),
        const SizedBox(height: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.update),
          semanticLabel: 'Show latest radar frame',
          tooltip: 'Latest',
          selected: true,
          onPressed: onLatest,
        ),
        const SizedBox(height: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.my_location),
          semanticLabel: 'Recenter radar map',
          tooltip: 'Recenter',
          selected: true,
          onPressed: onRecenter,
        ),
        const SizedBox(height: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.add),
          semanticLabel: 'Zoom in',
          tooltip: 'Zoom in',
          selected: true,
          onPressed: onZoomIn,
        ),
        const SizedBox(height: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.remove),
          semanticLabel: 'Zoom out',
          tooltip: 'Zoom out',
          selected: true,
          onPressed: onZoomOut,
        ),
        const SizedBox(height: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.layers_outlined),
          semanticLabel: 'Radar layers',
          tooltip: 'Layers',
          selected: true,
          onPressed: onLayers,
        ),
        const SizedBox(height: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.info_outline),
          semanticLabel: 'Radar legend and info',
          tooltip: 'Info',
          selected: true,
          onPressed: onInfo,
        ),
      ],
    );
  }
}

class _RadarBottomSheet extends StatelessWidget {
  const _RadarBottomSheet({
    required this.expanded,
    required this.height,
    required this.frame,
    required this.frames,
    required this.timelineIndex,
    required this.playing,
    required this.mode,
    required this.locationName,
    required this.futureCastAvailable,
    required this.futureCastMessage,
    required this.onModeChanged,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLatest,
    required this.onToggleExpanded,
  });

  final bool expanded;
  final double height;
  final RadarFrame frame;
  final List<RadarFrame> frames;
  final int timelineIndex;
  final bool playing;
  final RadarMode mode;
  final String locationName;
  final bool futureCastAvailable;
  final String? futureCastMessage;
  final ValueChanged<RadarMode> onModeChanged;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: height,
      child: DmGlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.sm,
          vertical: DMSpacing.xs,
        ),
        borderRadius: DMRadius.large,
        gradient: DMGradients.glassNavy,
        borderColor: DMColors.glassBorderStrong,
        shadows: DMShadows.floating,
        semanticLabel: 'Radar timeline and information',
        child: Column(
          children: [
            _SheetHandle(
              expanded: expanded,
              onTap: onToggleExpanded,
            ),
            Expanded(
              child: expanded
                  ? _ExpandedRadarSheetBody(
                      frame: frame,
                      frames: frames,
                      timelineIndex: timelineIndex,
                      playing: playing,
                      mode: mode,
                      locationName: locationName,
                      futureCastAvailable: futureCastAvailable,
                      futureCastMessage: futureCastMessage,
                      onModeChanged: onModeChanged,
                      onTimelineChanged: onTimelineChanged,
                      onPlayPause: onPlayPause,
                      onLatest: onLatest,
                    )
                  : _CompactRadarTimeline(
                      frame: frame,
                      frames: frames,
                      timelineIndex: timelineIndex,
                      playing: playing,
                      mode: mode,
                      showRangeLabels: false,
                      onTimelineChanged: onTimelineChanged,
                      onPlayPause: onPlayPause,
                      onLatest: onLatest,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded ? 'Collapse radar info' : 'Expand radar info',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: DMRadius.full,
          onTap: onTap,
          child: const SizedBox(
            height: 12,
            width: double.infinity,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DMColors.glassBorderStrong,
                  borderRadius: DMRadius.full,
                ),
                child: SizedBox(width: 42, height: 4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedRadarSheetBody extends StatelessWidget {
  const _ExpandedRadarSheetBody({
    required this.frame,
    required this.frames,
    required this.timelineIndex,
    required this.playing,
    required this.mode,
    required this.locationName,
    required this.futureCastAvailable,
    required this.futureCastMessage,
    required this.onModeChanged,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLatest,
  });

  final RadarFrame frame;
  final List<RadarFrame> frames;
  final int timelineIndex;
  final bool playing;
  final RadarMode mode;
  final String locationName;
  final bool futureCastAvailable;
  final String? futureCastMessage;
  final ValueChanged<RadarMode> onModeChanged;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _RadarModeSelector(
          mode: mode,
          futureCastAvailable: futureCastAvailable,
          futureCastMessage: futureCastMessage,
          onModeChanged: onModeChanged,
        ),
        const SizedBox(height: DMSpacing.sm),
        _CompactRadarTimeline(
          frame: frame,
          frames: frames,
          timelineIndex: timelineIndex,
          playing: playing,
          mode: mode,
          onTimelineChanged: onTimelineChanged,
          onPlayPause: onPlayPause,
          onLatest: onLatest,
        ),
        const SizedBox(height: DMSpacing.sm),
        Wrap(
          spacing: DMSpacing.xs,
          runSpacing: DMSpacing.xs,
          children: [
            _RadarInfoChip(
              icon: Icons.layers_outlined,
              label: mode.label,
            ),
            _RadarInfoChip(
              icon: Icons.schedule_rounded,
              label: _formatRadarTime(
                frame.timestamp,
                isLatest: frame.isLatest,
                latestLabel: frame.label == 'Now' ? 'Now' : 'Latest',
              ),
            ),
            _RadarInfoChip(
              icon: Icons.place_outlined,
              label: locationName,
            ),
          ],
        ),
        const SizedBox(height: DMSpacing.sm),
        const _RadarLegend(),
        const SizedBox(height: DMSpacing.xs),
        Text(
          mode == RadarMode.usForecast
              ? 'Radar © NOAA/NWS MRMS'
              : 'Radar © OpenWeather',
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _RadarModeSelector extends StatelessWidget {
  const _RadarModeSelector({
    required this.mode,
    required this.futureCastAvailable,
    required this.futureCastMessage,
    required this.onModeChanged,
  });

  final RadarMode mode;
  final bool futureCastAvailable;
  final String? futureCastMessage;
  final ValueChanged<RadarMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DMSpacing.xs,
      runSpacing: DMSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DmPillButton(
          label: 'Live Radar',
          semanticLabel: 'Show Live Radar',
          leading: const Icon(Icons.radar),
          variant: DmPillButtonVariant.glass,
          selected: mode == RadarMode.usForecast,
          padding: const EdgeInsets.symmetric(
            horizontal: DMSpacing.sm,
            vertical: DMSpacing.xs,
          ),
          onPressed: () => onModeChanged(RadarMode.usForecast),
        ),
        DmPillButton(
          label: 'FutureCast',
          semanticLabel: futureCastAvailable
              ? 'Show FutureCast'
              : 'FutureCast requires OpenWeather precipitation forecast map access',
          leading: const Icon(Icons.timeline),
          variant: DmPillButtonVariant.glass,
          selected: mode == RadarMode.futureCast,
          padding: const EdgeInsets.symmetric(
            horizontal: DMSpacing.sm,
            vertical: DMSpacing.xs,
          ),
          onPressed: futureCastAvailable
              ? () => onModeChanged(RadarMode.futureCast)
              : null,
        ),
        if (!futureCastAvailable && futureCastMessage != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              futureCastMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelSmall.copyWith(
                color: DMColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactRadarTimeline extends StatelessWidget {
  const _CompactRadarTimeline({
    required this.frame,
    required this.frames,
    required this.timelineIndex,
    required this.playing,
    required this.mode,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLatest,
    this.showRangeLabels = true,
  });

  final RadarFrame frame;
  final List<RadarFrame> frames;
  final int timelineIndex;
  final bool playing;
  final RadarMode mode;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final bool showRangeLabels;

  @override
  Widget build(BuildContext context) {
    final max = math.max(frames.length - 1, 1).toDouble();
    final divisions = math.max(frames.length - 1, 1);
    final historyLabel = switch (mode) {
      RadarMode.usForecast => '-90 min',
      RadarMode.futureCast => 'Now',
      RadarMode.global => '-2h',
    };
    final stepLabel =
        mode == RadarMode.usForecast ? 'MRMS frames' : '10 min frames';
    final endLabel = mode == RadarMode.futureCast ? '+6h' : 'Latest';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            DmIconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              semanticLabel:
                  playing ? 'Pause radar timeline' : 'Play radar timeline',
              tooltip: playing ? 'Pause' : 'Play',
              variant: DmIconButtonVariant.filled,
              onPressed: onPlayPause,
            ),
            const SizedBox(width: DMSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    frame.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DMTypography.labelLarge,
                  ),
                  const SizedBox(height: DMSpacing.xxs),
                  Text(
                    _formatRadarTime(
                      frame.timestamp,
                      isLatest: frame.isLatest,
                      latestLabel: frame.label == 'Now' ? 'Now' : 'Latest',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DMTypography.labelSmall.copyWith(
                      color: DMColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DMSpacing.sm),
            DmPillButton(
              label: 'Latest',
              semanticLabel: 'Show latest radar frame',
              variant: DmPillButtonVariant.glass,
              padding: const EdgeInsets.symmetric(
                horizontal: DMSpacing.sm,
                vertical: DMSpacing.xxs,
              ),
              onPressed: onLatest,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: DMColors.skyBlue,
            inactiveTrackColor: DMColors.glassStrong,
            thumbColor: DMColors.sunriseYellow,
            overlayColor: DMColors.opacity(DMColors.sunriseYellow, 0.18),
            valueIndicatorColor: DMColors.surfaceRaised,
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
          ),
          child: SizedBox(
            height: 32,
            child: Slider(
              value: timelineIndex.clamp(0, max.toInt()).toDouble(),
              min: 0,
              max: max,
              divisions: divisions,
              label: frame.label,
              semanticFormatterCallback: (value) {
                return 'Radar timeline '
                    '${_frameLabelFor(frames, value.round())}';
              },
              onChanged: onTimelineChanged,
            ),
          ),
        ),
        if (showRangeLabels)
          Row(
            children: [
              Expanded(
                child: Text(
                  historyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: DMColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  stepLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: DMColors.sunriseYellow,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  endLabel,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: DMColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RadarInfoChip extends StatelessWidget {
  const _RadarInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.cloudWhite, 0.08),
        borderRadius: DMRadius.full,
        border: Border.all(color: DMColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.sm,
          vertical: DMSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: DMColors.skyBlueSoft, size: DMSpacing.iconSm),
            const SizedBox(width: DMSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.labelSmall.copyWith(
                  color: DMColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      _LegendItem('Light', Color(0xFF62D9FF)),
      _LegendItem('Moderate', Color(0xFF3BFF83)),
      _LegendItem('Heavy', Color(0xFFFFD84D)),
      _LegendItem('Severe', Color(0xFFFF5A6E)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Precipitation legend',
          style: DMTypography.label.copyWith(color: DMColors.textSecondary),
        ),
        const SizedBox(height: DMSpacing.xs),
        Wrap(
          spacing: DMSpacing.sm,
          runSpacing: DMSpacing.xs,
          children: [
            for (final item in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: DMRadius.full,
                    ),
                    child: const SizedBox(width: 28, height: 8),
                  ),
                  const SizedBox(width: DMSpacing.xs),
                  Text(
                    item.label,
                    style: DMTypography.labelSmall.copyWith(
                      color: DMColors.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color);

  final String label;
  final Color color;
}

class _RadarNoticeBanner extends StatelessWidget {
  const _RadarNoticeBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.sm,
        vertical: DMSpacing.xs,
      ),
      borderRadius: DMRadius.full,
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.sunriseYellow,
      shadows: DMShadows.floating,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: DMColors.sunriseYellow,
            size: DMSpacing.iconMd,
          ),
          const SizedBox(width: DMSpacing.xs),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.bodySmall.copyWith(
                color: DMColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _coordinateLooksUs(double latitude, double longitude) {
  return latitude >= 18 &&
      latitude <= 72 &&
      longitude >= -170 &&
      longitude <= -64;
}

String _locationLabel(LocationCandidate location) {
  if (location.source == WeatherLocationSource.device.storageValue) {
    return location.displayName.trim().isEmpty
        ? 'Current location'
        : location.displayName;
  }
  if (location.source == WeatherLocationSource.unknown.storageValue) {
    return '${location.displayName} approximate';
  }
  return location.displayName;
}

String _frameLabelFor(List<RadarFrame> frames, int index) {
  if (frames.isEmpty) return 'Latest';
  return frames[index.clamp(0, frames.length - 1)].label;
}

String _tileIssueMessage(String? code) {
  return switch (code) {
    'openweather_radar_access_denied' ||
    'openweather_key_rejected' ||
    'OPENWEATHER_API_KEY_UNAVAILABLE' ||
    'OPENWEATHER_API_KEY_MISSING' =>
      'Radar product/API access issue. Check OpenWeather Maps access on the server key.',
    'futurecast_unavailable' =>
      'FutureCast requires OpenWeather precipitation forecast map access.',
    'radar_frame_unavailable' => 'Radar frame unavailable.',
    'openweather_invalid_request' => 'Radar frame unavailable.',
    'openweather_not_found' ||
    'openweather_tile_empty' =>
      'No precipitation nearby right now. Try zooming out.',
    'noaa_tile_empty' => 'No precipitation nearby right now. Try zooming out.',
    'noaa_invalid_request' => 'Radar frame unavailable.',
    'noaa_timeout' ||
    'noaa_unavailable' ||
    'noaa_rate_limited' ||
    'noaa_request_failed' ||
    'noaa_tile_invalid_content' =>
      'Radar source unavailable; base map still usable.',
    'openweather_timeout' ||
    'openweather_unavailable' ||
    'radar_tile_network_error' ||
    'weather_backend_unreachable' =>
      'Radar temporarily unavailable. The base map is still usable.',
    _ => 'Radar temporarily unavailable. The base map is still usable.',
  };
}

String _formatRadarTime(
  int timestamp, {
  bool isLatest = false,
  String latestLabel = 'Latest',
}) {
  final time = dateTimeFromUnixSeconds(timestamp);
  if (isLatest) return latestLabel;

  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '${time.month}/${time.day} $hour:$minute $suffix';
}
