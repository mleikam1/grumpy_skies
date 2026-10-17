import '../../models/temperature_unit.dart';
import '../../models/weather_safety.dart';
import '../roasts/content/roast_selector.dart';
import '../roasts/content/weather_roast_models.dart';
import '../roasts/models/roast_persona.dart';
import 'plancast_briefing.dart';
import 'plancast_day_summary.dart';
import 'plancast_models.dart';

export '../roasts/models/roast_mood.dart';

class PlanCastReadout {
  const PlanCastReadout(
      {required this.personaId,
      required this.text,
      required this.compactText,
      required this.fullText,
      required this.mood,
      required this.serious,
      required this.signature});
  final String personaId, text, compactText, fullText, signature;
  final RoastMood mood;
  final bool serious;
}

/// Factual aggregate first; a local, mild persona reaction second. Selection uses
/// the existing template selector, but never writes private context to history.
class PlanCastReadoutComposer {
  const PlanCastReadoutComposer();
  PlanCastReadout compose(
      {required PlanCastDaySummary summary,
      required String personaId,
      required DateTime now,
      TemperatureUnit temperatureUnit = TemperatureUnit.fahrenheit,
      bool privateTitles = true}) {
    final persona = RoastPersonas.normalizeId(personaId);
    final signature = planCastId(
        '${summary.signature}|$persona|${temperatureUnit.name}|$privateTitles|readout-v1');
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
          personaId: persona,
          text: text,
          compactText: alerts.isEmpty
              ? 'Weather disruption possible. Check event details and official guidance.'
              : '${alerts.first}. Check official guidance.',
          fullText: '$text ${_full(summary, now, privateTitles)}',
          mood: RoastMood.worried,
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
          personaId: persona,
          text: facts,
          compactText: facts,
          fullText: facts,
          mood: RoastMood.neutral,
          serious: false,
          signature: signature);
    }
    final mood = summary.events.any((e) => e.assessment.materiallyAffected)
        ? RoastMood.complaining
        : summary.state == PlanCastDayState.empty ||
                summary.state == PlanCastDayState.completed
            ? RoastMood.cozy
            : RoastMood.confident;
    final lines = _reactions[persona] ?? _reactions['karen']!;
    // Seven weekday slots guarantee that an otherwise empty seven-day view does
    // not repeat one line seven times. Facts and cache identity still cover every
    // event revision, location, forecast, unit, and feed filter in the snapshot.
    final line = RoastLine(
        id: 'plancast-$persona-${summary.day.weekday}',
        persona: persona,
        type: RoastType.today,
        tags: const [WeatherRoastTag.fallback],
        dayparts: const [Daypart.any],
        level: RoastLevel.mild,
        weight: 1,
        text: lines[summary.day.weekday - 1],
        mood: mood);
    final selection = const RoastSelector().select(
        pack: RoastPack(
            schemaVersion: 1,
            packVersion: 'plancast-local-v1',
            generatedAt: DateTime.utc(2026),
            personas: [persona],
            roasts: [line]),
        context: WeatherRoastContext(
            city: 'your plans',
            placeId: summary.signature,
            localTime: summary.day,
            evaluatedAt: now,
            scope: RoastScope.today,
            temperatureUnit: temperatureUnit,
            freshness: WeatherFreshness.unavailable,
            windowStart: summary.day,
            windowEnd: DateTime(
                summary.day.year, summary.day.month, summary.day.day + 1)),
        persona: persona,
        type: RoastType.today,
        maxLevel: RoastLevel.mild,
        seed: signature);
    final text = '$facts ${selection.renderedText}';
    final compact = _compact(summary, persona);
    return PlanCastReadout(
        personaId: persona,
        text: text,
        compactText: compact,
        fullText: '$text ${_full(summary, now, privateTitles)}',
        mood: selection.mood,
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
    if (labels.any((name) => name.isEmpty)) return '';
    final names = labels.toSet();
    if (names.length == 1) return ' around ${names.first}';
    if (names.length == 2) return ' around ${names.join(' and ')}';
    return names.isEmpty ? '' : ' across ${names.length} areas';
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

  static String _compact(PlanCastDaySummary s, String persona) {
    final reaction = (_compactReactions[persona] ??
        _compactReactions['karen']!)[s.day.weekday - 1];
    if (s.state == PlanCastDayState.empty) {
      return 'No plans in view. $reaction';
    }
    if (s.state == PlanCastDayState.completed) {
      return 'Plans finished. $reaction';
    }
    if (s.onlineCount == s.planCount) {
      return '${_plans(s.planCount)}, all online. $reaction';
    }
    final available = _available(s);
    final wet = available.where(_rain).toList();
    if (wet.isNotEmpty) {
      return '${_precipitation(wet)} possible${_where(wet)}. $reaction';
    }
    if (available.isEmpty) {
      return '${_plans(s.planCount)}; event weather ${s.loadingCount > 0 ? 'loading' : 'unavailable'}. $reaction';
    }
    final extreme = _temperatureConcern(available);
    if (extreme != null) {
      return '${extreme.$1} for ${_plans(extreme.$2.length)}${_where(extreme.$2)}. $reaction';
    }
    final windy = available.where(_windy).toList();
    if (windy.isNotEmpty) {
      return 'Wind for ${_plans(windy.length)}${_where(windy)}. $reaction';
    }
    final daily = available.any((e) => e.assessment.isDaily);
    return '${_plans(s.planCount)}, ${available.length} with ${daily ? 'day outlooks' : 'weather'}. $reaction';
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

  static const _compactReactions = <String, List<String>>{
    'karen': [
      'Naturally, I have notes.',
      'Consider management informed.',
      'I expect punctual clouds.',
      'My clipboard is ready.',
      'I have scheduling feedback.',
      'The atmosphere is on notice.',
      'Preparation is my love language.'
    ],
    'frat_bro': [
      'Preparation is a power move.',
      'The group chat is briefed.',
      'Big calendar energy, bro.',
      'The itinerary has entered chat.',
      'Planning deserves a fist bump.',
      'We brought the game plan.',
      'Organized is the new hype.'
    ],
    'two_year_old': [
      'I brought my tiny clipboard.',
      'This plan needs stickers.',
      'I demand a snack break.',
      'My serious face is ready.',
      'The sky forgot its manners.',
      'Gold star for checking first.',
      'I am the tiny supervisor.'
    ],
    'politician': [
      'My office is monitoring this.',
      'The committee has been briefed.',
      'Preparation has bipartisan support.',
      'We endorse checking the details.',
      'Consultations with clouds continue.',
      'The itinerary has conditional support.',
      'This concludes the planning statement.'
    ],
    'grandpa': [
      'Always worth checking first.',
      'A little planning goes far.',
      'My old notebook approves.',
      'Leave room for common sense.',
      'Check twice, leave once.',
      'That is my two cents.',
      'Preparation never goes out of style.'
    ],
  };

  static const _reactions = <String, List<String>>{
    'karen': [
      'Finally, a calendar that leaves room for my opinions.',
      'I will be forwarding my notes to the scheduling department.',
      'The sky has apparently invited itself to the planning meeting.',
      'I expect the forecast to respect the itinerary.',
      'Consider this my extremely polite weather-related feedback.',
      'Naturally, I have already requested to speak with the atmosphere.',
      'A little preparation saves a lot of strongly worded emails.',
    ],
    'frat_bro': [
      'The calendar has a game plan; I brought the commentary.',
      'Bro, checking the details is an underrated power move.',
      'We are putting actual preparation on the guest list.',
      'Consider the schedule briefed and the group chat informed.',
      'Big planning energy, minimal unnecessary surprises.',
      'The itinerary has entered its organized era, bro.',
      'A little preparation is the real main character move.',
    ],
    'two_year_old': [
      'I made a plan for the plan. It needs stickers.',
      'The calendar has boxes and I have very big opinions.',
      'I checked the sky. It did not say please.',
      'My important planning meeting includes a snack break.',
      'I am supervising the schedule with my serious face.',
      'The grown-ups made plans. I brought my tiny clipboard.',
      'I would like a gold star for checking first.',
    ],
    'politician': [
      'My office remains firmly committed to reading the itinerary.',
      'We are forming a committee to monitor these developments.',
      'This administration supports a comprehensive checking-before-leaving policy.',
      'I promise transparent forecasts and strategically timed umbrella decisions.',
      'The schedule has my conditional and extensively footnoted support.',
      'We will continue consulting the relevant atmospheric stakeholders.',
      'Preparation remains the cornerstone of our calendar platform.',
    ],
    'grandpa': [
      'A little checking now beats a long story later.',
      'We used to call this looking before we left.',
      'The calendar may be fancy, but preparation is still preparation.',
      'Keep a little room in the plan for common sense.',
      'My old notebook never had this much weather commentary.',
      'A good plan leaves room for a second look.',
      'That is my two cents, adjusted for atmospheric inflation.',
    ],
  };
}
