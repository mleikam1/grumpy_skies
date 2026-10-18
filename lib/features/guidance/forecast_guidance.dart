import 'package:flutter/material.dart';
import 'widgets/guidance_view.dart';
import '../../models/weather_models.dart';
import 'domain/guidance.dart';

GuidanceLocation forecastGuidanceLocation(WeatherBundle weather) =>
    GuidanceLocation(
      key: weather.current.latitude != null && weather.current.longitude != null
          ? 'point:${weather.current.latitude!.toStringAsFixed(5)},${weather.current.longitude!.toStringAsFixed(5)}'
          : 'forecast:${weather.current.locationName}:${weather.current.timezone}',
      label: weather.current.locationName,
      timezone: weather.current.timezone,
      latitude: weather.location?.lat ?? weather.current.latitude,
      longitude: weather.location?.lon ?? weather.current.longitude,
    );

class ForecastGuidanceView extends StatelessWidget {
  const ForecastGuidanceView(
      {super.key,
      required this.weather,
      required this.surface,
      this.hour,
      this.day,
      this.clock,
      this.fallback,
      this.compact = true});
  final WeatherBundle weather;
  final GuidanceSurface surface;
  final DateTime? hour, day;
  final DateTime Function()? clock;
  final Widget? fallback;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final location = forecastGuidanceLocation(weather);
    final evidence =
        GuidanceWeatherAdapter.fromBundle(weather, location: location);
    GuidanceInterval? window;
    if (hour != null) {
      window = GuidanceInterval(hour!, hour!.add(const Duration(hours: 1)));
    }
    if (day != null) {
      for (final period in evidence.daily) {
        final date = location.localTime(period.interval.start);
        if (date?.year == day!.year &&
            date?.month == day!.month &&
            date?.day == day!.day) {
          window = period.interval;
          break;
        }
      }
      if (window == null) return fallback ?? const SizedBox.shrink();
    }
    return GuidanceView(
        weather: evidence,
        context: GuidanceContext(
            surface: surface,
            location: location,
            window: window,
            allDay: day != null),
        clock: clock,
        fallback: fallback,
        compact: compact,
        scopeKey:
            'forecast:${day?.toIso8601String() ?? hour?.toIso8601String() ?? 'today'}');
  }
}
