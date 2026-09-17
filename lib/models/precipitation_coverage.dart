import 'weather_models.dart';

/// Minute samples each cover one minute; a next-hour claim requires continuous
/// timestamp coverage from the present through the horizon, not 60 list entries.
class PrecipitationCoverage {
  PrecipitationCoverage(List<MinutePrecipitation> samples, DateTime now,
      {bool unavailable = false}) {
    if (unavailable) return;
    final horizon = now.add(const Duration(hours: 1));
    points = samples
        .where((point) =>
            point.hasValue &&
            point.time.add(const Duration(minutes: 1)).isAfter(now) &&
            point.time.isBefore(horizon))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (points.isEmpty) return;
    var coveredUntil = now;
    for (final point in points) {
      if (point.time.isAfter(coveredUntil)) break;
      final end = point.time.add(const Duration(minutes: 1));
      if (end.isAfter(coveredUntil)) coveredUntil = end;
    }
    coversNextHour = !coveredUntil.isBefore(horizon);
  }

  List<MinutePrecipitation> points = const [];
  bool coversNextHour = false;

  String get heading =>
      coversNextHour ? 'Next hour' : 'Short-term precipitation';

  String summary(DateTime now) {
    if (points.isEmpty) return 'Precipitation forecast unavailable';
    final wet = points.where((point) => point.isWet);
    if (wet.isNotEmpty) {
      final delay = wet.first.time.difference(now).inSeconds / 60;
      final timing = delay <= 0 ? 'now' : 'in ${delay.ceil()} min';
      return coversNextHour
          ? 'Precipitation expected $timing'
          : 'Partial forecast: precipitation expected $timing';
    }
    return coversNextHour
        ? 'No precipitation expected in the next hour'
        : 'Partial forecast: no precipitation in available minutes';
  }
}
