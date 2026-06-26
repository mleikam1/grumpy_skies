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
  List<RadarFrame> _frames = const [];
  var _futureCastEnabled = true;
  var _playing = false;
  var _sheetExpanded = false;
  var _timelineIndex = 0;
  var _loadedDependencies = false;
  var _tileIssue = false;
  var _tileIssueUpdateQueued = false;
  var _tileIssueGeneration = 0;
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
    _rebuildTimeline(keepSelectedTimestamp: false);
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
    _rebuildTimeline(keepSelectedTimestamp: false);
    _recenter();
    if (mounted) setState(() {});
  }

  void _startBoundaryTimer() {
    _boundaryTimer?.cancel();
    _boundaryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _frames.isEmpty) return;
      final selectedTimestamp = _selectedFrame.timestamp;
      final latest = roundToNearestPastTenMinuteUnix();
      final wasLatest = selectedTimestamp == latest;
      _rebuildTimeline(keepSelectedTimestamp: !wasLatest);
      if (wasLatest) _jumpToLatest();
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
      setState(() {
        _timelineIndex = (_timelineIndex + 1) % _frames.length;
        _clearTileIssue();
      });
    });
  }

  void _rebuildTimeline({required bool keepSelectedTimestamp}) {
    final previous = keepSelectedTimestamp && _frames.isNotEmpty
        ? _selectedFrame.timestamp
        : null;
    final location = _locationController?.selectedLocation;
    final mode = _modeFor(location);
    final forecastEnabled = _futureCastEnabled && _futureAvailableFor(mode);
    final frames = generateRadarFrames(
      mode: mode,
      includeForecast: forecastEnabled,
    );

    _frames = frames;
    final latest = roundToNearestPastTenMinuteUnix();
    final target = previous ?? latest;
    _timelineIndex = _nearestIndexFor(target);
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
      final latest = roundToNearestPastTenMinuteUnix();
      return RadarFrame(
        timestamp: latest,
        label: 'Latest',
        type: RadarFrameType.latest,
        isLatest: true,
      );
    }
    return _frames[_timelineIndex.clamp(0, _frames.length - 1)];
  }

  RadarMode _modeFor(LocationCandidate? location) {
    if (location == null) return RadarMode.usForecast;
    if (location.isUs || _coordinateLooksUs(location.lat, location.lon)) {
      return RadarMode.usForecast;
    }
    return RadarMode.global;
  }

  bool _futureAvailableFor(RadarMode mode) {
    return mode == RadarMode.usForecast;
  }

  void _jumpToLatest() {
    final latest = roundToNearestPastTenMinuteUnix();
    setState(() {
      _timelineIndex = _nearestIndexFor(latest);
      _clearTileIssue();
    });
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

  void _toggleFutureCast() {
    setState(() {
      _futureCastEnabled = !_futureCastEnabled;
      _clearTileIssue();
      _rebuildTimeline(keepSelectedTimestamp: true);
    });
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

            final mode = _modeFor(location);
            final frame = _selectedFrame;
            final futureAvailable = _futureAvailableFor(mode);
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            final horizontal = width < 600 ? DMSpacing.sm : DMSpacing.xl;
            const collapsedSheetHeight = 128.0;
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
                  timestamp: frame.timestamp,
                  onTileIssue: _handleTileIssue,
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + DMSpacing.sm,
                  left: horizontal,
                  right: 88,
                  child: _RadarStatusStack(
                    locationName: _locationLabel(location),
                    frameLabel: frame.label,
                    futureAvailable: futureAvailable,
                    futureCastEnabled: _futureCastEnabled,
                    onFutureCastChanged:
                        futureAvailable ? _toggleFutureCast : null,
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
                if (_tileIssue)
                  Positioned(
                    left: horizontal,
                    right: horizontal,
                    bottom: sheetHeight + bottomInset + DMSpacing.x2,
                    child: _RadarNoticeBanner(
                      message: _tileIssueMessage(_tileIssueCode),
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
                        futureCastEnabled: _futureCastEnabled,
                        futureCastAvailable: futureAvailable,
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
    setState(() {
      _timelineIndex = value.round().clamp(0, _frames.length - 1);
      _clearTileIssue();
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

class _RadarStatusStack extends StatelessWidget {
  const _RadarStatusStack({
    required this.locationName,
    required this.frameLabel,
    required this.futureAvailable,
    required this.futureCastEnabled,
    required this.onFutureCastChanged,
  });

  final String locationName;
  final String frameLabel;
  final bool futureAvailable;
  final bool futureCastEnabled;
  final VoidCallback? onFutureCastChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadarStatusPill(
            locationName: locationName,
            frameLabel: frameLabel,
          ),
          if (futureAvailable) ...[
            const SizedBox(height: DMSpacing.xs),
            _RadarFutureCastChip(
              enabled: futureCastEnabled,
              onPressed: onFutureCastChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _RadarStatusPill extends StatelessWidget {
  const _RadarStatusPill({
    required this.locationName,
    required this.frameLabel,
  });

  final String locationName;
  final String frameLabel;

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
      semanticLabel: 'Radar, $locationName, $frameLabel',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
          ],
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

class _RadarFutureCastChip extends StatelessWidget {
  const _RadarFutureCastChip({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DmPillButton(
      label: 'FutureCast',
      semanticLabel:
          enabled ? 'Turn FutureCast frames off' : 'Turn FutureCast frames on',
      leading: const Icon(Icons.timeline),
      variant:
          enabled ? DmPillButtonVariant.secondary : DmPillButtonVariant.glass,
      selected: enabled,
      padding: const EdgeInsets.symmetric(
        horizontal: DMSpacing.sm,
        vertical: DMSpacing.xxs,
      ),
      onPressed: onPressed,
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
    required this.futureCastEnabled,
    required this.futureCastAvailable,
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
  final bool futureCastEnabled;
  final bool futureCastAvailable;
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
                      futureCastEnabled: futureCastEnabled,
                      futureCastAvailable: futureCastAvailable,
                      onTimelineChanged: onTimelineChanged,
                      onPlayPause: onPlayPause,
                      onLatest: onLatest,
                    )
                  : _CompactRadarTimeline(
                      frame: frame,
                      frames: frames,
                      timelineIndex: timelineIndex,
                      playing: playing,
                      futureCastEnabled: futureCastEnabled,
                      futureCastAvailable: futureCastAvailable,
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
    required this.futureCastEnabled,
    required this.futureCastAvailable,
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
  final bool futureCastEnabled;
  final bool futureCastAvailable;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _CompactRadarTimeline(
          frame: frame,
          frames: frames,
          timelineIndex: timelineIndex,
          playing: playing,
          futureCastEnabled: futureCastEnabled,
          futureCastAvailable: futureCastAvailable,
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
              label: _formatRadarTime(frame.timestamp),
            ),
            _RadarInfoChip(
              icon: Icons.place_outlined,
              label: locationName,
            ),
            _RadarInfoChip(
              icon: Icons.timeline,
              label: futureCastAvailable
                  ? 'FutureCast ${futureCastEnabled ? 'on' : 'off'}'
                  : 'FutureCast unavailable',
            ),
          ],
        ),
        const SizedBox(height: DMSpacing.sm),
        const _RadarLegend(),
        const SizedBox(height: DMSpacing.xs),
        Text(
          'Weather data © OpenWeather',
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.textMuted,
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
    required this.futureCastEnabled,
    required this.futureCastAvailable,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLatest,
    this.showRangeLabels = true,
  });

  final RadarFrame frame;
  final List<RadarFrame> frames;
  final int timelineIndex;
  final bool playing;
  final bool futureCastEnabled;
  final bool futureCastAvailable;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final VoidCallback onLatest;
  final bool showRangeLabels;

  @override
  Widget build(BuildContext context) {
    final max = math.max(frames.length - 1, 1).toDouble();
    final divisions = math.max(frames.length - 1, 1);

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
                    _formatRadarTime(frame.timestamp),
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
          child: Slider(
            value: timelineIndex.clamp(0, max.toInt()).toDouble(),
            min: 0,
            max: max,
            divisions: divisions,
            label: frame.label,
            semanticFormatterCallback: (value) {
              return 'Radar timeline ${_frameLabelFor(frames, value.round())}';
            },
            onChanged: onTimelineChanged,
          ),
        ),
        if (showRangeLabels)
          Row(
            children: [
              Expanded(
                child: Text(
                  '-2h',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DMTypography.labelSmall.copyWith(
                    color: DMColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '10 min frames',
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
                  futureCastAvailable && futureCastEnabled ? '+5h' : 'Latest',
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
    'openweather_invalid_request' =>
      'Invalid radar frame. Jump to Latest and try again.',
    'openweather_not_found' ||
    'openweather_tile_empty' =>
      'No precipitation nearby right now. Try zooming out or scrub FutureCast.',
    'openweather_timeout' ||
    'openweather_unavailable' ||
    'radar_tile_network_error' ||
    'weather_backend_unreachable' =>
      'Radar temporarily unavailable. The base map is still usable.',
    _ => 'Radar temporarily unavailable. The base map is still usable.',
  };
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
