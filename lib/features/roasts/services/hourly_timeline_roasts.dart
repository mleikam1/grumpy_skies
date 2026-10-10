import '../../../models/weather_models.dart';
import '../content/roast_selector.dart';
import 'local_roast_engine.dart';

class HourlyTimelineRoast {
  const HourlyTimelineRoast({required this.hour, required this.selection});
  final HourlyForecast hour;
  final RoastSelection selection;
  DateTime get targetTime => hour.time;
  DateTime get targetEnd => hour.time.add(const Duration(hours: 1));
}

typedef HourlyRoastSelector = RoastSelection? Function(
    HourlyForecast hour, Set<String> reservedIds, Set<String> reservedTexts);

/// Placement depends on absolute forecast timestamps, not row/date-header
/// indexes. This function has no clock, storage, network or impression effects.
List<HourlyTimelineRoast> scheduleHourlyTimelineRoasts({
  required List<HourlyForecast> hours,
  required HourlyRoastSelector select,
  List<HourlyTimelineRoast> retained = const [],
}) {
  if (hours.isEmpty) return const [];
  final sorted = hours.toList()..sort((a, b) => a.time.compareTo(b.time));
  final unique = <int, HourlyForecast>{};
  for (final hour in sorted) {
    unique.putIfAbsent(hour.time.millisecondsSinceEpoch, () => hour);
  }
  final records = unique.values.toList();
  // Revalidated targets survive a sliding forecast window. Reserve all their
  // content before filling gaps, including cards farther down the timeline.
  final result = retained.toList()
    ..sort((a, b) => a.targetTime.compareTo(b.targetTime));
  final fixedTargets = result.toList(growable: false);
  final ids = result.map((entry) => entry.selection.id).toSet();
  final texts = result
      .map((entry) => normalizeRoastText(entry.selection.renderedText))
      .toSet();
  var desired = records.first.time.add(const Duration(hours: 2));
  var earliest = records.first.time.add(const Duration(hours: 1));
  while (!earliest.isAfter(records.last.time)) {
    final nextRetained = fixedTargets
        .where((entry) => !entry.targetTime.isBefore(earliest))
        .firstOrNull;
    if (nextRetained != null &&
        !nextRetained.targetTime
            .isAfter(desired.add(const Duration(hours: 1)))) {
      earliest = nextRetained.targetTime.add(const Duration(hours: 3));
      desired = nextRetained.targetTime.add(const Duration(hours: 4));
      continue;
    }
    final nearby = records
        .where((hour) =>
            !hour.time.isBefore(earliest) &&
            !hour.time.isAfter(desired.add(const Duration(hours: 1))))
        .toList();
    if (nearby.isEmpty) {
      final next = records.where((h) => !h.time.isBefore(earliest)).firstOrNull;
      if (next == null) break;
      // Missing hours never manufacture a row or shorten elapsed spacing.
      if (next.time.isAfter(desired.add(const Duration(hours: 1)))) {
        desired = next.time;
        continue;
      }
    }
    double priority(HourlyForecast hour) {
      final index = records.indexOf(hour);
      final previous = index > 0 ? records[index - 1] : null;
      final adjacent = previous != null &&
          hour.time.difference(previous.time) <= const Duration(hours: 2);
      final weatherChange = adjacent &&
          previous.weatherId != null &&
          hour.weatherId != null &&
          _conditionGroup(previous.weatherId!) !=
              _conditionGroup(hour.weatherId!);
      final temperatureChange = adjacent &&
          previous.temperatureKnown &&
          hour.temperatureKnown &&
          previous.temperatureC.isFinite &&
          hour.temperatureC.isFinite &&
          (hour.temperatureC - previous.temperatureC).abs() >= 2;
      return (weatherChange || temperatureChange ? 1.5 : 0) -
          hour.time.difference(desired).inMinutes.abs() / 60;
    }

    nearby.sort((a, b) {
      final rank = priority(b).compareTo(priority(a));
      return rank == 0 ? a.time.compareTo(b.time) : rank;
    });
    HourlyTimelineRoast? chosen;
    for (final hour in nearby) {
      if (!_canInsert(hour.time, result)) continue;
      final selection =
          select(hour, Set.unmodifiable(ids), Set.unmodifiable(texts));
      if (selection == null ||
          selection.line.isFallback ||
          selection.line.isSevere ||
          selection.source == 'application') {
        continue;
      }
      final text = normalizeRoastText(selection.renderedText);
      if (ids.contains(selection.id) || texts.contains(text)) continue;
      chosen = HourlyTimelineRoast(hour: hour, selection: selection);
      ids.add(selection.id);
      texts.add(text);
      result.add(chosen);
      break;
    }
    if (chosen != null) {
      earliest = chosen.targetTime.add(const Duration(hours: 3));
      desired = chosen.targetTime.add(const Duration(hours: 4));
    } else {
      // An unsuitable slot is genuinely skipped; do not fill it with generic
      // fallback copy or force another=true to manufacture variety.
      earliest = desired.add(const Duration(hours: 2));
      desired = desired.add(const Duration(hours: 4));
    }
  }
  result.sort((a, b) => a.targetTime.compareTo(b.targetTime));
  return List.unmodifiable(result);
}

bool _canInsert(DateTime target, List<HourlyTimelineRoast> entries) {
  if (entries.any((entry) =>
      target.difference(entry.targetTime).abs() < const Duration(hours: 3))) {
    return false;
  }
  final instants = [...entries.map((e) => e.targetTime), target]..sort();
  // Retained cards can be before OR after a new candidate, so check every
  // forward rolling window rather than counting only earlier cards.
  return instants.every((start) =>
      instants
          .where((time) =>
              !time.isBefore(start) &&
              time.difference(start) < const Duration(hours: 24))
          .length <=
      6);
}

int _conditionGroup(int code) =>
    code >= 800 && code <= 804 ? (code <= 801 ? code : 802) : code ~/ 100;
