import 'guidance_evidence.dart';

class GuidanceFamily {
  GuidanceFamily(
      {required this.id,
      required this.activity,
      required Iterable<String> surfaces,
      required Iterable<String> requiredEvidence,
      required Iterable<String> excludedWhen,
      required this.priorityBand,
      required this.semanticDedupeKey,
      required this.claimLimit,
      required this.cooldownPolicy})
      : surfaces = Set.unmodifiable(surfaces),
        requiredEvidence = Set.unmodifiable(requiredEvidence),
        excludedWhen = Set.unmodifiable(excludedWhen);
  final String id,
      activity,
      priorityBand,
      semanticDedupeKey,
      claimLimit,
      cooldownPolicy;
  final Set<String> surfaces, requiredEvidence, excludedWhen;
}

class GuidanceTemplate {
  GuidanceTemplate(
      {required this.id,
      required this.familyId,
      required this.text,
      Iterable<String> requiredGuards = const []})
      : requiredGuards = Set.unmodifiable(requiredGuards);
  final String id, familyId, text;
  final Set<String> requiredGuards;
}

class GuidanceCatalog {
  GuidanceCatalog(
      {required this.locale,
      required this.version,
      required Iterable<GuidanceFamily> families,
      required Iterable<GuidanceTemplate> templates})
      : families = List.unmodifiable(families),
        templates = List.unmodifiable(templates);
  final String locale, version;
  final List<GuidanceFamily> families;
  final List<GuidanceTemplate> templates;

  factory GuidanceCatalog.fromJson(
      Map<String, dynamic> catalog, Map<String, dynamic> contracts) {
    void require(bool test, String message) {
      if (!test) throw FormatException(message);
    }

    void fields(Map<String, dynamic> value, Set<String> allowed) => require(
        value.keys.every(allowed.contains), 'Unsupported catalog field');
    fields(catalog, {
      'schemaVersion',
      'catalogVersion',
      'locale',
      'editorialStatus',
      'templates'
    });
    fields(contracts, {
      'schemaVersion',
      'catalogVersion',
      'locale',
      'status',
      'purpose',
      'globalPolicy',
      'families',
      'variantOverrides',
      'predicateDefinitions'
    });
    require(catalog['schemaVersion'] == 1 && contracts['schemaVersion'] == 1,
        'Unsupported schema');
    require(
        catalog['locale'] == 'en-US' &&
            contracts['locale'] == catalog['locale'],
        'Unsupported locale');
    require(catalog['catalogVersion'] == contracts['catalogVersion'],
        'Mismatched catalog version');
    final families = <GuidanceFamily>[];
    final familyIds = <String>{};
    for (final raw in catalogList(contracts['families'])) {
      final data = (raw as Map).cast<String, dynamic>();
      fields(data, {
        'id',
        'title',
        'activity',
        'allowedSurfaces',
        'priorityBand',
        'requiredEvidence',
        'excludedWhen',
        'claimLimit',
        'semanticDedupeKey',
        'cooldownPolicy'
      });
      final id = data['id'] as String;
      final required = catalogStrings(data['requiredEvidence']);
      final excluded = catalogStrings(data['excludedWhen']);
      final surfaces = catalogStrings(data['allowedSurfaces']);
      require(knownFamilyIds.contains(id) && familyIds.add(id),
          'Unknown or duplicate family');
      require([...required, ...excluded].every(knownGuidanceGuards.contains),
          'Unknown evidence guard');
      require(
          surfaces.isNotEmpty &&
              surfaces.every(
                  (s) => GuidanceSurface.values.any((v) => v.catalogId == s)),
          'Unknown surface');
      require(
          const {
            'outdoor',
            'walking',
            'dog_walking',
            'cycling',
            'driving_commute',
            'outdoor_event',
            'any'
          }.contains(data['activity']),
          'Unknown activity');
      require(
          const {'preparation', 'activity_impact', 'adverse_condition'}
              .contains(data['priorityBand']),
          'Unknown priority');
      final registered = registeredFamilyContracts[id]!;
      require(
          data['activity'] == registered['activity'] &&
              data['priorityBand'] == registered['priorityBand'] &&
              data['semanticDedupeKey'] == registered['semanticDedupeKey'] &&
              _sameStrings(
                  required, registered['requiredEvidence'] as List<String>) &&
              _sameStrings(
                  excluded, registered['excludedWhen'] as List<String>) &&
              _sameStrings(
                  surfaces, registered['allowedSurfaces'] as List<String>),
          'Catalog cannot weaken registered family requirements');
      families.add(GuidanceFamily(
          id: id,
          activity: data['activity'] as String,
          surfaces: surfaces,
          requiredEvidence: required,
          excludedWhen: excluded,
          priorityBand: data['priorityBand'] as String,
          semanticDedupeKey: data['semanticDedupeKey'] as String,
          claimLimit: data['claimLimit'] as String,
          cooldownPolicy: data['cooldownPolicy'] as String));
    }
    final ids = <String>{};
    final texts = <String>{};
    final templates = <GuidanceTemplate>[];
    for (final raw in catalogList(catalog['templates'])) {
      final data = (raw as Map).cast<String, dynamic>();
      fields(data, {'id', 'familyId', 'text', 'requiredGuards'});
      final id = data['id'] as String;
      final familyId = data['familyId'] as String;
      final text = data['text'] as String;
      final guards = catalogStrings(data['requiredGuards']);
      require(ids.add(id) && RegExp(r'^[a-z][a-z0-9_]+$').hasMatch(id),
          'Invalid or duplicate template ID');
      require(familyIds.contains(familyId) && id.startsWith('${familyId}_'),
          'Unknown family reference');
      require(
          guards.every(knownGuidanceGuards.contains), 'Unknown variant guard');
      require(
          text.isNotEmpty &&
              text.length <= 240 &&
              !RegExp(r'[{}]').hasMatch(text),
          'Invalid text or unsupported placeholder');
      require(
          texts.add(text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')),
          'Duplicate template text');
      require(
          (registeredVariantGuards[id] ?? const <String>[])
              .every(guards.contains),
          'Catalog cannot weaken registered variant requirements');
      templates.add(GuidanceTemplate(
          id: id, familyId: familyId, text: text, requiredGuards: guards));
    }
    require(familyIds.every((id) => templates.any((t) => t.familyId == id)),
        'Empty family');
    // The supplied narrower overrides remain mandatory even if a pack omits them.
    for (final raw in catalogList(contracts['variantOverrides'])) {
      final data = (raw as Map).cast<String, dynamic>();
      final matching = templates.where((t) => t.id == data['templateId']);
      require(matching.length == 1, 'Unknown variant override');
      require(
          catalogStrings(data['additionalRequiredEvidence'])
              .every(matching.single.requiredGuards.contains),
          'Missing narrower variant guard');
    }
    return GuidanceCatalog(
        locale: catalog['locale'] as String,
        version: catalog['catalogVersion'] as String,
        families: families,
        templates: templates);
  }
}

List<dynamic> catalogList(Object? value) {
  if (value is! List) throw const FormatException('Expected catalog list');
  return value;
}

List<String> catalogStrings(Object? value) => catalogList(value).cast<String>();

const knownFamilyIds = <String>{
  'rain_likely_outing',
  'rain_possible_outing',
  'rain_current',
  'rain_later',
  'lower_rain_window',
  'rain_ending_trend',
  'rain_evening',
  'wet_walk',
  'dog_rain',
  'dog_heat',
  'dog_cold',
  'dog_wind',
  'dog_lower_rain_window',
  'dog_after_dark',
  'bike_rain',
  'bike_wind',
  'bike_heat',
  'bike_cold',
  'bike_after_dark',
  'bike_lower_rain_window',
  'commute_rain',
  'commute_snow',
  'commute_fog',
  'commute_wind',
  'commute_freezing_precip',
  'hot_day',
  'cool_morning_warm_afternoon',
  'warm_day_cool_evening',
  'cold_day',
  'gusty_day',
  'humid_day',
  'uv_elevated',
  'aqi_elevated',
  'snow_outing',
  'freezing_precip_outing',
  'fog_outing',
  'event_rain',
  'event_heat',
  'event_cool_evening',
  'forecast_unavailable',
};

const knownGuidanceGuards = <String>{
  'cold_outlook',
  'complete_comparison_windows',
  'cool_event_outlook',
  'cool_morning',
  'current_forecast_context',
  'cycling_activity_context',
  'daytime_uv_interval_coverage',
  'different_local_day',
  'dog_activity_context',
  'driving_commute_context',
  'elevated_aqi_category',
  'elevated_uv_category',
  'evening_event_in_local_zone',
  'event_interval_coverage',
  'existing_user_triggered_refresh_available',
  'explicit_fog_or_low_visibility',
  'explicit_fog_or_low_visibility_overlapping_commute',
  'explicit_freezing_precipitation',
  'explicit_freezing_precipitation_overlapping_commute',
  'explicit_outdoor_event',
  'explicit_snow_forecast',
  'explicit_snow_forecast_overlapping_commute',
  'fresh_current_rain_observation',
  'future_only_surface',
  'hourly_probability_comparison',
  'hourly_probability_downward_comparison',
  'humidity_or_dewpoint_evidence',
  'incomplete_comparison',
  'known_cycling_activity_interval',
  'known_dog_activity_interval',
  'known_hazard_in_window',
  'known_or_user_selected_activity_window',
  'later_same_local_day',
  'light_or_moderate_rain',
  'liquid_rain_probability',
  'liquid_rain_type',
  'local_sunset_or_night_evidence',
  'matching_aqi_time_location',
  'materially_cooler_evening',
  'materially_warmer_afternoon',
  'meaningful_rain_probability_improvement',
  'named_aqi_scheme',
  'named_uv_index',
  'no_reliable_required_forecast',
  'notable_gusts_in_activity_window',
  'notable_gusts_outlook',
  'notable_gusts_overlapping_commute',
  'outside_forecast_horizon',
  'permanent_permission_denial',
  'probability_likely',
  'probability_likely_in_activity_window',
  'probability_likely_in_event_window',
  'probability_likely_overlapping_commute',
  'probability_possible',
  'rain_supported_in_activity_window',
  'refresh_may_resolve_absence',
  'relevant_outing_or_day_window',
  'relevant_outing_window',
  'resolved_event_location',
  'same_day_daytime_evening_coverage',
  'same_day_morning_afternoon_coverage',
  'severe_air_quality_requires_primary_guidance',
  'umbrella_conflict',
  'unsupported_capability',
  'upcoming_evening_same_local_day',
  'walking_activity_context',
  'warm_daytime',
  'warm_humid_rule_met',
  'warm_or_hot_event_outlook',
  'warm_or_hot_outlook',
  'warm_outlook',
};

bool _sameStrings(Iterable<String> first, Iterable<String> second) =>
    first.length == second.length && first.toSet().containsAll(second);

const registeredFamilyContracts = <String, Map<String, Object>>{
  'rain_likely_outing': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'rain_likely_outing',
    'requiredEvidence': <String>[
      'liquid_rain_type',
      'probability_likely',
      'relevant_outing_or_day_window'
    ],
    'excludedWhen': <String>['umbrella_conflict'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'rain_possible_outing': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'rain_possible_outing',
    'requiredEvidence': <String>[
      'liquid_rain_type',
      'probability_possible',
      'relevant_outing_or_day_window'
    ],
    'excludedWhen': <String>['umbrella_conflict'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'rain_current': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'rain_current',
    'requiredEvidence': <String>[
      'fresh_current_rain_observation',
      'light_or_moderate_rain'
    ],
    'excludedWhen': <String>['umbrella_conflict', 'future_only_surface'],
    'allowedSurfaces': <String>['today_summary', 'current_detail'],
  },
  'rain_later': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'rain_later',
    'requiredEvidence': <String>[
      'liquid_rain_type',
      'hourly_probability_comparison',
      'later_same_local_day'
    ],
    'excludedWhen': <String>['umbrella_conflict', 'different_local_day'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'lower_rain_window': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'lower_rain_window',
    'requiredEvidence': <String>[
      'liquid_rain_probability',
      'complete_comparison_windows',
      'meaningful_rain_probability_improvement'
    ],
    'excludedWhen': <String>['known_hazard_in_window', 'incomplete_comparison'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'rain_ending_trend': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'rain_ending_trend',
    'requiredEvidence': <String>[
      'fresh_current_rain_observation',
      'liquid_rain_type',
      'hourly_probability_downward_comparison'
    ],
    'excludedWhen': <String>['known_hazard_in_window', 'incomplete_comparison'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'rain_evening': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'rain_evening',
    'requiredEvidence': <String>[
      'liquid_rain_type',
      'probability_likely',
      'upcoming_evening_same_local_day'
    ],
    'excludedWhen': <String>['umbrella_conflict'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'wet_walk': {
    'activity': 'walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'wet_walk',
    'requiredEvidence': <String>[
      'fresh_current_rain_observation',
      'walking_activity_context'
    ],
    'excludedWhen': <String>['known_hazard_in_window', 'future_only_surface'],
    'allowedSurfaces': <String>['today_summary', 'current_detail'],
  },
  'dog_rain': {
    'activity': 'dog_walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'dog_rain',
    'requiredEvidence': <String>[
      'dog_activity_context',
      'liquid_rain_type',
      'rain_supported_in_activity_window'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'dog_heat': {
    'activity': 'dog_walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'dog_heat',
    'requiredEvidence': <String>['dog_activity_context', 'warm_or_hot_outlook'],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'dog_cold': {
    'activity': 'dog_walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'dog_cold',
    'requiredEvidence': <String>['dog_activity_context', 'cold_outlook'],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'dog_wind': {
    'activity': 'dog_walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'dog_wind',
    'requiredEvidence': <String>[
      'dog_activity_context',
      'notable_gusts_outlook'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'dog_lower_rain_window': {
    'activity': 'dog_walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'dog_lower_rain_window',
    'requiredEvidence': <String>[
      'dog_activity_context',
      'complete_comparison_windows',
      'meaningful_rain_probability_improvement'
    ],
    'excludedWhen': <String>['known_hazard_in_window', 'incomplete_comparison'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'dog_after_dark': {
    'activity': 'dog_walking',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'dog_after_dark',
    'requiredEvidence': <String>[
      'known_dog_activity_interval',
      'local_sunset_or_night_evidence'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'bike_rain': {
    'activity': 'cycling',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'bike_rain',
    'requiredEvidence': <String>[
      'cycling_activity_context',
      'liquid_rain_type',
      'probability_likely_in_activity_window'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'bike_wind': {
    'activity': 'cycling',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'bike_wind',
    'requiredEvidence': <String>[
      'cycling_activity_context',
      'notable_gusts_in_activity_window'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'bike_heat': {
    'activity': 'cycling',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'bike_heat',
    'requiredEvidence': <String>[
      'cycling_activity_context',
      'warm_or_hot_outlook'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'bike_cold': {
    'activity': 'cycling',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'bike_cold',
    'requiredEvidence': <String>['cycling_activity_context', 'cold_outlook'],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'bike_after_dark': {
    'activity': 'cycling',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'bike_after_dark',
    'requiredEvidence': <String>[
      'known_cycling_activity_interval',
      'local_sunset_or_night_evidence'
    ],
    'excludedWhen': <String>['known_hazard_in_window'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'bike_lower_rain_window': {
    'activity': 'cycling',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'bike_lower_rain_window',
    'requiredEvidence': <String>[
      'cycling_activity_context',
      'complete_comparison_windows',
      'meaningful_rain_probability_improvement'
    ],
    'excludedWhen': <String>['known_hazard_in_window', 'incomplete_comparison'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'commute_rain': {
    'activity': 'driving_commute',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'commute_rain',
    'requiredEvidence': <String>[
      'driving_commute_context',
      'liquid_rain_type',
      'probability_likely_overlapping_commute'
    ],
    'excludedWhen': <String>['umbrella_conflict'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'commute_snow': {
    'activity': 'driving_commute',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'commute_snow',
    'requiredEvidence': <String>[
      'driving_commute_context',
      'explicit_snow_forecast_overlapping_commute'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'commute_fog': {
    'activity': 'driving_commute',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'commute_fog',
    'requiredEvidence': <String>[
      'driving_commute_context',
      'explicit_fog_or_low_visibility_overlapping_commute'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'commute_wind': {
    'activity': 'driving_commute',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'commute_wind',
    'requiredEvidence': <String>[
      'driving_commute_context',
      'notable_gusts_overlapping_commute'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'commute_freezing_precip': {
    'activity': 'driving_commute',
    'priorityBand': 'adverse_condition',
    'semanticDedupeKey': 'commute_freezing_precip',
    'requiredEvidence': <String>[
      'driving_commute_context',
      'explicit_freezing_precipitation_overlapping_commute'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'hot_day': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'hot_day',
    'requiredEvidence': <String>[
      'warm_or_hot_outlook',
      'relevant_outing_or_day_window'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'cool_morning_warm_afternoon': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'cool_morning_warm_afternoon',
    'requiredEvidence': <String>[
      'same_day_morning_afternoon_coverage',
      'cool_morning',
      'materially_warmer_afternoon'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'warm_day_cool_evening': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'warm_day_cool_evening',
    'requiredEvidence': <String>[
      'same_day_daytime_evening_coverage',
      'warm_daytime',
      'materially_cooler_evening'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'cold_day': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'cold_day',
    'requiredEvidence': <String>[
      'cold_outlook',
      'relevant_outing_or_day_window'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'gusty_day': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'gusty_day',
    'requiredEvidence': <String>[
      'notable_gusts_outlook',
      'relevant_outing_or_day_window'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'humid_day': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'humid_day',
    'requiredEvidence': <String>[
      'warm_outlook',
      'humidity_or_dewpoint_evidence',
      'warm_humid_rule_met'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'uv_elevated': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'uv_elevated',
    'requiredEvidence': <String>[
      'named_uv_index',
      'elevated_uv_category',
      'daytime_uv_interval_coverage'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'aqi_elevated': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'aqi_elevated',
    'requiredEvidence': <String>[
      'named_aqi_scheme',
      'elevated_aqi_category',
      'matching_aqi_time_location'
    ],
    'excludedWhen': <String>['severe_air_quality_requires_primary_guidance'],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'snow_outing': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'snow_outing',
    'requiredEvidence': <String>[
      'explicit_snow_forecast',
      'relevant_outing_window'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'freezing_precip_outing': {
    'activity': 'outdoor',
    'priorityBand': 'adverse_condition',
    'semanticDedupeKey': 'freezing_precip_outing',
    'requiredEvidence': <String>[
      'explicit_freezing_precipitation',
      'relevant_outing_window'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'fog_outing': {
    'activity': 'outdoor',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'fog_outing',
    'requiredEvidence': <String>[
      'explicit_fog_or_low_visibility',
      'relevant_outing_window'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary'
    ],
  },
  'event_rain': {
    'activity': 'outdoor_event',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'event_rain',
    'requiredEvidence': <String>[
      'explicit_outdoor_event',
      'resolved_event_location',
      'event_interval_coverage',
      'liquid_rain_type',
      'probability_likely_in_event_window'
    ],
    'excludedWhen': <String>['umbrella_conflict'],
    'allowedSurfaces': <String>['event_detail', 'plancast_summary'],
  },
  'event_heat': {
    'activity': 'outdoor_event',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'event_heat',
    'requiredEvidence': <String>[
      'explicit_outdoor_event',
      'resolved_event_location',
      'event_interval_coverage',
      'warm_or_hot_event_outlook'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>['event_detail', 'plancast_summary'],
  },
  'event_cool_evening': {
    'activity': 'outdoor_event',
    'priorityBand': 'activity_impact',
    'semanticDedupeKey': 'event_cool_evening',
    'requiredEvidence': <String>[
      'explicit_outdoor_event',
      'resolved_event_location',
      'event_interval_coverage',
      'evening_event_in_local_zone',
      'cool_event_outlook'
    ],
    'excludedWhen': <String>[],
    'allowedSurfaces': <String>['event_detail', 'plancast_summary'],
  },
  'forecast_unavailable': {
    'activity': 'any',
    'priorityBand': 'preparation',
    'semanticDedupeKey': 'forecast_unavailable',
    'requiredEvidence': <String>[
      'no_reliable_required_forecast',
      'existing_user_triggered_refresh_available',
      'refresh_may_resolve_absence'
    ],
    'excludedWhen': <String>[
      'unsupported_capability',
      'outside_forecast_horizon',
      'permanent_permission_denial'
    ],
    'allowedSurfaces': <String>[
      'today_summary',
      'hourly_detail',
      'day_detail',
      'plancast_summary',
      'event_detail'
    ],
  },
};
const registeredVariantGuards = <String, List<String>>{
  'fog_outing_03': <String>['walking_activity_context'],
  'snow_outing_05': <String>['walking_activity_context'],
  'forecast_unavailable_02': <String>['current_forecast_context'],
  'dog_rain_01': <String>['known_or_user_selected_activity_window'],
  'dog_rain_03': <String>['known_or_user_selected_activity_window'],
  'dog_rain_05': <String>['known_or_user_selected_activity_window'],
  'dog_rain_06': <String>['known_or_user_selected_activity_window'],
  'dog_heat_01': <String>['known_or_user_selected_activity_window'],
  'dog_heat_03': <String>['known_or_user_selected_activity_window'],
  'dog_heat_04': <String>['known_or_user_selected_activity_window'],
  'dog_cold_01': <String>['known_or_user_selected_activity_window'],
  'dog_cold_03': <String>['known_or_user_selected_activity_window'],
  'dog_cold_06': <String>['known_or_user_selected_activity_window'],
  'dog_wind_01': <String>['known_or_user_selected_activity_window'],
  'dog_wind_02': <String>['known_or_user_selected_activity_window'],
  'dog_wind_03': <String>['known_or_user_selected_activity_window'],
  'dog_wind_06': <String>['known_or_user_selected_activity_window'],
  'bike_rain_01': <String>['known_or_user_selected_activity_window'],
  'bike_rain_02': <String>['known_or_user_selected_activity_window'],
  'bike_rain_04': <String>['known_or_user_selected_activity_window'],
  'bike_rain_06': <String>['known_or_user_selected_activity_window'],
  'bike_wind_01': <String>['known_or_user_selected_activity_window'],
  'bike_wind_02': <String>['known_or_user_selected_activity_window'],
  'bike_wind_03': <String>['known_or_user_selected_activity_window'],
  'bike_wind_04': <String>['known_or_user_selected_activity_window'],
  'bike_heat_01': <String>['known_or_user_selected_activity_window'],
  'bike_heat_03': <String>['known_or_user_selected_activity_window'],
  'bike_heat_05': <String>['known_or_user_selected_activity_window'],
  'bike_heat_06': <String>['known_or_user_selected_activity_window'],
  'bike_cold_01': <String>['known_or_user_selected_activity_window'],
  'bike_cold_03': <String>['known_or_user_selected_activity_window'],
  'bike_cold_05': <String>['known_or_user_selected_activity_window'],
  'bike_cold_06': <String>['known_or_user_selected_activity_window'],
  'dog_after_dark_01': <String>['known_or_user_selected_activity_window'],
  'bike_after_dark_01': <String>['known_or_user_selected_activity_window'],
};
