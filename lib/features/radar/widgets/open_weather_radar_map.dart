import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_theme.dart';
import '../../../design/dm_spacing.dart';
import '../../../models/weather_models.dart';
import '../../../services/open_weather_backend_client.dart';

const double radarCityZoom = 10;

/// OSM's public service is keyless and best effort. Keep HTTP caching enabled,
/// identify native requests, and load only the visible viewport (no prefetch).
/// See docs/ui_implementation/refinement/RADAR.md for the usage policy.
const radarBasemapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const radarMapUserAgent = 'WingmanWeather/1.0 (com.example.grumpy_skies)';

class OpenWeatherRadarMap extends StatefulWidget {
  const OpenWeatherRadarMap({
    super.key,
    required this.client,
    required this.mapController,
    required this.location,
    required this.mode,
    required this.frame,
    this.opacity = 0.65,
    this.overlayVisible = true,
    this.active = true,
    this.recenterOnLocationChange = true,
    this.onTileIssue,
    this.onBasemapIssue,
    this.onFrameLoading,
    this.onPositionChanged,
    this.onMapReady,
    this.tileProvider,
  });

  final OpenWeatherBackendClient client;
  final MapController mapController;
  final LocationCandidate location;
  final RadarMode mode;
  // No frame means no imagery. A synthetic timestamp must never imply data.
  final RadarFrame? frame;
  final double opacity;
  final bool overlayVisible;
  final bool active;
  final bool recenterOnLocationChange;
  final ValueChanged<String?>? onTileIssue;
  final ValueChanged<bool>? onBasemapIssue;
  final ValueChanged<bool>? onFrameLoading;
  final PositionCallback? onPositionChanged;
  final VoidCallback? onMapReady;
  final TileProvider? tileProvider;

  @override
  State<OpenWeatherRadarMap> createState() => _OpenWeatherRadarMapState();
}

class _OpenWeatherRadarMapState extends State<OpenWeatherRadarMap> {
  static final _transparentTileErrorImage = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    ),
  );

  var _healthCheckSerial = 0;
  String? _healthProbeKey;
  Future<RadarHealth>? _healthProbe;
  String? _healthIssue;
  Timer? _healthDebounce;
  final _failedBasemapTiles = <TileCoordinates>{};
  bool _lastBasemapIssue = false;
  // TileImage equality only compares coordinates, so identity is essential
  // when different frames request the same square of the map.
  final _radarTiles = Map<TileImage, _RadarTileState>.identity();
  var _frameGeneration = 0;
  bool _statusNotificationScheduled = false;
  bool? _lastFrameLoading;
  String? _lastTileIssue;

  LatLng get _center => LatLng(widget.location.lat, widget.location.lon);
  bool get _showWeather =>
      widget.active && widget.overlayVisible && widget.frame != null;
  String? get _frameKey => widget.frame == null
      ? null
      : '${widget.mode.pathSegment}:${widget.frame!.source}:'
          '${widget.frame!.timestamp}';

  @override
  void initState() {
    super.initState();
    _checkRadarTileHealth();
    _scheduleRadarStatus();
  }

  @override
  void dispose() {
    _healthCheckSerial++;
    _healthDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OpenWeatherRadarMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged = oldWidget.location.lat != widget.location.lat ||
        oldWidget.location.lon != widget.location.lon;
    if (locationChanged && widget.recenterOnLocationChange) {
      final location = _center;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || location != _center) return;
        widget.mapController.move(location, radarCityZoom);
      });
    }

    final frameChanged = oldWidget.mode != widget.mode ||
        oldWidget.frame?.timestamp != widget.frame?.timestamp ||
        oldWidget.frame?.source != widget.frame?.source;
    if (frameChanged ||
        locationChanged ||
        oldWidget.active != widget.active ||
        oldWidget.overlayVisible != widget.overlayVisible) {
      _frameGeneration++;
      _radarTiles.clear();
      if (frameChanged || locationChanged) _healthIssue = null;
      _scheduleRadarStatus();
    }
    if (frameChanged ||
        locationChanged ||
        oldWidget.active != widget.active ||
        oldWidget.overlayVisible != widget.overlayVisible) {
      _checkRadarTileHealth();
    }
  }

  void _checkRadarTileHealth() {
    _healthDebounce?.cancel();
    final serial = ++_healthCheckSerial;
    final frame = widget.frame;
    if (!_showWeather || frame == null) return;
    final key = '$_frameKey:'
        '${widget.location.lat.toStringAsFixed(3)}:'
        '${widget.location.lon.toStringAsFixed(3)}';
    final existingProbe = _healthProbe;
    if (_healthProbeKey == key && existingProbe != null) {
      // Reuse both pending and completed results when returning to this frame.
      // Visibility/mode changes invalidate delivery, not the evidence itself.
      unawaited(_observeHealth(existingProbe, serial));
      return;
    }
    final mode = widget.mode;
    final location = widget.location;
    _healthDebounce = Timer(const Duration(milliseconds: 260), () {
      // A cancelled debounce has not consumed the request. Keep the latest
      // probe Future so a brief hide or mode switch cannot erase an unavailable
      // result while suppressing the replacement request for that same frame.
      final probe = widget.client.radarTileHealth(
        mode: mode,
        timestamp: frame.timestamp,
        latitude: location.lat,
        longitude: location.lon,
        source: frame.source,
      );
      _healthProbeKey = key;
      _healthProbe = probe;
      unawaited(_observeHealth(probe, serial));
    });
  }

  Future<void> _observeHealth(Future<RadarHealth> probe, int serial) async {
    final health = await probe;
    if (!mounted || !_showWeather || serial != _healthCheckSerial) return;
    _healthIssue =
        health.available ? null : health.fallbackCode ?? 'radar_tile_error';
    _scheduleRadarStatus();
  }

  @override
  Widget build(BuildContext context) {
    final basemap = TileLayer(
      key: const ValueKey('radar-basemap'),
      tileProvider: widget.tileProvider,
      urlTemplate: radarBasemapUrl,
      userAgentPackageName: radarMapUserAgent,
      // Retain flutter_map's HTTP-aware native cache / browser cache.
      panBuffer: 0,
      maxNativeZoom: 19,
      tileBuilder: (context, child, tile) => _BasemapTileStatus(
        tile: tile,
        onStatus: _handleBasemapTileStatus,
        child: child,
      ),
    );

    return TickerMode(
      enabled: widget.active,
      child: FlutterMap(
        mapController: widget.mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: radarCityZoom,
          minZoom: 3,
          maxZoom: 12,
          onPositionChanged: widget.onPositionChanged,
          onMapReady: widget.onMapReady,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // Raster labels cannot be independently raised above weather. Only
          // transform the cartographic base; retain the provider radar palette.
          if (Theme.of(context).brightness == Brightness.dark)
            darkModeTilesContainerBuilder(context, basemap)
          else
            basemap,
          if (_showWeather) _radarTileLayer(widget.frame!),
          MarkerLayer(
            markers: [
              Marker(
                point: _center,
                width: 64,
                height: 64,
                child: const _LocationMarker(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleBasemapTileStatus(TileCoordinates coordinates, bool failed) {
    if (!mounted) return;
    if (failed) {
      _failedBasemapTiles.add(coordinates);
    } else {
      _failedBasemapTiles.remove(coordinates);
    }
    final hasIssue = _failedBasemapTiles.isNotEmpty;
    if (hasIssue == _lastBasemapIssue) return;
    _lastBasemapIssue = hasIssue;
    // Tile listeners may run during map layout or disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        widget.onBasemapIssue?.call(_lastBasemapIssue);
      }
    });
  }

  void _handleRadarTileStatus(
      int generation, TileImage tile, _RadarTileState? state) {
    if (!mounted || !_showWeather || generation != _frameGeneration) return;
    if (state == null) {
      _radarTiles.remove(tile);
    } else {
      _radarTiles[tile] = state;
    }
    _scheduleRadarStatus();
  }

  void _scheduleRadarStatus() {
    if (_statusNotificationScheduled) return;
    _statusNotificationScheduled = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _statusNotificationScheduled = false;
      if (!mounted) return;
      final loading = _showWeather &&
          (_radarTiles.isEmpty ||
              _radarTiles.values.contains(_RadarTileState.loading));
      final issue = !_showWeather
          ? null
          : _radarTiles.values.contains(_RadarTileState.failed)
              ? 'radar_tile_network_error'
              : _healthIssue;
      if (loading != _lastFrameLoading) {
        _lastFrameLoading = loading;
        widget.onFrameLoading?.call(loading);
      }
      if (issue != _lastTileIssue) {
        _lastTileIssue = issue;
        widget.onTileIssue?.call(issue);
      }
    });
  }

  Widget _radarTileLayer(RadarFrame frame) {
    final generation = _frameGeneration;
    final radarTemplate = widget.client.radarTileUrlTemplate(
      mode: widget.mode,
      timestamp: frame.timestamp,
      source: frame.source,
    );
    final nativeMaxZoom = frame.source == 'noaa_mrms' ? 12 : 7;

    return TileLayer(
      tileProvider: widget.tileProvider,
      // Removing the previous layer prevents observations or an earlier frame
      // remaining underneath a newly selected forecast timestamp.
      key: ValueKey('radar-$_frameKey'),
      urlTemplate: radarTemplate,
      userAgentPackageName: radarMapUserAgent,
      panBuffer: 0,
      minNativeZoom: 3,
      maxNativeZoom: nativeMaxZoom,
      maxZoom: 12,
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: _transparentTileErrorImage,
      tileBuilder: (context, tileWidget, tile) => _RadarTileStatus(
        key: ObjectKey(tile),
        tile: tile,
        generation: generation,
        onStatus: _handleRadarTileStatus,
        child: Opacity(
          opacity: widget.opacity.clamp(0.0, 1.0),
          child: tileWidget,
        ),
      ),
    );
  }
}

enum _RadarTileState { loading, loaded, failed }

/// Reads the image's actual completion rather than mistaking successful
/// metadata/health requests or an elapsed timer for a rendered frame.
class _RadarTileStatus extends StatefulWidget {
  const _RadarTileStatus({
    super.key,
    required this.tile,
    required this.generation,
    required this.onStatus,
    required this.child,
  });
  final TileImage tile;
  final int generation;
  final void Function(int, TileImage, _RadarTileState?) onStatus;
  final Widget child;

  @override
  State<_RadarTileStatus> createState() => _RadarTileStatusState();
}

class _RadarTileStatusState extends State<_RadarTileStatus> {
  @override
  void initState() {
    super.initState();
    widget.tile.addListener(_report);
    _report();
  }

  @override
  void didUpdateWidget(covariant _RadarTileStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tile, widget.tile)) {
      oldWidget.tile.removeListener(_report);
      oldWidget.onStatus(oldWidget.generation, oldWidget.tile, null);
      widget.tile.addListener(_report);
    }
    _report();
  }

  void _report() => widget.onStatus(
        widget.generation,
        widget.tile,
        widget.tile.loadError
            ? _RadarTileState.failed
            : widget.tile.loadFinishedAt == null
                ? _RadarTileState.loading
                : _RadarTileState.loaded,
      );

  @override
  void dispose() {
    widget.tile.removeListener(_report);
    widget.onStatus(widget.generation, widget.tile, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LocationMarker extends StatelessWidget {
  const _LocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DMColors.opacity(DMColors.skyBlue, 0.22),
          border: Border.all(
            color: DMColors.opacity(DMColors.skyBlue, 0.46),
            width: 2,
          ),
        ),
        child: const SizedBox.square(
          dimension: 34,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DMColors.sunriseYellow,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kept above the radar sheets/notices by RadarScreen so licence attribution
/// stays visible at every sheet position and large text size.
class RadarMapAttribution extends StatelessWidget {
  const RadarMapAttribution({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final noaa = source == 'noaa_mrms';
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: context.dmColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _AttributionLink(
              label: '© OpenStreetMap',
              semanticLabel: '© OpenStreetMap contributors. Map licence.',
              url: 'https://www.openstreetmap.org/copyright',
            ),
            _AttributionLink(
              label: noaa ? 'Radar: NOAA/NWS' : 'Radar: OpenWeather',
              semanticLabel: noaa
                  ? 'Radar data from NOAA and the National Weather Service.'
                  : 'Radar data from OpenWeather.',
              url: noaa
                  ? 'https://radar.weather.gov/'
                  : 'https://openweathermap.org/',
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.semanticLabel,
    required this.url,
  });

  final String label;
  final String semanticLabel;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Source: $url'),
            ));
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: DMSpacing.xs, vertical: 4),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.dmColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tracks rendered tile failures separately from radar-overlay health. A tile
/// that recovers or leaves the viewport no longer keeps the warning active.
class _BasemapTileStatus extends StatefulWidget {
  const _BasemapTileStatus(
      {required this.tile, required this.onStatus, required this.child});
  final TileImage tile;
  final void Function(TileCoordinates, bool) onStatus;
  final Widget child;

  @override
  State<_BasemapTileStatus> createState() => _BasemapTileStatusState();
}

class _BasemapTileStatusState extends State<_BasemapTileStatus> {
  @override
  void initState() {
    super.initState();
    widget.tile.addListener(_report);
    _report();
  }

  @override
  void didUpdateWidget(covariant _BasemapTileStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.tile, widget.tile)) return;
    oldWidget.tile.removeListener(_report);
    oldWidget.onStatus(oldWidget.tile.coordinates, false);
    widget.tile.addListener(_report);
    _report();
  }

  void _report() =>
      widget.onStatus(widget.tile.coordinates, widget.tile.loadError);

  @override
  void dispose() {
    widget.tile.removeListener(_report);
    widget.onStatus(widget.tile.coordinates, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
