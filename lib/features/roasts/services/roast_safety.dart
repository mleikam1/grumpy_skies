import '../../../models/weather_models.dart';
import '../../../models/weather_safety.dart';
import '../content/roast_selector.dart';
import '../content/weather_roast_models.dart';

/// Revalidates a frozen handoff against the current safety state. Does not
/// select another joke, fetch weather, or manufacture alert wording.
bool roastHumorBlocked(WeatherBundle? weather,
    {DateTime? now, RoastSelection? selection}) {
  final positive = selection?.requiresVerifiedAlerts == true ||
      (selection?.line.tags.any(
              {WeatherRoastTag.nice, WeatherRoastTag.weekendGood}.contains) ??
          false);
  if (weather == null) return positive;
  final context = WeatherRoastContext.fromWeatherBundle(weather,
      now: now ?? DateTime.now());
  return context.requiresSafetyMessage ||
      (positive && context.safetyStatus != WeatherSafetyStatus.clear);
}
