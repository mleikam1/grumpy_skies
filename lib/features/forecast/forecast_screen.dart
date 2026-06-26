import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/daymaker_sample_data.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../features/roasts/content/roast_pack_repository.dart';
import '../../features/roasts/content/roast_selector.dart';
import '../../features/roasts/content/weather_roast_models.dart';
import '../../models/weather_models.dart';
import '../../repositories/weather_repository.dart';
import '../../services/open_weather_backend_client.dart';
import '../../services/weather_location_controller.dart';
import '../../shared/assets/dm_assets.dart';
import '../../shared/widgets/daymaker_components.dart';
import '../../shared/widgets/weather_location_selector.dart';
import 'widgets/forecast_dashboard_widgets.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({
    super.key,
    this.weatherRepository,
  });

  final WeatherRepository? weatherRepository;

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  static const _sampleUpdatedOffset = Duration(minutes: 10);

  WeatherRepository? _repository;
  RoastPackRepository? _roastPackRepository;
  WeatherLocationController? _locationController;
  WeatherBundle? _weather;
  RoastPack? _roastPack;
  DateTime? _relativeNow;
  Object? _error;
  Timer? _autoRefreshTimer;
  String? _activeLocationKey;
  var _loading = true;
  var _loadingRoastPack = false;
  var _roastIndex = 0;
  var _loadedRepository = false;
  var _showLocationSelector = false;
  final _recentRoastIds = <String>[];
  final _roastSelector = const RoastSelector();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedRepository) return;

    _repository = widget.weatherRepository ?? context.read<WeatherRepository>();
    _roastPackRepository = _readRoastPackRepository() ?? RoastPackRepository();
    _locationController = _readLocationController() ??
        WeatherLocationController(
          repository: _repository!,
        );
    _locationController!.addListener(_handleLocationChanged);
    _loadedRepository = true;
    _startAutoRefresh();
    unawaited(_loadRoastPack());
    if (_locationController!.selectedLocation == null) {
      setState(() => _loading = false);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadWeather();
      });
    }
  }

  RoastPackRepository? _readRoastPackRepository() {
    try {
      return context.read<RoastPackRepository>();
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant ForecastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherRepository != widget.weatherRepository &&
        widget.weatherRepository != null) {
      _repository = widget.weatherRepository;
      _loadWeather(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
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

  Future<void> _loadRoastPack() async {
    if (_loadingRoastPack || _roastPack != null) return;
    _loadingRoastPack = true;
    try {
      final pack = await _roastPackRepository!.loadPack();
      if (!mounted) return;
      setState(() => _roastPack = pack);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[GrumpySkies] roast pack load error: $error');
      }
    } finally {
      _loadingRoastPack = false;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (!mounted || _loading || _weather == null) return;
      _loadWeather();
    });
  }

  void _handleLocationChanged() {
    final location = _locationController?.selectedLocation;
    if (location == null) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _activeLocationKey = null;
        _loading = false;
        _showLocationSelector = true;
      });
      return;
    }

    final key = _locationKey(location);
    if (key == _activeLocationKey) {
      if (mounted) setState(() {});
      return;
    }

    _activeLocationKey = key;
    _showLocationSelector = false;
    _loadWeather(forceRefresh: true);
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    final location = _locationController?.selectedLocation;
    if (location == null) {
      setState(() {
        _loading = false;
        _showLocationSelector = true;
      });
      return;
    }

    _activeLocationKey = _locationKey(location);
    setState(() {
      _loading = true;
      _error = null;
    });
    _locationController?.markFetchingWeather();

    try {
      final weather = await _repository!.getWeather(
        latitude: location.lat,
        longitude: location.lon,
        forceRefresh: forceRefresh,
        location: location,
      );
      if (!mounted) return;

      final now = DateTime.now();
      final observedAt = weather.current.lastUpdated;
      final relativeNow =
          now.difference(observedAt).abs() > const Duration(hours: 6)
              ? observedAt.add(_sampleUpdatedOffset)
              : now;
      setState(() {
        _weather = weather;
        _relativeNow = relativeNow;
      });
      _locationController?.markWeatherLoaded();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      _locationController?.markWeatherError(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static String _locationKey(LocationCandidate location) {
    return '${location.lat.toStringAsFixed(4)},${location.lon.toStringAsFixed(4)}';
  }

  void _showNotificationsMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Forecast notifications are on.')),
      );
  }

  void _showNextRoast() {
    final weather = _weather;
    final pack = _roastPack;
    if (weather != null && pack != null) {
      final snapshot = _snapshotForWeather(weather);
      final selection = _selectWeatherRoast(pack, weather, snapshot);
      _recentRoastIds.add(selection.line.id);
      if (_recentRoastIds.length > 8) {
        _recentRoastIds.removeRange(0, _recentRoastIds.length - 8);
      }
    }

    setState(() {
      _roastIndex++;
    });
  }

  Future<void> _shareRoast() async {
    final weather = _weather;
    final roast = weather == null
        ? DayMakerSampleData
            .roastHistory[_roastIndex % DayMakerSampleData.roastHistory.length]
        : _roastForWeather(weather, _snapshotForWeather(weather));
    await Clipboard.setData(ClipboardData(text: roast.text));
    if (!mounted) return;

    // TODO(haptics): Add success feedback after native share/copy completes.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Roast copied for sharing.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: DMGradients.appBackground,
        color: DMColors.deepNavy,
        foreground: const _ForecastBackdrop(),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _weather == null) {
      return const Center(
        child: CircularProgressIndicator(color: DMColors.sunriseYellow),
      );
    }

    if (_error != null && _weather == null) {
      return _ForecastStateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Forecast unavailable',
        message: _friendlyError(_error),
        actionLabel: 'Retry',
        onAction: () => _loadWeather(forceRefresh: true),
      );
    }

    if (_weather == null || _showLocationSelector) {
      return _LocationSelectionBody(
        controller: _locationController!,
        onLocationSelected: (_) {
          setState(() => _showLocationSelector = false);
        },
      );
    }

    final weather = _weather!;
    final snapshot = _snapshotForWeather(weather);
    final now = _relativeNow ?? weather.current.lastUpdated;
    final roast = _roastForWeather(weather, snapshot);
    final location = _cityName(
      weather.current.locationName.isNotEmpty
          ? weather.current.locationName
          : _locationController?.selectedLocation?.displayName ?? '',
    );

    return RefreshIndicator(
      color: DMColors.deepNavy,
      backgroundColor: DMColors.sunriseYellow,
      onRefresh: () => _loadWeather(forceRefresh: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final breakpoint = DMBreakpoints.fromWidth(width);
          final maxWidth = switch (breakpoint) {
            DMBreakpoint.compact => double.infinity,
            DMBreakpoint.medium => 760.0,
            DMBreakpoint.expanded => 1120.0,
          };
          final gap = breakpoint.isExpanded ? DMSpacing.xl : DMSpacing.md;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: DMSpacing.pagePaddingForWidth(width).copyWith(
              bottom: DMSpacing.x2,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ForecastHeader(
                        location: location,
                        onNotificationsPressed: _showNotificationsMessage,
                        onChangeLocation: () {
                          setState(() => _showLocationSelector = true);
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: DMSpacing.sm),
                        _StaleWeatherBanner(message: _friendlyError(_error)),
                      ],
                      if (_showLocationSelector) ...[
                        SizedBox(height: gap),
                        WeatherLocationSelector(
                          controller: _locationController!,
                          title: 'Change location',
                          onLocationSelected: (_) {
                            setState(() => _showLocationSelector = false);
                          },
                        ),
                      ],
                      SizedBox(height: gap),
                      _ForecastTopSection(
                        weather: weather,
                        now: now,
                        gap: gap,
                        expanded: breakpoint.isExpanded,
                      ),
                      SizedBox(height: gap),
                      ForecastRoastCard(
                        persona: DayMakerSampleData.persona,
                        roast: roast,
                        onNewRoast: _showNextRoast,
                        onShare: _shareRoast,
                      ),
                      SizedBox(height: gap),
                      ForecastMetricChips(weather: snapshot),
                      SizedBox(height: gap),
                      ShortTermPrecipitationCard(
                        minutes: weather.minutePrecipitation,
                      ),
                      if (weather.alerts.isNotEmpty) ...[
                        SizedBox(height: gap),
                        WeatherAlertsPanel(alerts: weather.alerts),
                      ],
                      SizedBox(height: gap),
                      _ForecastLowerSection(
                        weather: weather,
                        gap: gap,
                        expanded: breakpoint.isExpanded,
                      ),
                      SizedBox(height: gap),
                      const _WeatherAttributionFooter(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _cityName(String locationName) {
    final trimmed = locationName.trim();
    if (trimmed.isEmpty) return 'Current location';
    return trimmed.split(',').first.trim();
  }

  Roast _roastForWeather(WeatherBundle weather, WeatherSnapshot snapshot) {
    final pack = _roastPack;
    if (pack == null) {
      return DayMakerSampleData
          .roastHistory[_roastIndex % DayMakerSampleData.roastHistory.length];
    }

    final selection = _selectWeatherRoast(pack, weather, snapshot);
    return Roast(
      id: selection.line.id,
      personaId: selection.line.persona,
      weatherSnapshotId: snapshot.id,
      text: selection.renderedText,
      category: selection.line.type.name,
      createdAt: weather.current.displayUpdatedAt,
      xpReward: 15,
    );
  }

  RoastSelection _selectWeatherRoast(
    RoastPack pack,
    WeatherBundle weather,
    WeatherSnapshot snapshot,
  ) {
    final context = WeatherRoastContext.fromWeatherBundle(
      weather,
      now: _relativeNow ?? weather.current.displayUpdatedAt,
    );
    return _roastSelector.select(
      pack: pack,
      context: context,
      persona: DayMakerSampleData.persona.id,
      type: RoastType.today,
      maxLevel: RoastLevel.medium,
      recentRoastIds: _recentRoastIds,
      seed: '${snapshot.id}|${weather.current.displayUpdatedAt}|$_roastIndex',
    );
  }

  static WeatherSnapshot _snapshotForWeather(WeatherBundle weather) {
    final existing = weather.snapshot;
    if (existing != null) return existing;

    final current = weather.current;
    return WeatherSnapshot(
      id: 'current-${current.lastUpdated.millisecondsSinceEpoch}',
      locationName: current.locationName,
      condition: current.condition,
      temperatureF: current.temperatureF.round(),
      feelsLikeF: current.feelsLikeF.round(),
      windMph: current.windMph,
      windDirection: current.windDirection,
      humidityPercent: current.humidity,
      rainChancePercent: current.precipitationChance,
      aqi: current.aqi,
      aqiCategory: current.aqiCategory,
      uvIndex: current.uvIndex,
      uvCategory: current.uvCategory,
      chaosMeterPercent: current.chaosMeterPercent,
      observedAt: current.lastUpdated,
      hourly: weather.hourly
          .map(
            (hour) => ForecastHour(
              time: hour.time,
              temperatureF: hour.temperatureF.round(),
              condition: hour.condition,
              rainChancePercent: hour.precipitationChance,
            ),
          )
          .toList(),
      daily: weather.daily
          .map(
            (day) => ForecastDay(
              date: day.date,
              lowF: day.minTempF.round(),
              highF: day.maxTempF.round(),
              condition: day.condition,
              rainChancePercent: day.precipitationChance,
            ),
          )
          .toList(),
      metrics: const [],
    );
  }

  static String _friendlyError(Object? error) {
    if (error is OpenWeatherBackendException) {
      return error.message;
    }

    if (kDebugMode && error != null) {
      debugPrint('[GrumpySkies] forecast error: $error');
    }

    if (error == null) {
      return 'Pull to refresh or try again in a moment.';
    }
    return 'Weather service is unavailable. Check your connection and try again.';
  }
}

class _LocationSelectionBody extends StatelessWidget {
  const _LocationSelectionBody({
    required this.controller,
    required this.onLocationSelected,
  });

  final WeatherLocationController controller;
  final ValueChanged<LocationCandidate> onLocationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ListView(
            padding: DMSpacing.pagePaddingForWidth(width).copyWith(
              bottom: DMSpacing.x2,
            ),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: WeatherLocationSelector(
                    controller: controller,
                    onLocationSelected: onLocationSelected,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StaleWeatherBanner extends StatelessWidget {
  const _StaleWeatherBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: const EdgeInsets.all(DMSpacing.sm),
      borderColor: DMColors.sunriseYellow,
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: DMColors.sunriseYellow),
          const SizedBox(width: DMSpacing.sm),
          Expanded(
            child: Text(
              '$message Showing the last successful update.',
              style: DMTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastTopSection extends StatelessWidget {
  const _ForecastTopSection({
    required this.weather,
    required this.now,
    required this.gap,
    required this.expanded,
  });

  final WeatherBundle weather;
  final DateTime now;
  final double gap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final current = ForecastCurrentWeatherCard(
      weather: weather.current,
      now: now,
    );
    final hero = ForecastHeroAtmosphere(expanded: expanded);

    if (!expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          current,
          SizedBox(height: gap),
          hero,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: current),
        SizedBox(width: gap),
        Expanded(flex: 7, child: hero),
      ],
    );
  }
}

class _ForecastLowerSection extends StatelessWidget {
  const _ForecastLowerSection({
    required this.weather,
    required this.gap,
    required this.expanded,
  });

  final WeatherBundle weather;
  final double gap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final forecast = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ForecastHourlyStrip(
          hourly: weather.hourly,
          sunrise: weather.current.sunrise,
          sunset: weather.current.sunset,
        ),
        SizedBox(height: gap),
        ForecastDailyGrid(
          daily: weather.daily,
          sunrise: weather.current.sunrise,
          sunset: weather.current.sunset,
        ),
      ],
    );
    final details = ForecastExtraMetrics(weather: weather.current);

    if (!expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          forecast,
          SizedBox(height: gap),
          details,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: forecast),
        SizedBox(width: gap),
        Expanded(flex: 4, child: details),
      ],
    );
  }
}

class ShortTermPrecipitationCard extends StatelessWidget {
  const ShortTermPrecipitationCard({
    super.key,
    required this.minutes,
  });

  final List<MinutePrecipitation> minutes;

  @override
  Widget build(BuildContext context) {
    final wetIndex = minutes.indexWhere((minute) => minute.isWet);
    final hasPrecipitation = wetIndex >= 0;
    final title = hasPrecipitation
        ? 'Precipitation starts ${_relativeMinuteLabel(wetIndex)}'
        : 'No precipitation expected in the next hour';
    final visibleMinutes = hasPrecipitation
        ? minutes.skip(wetIndex).take(12).toList()
        : minutes.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: 'Next hour'),
        const SizedBox(height: DMSpacing.sm),
        DmGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasPrecipitation
                        ? Icons.umbrella_outlined
                        : Icons.check_circle_outline,
                    color: hasPrecipitation
                        ? DMColors.rainTeal
                        : DMColors.mintGreen,
                  ),
                  const SizedBox(width: DMSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.title,
                    ),
                  ),
                ],
              ),
              if (visibleMinutes.isNotEmpty) ...[
                const SizedBox(height: DMSpacing.md),
                SizedBox(
                  height: 88,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final minute in visibleMinutes)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                            ),
                            child: _MinuteBar(minute: minute),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _relativeMinuteLabel(int index) {
    if (index <= 0) return 'now';
    return 'in $index min';
  }
}

class _MinuteBar extends StatelessWidget {
  const _MinuteBar({required this.minute});

  final MinutePrecipitation minute;

  @override
  Widget build(BuildContext context) {
    final amount = minute.precipitation.clamp(0, 0.25);
    final height = 8 + (amount / 0.25 * 58);
    final color = minute.isWet ? DMColors.rainTeal : DMColors.glassStrong;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message:
              '${_formatTime(minute.time)}: ${minute.precipitation.toStringAsFixed(2)} in',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: DMSpacing.xxs),
        Text(
          _formatMinute(minute.time),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: DMTypography.labelSmall.copyWith(
            color: DMColors.textMuted,
          ),
        ),
      ],
    );
  }

  static String _formatMinute(DateTime time) {
    return time.minute.toString().padLeft(2, '0');
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class WeatherAlertsPanel extends StatelessWidget {
  const WeatherAlertsPanel({
    super.key,
    required this.alerts,
  });

  final List<WeatherAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DmSectionHeader(title: 'Alerts'),
        const SizedBox(height: DMSpacing.sm),
        for (var index = 0; index < alerts.length; index++) ...[
          if (index > 0) const SizedBox(height: DMSpacing.sm),
          _WeatherAlertTile(alert: alerts[index]),
        ],
      ],
    );
  }
}

class _WeatherAlertTile extends StatelessWidget {
  const _WeatherAlertTile({required this.alert});

  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      borderColor: DMColors.alertOrange,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: DMColors.sunriseYellow,
        collapsedIconColor: DMColors.textMuted,
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: DMColors.alertOrange,
        ),
        title: Text(
          alert.event,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.title,
        ),
        subtitle: Text(
          _subtitle(alert),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.bodySmall,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              alert.description.isEmpty
                  ? 'No additional alert details were provided.'
                  : alert.description,
              style: DMTypography.body,
            ),
          ),
        ],
      ),
    );
  }

  static String _subtitle(WeatherAlert alert) {
    final times = [
      if (alert.start != null) _formatDateTime(alert.start!),
      if (alert.end != null) 'until ${_formatDateTime(alert.end!)}',
    ].join(' ');
    if (times.isEmpty) return alert.senderName;
    return '${alert.senderName} · $times';
  }

  static String _formatDateTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${time.month}/${time.day} $hour:$minute $suffix';
  }
}

class _WeatherAttributionFooter extends StatelessWidget {
  const _WeatherAttributionFooter();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Weather data © OpenWeather',
      textAlign: TextAlign.center,
      style: DMTypography.bodySmall.copyWith(
        color: DMColors.textMuted,
      ),
    );
  }
}

class _ForecastStateMessage extends StatelessWidget {
  const _ForecastStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DMSpacing.xl),
        child: DmGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: DMColors.skyBlueSoft),
              const SizedBox(height: DMSpacing.md),
              Text(title,
                  textAlign: TextAlign.center, style: DMTypography.title),
              const SizedBox(height: DMSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DMTypography.body,
              ),
              const SizedBox(height: DMSpacing.md),
              DmPillButton(label: actionLabel, onPressed: onAction),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastBackdrop extends StatelessWidget {
  const _ForecastBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // TODO(assets): Drop generated forecast backgrounds into DmAssets so
        // condition-specific art can replace the painted fallback.
        DmAssetImage(
          assetPath: DmAssets.backgrounds.forecast.clearDay,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          placeholderBuilder: (_) => const SizedBox.shrink(),
        ),
        CustomPaint(painter: _ForecastBackdropPainter()),
      ],
    );
  }
}

class _ForecastBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          DMColors.opacity(DMColors.sunriseYellow, 0.26),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.04),
          radius: size.width * 0.46,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.04),
      size.width * 0.46,
      topGlow,
    );

    final lowerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          DMColors.opacity(DMColors.rainTeal, 0.18),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.08, size.height * 0.64),
          radius: size.width * 0.42,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.64),
      size.width * 0.42,
      lowerGlow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
