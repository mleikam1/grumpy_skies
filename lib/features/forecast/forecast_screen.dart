import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/daymaker_sample_data.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../models/weather_models.dart';
import '../../repositories/weather_repository.dart';
import '../../shared/widgets/daymaker_components.dart';
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
  static const _latitude = 37.7749;
  static const _longitude = -122.4194;
  static const _sampleUpdatedOffset = Duration(minutes: 10);

  WeatherRepository? _repository;
  WeatherBundle? _weather;
  DateTime? _relativeNow;
  Object? _error;
  var _loading = true;
  var _roastIndex = 0;
  var _loadedRepository = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedRepository) return;

    _repository = widget.weatherRepository ?? context.read<WeatherRepository>();
    _loadedRepository = true;
    _loadWeather();
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

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final weather = await _repository!.getWeather(
        latitude: _latitude,
        longitude: _longitude,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        _weather = weather;
        _relativeNow = weather.current.lastUpdated.add(_sampleUpdatedOffset);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showNotificationsMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Forecast notifications are on.')),
      );
  }

  void _showNextRoast() {
    final history = DayMakerSampleData.roastHistory;
    if (history.isEmpty) return;

    // TODO(haptics): Use light selection feedback when cycling roasts.
    setState(() {
      _roastIndex = (_roastIndex + 1) % history.length;
    });
  }

  Future<void> _shareRoast() async {
    final roast = DayMakerSampleData.roastHistory[_roastIndex];
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
        message: 'Pull to refresh or try again in a moment.',
        actionLabel: 'Retry',
        onAction: () => _loadWeather(forceRefresh: true),
      );
    }

    final weather = _weather!;
    final snapshot = weather.snapshot ?? DayMakerSampleData.weatherSnapshot;
    final now = _relativeNow ?? weather.current.lastUpdated;
    final roast = DayMakerSampleData.roastHistory[_roastIndex];
    final location = _cityName(weather.current.locationName);

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
                      ),
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
                      _ForecastLowerSection(
                        weather: weather,
                        gap: gap,
                        expanded: breakpoint.isExpanded,
                      ),
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
    if (trimmed.isEmpty) return 'San Francisco';
    return trimmed.split(',').first.trim();
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
        ForecastHourlyStrip(hourly: weather.hourly),
        SizedBox(height: gap),
        ForecastDailyGrid(daily: weather.daily),
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
    return CustomPaint(painter: _ForecastBackdropPainter());
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
