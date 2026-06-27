import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../models/weather_models.dart';
import '../../../services/open_weather_backend_client.dart';

const double radarCityZoom = 10;

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
  });

  final OpenWeatherBackendClient client;
  final MapController mapController;
  final LocationCandidate location;
  final RadarMode mode;
  final RadarFrame frame;
  final RadarFrame? previousFrame;
  final ValueChanged<String?>? onTileIssue;

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
    final attribution = widget.frame.source == 'noaa_mrms'
        ? 'Map © OpenStreetMap contributors © CARTO · Radar © NOAA/NWS MRMS'
        : 'Map © OpenStreetMap contributors © CARTO · Radar © OpenWeather';

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
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.grumpy_skies',
          subdomains: const ['a', 'b', 'c', 'd'],
          maxNativeZoom: 19,
        ),
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
        Positioned(
          left: DMSpacing.md,
          bottom: 132,
          child: _MapAttribution(text: attribution),
        ),
      ],
    );
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
      key: ValueKey('radar-${frame.source}-${frame.timestamp}'),
      urlTemplate: radarTemplate,
      userAgentPackageName: 'com.example.grumpy_skies',
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

class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(DMColors.deepNavy, 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DMSpacing.xs,
          vertical: 4,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: DMColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
