import '../../models/temperature_unit.dart';
import 'plancast_briefing.dart';
import 'plancast_day_summary.dart';
import 'plancast_models.dart';

class PlanCastReadout {
  const PlanCastReadout(
      {required this.text,
      required this.compactText,
      required this.fullText,
      required this.serious,
      required this.signature});
  final String text, compactText, fullText, signature;
  final bool serious;
}

/// Factual weather summaries use the existing resolved event snapshot only.
/// Composing text makes no requests and never writes private context to history.
class PlanCastReadoutComposer {
  const PlanCastReadoutComposer();
  PlanCastReadout compose(
      {required PlanCastDaySummary summary,
      required DateTime now,
      TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
      bool privateTitles = true}) {
    final signature = planCastId(
        '${summary.signature}|${temperatureUnit.name}|$privateTitles|readout-v2');
    final facts = _facts(summary);
    if (summary.hasSeriousWeather) {
      final alerts = summary.events
          .expand((e) => e.assessment.alerts)
          .map((a) => a.event)
          .toSet();
      final headline = alerts.isEmpty
          ? 'Weather disruption is possible during plans in this view.'
          : '${alerts.first} affects a plan in this view.';
      final text =
          '$headline Check official guidance and the affected event details before making plans.';
      return PlanCastReadout(
          text: text,
          compactText: alerts.isEmpty
              ? 'Weather disruption possible. Check event details and official guidance.'
              : '${alerts.first}. Check official guidance.',
          fullText: '$text ${_full(summary, now, privateTitles)}',
          serious: true,
          signature: signature);
    }
    final operational = {
      PlanCastDayState.loading,
      PlanCastDayState.disconnected,
      PlanCastDayState.noCalendars,
      PlanCastDayState.filteredEmpty
    }.contains(summary.state);
    if (operational) {
      return PlanCastReadout(
          text: facts,
          compactText: facts,
          fullText: facts,
          serious: false,
          signature: signature);
    }
    final text = facts;
    final compact = _compact(summary);
    return PlanCastReadout(
        text: text,
        compactText: compact,
        fullText: '$text ${_full(summary, now, privateTitles)}',
        serious: false,
        signature: signature);
  }

  static String _full(
      PlanCastDaySummary day, DateTime now, bool privateTitles) {
    if (day.events.isEmpty) return '';
    return const PlanCastBriefingComposer()
        .compose(
            today: day.events,
            tomorrow: const [],
            now: now,
            privateTitles: privateTitles)
        .text;
  }

  static List<PlanCastEventWeather> _available(PlanCastDaySummary s) =>
      s.events.where((e) => !e.isOnline && e.assessment.usable).toList();
  static bool _rain(PlanCastEventWeather e) =>
      (e.assessment.peakPrecipitationChance ?? 0) >= 40 ||
      RegExp(r'rain|shower|drizzle|snow|sleet', caseSensitive: false)
          .hasMatch(e.assessment.condition);
  static String _plans(int count) => '$count ${count == 1 ? 'plan' : 'plans'}';
  static String _place(PlanCastEventWeather item) {
    final resolved = item.resolvedLocation;
    // Calendar venue names can reveal health or other sensitive appointment
    // details. Only broad city/area metadata is allowed in primary readouts.
    if (resolved == null ||
        !{LocationPrecision.city, LocationPrecision.area}
            .contains(resolved.precision)) {
      return '';
    }
    final name = resolved.candidate?.name.trim() ?? '';
    return name.isEmpty || name == 'Your area' ? '' : name;
  }

  static String _where(List<PlanCastEventWeather> events) {
    final labels = events.map(_place).toList();
    final hasAssumedArea =
        events.any((e) => e.resolvedLocation?.areaAssumed == true);
    if (labels.any((name) => name.isEmpty)) {
      return hasAssumedArea ? ' (using an assumed area)' : '';
    }
    final names = labels.toSet();
    final assumed = hasAssumedArea ? ' (assumed area)' : '';
    if (names.length == 1) return ' around ${names.first}$assumed';
    if (names.length == 2) return ' around ${names.join(' and ')}$assumed';
    return names.isEmpty ? '' : ' across ${names.length} areas$assumed';
  }

  static String _facts(PlanCastDaySummary s) {
    switch (s.state) {
      case PlanCastDayState.loading:
        return 'Loading your selected calendars and event forecasts.';
      case PlanCastDayState.disconnected:
        return 'Connect calendars to see weather alongside your plans.';
      case PlanCastDayState.noCalendars:
        return 'Choose calendars to build your PlanCast.';
      case PlanCastDayState.filteredEmpty:
        return 'No plans match this calendar filter. Your imported calendars are unchanged.';
      case PlanCastDayState.completed:
        return 'The ${_plans(s.completedCount)} in this view ${s.completedCount == 1 ? 'has' : 'have'} finished; the rest of the day is unscheduled.';
      case PlanCastDayState.empty:
        return 'No plans in this day’s calendar view, and no event weather to check.';
      case PlanCastDayState.ready:
        break;
    }
    final physical = s.events.where((e) => !e.isOnline).toList();
    if (physical.isEmpty) {
      return 'All ${_plans(s.planCount)} in this view are online, so venue weather is unnecessary.';
    }
    final available = _available(s);
    if (available.isEmpty) {
      if (s.loadingCount > 0) {
        return 'Your ${_plans(s.planCount)} are here; event weather is still loading.';
      }
      return 'Your ${_plans(s.planCount)} are here, but useful event forecasts are not available yet.';
    }
    final wet = available.where(_rain).toList();
    final broad = available.any((e) => e.assessment.isDaily);
    if (wet.isNotEmpty) {
      return '${_plans(wet.length)}${_where(wet)} ${wet.length == 1 ? 'has' : 'have'} ${_precipitation(wet).toLowerCase()} in ${broad ? 'the day outlook' : 'the available event forecast'}${available.length < physical.length ? '; other coverage is incomplete' : ''}.';
    }
    final extreme = _temperatureConcern(available);
    if (extreme != null) {
      return '${extreme.$1} appears in ${_plans(extreme.$2.length)}${_where(extreme.$2)}; check the event forecast before heading out.';
    }
    final windy = available.where(_windy).toList();
    if (windy.isNotEmpty) {
      return 'Wind may affect ${_plans(windy.length)}${_where(windy)}; check the event windows before heading out.';
    }
    final dry = available.length == physical.length &&
        available.every((e) =>
            e.assessment.coverage == ForecastCoverage.hourly &&
            e.assessment.peakPrecipitationChance != null &&
            e.assessment.peakPrecipitationChance! < 20 &&
            RegExp(r'clear|sun|cloud', caseSensitive: false)
                .hasMatch(e.assessment.condition));
    if (dry) {
      return 'Rain chances stay low during ${physical.length == 1 ? 'the plan' : 'all ${physical.length} physical plans'}${_where(physical)} in this view.';
    }
    return '${_plans(available.length)} ${available.length == 1 ? 'has' : 'have'} ${broad ? 'a broad day outlook' : 'usable event weather'}${available.length < physical.length ? '; other forecasts are incomplete' : ', with conditions shown for each location'}.';
  }

  static String _compact(PlanCastDaySummary s) {
    if (s.state == PlanCastDayState.empty) {
      return 'No plans in view.';
    }
    if (s.state == PlanCastDayState.completed) {
      return 'Plans finished.';
    }
    if (s.onlineCount == s.planCount) {
      return '${_plans(s.planCount)}, all online.';
    }
    final available = _available(s);
    final wet = available.where(_rain).toList();
    if (wet.isNotEmpty) {
      return '${_precipitation(wet)} possible${_where(wet)}${wet.any((e) => e.assessment.isDaily) ? ' · day outlook' : ''}.';
    }
    if (available.isEmpty) {
      return '${_plans(s.planCount)}; event weather ${s.loadingCount > 0 ? 'loading' : 'unavailable'}.';
    }
    final extreme = _temperatureConcern(available);
    if (extreme != null) {
      return '${extreme.$1} for ${_plans(extreme.$2.length)}${_where(extreme.$2)}.';
    }
    final windy = available.where(_windy).toList();
    if (windy.isNotEmpty) {
      return 'Wind for ${_plans(windy.length)}${_where(windy)}.';
    }
    final daily = available.any((e) => e.assessment.isDaily);
    return '${_plans(s.planCount)}, ${available.length} with ${daily ? 'day outlooks' : 'weather'}.';
  }

  static bool _windy(PlanCastEventWeather item) =>
      (item.assessment.maxWindKph ?? 0) >= 30 ||
      (item.assessment.maxGustKph ?? 0) >= 45;

  static (String, List<PlanCastEventWeather>)? _temperatureConcern(
      List<PlanCastEventWeather> available) {
    final hot = available
        .where((item) =>
            item.assessment.maxTemperatureC?.isFinite == true &&
            item.assessment.maxTemperatureC! >= 32)
        .toList();
    final cold = available
        .where((item) =>
            item.assessment.minTemperatureC?.isFinite == true &&
            item.assessment.minTemperatureC! <= 0)
        .toList();
    if (hot.isNotEmpty && cold.isNotEmpty) {
      return ('Heat and cold', {...hot, ...cold}.toList());
    }
    if (hot.isNotEmpty) return ('Heat', hot);
    if (cold.isNotEmpty) return ('Freezing temperatures', cold);
    return null;
  }

  static String _precipitation(List<PlanCastEventWeather> items) {
    final conditions =
        items.map((e) => e.assessment.condition.toLowerCase()).join(' ');
    if (RegExp(r'snow|sleet').hasMatch(conditions)) return 'Rain or snow';
    if (RegExp(r'rain|shower|drizzle').hasMatch(conditions)) return 'Rain';
    return 'Precipitation';
  }
}
