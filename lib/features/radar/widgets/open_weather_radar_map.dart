import '../../../design/dm_theme.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../models/weather_models.dart';
import '../../../services/open_weather_backend_client.dart';

const double radarCityZoom = 10;

/// OSM's public service is keyless and best effort. Keep HTTP caching enabled,
/// identify native requests, and load only the visible viewport (no prefetch).
/// See docs/ui_implementation/refinement/RADAR.md for the usage policy.
const radarBasemapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const radarMapUserAgent = 'DayMaker/1.0 (com.example.grumpy_skies)';

class OpenWeatherRadarMap extends StatefulWidget {
  const OpenWeatherRadarMap({
    super.key,
    required this.client,
    required this.mapController,
    required this.location,
    required this.mode,
    required this.frame,
    this.previousFrame,
    this.onTileIssue,
    this.onBasemapIssue,
    this.tileProvider,
  });

  final OpenWeatherBackendClient client;
  final MapController mapController;
  final LocationCandidate location;
  final RadarMode mode;
  final RadarFrame frame;
  final RadarFrame? previousFrame;
  final ValueChanged<String?>? onTileIssue;
  final ValueChanged<bool>? onBasemapIssue;
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
  String? _lastHealthCheckKey;
  Timer? _healthDebounce;
  final _failedBasemapTiles = <TileCoordinates>{};
  bool _lastBasemapIssue = false;

  LatLng get _center => LatLng(widget.location.lat, widget.location.lon);

  @override
  void initState() {
    super.initState();
    _checkRadarTileHealth();
  }

  @override
  void dispose() {
    _healthDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OpenWeatherRadarMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.lat != widget.location.lat ||
        oldWidget.location.lon != widget.location.lon) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.mapController.move(_center, radarCityZoom);
      });
    }

    if (oldWidget.location.lat != widget.location.lat ||
        oldWidget.location.lon != widget.location.lon ||
        oldWidget.mode != widget.mode ||
        oldWidget.frame.timestamp != widget.frame.timestamp ||
        oldWidget.frame.source != widget.frame.source) {
      _checkRadarTileHealth();
    }
  }

  void _checkRadarTileHealth() {
    final key = '${widget.mode.pathSegment}:'
        '${widget.frame.source}:'
        '${widget.frame.timestamp}:'
        '${widget.location.lat.toStringAsFixed(3)}:'
        '${widget.location.lon.toStringAsFixed(3)}';
    if (_lastHealthCheckKey == key) return;

    _lastHealthCheckKey = key;
    _healthDebounce?.cancel();
    final serial = ++_healthCheckSerial;
    _healthDebounce = Timer(const Duration(milliseconds: 260), () {
      widget.client
          .radarTileHealth(
        mode: widget.mode,
        timestamp: widget.frame.timestamp,
        latitude: widget.location.lat,
        longitude: widget.location.lon,
        source: widget.frame.source,
      )
          .then((health) {
        if (!mounted || serial != _healthCheckSerial) return;
        widget.onTileIssue?.call(
          health.available ? null : health.fallbackCode ?? 'radar_tile_error',
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final basemap = TileLayer(
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

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: radarCityZoom,
        minZoom: 3,
        maxZoom: 12,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // Transform the cartographic base only; precipitation keeps its source palette.
        if (Theme.of(context).brightness == Brightness.dark)
          darkModeTilesContainerBuilder(context, basemap)
        else
          basemap,
        if (widget.previousFrame != null &&
            (widget.previousFrame!.timestamp != widget.frame.timestamp ||
                widget.previousFrame!.source != widget.frame.source))
          _radarTileLayer(
            frame: widget.previousFrame!,
            opacity: 0.48,
            reportErrors: false,
          ),
        TweenAnimationBuilder<double>(
          key: ValueKey(
            'radar-fade-${widget.frame.source}-${widget.frame.timestamp}',
          ),
          tween: Tween(begin: 0, end: 0.72),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, opacity, _) {
            return _radarTileLayer(
              frame: widget.frame,
              opacity: opacity,
              reportErrors: true,
            );
          },
        ),
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
      if (mounted) widget.onBasemapIssue?.call(_lastBasemapIssue);
    });
  }

  Widget _radarTileLayer({
    required RadarFrame frame,
    required double opacity,
    required bool reportErrors,
  }) {
    final radarTemplate = widget.client.radarTileUrlTemplate(
      mode: widget.mode,
      timestamp: frame.timestamp,
      source: frame.source,
    );
    final nativeMaxZoom = frame.source == 'noaa_mrms' ? 12 : 7;

    return TileLayer(
      tileProvider: widget.tileProvider,
      key: ValueKey('radar-${frame.source}-${frame.timestamp}'),
      urlTemplate: radarTemplate,
      userAgentPackageName: radarMapUserAgent,
      panBuffer: 0,
      minNativeZoom: 3,
      maxNativeZoom: nativeMaxZoom,
      maxZoom: 12,
      errorImage: _transparentTileErrorImage,
      tileBuilder: (context, tileWidget, tile) {
        return Opacity(opacity: opacity, child: tileWidget);
      },
      errorTileCallback: reportErrors
          ? (_, __, ___) {
              widget.onTileIssue?.call('radar_tile_network_error');
            }
          : null,
    );
  }
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: context.dmColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final opened = await launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
              mode: LaunchMode.externalApplication,
            );
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Map licence: openstreetmap.org/copyright'),
              ));
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DMSpacing.xs, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '© OpenStreetMap contributors',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.dmColors.textPrimary,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                  Text(
                    source == 'noaa_mrms'
                        ? 'Radar © NOAA/NWS MRMS'
                        : 'Radar © OpenWeather',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.dmColors.textSecondary,
                        ),
                  ),
                ],
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
    if (oldWidget.tile == widget.tile) return;
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
