import 'dart:math' as math;

import 'guidance_catalog.dart';
import 'guidance_evidence.dart';
import 'guidance_result.dart';

/// Deterministic, side-effect-free eligibility and ranking. Persistence and
/// visible-impression recording belong to the application controller.
class GuidanceEngine {
  const GuidanceEngine({this.policy = const GuidancePolicy()});
  final GuidancePolicy policy;

  List<GuidanceCandidate> evaluate(
      {required WeatherEvidence weather,
      required GuidanceContext context,
      required DateTime now,
      required GuidanceCatalog catalog}) {
    if (!weather.locationMatched ||
        weather.location.key != context.location.key ||
        !context.location.validAt(now) ||
        context.unsupported ||
        context.permissionDenied) {
      return const [];
    }
    final evaluation = _Evaluation(weather, context, now, policy);
    if (!evaluation.target.isValid || !evaluation.target.end.isAfter(now)) {
      return const [];
    }
    // Official alert content stays in code and retains the original detail record.
    final alerts = weather.alerts
        .where((alert) =>
            alert.location.key == context.location.key &&
            alert.interval.overlaps(evaluation.target) &&
            alert.interval.end.isAfter(now))
        .toList()
      ..sort((a, b) {
        final priority = _alertPriority(b).compareTo(_alertPriority(a));
        return priority == 0 ? a.id.compareTo(b.id) : priority;
      });
    if (alerts.isNotEmpty) {
      final alert = alerts.first;
      final checked = alert.checkedAt;
      if (checked == null ||
          checked.isAfter(now) ||
          !now.isBefore(checked.add(policy.alertMaxAge))) {
        return const [];
      }
      final end = _earlier(alert.interval.end, checked.add(policy.alertMaxAge));
      return [
        GuidanceCandidate(
            ruleId: 'official_alert',
            familyId: 'official_alert',
            templateId: 'official_alert_fixed',
            text:
                'Review the official ${alert.event} details and instructions.',
            semanticDedupeKey: 'official_alert:${alert.id}',
            situationFingerprint: guidanceFingerprint(
                '${context.location.key}|${alert.id}|${alert.interval.signature}|${alert.instructions}'),
            activity: context.activity,
            location: context.location,
            supportedFacts: const [],
            validFrom: now,
            validUntil: end,
            priority: 1000,
            serious: true,
            alert: alert,
            reason:
                '${alert.issuer}; ${alert.area ?? context.location.label}; ${alert.interval.signature}')
      ];
    }
    final hazard = evaluation.hazardFacts;
    final freezingOnly = evaluation.freezingOnly;
    if (hazard.isNotEmpty && !freezingOnly) {
      final end = evaluation.expiry(hazard);
      if (!end.isAfter(now)) return const [];
      return [
        GuidanceCandidate(
            ruleId: 'serious_weather',
            familyId: 'serious_weather',
            templateId: 'serious_weather_fixed',
            text: evaluation.hazardText,
            semanticDedupeKey: 'serious_weather',
            situationFingerprint:
                evaluation.fingerprint('serious_weather', hazard),
            activity: context.activity,
            location: context.location,
            supportedFacts: hazard,
            validFrom: now,
            validUntil: end,
            priority: 900,
            serious: true,
            reason:
                'Applicable adverse conditions in the displayed location and interval; official alerts remain separate.')
      ];
    }
    final candidates = <GuidanceCandidate>[];
    for (final family in catalog.families) {
      if (freezingOnly &&
          !const {'freezing_precip_outing', 'commute_freezing_precip'}
              .contains(family.id)) {
        continue;
      }
      if (!family.surfaces.contains(context.surface.catalogId) ||
          !evaluation.activityMatches(family.activity)) {
        continue;
      }
      final guards = evaluation.guardsFor(family.id);
      if (!family.requiredEvidence
              .every((key) => guards[key]?.passed == true) ||
          family.excludedWhen.any((key) => guards[key]?.passed == true)) {
        continue;
      }
      for (final template in catalog.templates
          .where((template) => template.familyId == family.id)) {
        if (!template.requiredGuards
            .every((key) => guards[key]?.passed == true)) {
          continue;
        }
        final facts = <EvidenceField<Object>>[];
        for (final key in {
          ...family.requiredEvidence,
          ...template.requiredGuards
        }) {
          for (final field in guards[key]?.facts ?? <EvidenceField<Object>>[]) {
            if (!facts.any((old) => old.signature == field.signature)) {
              facts.add(field);
            }
          }
        }
        final until = facts.isEmpty
            ? _earlier(
                now.add(const Duration(minutes: 5)), evaluation.target.end)
            : evaluation.expiry(facts);
        if (!until.isAfter(now)) continue;
        final specificActivity =
            family.activity != 'outdoor' && family.activity != 'any';
        final candidateActivity =
            specificActivity ? context.activity : GuidanceActivity.outdoor;
        final activityPriority = switch (candidateActivity) {
          GuidanceActivity.outdoorEvent ||
          GuidanceActivity.drivingCommute =>
            300,
          GuidanceActivity.dogWalking ||
          GuidanceActivity.cycling ||
          GuidanceActivity.walking =>
            200,
          GuidanceActivity.outdoor => 100,
        };
        final priority = activityPriority +
            (family.priorityBand == 'adverse_condition'
                ? 60
                : family.priorityBand == 'activity_impact'
                    ? 30
                    : 0) +
            (family.id == 'rain_current' ? 25 : 0) +
            (family.id.contains('lower_rain_window') ? 20 : 0);
        candidates.add(GuidanceCandidate(
            ruleId: family.id,
            familyId: family.id,
            templateId: template.id,
            text: template.text,
            semanticDedupeKey: family.semanticDedupeKey,
            situationFingerprint: evaluation.fingerprint(family.id, facts),
            activity: candidateActivity,
            location: context.location,
            supportedFacts: facts,
            validFrom: now,
            validUntil: until,
            priority: freezingOnly ? 900 : priority,
            serious: freezingOnly,
            comparisonWindow: evaluation.windowFor(family.id),
            reliability:
                facts.where((f) => f.kind == EvidenceKind.observation).length,
            specificity: facts.length,
            reason: _reason(family.id, context)));
      }
    }
    candidates.sort((a, b) {
      var order = b.priority.compareTo(a.priority);
      if (order == 0) order = b.reliability.compareTo(a.reliability);
      if (order == 0) order = b.specificity.compareTo(a.specificity);
      if (order == 0) order = a.familyId.compareTo(b.familyId);
      if (order == 0) {
        order = guidanceFingerprint('${a.situationFingerprint}|${a.templateId}')
            .compareTo(guidanceFingerprint(
                '${b.situationFingerprint}|${b.templateId}'));
      }
      return order;
    });
    return List.unmodifiable(candidates);
  }
}

class _Guard {
  const _Guard(this.passed, [this.facts = const []]);
  final bool passed;
  final List<EvidenceField<Object>> facts;
}

class _Window {
  _Window(this.interval, this.periods, this.probabilities, this.score,
      this.comfortPenalty);
  final GuidanceInterval interval;
  final List<WeatherEvidencePeriod> periods;
  final List<EvidenceField<Object>> probabilities;
  // Internal worst-hour comparison score; never an outing probability.
  final double score;
  final double comfortPenalty;
}

class _Evaluation {
  _Evaluation(this.weather, this.context, this.now, this.policy) {
    target = context.window ??
        GuidanceInterval(now, now.add(context.outingDuration));
    dailyMode = context.allDay || context.surface == GuidanceSurface.dayDetail;
    final source = dailyMode ? weather.daily : weather.hourly;
    periods = source.where((p) => p.interval.overlaps(target)).toList()
      ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
    coverage = _covers(periods, target) &&
        (!dailyMode ||
            (periods.isNotEmpty &&
                periods.first.interval.start.isAtSameMomentAs(target.start) &&
                periods.last.interval.end.isAtSameMomentAs(target.end)));
    fields = [
      if (coverage)
        for (final period in periods)
          ...period.fields.where((f) => usable(f, target)),
      if (currentContext && weather.current != null)
        ...weather.current!.fields.where((f) => usable(f, target)),
    ];
    comparison = _comparison();
    laterRain = _laterRain(evening: false);
    eveningRain = _laterRain(evening: true);
  }
  final WeatherEvidence weather;
  final GuidanceContext context;
  final DateTime now;
  final GuidancePolicy policy;
  late final GuidanceInterval target;
  late final bool dailyMode, coverage;
  late final List<WeatherEvidencePeriod> periods;
  late final List<EvidenceField<Object>> fields;
  late final (_Window, _Window)? comparison;
  late final WeatherEvidencePeriod? laterRain, eveningRain;
  bool get currentContext =>
      !dailyMode &&
      target.contains(now) &&
      (context.surface == GuidanceSurface.todaySummary ||
          context.surface == GuidanceSurface.currentDetail);
  bool usable(EvidenceField<Object>? field, GuidanceInterval interval) =>
      policy.usable(field, now, context.location, interval);
  List<EvidenceField<Object>> values(GuidanceField key) =>
      fields.where((f) => f.field == key).toList();
  List<EvidenceField<Object>> numbers(
          GuidanceField key, bool Function(double) test) =>
      values(key)
          .where((f) => f.value is num && test((f.value as num).toDouble()))
          .toList();
  List<EvidenceField<Object>> equals(GuidanceField key, Object value) =>
      values(key).where((f) => f.value == value).toList();
  List<EvidenceField<Object>> get types =>
      equals(GuidanceField.precipitationType, PrecipitationType.liquidRain);
  List<EvidenceField<Object>> get currentRain => fields
      .where((f) =>
          f.kind == EvidenceKind.observation &&
          f.field == GuidanceField.precipitationType &&
          f.value == PrecipitationType.liquidRain)
      .toList();

  bool activityMatches(String activity) => switch (activity) {
        'any' => true,
        'outdoor' => context.activity != GuidanceActivity.outdoorEvent &&
            context.activity != GuidanceActivity.drivingCommute,
        'dog_walking' => context.activity == GuidanceActivity.dogWalking,
        'cycling' => context.activity == GuidanceActivity.cycling,
        'walking' => context.activity == GuidanceActivity.walking,
        'driving_commute' =>
          context.activity == GuidanceActivity.drivingCommute &&
              (context.knownActivity || context.userSelectedWindow) &&
              context.window != null,
        'outdoor_event' => context.activity == GuidanceActivity.outdoorEvent &&
            context.knownActivity &&
            context.window != null,
        _ => false,
      };

  List<EvidenceField<Object>> _hazards(Iterable<EvidenceField<Object>> input) =>
      input.where((f) {
        if (f.field == GuidanceField.severeHazard && f.value == true) {
          return true;
        }
        if (f.field == GuidanceField.precipitationType &&
            f.value == PrecipitationType.freezing) {
          return true;
        }
        if (f.value is! num) return false;
        final value = (f.value as num).toDouble();
        return switch (f.field) {
          GuidanceField.temperatureC ||
          GuidanceField.feelsLikeC =>
            value >= policy.dangerousHeatC || value <= policy.dangerousColdC,
          GuidanceField.windKph ||
          GuidanceField.gustKph =>
            value >= policy.dangerousWindKph,
          GuidanceField.aqi => _aqiSevere(f),
          _ => false,
        };
      }).toList();
  List<EvidenceField<Object>> get hazardFacts => _hazards(fields);
  bool get freezingOnly =>
      hazardFacts.isNotEmpty &&
      hazardFacts.any((f) =>
          f.kind == EvidenceKind.forecast &&
          f.field == GuidanceField.precipitationType &&
          f.value == PrecipitationType.freezing) &&
      hazardFacts.every((f) =>
          f.field == GuidanceField.precipitationType ||
          f.field == GuidanceField.severeHazard) &&
      !values(GuidanceField.conditionCode).any((f) =>
          f.value is int &&
          ((f.value as int) >= 200 && (f.value as int) < 300 ||
              const {711, 762, 771, 781}.contains(f.value)));
  String get hazardText {
    if (hazardFacts.any((f) =>
        f.field == GuidanceField.precipitationType &&
        f.value == PrecipitationType.freezing)) {
      return context.activity == GuidanceActivity.drivingCommute
          ? 'Freezing precipitation is forecast around this commute window. Check official conditions before driving.'
          : 'Freezing precipitation is indicated for this period. Consider changing outdoor plans and check official conditions.';
    }
    if (hazardFacts.any((f) => f.field == GuidanceField.aqi)) {
      return 'Air quality is very poor in this area. Check the source guidance before outdoor activity.';
    }
    return 'Adverse weather is indicated for this period. Review the forecast and official alerts before outdoor activity.';
  }

  Map<String, _Guard> guardsFor(String familyId) {
    final guards = <String, _Guard>{
      for (final id in knownGuidanceGuards) id: const _Guard(false)
    };
    void put(String id, bool pass,
            [List<EvidenceField<Object>> evidence = const []]) =>
        guards[id] = _Guard(pass, evidence);
    final likely = numbers(GuidanceField.precipitationProbability,
            (v) => v >= policy.rainLikely && v <= 1)
        .where((probability) =>
            types.any((type) => _sameEvidencePeriod(probability, type)))
        .toList();
    final possible = numbers(GuidanceField.precipitationProbability,
            (v) => v >= policy.rainPossible && v < policy.rainLikely)
        .where((probability) =>
            types.any((type) => _sameEvidencePeriod(probability, type)))
        .toList();
    List<EvidenceField<Object>> forecastOnly(
            List<EvidenceField<Object>> values) =>
        values.where((f) => f.kind == EvidenceKind.forecast).toList();
    final warm = forecastOnly(
        numbers(GuidanceField.temperatureC, (v) => v >= policy.warmC));
    final cold = forecastOnly(
        numbers(GuidanceField.temperatureC, (v) => v <= policy.coldC));
    final cool = forecastOnly(
        numbers(GuidanceField.temperatureC, (v) => v <= policy.coolC));
    final gusts = forecastOnly(
        numbers(GuidanceField.gustKph, (v) => v >= policy.notableGustKph));
    final snow = forecastOnly(
        equals(GuidanceField.precipitationType, PrecipitationType.snow));
    final freezing = forecastOnly(
        equals(GuidanceField.precipitationType, PrecipitationType.freezing));
    final fog = forecastOnly([
      ...equals(GuidanceField.conditionCode, 741),
      ...numbers(GuidanceField.visibilityMeters,
          (v) => v <= policy.lowVisibilityMeters && v >= 0),
    ]);
    final isDog = context.activity == GuidanceActivity.dogWalking;
    final isBike = context.activity == GuidanceActivity.cycling;
    final isCommute = context.activity == GuidanceActivity.drivingCommute &&
        (context.knownActivity || context.userSelectedWindow) &&
        context.window != null &&
        !dailyMode;
    final isEvent = context.activity == GuidanceActivity.outdoorEvent &&
        context.knownActivity &&
        context.window != null;
    final wet = currentRain;
    final appropriate = coverage || (currentContext && fields.isNotEmpty);
    put('relevant_outing_or_day_window', appropriate);
    put('relevant_outing_window', appropriate);
    put('liquid_rain_type', types.isNotEmpty, types);
    put('probability_likely', likely.isNotEmpty, likely);
    put('probability_possible', possible.isNotEmpty, possible);
    put('fresh_current_rain_observation', wet.isNotEmpty, wet);
    final lightModerate = values(GuidanceField.rainIntensity)
        .where((f) =>
            f.kind == EvidenceKind.observation &&
            (f.value == RainIntensity.light ||
                f.value == RainIntensity.moderate))
        .toList();
    put('light_or_moderate_rain', lightModerate.isNotEmpty, lightModerate);
    put('future_only_surface', !currentContext);
    put('current_forecast_context', currentContext);
    put('dog_activity_context', isDog);
    put('cycling_activity_context', isBike);
    put('walking_activity_context',
        context.activity == GuidanceActivity.walking);
    put('driving_commute_context', isCommute);
    put(
        'known_or_user_selected_activity_window',
        (context.knownActivity || context.userSelectedWindow) &&
            context.window != null);
    put(
        'known_dog_activity_interval',
        isDog &&
            (context.knownActivity || context.userSelectedWindow) &&
            context.window != null &&
            !dailyMode);
    put(
        'known_cycling_activity_interval',
        isBike &&
            (context.knownActivity || context.userSelectedWindow) &&
            context.window != null &&
            !dailyMode);
    final rain = [...likely, ...possible];
    put('rain_supported_in_activity_window',
        appropriate && (rain.isNotEmpty || wet.isNotEmpty), [...rain, ...wet]);
    for (final key in [
      'probability_likely_in_activity_window',
      'probability_likely_overlapping_commute',
      'probability_likely_in_event_window'
    ]) {
      put(key, coverage && likely.isNotEmpty, likely);
    }
    for (final key in [
      'warm_or_hot_outlook',
      'warm_or_hot_event_outlook',
      'warm_outlook'
    ]) {
      put(key, warm.isNotEmpty, warm);
    }
    put('cold_outlook', cold.isNotEmpty, cold);
    put('cool_event_outlook', cool.isNotEmpty, cool);
    for (final key in [
      'notable_gusts_outlook',
      'notable_gusts_in_activity_window',
      'notable_gusts_overlapping_commute'
    ]) {
      put(key, gusts.isNotEmpty, gusts);
    }
    for (final key in [
      'explicit_snow_forecast',
      'explicit_snow_forecast_overlapping_commute'
    ]) {
      put(key, snow.isNotEmpty, snow);
    }
    for (final key in [
      'explicit_freezing_precipitation',
      'explicit_freezing_precipitation_overlapping_commute'
    ]) {
      put(key, freezing.isNotEmpty, freezing);
    }
    for (final key in [
      'explicit_fog_or_low_visibility',
      'explicit_fog_or_low_visibility_overlapping_commute'
    ]) {
      put(key, fog.isNotEmpty, fog);
    }
    final umbrellaConflict = [
      ...numbers(GuidanceField.windKph, (v) => v >= policy.umbrellaWindKph),
      ...numbers(GuidanceField.gustKph, (v) => v >= policy.umbrellaWindKph),
      ...hazardFacts
    ];
    put('umbrella_conflict', umbrellaConflict.isNotEmpty, umbrellaConflict);
    put('known_hazard_in_window', hazardFacts.isNotEmpty, hazardFacts);
    final humidity = [
      ...numbers(GuidanceField.humidityPercent,
          (v) => v >= policy.humidPercent && v <= 100),
      ...numbers(GuidanceField.dewPointC, (v) => v >= policy.humidDewPointC)
    ];
    put('humidity_or_dewpoint_evidence', humidity.isNotEmpty, humidity);
    final warmHumid = warm.any((temperature) =>
        humidity.any((moisture) => _sameEvidencePeriod(temperature, moisture)));
    put('warm_humid_rule_met', warmHumid, [...warm, ...humidity]);
    final night = equals(GuidanceField.daylight, false);
    final sunsets = values(GuidanceField.sunset)
        .where((f) =>
            f.value is DateTime &&
            !(f.value as DateTime).isAfter(f.interval.start))
        .toList();
    put(
        'local_sunset_or_night_evidence',
        !dailyMode &&
            coverage &&
            night.length == periods.length &&
            night.isNotEmpty &&
            sunsets.length == periods.length,
        [...night, ...sunsets]);
    final uv = numbers(GuidanceField.uvIndex, (v) => v >= 0 && v <= 30)
        .where((f) => f.unit == 'UV Index')
        .toList();
    final elevatedUv =
        uv.where((f) => (f.value as num) >= policy.elevatedUv).toList();
    put('named_uv_index', uv.isNotEmpty, uv);
    put('elevated_uv_category', elevatedUv.isNotEmpty, elevatedUv);
    final daylight = equals(GuidanceField.daylight, true);
    put(
        'daytime_uv_interval_coverage',
        !dailyMode &&
            uv.isNotEmpty &&
            daylight.isNotEmpty &&
            uv.every((u) => daylight.any((d) => d.interval.covers(u.interval))),
        [...uv, ...daylight]);
    final aqi = values(GuidanceField.aqi).where(_knownAqi).toList();
    final elevatedAqi = aqi.where(_aqiElevated).toList();
    put('named_aqi_scheme', aqi.isNotEmpty, aqi);
    put('elevated_aqi_category', elevatedAqi.isNotEmpty, elevatedAqi);
    put('matching_aqi_time_location', aqi.isNotEmpty, aqi);
    put('severe_air_quality_requires_primary_guidance', aqi.any(_aqiSevere),
        aqi.where(_aqiSevere).toList());
    put('explicit_outdoor_event', isEvent);
    put('resolved_event_location', context.location.validAt(now));
    put('event_interval_coverage', coverage);
    final eventLocal = context.location.localTime(target.start);
    put(
        'evening_event_in_local_zone',
        !dailyMode &&
            eventLocal != null &&
            eventLocal.hour >= 18 &&
            eventLocal.hour < 24);
    final comparisonFacts = comparison == null
        ? <EvidenceField<Object>>[]
        : [
            ...comparison!.$1.probabilities,
            ...comparison!.$2.probabilities,
            for (final p in [
              ...comparison!.$1.periods,
              ...comparison!.$2.periods
            ])
              ...p.fields.where((f) =>
                  usable(f, p.interval) &&
                  const {
                    GuidanceField.precipitationType,
                    GuidanceField.temperatureC,
                    GuidanceField.windKph,
                    GuidanceField.gustKph,
                    GuidanceField.aqi,
                    GuidanceField.daylight,
                    GuidanceField.rainIntensity,
                    GuidanceField.severeHazard
                  }.contains(f.field)),
          ];
    put('complete_comparison_windows', comparison != null, comparisonFacts);
    put('incomplete_comparison', comparison == null);
    put('meaningful_rain_probability_improvement', comparison != null,
        comparisonFacts);
    put('liquid_rain_probability', comparison != null, comparisonFacts);
    put('hourly_probability_downward_comparison',
        comparison != null && wet.isNotEmpty, [...comparisonFacts, ...wet]);
    if (familyId == 'rain_ending_trend' &&
        comparison != null &&
        wet.isNotEmpty) {
      put('liquid_rain_type', true, wet);
    }
    final later = laterRain;
    if (later != null) {
      final laterFields =
          later.fields.where((f) => usable(f, later.interval)).toList();
      put('hourly_probability_comparison', true,
          [...laterFields, ...values(GuidanceField.precipitationProbability)]);
      put('later_same_local_day', true, laterFields);
      if (familyId == 'rain_later') {
        put(
            'liquid_rain_type',
            true,
            laterFields
                .where((f) => f.field == GuidanceField.precipitationType)
                .toList());
      }
    }
    if (eveningRain case final evening?) {
      final eveningFields =
          evening.fields.where((f) => usable(f, evening.interval)).toList();
      put('upcoming_evening_same_local_day', true, eveningFields);
      if (familyId == 'rain_evening') {
        put(
            'liquid_rain_type',
            true,
            eveningFields
                .where((f) => f.field == GuidanceField.precipitationType)
                .toList());
        put(
            'probability_likely',
            true,
            eveningFields
                .where((f) => f.field == GuidanceField.precipitationProbability)
                .toList());
      }
    }
    _temperaturePhases(put);
    final noForecast = fields.isEmpty;
    put('no_reliable_required_forecast', noForecast);
    put('existing_user_triggered_refresh_available', context.allowRefresh);
    put(
        'refresh_may_resolve_absence',
        context.allowRefresh &&
            !context.unsupported &&
            !context.permissionDenied &&
            !_outsideHorizon);
    put('unsupported_capability', context.unsupported);
    put('permanent_permission_denial', context.permissionDenied);
    put('outside_forecast_horizon', _outsideHorizon);
    return guards;
  }

  bool get _outsideHorizon {
    final periods = [...weather.hourly, ...weather.daily];
    return periods.isNotEmpty &&
        periods.every((p) => !p.interval.end.isAfter(target.start));
  }

  DateTime expiry(List<EvidenceField<Object>> evidence) {
    var end = target.end;
    for (final field in evidence) {
      // Evidence for a later comparison may begin in the future; advice can be
      // read now, but never after its original source expires or action closes.
      end = _earlier(end, policy.expiry(field));
    }
    if (context.location.validUntil case final limit?) {
      end = _earlier(end, limit);
    }
    return end;
  }

  String fingerprint(String family, List<EvidenceField<Object>> evidence) {
    final facts = evidence.map((f) => f.signature).toList()..sort();
    final block = now.toUtc().millisecondsSinceEpoch ~/
        const Duration(minutes: 30).inMilliseconds;
    return guidanceFingerprint(
        '$family|${context.activity.name}|${context.location.key}|${context.location.timezone}|${context.location.assumed}|${context.window?.signature ?? block}|${context.knownActivity}|${facts.join('|')}');
  }

  GuidanceInterval? windowFor(String family) => switch (family) {
        'lower_rain_window' ||
        'dog_lower_rain_window' ||
        'bike_lower_rain_window' ||
        'rain_ending_trend' =>
          comparison?.$2.interval,
        'rain_later' => laterRain?.interval,
        'rain_evening' => eveningRain?.interval,
        _ => null,
      };

  _Window? _window(GuidanceInterval interval) {
    final periods = weather.hourly
        .where((p) => p.interval.overlaps(interval))
        .toList()
      ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
    if (!_covers(periods, interval)) return null;
    final probabilities = <EvidenceField<Object>>[];
    for (final period in periods) {
      final probability = period.field(GuidanceField.precipitationProbability);
      final type = period.field(GuidanceField.precipitationType);
      if (!usable(probability, interval) ||
          !usable(type, interval) ||
          probability!.value is! num ||
          !const {PrecipitationType.none, PrecipitationType.liquidRain}
              .contains(type!.value)) {
        return null;
      }
      if (_hazards(period.fields.where((f) => usable(f, interval)))
          .isNotEmpty) {
        return null;
      }
      if (weather.alerts.any((a) =>
          a.location.key == context.location.key &&
          a.interval.overlaps(interval) &&
          a.interval.end.isAfter(now))) {
        return null;
      }
      final value = (probability.value as num).toDouble();
      if (value < 0 || value > 1) return null;
      if (value > 0 && type.value != PrecipitationType.liquidRain) return null;
      probabilities.add(probability);
    }
    var penalty = 0.0;
    for (final period in periods) {
      var periodPenalty = 0.0;
      for (final field in period.fields.where((f) => usable(f, interval))) {
        final value = field.value;
        if (value is num) {
          if (field.field == GuidanceField.temperatureC) {
            periodPenalty += math.max(0, value - policy.warmC) * .02 +
                math.max(0, policy.coldC - value) * .02;
          } else if (field.field == GuidanceField.gustKph ||
              field.field == GuidanceField.windKph) {
            periodPenalty += math.max(0, value - policy.notableGustKph) * .01;
          } else if (field.field == GuidanceField.aqi && _aqiElevated(field)) {
            periodPenalty += .2;
          }
        }
        if (field.field == GuidanceField.rainIntensity &&
            value == RainIntensity.heavy) {
          periodPenalty += .4;
        }
        if (field.field == GuidanceField.daylight &&
            value == false &&
            const {
              GuidanceActivity.dogWalking,
              GuidanceActivity.cycling,
              GuidanceActivity.walking
            }.contains(context.activity)) {
          periodPenalty += .15;
        }
      }
      penalty = math.max(penalty, periodPenalty);
    }
    return _Window(
        interval,
        periods,
        probabilities,
        probabilities.map((f) => (f.value as num).toDouble()).reduce(math.max),
        penalty);
  }

  (_Window, _Window)? _comparison() {
    if (dailyMode ||
        context.knownActivity ||
        context.surface == GuidanceSurface.hourlyDetail ||
        context.surface == GuidanceSurface.eventDetail) {
      return null;
    }
    final duration = context.outingDuration;
    if (duration < const Duration(minutes: 15) ||
        duration > const Duration(hours: 3)) {
      return null;
    }
    final base = _window(GuidanceInterval(now, now.add(duration)));
    if (base == null) return null;
    final horizon = now.add(policy.windowHorizon);
    final candidates = <_Window>[];
    for (final hour in weather.hourly) {
      if (!hour.interval.start.isAfter(now) ||
          hour.interval.start.add(duration).isAfter(horizon)) {
        continue;
      }
      final window = _window(GuidanceInterval(
          hour.interval.start, hour.interval.start.add(duration)));
      if (window != null &&
          base.score - window.score >= policy.meaningfulRainDifference &&
          window.score + window.comfortPenalty <
              base.score + base.comfortPenalty) {
        candidates.add(window);
      }
    }
    candidates.sort((a, b) {
      final difference =
          (a.score + a.comfortPenalty).compareTo(b.score + b.comfortPenalty);
      return difference == 0
          ? a.interval.start.compareTo(b.interval.start)
          : difference;
    });
    return candidates.isEmpty ? null : (base, candidates.first);
  }

  WeatherEvidencePeriod? _laterRain({required bool evening}) {
    if (dailyMode ||
        context.window != null ||
        !currentContext ||
        currentRain.isNotEmpty) {
      return null;
    }
    final localNow = context.location.localTime(now);
    if (localNow == null) return null;
    final base = _window(target);
    if (base == null) return null;
    final sorted = [...weather.hourly]
      ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
    for (final period in sorted) {
      final local = context.location.localTime(period.interval.start);
      if (!period.interval.start.isAfter(now) ||
          local == null ||
          !_sameDate(local, localNow) ||
          (evening && local.hour < 18)) {
        continue;
      }
      final candidate = _window(period.interval);
      if (candidate == null ||
          candidate.score < policy.rainLikely ||
          (!evening &&
              candidate.score - base.score < policy.meaningfulRainDifference)) {
        continue;
      }
      if (period.field(GuidanceField.precipitationType)?.value ==
          PrecipitationType.liquidRain) {
        return period;
      }
    }
    return null;
  }

  void _temperaturePhases(
      void Function(String, bool, [List<EvidenceField<Object>>]) put) {
    final day = context.location.localTime(target.start);
    if (day == null ||
        (context.surface != GuidanceSurface.todaySummary &&
            context.surface != GuidanceSurface.dayDetail)) {
      return;
    }
    List<EvidenceField<Object>> phase(int first, int last) => weather.hourly
        .where((p) {
          final local = context.location.localTime(p.interval.start);
          return local != null &&
              _sameDate(local, day) &&
              local.hour >= first &&
              local.hour < last;
        })
        .map((p) => p.field(GuidanceField.temperatureC))
        .whereType<EvidenceField<Object>>()
        .where((f) => usable(f, f.interval) && f.value is num)
        .toList();
    bool complete(List<EvidenceField<Object>> values) {
      if (values.length < 2) return false;
      final ordered = [...values]
        ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
      return _covers(
          ordered
              .map((f) =>
                  WeatherEvidencePeriod(interval: f.interval, fields: [f]))
              .toList(),
          GuidanceInterval(
              ordered.first.interval.start, ordered.last.interval.end));
    }

    final morning = phase(6, 12),
        afternoon = phase(12, 18),
        evening = phase(18, 23);
    if (complete(morning) && complete(afternoon)) {
      final coolMorning = morning.any((f) => (f.value as num) <= policy.coolC);
      final warmer =
          afternoon.map((f) => (f.value as num).toDouble()).reduce(math.max) -
                  morning
                      .map((f) => (f.value as num).toDouble())
                      .reduce(math.min) >=
              policy.materialTemperatureDifferenceC;
      put('same_day_morning_afternoon_coverage', true,
          [...morning, ...afternoon]);
      put('cool_morning', coolMorning, morning);
      put('materially_warmer_afternoon', warmer, afternoon);
    }
    if (complete(afternoon) && complete(evening)) {
      final warmDay = afternoon.any((f) => (f.value as num) >= policy.warmC);
      final cooler =
          afternoon.map((f) => (f.value as num).toDouble()).reduce(math.max) -
                  evening
                      .map((f) => (f.value as num).toDouble())
                      .reduce(math.min) >=
              policy.materialTemperatureDifferenceC;
      put('same_day_daytime_evening_coverage', true,
          [...afternoon, ...evening]);
      put('warm_daytime', warmDay, afternoon);
      put('materially_cooler_evening', cooler, evening);
    }
  }
}

bool _covers(List<WeatherEvidencePeriod> periods, GuidanceInterval target) {
  var covered = target.start;
  for (final period in periods) {
    if (!period.interval.overlaps(target)) continue;
    if (period.interval.start.isAfter(covered)) return false;
    if (period.interval.end.isAfter(covered)) covered = period.interval.end;
    if (!covered.isBefore(target.end)) return true;
  }
  return false;
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool _sameEvidencePeriod(EvidenceField<Object> a, EvidenceField<Object> b) =>
    a.provider == b.provider &&
    a.location.key == b.location.key &&
    a.kind == b.kind &&
    a.interval.signature == b.interval.signature &&
    a.sourceTime == b.sourceTime;
int _alertPriority(GuidanceAlert alert) {
  final severity = switch (alert.severity?.trim().toLowerCase()) {
    'extreme' => 5,
    'severe' => 4,
    'moderate' => 3,
    'minor' => 2,
    _ => 1,
  };
  final title = alert.event.toLowerCase();
  final designation = RegExp(r'\bemergency\b').hasMatch(title)
      ? 4
      : RegExp(r'\bwarning\b').hasMatch(title)
          ? 3
          : RegExp(r'\bwatch\b').hasMatch(title)
              ? 2
              : RegExp(r'\badvisory\b').hasMatch(title)
                  ? 1
                  : 0;
  return severity * 10 + designation;
}

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
bool _knownAqi(EvidenceField<Object> field) =>
    field.value is num &&
    switch (field.unit.toLowerCase()) {
      'openweather_1_5' =>
        (field.value as num) >= 1 && (field.value as num) <= 5,
      'us_epa' ||
      'us_epa_aqi' =>
        (field.value as num) >= 0 && (field.value as num) <= 500,
      _ => false,
    };
bool _aqiElevated(EvidenceField<Object> field) =>
    _knownAqi(field) &&
    (field.value as num) >=
        (field.unit.toLowerCase() == 'openweather_1_5' ? 3 : 101);
bool _aqiSevere(EvidenceField<Object> field) =>
    _knownAqi(field) &&
    (field.value as num) >=
        (field.unit.toLowerCase() == 'openweather_1_5' ? 5 : 201);

String _reason(String family, GuidanceContext context) {
  if (family == 'rain_current') {
    return 'Fresh current conditions report rain in this area.';
  }
  if (family.contains('lower_rain_window') || family == 'rain_ending_trend') {
    return 'Covered hourly forecasts show lower rain chances in the highlighted window. Other conditions can still affect your plans.';
  }
  if (family == 'cool_morning_warm_afternoon') {
    return 'The hourly forecast changes from cooler morning conditions to warmer afternoon temperatures.';
  }
  if (family == 'warm_day_cool_evening') {
    return 'The hourly forecast shows a cooler evening after a warmer daytime period.';
  }
  if (family == 'uv_elevated') {
    return 'The current UV observation is elevated for this location.';
  }
  if (family == 'aqi_elevated') {
    return 'The air-quality reading is elevated for its declared index and location.';
  }
  if (family == 'forecast_unavailable') {
    return 'There is not enough current forecast information for a more specific action.';
  }
  if (context.allDay || context.surface == GuidanceSurface.dayDetail) {
    return 'The daily outlook supports this preparation, but does not specify the exact hours affected.';
  }
  if (context.activity == GuidanceActivity.outdoorEvent) {
    return 'Forecast hours overlap this outdoor event at its resolved location.';
  }
  if (context.activity == GuidanceActivity.drivingCommute) {
    return 'Forecast hours overlap your selected commute window in this area.';
  }
  return 'The forecast indicates conditions worth preparing for in this period. The observations and forecast hours below explain why.';
}
