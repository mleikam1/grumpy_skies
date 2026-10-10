import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../fun/meme/meme_weather.dart';
import '../roasts/services/displayed_roast_share.dart';
import '../../models/temperature_unit.dart';
import '../../repositories/fake_weather_repository.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_theme.dart';
import 'widgets/forecast_insight_card.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../features/roasts/models/roast_persona.dart';
import '../../features/roasts/content/roast_pack_repository.dart';
import '../../models/weather_models.dart';
import '../../models/weather_safety.dart';
import '../../models/precipitation_coverage.dart';
import '../../monetization/ad_placement.dart';
import '../../monetization/widgets/ad_section.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/pack_roast_repository.dart';
import '../roasts/controllers/local_roast_controller.dart';
import '../../repositories/weather_repository.dart';
import '../../services/open_weather_backend_client.dart';
import '../../services/settings_controller.dart';
import '../../services/weather_location_controller.dart';
import '../../shared/widgets/daymaker_components.dart';
import '../../shared/widgets/weather_location_selector.dart';
import 'widgets/forecast_dashboard_widgets.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({
    super.key,
    this.weatherRepository,
    this.clock,
  });

  final WeatherRepository? weatherRepository;
  final WeatherClock? clock;

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen>
    with WidgetsBindingObserver {
  DateTime get _now => (widget.clock ?? DateTime.now)();
  int _requestSerial = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) return;
    final weather = _weather;
    final now = _now;
    final retrievedAt =
        weather?.current.fetchedAt ?? weather?.current.displayUpdatedAt;
    final retrievalAge =
        retrievedAt == null ? null : now.difference(retrievedAt);
    final needsRefresh = weather == null ||
        weather.isOfflineCache ||
        _error != null ||
        weatherFreshness(weather.current.displayUpdatedAt, now) !=
            WeatherFreshness.fresh ||
        retrievalAge == null ||
        retrievalAge.isNegative ||
        retrievalAge >= const Duration(minutes: 10);
    // Returning from an SDK view, share sheet, or brief interruption rechecks
    // elapsed time without manufacturing another weather request.
    if (needsRefresh) _locationController?.invalidateWeatherSafety();
    if (mounted) setState(() {});
    if (needsRefresh &&
        _locationController?.selectedLocation != null &&
        !_loading) {
      unawaited(_loadWeather(forceRefresh: true));
    }
  }

  WeatherRepository? _repository;
  RoastPackRepository? _roastPackRepository;
  SettingsRepository? _settingsRepository;
  WeatherLocationController? _locationController;
  WeatherBundle? _weather;
  late LocalRoastController _localRoasts;
  bool _ownsRoastController = false;
  Object? _error;
  Timer? _autoRefreshTimer;
  String? _activeLocationKey;
  var _loading = true;
  var _loadedRepository = false;
  var _showLocationSelector = false;
  var _selectedPersonaId = RoastPersonas.defaultPersona.id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedRepository) return;

    _repository = widget.weatherRepository ?? context.read<WeatherRepository>();
    _roastPackRepository = _readRoastPackRepository() ?? RoastPackRepository();
    final sharedRoasts = context.read<LocalRoastController?>();
    _ownsRoastController = sharedRoasts == null;
    _localRoasts =
        sharedRoasts ?? LocalRoastController(repository: _roastPackRepository);
    _localRoasts.addListener(_onRoastContentChanged);
    _settingsRepository = _readSettingsRepository();
    _locationController = _readLocationController() ??
        WeatherLocationController(
          repository: _repository!,
        );
    _locationController!.addListener(_handleLocationChanged);
    _loadedRepository = true;
    _startAutoRefresh();
    unawaited(_loadSelectedPersona());
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

  SettingsRepository? _readSettingsRepository() {
    try {
      return context.read<SettingsRepository>();
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
    _localRoasts.removeListener(_onRoastContentChanged);
    if (_ownsRoastController) _localRoasts.dispose();
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _loadSelectedPersona() async {
    final repository = _settingsRepository;
    if (repository == null) return;

    try {
      final settings = await repository.loadSettings();
      if (!mounted) return;
      setState(() {
        _selectedPersonaId =
            RoastPersonas.normalizeId(settings.selectedPersonaId);
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[GrumpySkies] selected persona load error: $error');
      }
    }
  }

  String _selectedPersonaIdForBuild() {
    try {
      final controller = context.watch<SettingsController>();
      return RoastPersonas.normalizeId(controller.selectedPersonaId);
    } catch (_) {
      return _selectedPersonaId;
    }
  }

  void _onRoastContentChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRoastPack() async {
    await _localRoasts.initialize();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || !_foreground) return;
      setState(() {});
      if (_loading || _weather == null) return;
      final retrieval =
          _weather!.current.fetchedAt ?? _weather!.current.displayUpdatedAt;
      if (_now.difference(retrieval) >= const Duration(minutes: 10)) {
        _loadWeather();
      }
    });
  }

  void _handleLocationChanged() {
    final location = _locationController?.selectedLocation;
    if (location == null) {
      if (!mounted) return;
      _readMemeRegistry()?.clearSource('forecast');
      setState(() {
        _requestSerial++;
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

    _readMemeRegistry()?.clearSource('forecast');
    _activeLocationKey = key;
    _weather = null;
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

    final requestSerial = ++_requestSerial;
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
      if (!mounted || requestSerial != _requestSerial) return;
      _localRoasts.publishWeather(weather, location);
      setState(() => _weather = weather);
      _locationController?.updateWeatherSafety(weather, location);
      _locationController?.markWeatherLoaded();
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      setState(() => _error = error);
      _locationController?.markWeatherError(_friendlyError(error));
    } finally {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  static String _locationKey(LocationCandidate location) {
    return '${location.lat.toStringAsFixed(4)},${location.lon.toStringAsFixed(4)}';
  }

  void _showNextRoast(String personaId) {
    _localRoasts.select(
        persona: personaId,
        bundle: _weather,
        now: _now,
        unit: context.read<SettingsController?>()?.temperatureUnit ??
            TemperatureUnit.fahrenheit,
        another: true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            stops: const [
              0,
              .45,
              1
            ],
            colors: [
              context.dmColors.heroGradient.colors[1],
              context.dmColors.appBackground,
              context.dmColors.appBackground
            ]),
        color: context.dmColors.appBackground,
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
    final selectedPersonaId = _selectedPersonaIdForBuild();
    final selectedPersona =
        RoastPersonas.byId(selectedPersonaId).toDayMakerPersona();
    final now = _now;
    final relevantAlerts =
        weather.alerts.where((alert) => alert.isRelevantAt(now)).toList();
    final observationFresh =
        weatherFreshness(weather.current.displayUpdatedAt, now) ==
            WeatherFreshness.fresh;
    final cached = weather.isOfflineCache || _error != null;
    final roast = _roastForWeather(weather, snapshot, selectedPersona.id);
    final memeSource = _memeSource(roast, weather);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_weather, weather) ||
          RoastPersonas.normalizeId(
                  context.read<SettingsController?>()?.selectedPersonaId ??
                      _selectedPersonaId) !=
              selectedPersona.id ||
          _showLocationSelector) {
        return;
      }
      if (relevantAlerts.isNotEmpty) {
        _readMemeRegistry()?.clearSource('forecast');
        return;
      }
      _readMemeRegistry()?.publish(memeSource, weather: weather);
      if (roast.selection != null) {
        _localRoasts.commitDisplayed(roast.selection!);
      }
    });
    final location = (weather.current.locationName.isNotEmpty
        ? weather.current.locationName
        : _locationController?.selectedLocation?.displayName ?? '');

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
            key: const PageStorageKey('today-scroll'),
            padding: EdgeInsets.fromLTRB(
                width >= 600 ? 24 : 18, 8, width >= 600 ? 24 : 18, 24),
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
                        status: cached
                            ? 'Cached'
                            : observationFresh
                                ? 'Live'
                                : 'Stale',
                        onChangeLocation: () {
                          setState(() => _showLocationSelector = true);
                        },
                      ),
                      if (cached) ...[
                        const SizedBox(height: DMSpacing.sm),
                        _StaleWeatherBanner(
                            message: _error == null
                                ? 'Offline cached weather.'
                                : _friendlyError(_error)),
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
                      if (_repository is FakeWeatherRepository) ...[
                        SizedBox(height: gap),
                        const Text('Sample weather · demonstration data',
                            style: DMTypography.bodySmall),
                      ],
                      if (relevantAlerts.isNotEmpty) ...[
                        SizedBox(height: gap),
                        WeatherAlertsPanel(alerts: relevantAlerts),
                      ],
                      ForecastCurrentWeatherCard(
                        weather: weather.current,
                        now: now,
                        today:
                            weather.daily.isEmpty ? null : weather.daily.first,
                      ),
                      const SizedBox(height: 8),
                      ForecastInsightCard(
                          weather: weather,
                          now: now,
                          unavailable: cached || !observationFresh),
                      if (relevantAlerts.isEmpty) ...[
                        const SizedBox(height: 10),
                        ForecastRoastCard(
                          persona: selectedPersona,
                          roast: roast,
                          sourceLabel:
                              memeSource.isSample ? 'Sample roast' : null,
                          onNewRoast: () => _showNextRoast(selectedPersona.id),
                          onShare: () =>
                              showDisplayedRoastShareSheet(context, memeSource),
                          onShareToMeme: () => context
                              .push(AppRoutes.memeGenerator, extra: memeSource),
                        ),
                      ],
                      ForecastHourlyStrip(
                        hourly: weather.hourly,
                        sunrise: weather.current.sunrise,
                        sunset: weather.current.sunset,
                        referenceTime: now,
                        timezoneOffset: weather.current.timezoneOffset,
                        errorMessage: weather.hourlyForecastMessage,
                      ),
                      ForecastDailyGrid(
                        daily: weather.daily,
                        sunrise: weather.current.sunrise,
                        sunset: weather.current.sunset,
                        referenceTime: now,
                        timezoneOffset: weather.current.timezoneOffset,
                        errorMessage: weather.dailyForecastMessage,
                      ),
                      const SizedBox(height: 12),
                      Text(
                          _observationLabel(
                              weather.current.displayUpdatedAt, now),
                          style: TextStyle(
                              fontSize: 11,
                              color: context.dmColors.textSecondary)),
                      const SizedBox(height: 16),
                      ForecastMetricChips(
                          weather: snapshot,
                          rainAvailable: observationFresh &&
                              !cached &&
                              (weather.current.precipitationChanceKnown ||
                                  weather.hourly.any((hour) =>
                                      hour.precipitationChanceKnown &&
                                      !hour.time.isBefore(now) &&
                                      hour.time.isBefore(now
                                          .add(const Duration(hours: 12)))))),
                      const SizedBox(height: 16),
                      ShortTermPrecipitationCard(
                          minutes: weather.minutePrecipitation,
                          now: now,
                          unavailable: !observationFresh || cached,
                          units: weather.current.units),
                      const SizedBox(height: 16),
                      ForecastExtraMetrics(weather: weather.current),
                      if (!_loading &&
                          !cached &&
                          observationFresh &&
                          relevantAlerts.isEmpty &&
                          _repository is! FakeWeatherRepository)
                        const AdSection(placement: AdPlacement.forecastBanner),
                      const SizedBox(height: 16),
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

  DisplayedRoastRegistry? _readMemeRegistry() {
    try {
      return context.read<DisplayedRoastRegistry>();
    } catch (_) {
      return null;
    }
  }

  DisplayedRoastSnapshot _memeSource(Roast roast, WeatherBundle weather) {
    var unit = TemperatureUnit.fahrenheit;
    try {
      unit = context.read<SettingsController>().temperatureUnit;
    } catch (_) {
      // Independent forecast widget tests do not require app-level settings.
    }
    return DisplayedRoastSnapshot(
      id: roast.id,
      text: roast.text,
      personaId: roast.personaId,
      mood: roast.resolvedMood,
      selection: roast.selection,
      sourceKey: 'forecast',
      sourceLabel: 'Home forecast',
      isSample: _repository is FakeWeatherRepository,
      weatherSnapshot: MemeWeather.freeze(
        weather,
        temperatureUnit: unit,
        isSample: _repository is FakeWeatherRepository,
        now: _now,
      ),
    );
  }

  static String _observationLabel(DateTime updated, DateTime now) {
    if (updated.millisecondsSinceEpoch <= 0) {
      return 'Observation time unavailable';
    }
    final age = now.difference(updated);
    if (age.isNegative) return 'Observation timestamp is ahead of device clock';
    if (age.inMinutes < 1) return 'Observed just now';
    if (age.inHours < 1) {
      return 'Observed ${age.inMinutes} min ago${age > const Duration(minutes: 30) ? ' · Stale' : ''}';
    }
    return 'Observed ${age.inHours} hours ago · Stale';
  }

  Roast _roastForWeather(
      WeatherBundle weather, WeatherSnapshot snapshot, String personaId) {
    final selection = _localRoasts.select(
        persona: personaId,
        bundle: weather,
        now: _now,
        unit: context.read<SettingsController?>()?.temperatureUnit ??
            TemperatureUnit.fahrenheit);
    return PackRoastRepository.fromSelection(selection,
        weatherSnapshotId: snapshot.id);
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

class ShortTermPrecipitationCard extends StatelessWidget {
  const ShortTermPrecipitationCard({
    super.key,
    required this.minutes,
    this.now,
    this.unavailable = false,
    this.units = 'imperial',
  });

  final List<MinutePrecipitation> minutes;
  final DateTime? now;
  final bool unavailable;
  final String units;

  @override
  Widget build(BuildContext context) {
    final reference = now ?? DateTime.now();
    final coverage =
        PrecipitationCoverage(minutes, reference, unavailable: unavailable);
    final hasPrecipitation = coverage.points.any((minute) => minute.isWet);
    final title = coverage.summary(reference);
    final visibleMinutes = coverage.points.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmSectionHeader(title: coverage.heading),
        const SizedBox(height: DMSpacing.sm),
        DmGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (hasPrecipitation)
                    const DaymakerWeatherIcon(
                      iconSlug: 'umbrella',
                      size: DMSpacing.iconMd,
                      semanticLabel: 'Precipitation',
                      color: DMColors.rainTeal,
                    )
                  else
                    Icon(
                      coverage.coversNextHour
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: coverage.coversNextHour
                          ? DMColors.mintGreen
                          : context.dmColors.textMuted,
                    ),
                  const SizedBox(width: DMSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: DMTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
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
                            child: _MinuteBar(minute: minute, units: units),
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
}

class _MinuteBar extends StatelessWidget {
  const _MinuteBar({required this.minute, required this.units});

  final MinutePrecipitation minute;
  final String units;

  @override
  Widget build(BuildContext context) {
    final amount = minute.precipitation.clamp(0, 0.25);
    final height = 8 + (amount / 0.25 * 58);
    final color =
        minute.isWet ? DMColors.rainTeal : context.dmColors.glassStrong;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message:
              '${_formatTime(minute.time)}: ${minute.precipitation.toStringAsFixed(2)} ${units == 'imperial' ? 'in/h' : 'mm/h'}',
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
            color: context.dmColors.textMuted,
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
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          // Separate expansion state from the enclosing forecast scroll offset.
          key: PageStorageKey<String>(
              'weather-alert:${alert.senderName}|${alert.event}|${alert.start}|${alert.end}|${alert.area}'),
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: DMColors.sunriseYellow,
          collapsedIconColor: context.dmColors.textMuted,
          leading: const Icon(
            Icons.warning_amber_rounded,
            color: DMColors.alertOrange,
          ),
          title: Text(
            alert.event,
            style: DMTypography.title,
          ),
          subtitle: Text(
            _subtitle(alert),
            style: DMTypography.bodySmall,
          ),
          children: [
            if (alert.area?.isNotEmpty == true)
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Area: ${alert.area}', style: DMTypography.body)),
            if (alert.instructions?.isNotEmpty == true)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: DMSpacing.sm),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child:
                          Text(alert.instructions!, style: DMTypography.body))),
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
    return '${time.month}/${time.day}/${time.year} $hour:$minute $suffix ${time.timeZoneName}';
  }
}

class _WeatherAttributionFooter extends StatelessWidget {
  const _WeatherAttributionFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('Weather data © OpenWeather',
          textAlign: TextAlign.center,
          style: DMTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w400,
              color: context.dmColors.textSecondary)),
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
