#!/usr/bin/env python3
"""Validate the reviewed bundled Wingman catalog without network or dependencies.

The registries below are an explicit code-reviewed schema, not capabilities inferred
from JSON. Coordinate registry changes with the Dart parser and predicate engine.
"""
from __future__ import annotations

import argparse
import copy
import difflib
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_NAME = "wingman_tips.en-US.json"
CONTRACT_NAME = "wingman_tip_family_contracts.json"
MAX_FILE_BYTES = 1_048_576
MAX_TEXT_CHARS = 160
MAX_TEXT_WORDS = 28

FAMILY_CONTRACTS = {'aqi_elevated': {'activity': 'outdoor',
                  'allowedSurfaces': ['today_summary',
                                      'hourly_detail',
                                      'day_detail',
                                      'plancast_summary'],
                  'excludedWhen': ['severe_air_quality_requires_primary_guidance'],
                  'priorityBand': 'preparation',
                  'requiredEvidence': ['named_aqi_scheme',
                                       'elevated_aqi_category',
                                       'matching_aqi_time_location'],
                  'semanticDedupeKey': 'aqi_elevated'},
 'bike_after_dark': {'activity': 'cycling',
                     'allowedSurfaces': ['today_summary',
                                         'hourly_detail',
                                         'day_detail',
                                         'plancast_summary'],
                     'excludedWhen': ['known_hazard_in_window'],
                     'priorityBand': 'preparation',
                     'requiredEvidence': ['known_cycling_activity_interval',
                                          'local_sunset_or_night_evidence'],
                     'semanticDedupeKey': 'bike_after_dark'},
 'bike_cold': {'activity': 'cycling',
               'allowedSurfaces': ['today_summary',
                                   'hourly_detail',
                                   'day_detail',
                                   'plancast_summary'],
               'excludedWhen': ['known_hazard_in_window'],
               'priorityBand': 'preparation',
               'requiredEvidence': ['cycling_activity_context', 'cold_outlook'],
               'semanticDedupeKey': 'bike_cold'},
 'bike_heat': {'activity': 'cycling',
               'allowedSurfaces': ['today_summary',
                                   'hourly_detail',
                                   'day_detail',
                                   'plancast_summary'],
               'excludedWhen': ['known_hazard_in_window'],
               'priorityBand': 'preparation',
               'requiredEvidence': ['cycling_activity_context', 'warm_or_hot_outlook'],
               'semanticDedupeKey': 'bike_heat'},
 'bike_lower_rain_window': {'activity': 'cycling',
                            'allowedSurfaces': ['today_summary',
                                                'hourly_detail',
                                                'day_detail',
                                                'plancast_summary'],
                            'excludedWhen': ['known_hazard_in_window', 'incomplete_comparison'],
                            'priorityBand': 'preparation',
                            'requiredEvidence': ['cycling_activity_context',
                                                 'complete_comparison_windows',
                                                 'meaningful_rain_probability_improvement'],
                            'semanticDedupeKey': 'bike_lower_rain_window'},
 'bike_rain': {'activity': 'cycling',
               'allowedSurfaces': ['today_summary',
                                   'hourly_detail',
                                   'day_detail',
                                   'plancast_summary'],
               'excludedWhen': ['known_hazard_in_window'],
               'priorityBand': 'preparation',
               'requiredEvidence': ['cycling_activity_context',
                                    'liquid_rain_type',
                                    'probability_likely_in_activity_window'],
               'semanticDedupeKey': 'bike_rain'},
 'bike_wind': {'activity': 'cycling',
               'allowedSurfaces': ['today_summary',
                                   'hourly_detail',
                                   'day_detail',
                                   'plancast_summary'],
               'excludedWhen': ['known_hazard_in_window'],
               'priorityBand': 'preparation',
               'requiredEvidence': ['cycling_activity_context', 'notable_gusts_in_activity_window'],
               'semanticDedupeKey': 'bike_wind'},
 'cold_day': {'activity': 'outdoor',
              'allowedSurfaces': ['today_summary',
                                  'hourly_detail',
                                  'day_detail',
                                  'plancast_summary'],
              'excludedWhen': [],
              'priorityBand': 'preparation',
              'requiredEvidence': ['cold_outlook', 'relevant_outing_or_day_window'],
              'semanticDedupeKey': 'cold_day'},
 'commute_fog': {'activity': 'driving_commute',
                 'allowedSurfaces': ['today_summary',
                                     'hourly_detail',
                                     'day_detail',
                                     'plancast_summary'],
                 'excludedWhen': [],
                 'priorityBand': 'activity_impact',
                 'requiredEvidence': ['driving_commute_context',
                                      'explicit_fog_or_low_visibility_overlapping_commute'],
                 'semanticDedupeKey': 'commute_fog'},
 'commute_freezing_precip': {'activity': 'driving_commute',
                             'allowedSurfaces': ['today_summary',
                                                 'hourly_detail',
                                                 'day_detail',
                                                 'plancast_summary'],
                             'excludedWhen': [],
                             'priorityBand': 'adverse_condition',
                             'requiredEvidence': ['driving_commute_context',
                                                  'explicit_freezing_precipitation_overlapping_commute'],
                             'semanticDedupeKey': 'commute_freezing_precip'},
 'commute_rain': {'activity': 'driving_commute',
                  'allowedSurfaces': ['today_summary',
                                      'hourly_detail',
                                      'day_detail',
                                      'plancast_summary'],
                  'excludedWhen': ['umbrella_conflict'],
                  'priorityBand': 'activity_impact',
                  'requiredEvidence': ['driving_commute_context',
                                       'liquid_rain_type',
                                       'probability_likely_overlapping_commute'],
                  'semanticDedupeKey': 'commute_rain'},
 'commute_snow': {'activity': 'driving_commute',
                  'allowedSurfaces': ['today_summary',
                                      'hourly_detail',
                                      'day_detail',
                                      'plancast_summary'],
                  'excludedWhen': [],
                  'priorityBand': 'activity_impact',
                  'requiredEvidence': ['driving_commute_context',
                                       'explicit_snow_forecast_overlapping_commute'],
                  'semanticDedupeKey': 'commute_snow'},
 'commute_wind': {'activity': 'driving_commute',
                  'allowedSurfaces': ['today_summary',
                                      'hourly_detail',
                                      'day_detail',
                                      'plancast_summary'],
                  'excludedWhen': [],
                  'priorityBand': 'activity_impact',
                  'requiredEvidence': ['driving_commute_context',
                                       'notable_gusts_overlapping_commute'],
                  'semanticDedupeKey': 'commute_wind'},
 'cool_morning_warm_afternoon': {'activity': 'outdoor',
                                 'allowedSurfaces': ['today_summary',
                                                     'hourly_detail',
                                                     'day_detail',
                                                     'plancast_summary'],
                                 'excludedWhen': [],
                                 'priorityBand': 'preparation',
                                 'requiredEvidence': ['same_day_morning_afternoon_coverage',
                                                      'cool_morning',
                                                      'materially_warmer_afternoon'],
                                 'semanticDedupeKey': 'cool_morning_warm_afternoon'},
 'dog_after_dark': {'activity': 'dog_walking',
                    'allowedSurfaces': ['today_summary',
                                        'hourly_detail',
                                        'day_detail',
                                        'plancast_summary'],
                    'excludedWhen': ['known_hazard_in_window'],
                    'priorityBand': 'preparation',
                    'requiredEvidence': ['known_dog_activity_interval',
                                         'local_sunset_or_night_evidence'],
                    'semanticDedupeKey': 'dog_after_dark'},
 'dog_cold': {'activity': 'dog_walking',
              'allowedSurfaces': ['today_summary',
                                  'hourly_detail',
                                  'day_detail',
                                  'plancast_summary'],
              'excludedWhen': ['known_hazard_in_window'],
              'priorityBand': 'preparation',
              'requiredEvidence': ['dog_activity_context', 'cold_outlook'],
              'semanticDedupeKey': 'dog_cold'},
 'dog_heat': {'activity': 'dog_walking',
              'allowedSurfaces': ['today_summary',
                                  'hourly_detail',
                                  'day_detail',
                                  'plancast_summary'],
              'excludedWhen': ['known_hazard_in_window'],
              'priorityBand': 'preparation',
              'requiredEvidence': ['dog_activity_context', 'warm_or_hot_outlook'],
              'semanticDedupeKey': 'dog_heat'},
 'dog_lower_rain_window': {'activity': 'dog_walking',
                           'allowedSurfaces': ['today_summary',
                                               'hourly_detail',
                                               'day_detail',
                                               'plancast_summary'],
                           'excludedWhen': ['known_hazard_in_window', 'incomplete_comparison'],
                           'priorityBand': 'preparation',
                           'requiredEvidence': ['dog_activity_context',
                                                'complete_comparison_windows',
                                                'meaningful_rain_probability_improvement'],
                           'semanticDedupeKey': 'dog_lower_rain_window'},
 'dog_rain': {'activity': 'dog_walking',
              'allowedSurfaces': ['today_summary',
                                  'hourly_detail',
                                  'day_detail',
                                  'plancast_summary'],
              'excludedWhen': ['known_hazard_in_window'],
              'priorityBand': 'preparation',
              'requiredEvidence': ['dog_activity_context',
                                   'liquid_rain_type',
                                   'rain_supported_in_activity_window'],
              'semanticDedupeKey': 'dog_rain'},
 'dog_wind': {'activity': 'dog_walking',
              'allowedSurfaces': ['today_summary',
                                  'hourly_detail',
                                  'day_detail',
                                  'plancast_summary'],
              'excludedWhen': ['known_hazard_in_window'],
              'priorityBand': 'preparation',
              'requiredEvidence': ['dog_activity_context', 'notable_gusts_outlook'],
              'semanticDedupeKey': 'dog_wind'},
 'event_cool_evening': {'activity': 'outdoor_event',
                        'allowedSurfaces': ['event_detail', 'plancast_summary'],
                        'excludedWhen': [],
                        'priorityBand': 'activity_impact',
                        'requiredEvidence': ['explicit_outdoor_event',
                                             'resolved_event_location',
                                             'event_interval_coverage',
                                             'evening_event_in_local_zone',
                                             'cool_event_outlook'],
                        'semanticDedupeKey': 'event_cool_evening'},
 'event_heat': {'activity': 'outdoor_event',
                'allowedSurfaces': ['event_detail', 'plancast_summary'],
                'excludedWhen': [],
                'priorityBand': 'activity_impact',
                'requiredEvidence': ['explicit_outdoor_event',
                                     'resolved_event_location',
                                     'event_interval_coverage',
                                     'warm_or_hot_event_outlook'],
                'semanticDedupeKey': 'event_heat'},
 'event_rain': {'activity': 'outdoor_event',
                'allowedSurfaces': ['event_detail', 'plancast_summary'],
                'excludedWhen': ['umbrella_conflict'],
                'priorityBand': 'activity_impact',
                'requiredEvidence': ['explicit_outdoor_event',
                                     'resolved_event_location',
                                     'event_interval_coverage',
                                     'liquid_rain_type',
                                     'probability_likely_in_event_window'],
                'semanticDedupeKey': 'event_rain'},
 'fog_outing': {'activity': 'outdoor',
                'allowedSurfaces': ['today_summary',
                                    'hourly_detail',
                                    'day_detail',
                                    'plancast_summary'],
                'excludedWhen': [],
                'priorityBand': 'preparation',
                'requiredEvidence': ['explicit_fog_or_low_visibility', 'relevant_outing_window'],
                'semanticDedupeKey': 'fog_outing'},
 'forecast_unavailable': {'activity': 'any',
                          'allowedSurfaces': ['today_summary',
                                              'hourly_detail',
                                              'day_detail',
                                              'plancast_summary',
                                              'event_detail'],
                          'excludedWhen': ['unsupported_capability',
                                           'outside_forecast_horizon',
                                           'permanent_permission_denial'],
                          'priorityBand': 'preparation',
                          'requiredEvidence': ['no_reliable_required_forecast',
                                               'existing_user_triggered_refresh_available',
                                               'refresh_may_resolve_absence'],
                          'semanticDedupeKey': 'forecast_unavailable'},
 'freezing_precip_outing': {'activity': 'outdoor',
                            'allowedSurfaces': ['today_summary',
                                                'hourly_detail',
                                                'day_detail',
                                                'plancast_summary'],
                            'excludedWhen': [],
                            'priorityBand': 'adverse_condition',
                            'requiredEvidence': ['explicit_freezing_precipitation',
                                                 'relevant_outing_window'],
                            'semanticDedupeKey': 'freezing_precip_outing'},
 'gusty_day': {'activity': 'outdoor',
               'allowedSurfaces': ['today_summary',
                                   'hourly_detail',
                                   'day_detail',
                                   'plancast_summary'],
               'excludedWhen': [],
               'priorityBand': 'preparation',
               'requiredEvidence': ['notable_gusts_outlook', 'relevant_outing_or_day_window'],
               'semanticDedupeKey': 'gusty_day'},
 'hot_day': {'activity': 'outdoor',
             'allowedSurfaces': ['today_summary',
                                 'hourly_detail',
                                 'day_detail',
                                 'plancast_summary'],
             'excludedWhen': [],
             'priorityBand': 'preparation',
             'requiredEvidence': ['warm_or_hot_outlook', 'relevant_outing_or_day_window'],
             'semanticDedupeKey': 'hot_day'},
 'humid_day': {'activity': 'outdoor',
               'allowedSurfaces': ['today_summary',
                                   'hourly_detail',
                                   'day_detail',
                                   'plancast_summary'],
               'excludedWhen': [],
               'priorityBand': 'preparation',
               'requiredEvidence': ['warm_outlook',
                                    'humidity_or_dewpoint_evidence',
                                    'warm_humid_rule_met'],
               'semanticDedupeKey': 'humid_day'},
 'lower_rain_window': {'activity': 'outdoor',
                       'allowedSurfaces': ['today_summary',
                                           'hourly_detail',
                                           'day_detail',
                                           'plancast_summary'],
                       'excludedWhen': ['known_hazard_in_window', 'incomplete_comparison'],
                       'priorityBand': 'preparation',
                       'requiredEvidence': ['liquid_rain_probability',
                                            'complete_comparison_windows',
                                            'meaningful_rain_probability_improvement'],
                       'semanticDedupeKey': 'lower_rain_window'},
 'rain_current': {'activity': 'outdoor',
                  'allowedSurfaces': ['today_summary', 'current_detail'],
                  'excludedWhen': ['umbrella_conflict', 'future_only_surface'],
                  'priorityBand': 'preparation',
                  'requiredEvidence': ['fresh_current_rain_observation', 'light_or_moderate_rain'],
                  'semanticDedupeKey': 'rain_current'},
 'rain_ending_trend': {'activity': 'outdoor',
                       'allowedSurfaces': ['today_summary',
                                           'hourly_detail',
                                           'day_detail',
                                           'plancast_summary'],
                       'excludedWhen': ['known_hazard_in_window', 'incomplete_comparison'],
                       'priorityBand': 'preparation',
                       'requiredEvidence': ['fresh_current_rain_observation',
                                            'liquid_rain_type',
                                            'hourly_probability_downward_comparison'],
                       'semanticDedupeKey': 'rain_ending_trend'},
 'rain_evening': {'activity': 'outdoor',
                  'allowedSurfaces': ['today_summary',
                                      'hourly_detail',
                                      'day_detail',
                                      'plancast_summary'],
                  'excludedWhen': ['umbrella_conflict'],
                  'priorityBand': 'preparation',
                  'requiredEvidence': ['liquid_rain_type',
                                       'probability_likely',
                                       'upcoming_evening_same_local_day'],
                  'semanticDedupeKey': 'rain_evening'},
 'rain_later': {'activity': 'outdoor',
                'allowedSurfaces': ['today_summary',
                                    'hourly_detail',
                                    'day_detail',
                                    'plancast_summary'],
                'excludedWhen': ['umbrella_conflict', 'different_local_day'],
                'priorityBand': 'preparation',
                'requiredEvidence': ['liquid_rain_type',
                                     'hourly_probability_comparison',
                                     'later_same_local_day'],
                'semanticDedupeKey': 'rain_later'},
 'rain_likely_outing': {'activity': 'outdoor',
                        'allowedSurfaces': ['today_summary',
                                            'hourly_detail',
                                            'day_detail',
                                            'plancast_summary'],
                        'excludedWhen': ['umbrella_conflict'],
                        'priorityBand': 'preparation',
                        'requiredEvidence': ['liquid_rain_type',
                                             'probability_likely',
                                             'relevant_outing_or_day_window'],
                        'semanticDedupeKey': 'rain_likely_outing'},
 'rain_possible_outing': {'activity': 'outdoor',
                          'allowedSurfaces': ['today_summary',
                                              'hourly_detail',
                                              'day_detail',
                                              'plancast_summary'],
                          'excludedWhen': ['umbrella_conflict'],
                          'priorityBand': 'preparation',
                          'requiredEvidence': ['liquid_rain_type',
                                               'probability_possible',
                                               'relevant_outing_or_day_window'],
                          'semanticDedupeKey': 'rain_possible_outing'},
 'snow_outing': {'activity': 'outdoor',
                 'allowedSurfaces': ['today_summary',
                                     'hourly_detail',
                                     'day_detail',
                                     'plancast_summary'],
                 'excludedWhen': [],
                 'priorityBand': 'preparation',
                 'requiredEvidence': ['explicit_snow_forecast', 'relevant_outing_window'],
                 'semanticDedupeKey': 'snow_outing'},
 'uv_elevated': {'activity': 'outdoor',
                 'allowedSurfaces': ['today_summary',
                                     'hourly_detail',
                                     'day_detail',
                                     'plancast_summary'],
                 'excludedWhen': [],
                 'priorityBand': 'preparation',
                 'requiredEvidence': ['named_uv_index',
                                      'elevated_uv_category',
                                      'daytime_uv_interval_coverage'],
                 'semanticDedupeKey': 'uv_elevated'},
 'warm_day_cool_evening': {'activity': 'outdoor',
                           'allowedSurfaces': ['today_summary',
                                               'hourly_detail',
                                               'day_detail',
                                               'plancast_summary'],
                           'excludedWhen': [],
                           'priorityBand': 'preparation',
                           'requiredEvidence': ['same_day_daytime_evening_coverage',
                                                'warm_daytime',
                                                'materially_cooler_evening'],
                           'semanticDedupeKey': 'warm_day_cool_evening'},
 'wet_walk': {'activity': 'walking',
              'allowedSurfaces': ['today_summary', 'current_detail'],
              'excludedWhen': ['known_hazard_in_window', 'future_only_surface'],
              'priorityBand': 'preparation',
              'requiredEvidence': ['fresh_current_rain_observation', 'walking_activity_context'],
              'semanticDedupeKey': 'wet_walk'}}

VARIANT_GUARDS = {'bike_after_dark_01': ['known_or_user_selected_activity_window'],
 'bike_cold_01': ['known_or_user_selected_activity_window'],
 'bike_cold_03': ['known_or_user_selected_activity_window'],
 'bike_cold_05': ['known_or_user_selected_activity_window'],
 'bike_cold_06': ['known_or_user_selected_activity_window'],
 'bike_heat_01': ['known_or_user_selected_activity_window'],
 'bike_heat_03': ['known_or_user_selected_activity_window'],
 'bike_heat_05': ['known_or_user_selected_activity_window'],
 'bike_heat_06': ['known_or_user_selected_activity_window'],
 'bike_rain_01': ['known_or_user_selected_activity_window'],
 'bike_rain_02': ['known_or_user_selected_activity_window'],
 'bike_rain_04': ['known_or_user_selected_activity_window'],
 'bike_rain_06': ['known_or_user_selected_activity_window'],
 'bike_wind_01': ['known_or_user_selected_activity_window'],
 'bike_wind_02': ['known_or_user_selected_activity_window'],
 'bike_wind_03': ['known_or_user_selected_activity_window'],
 'bike_wind_04': ['known_or_user_selected_activity_window'],
 'dog_after_dark_01': ['known_or_user_selected_activity_window'],
 'dog_cold_01': ['known_or_user_selected_activity_window'],
 'dog_cold_03': ['known_or_user_selected_activity_window'],
 'dog_cold_06': ['known_or_user_selected_activity_window'],
 'dog_heat_01': ['known_or_user_selected_activity_window'],
 'dog_heat_03': ['known_or_user_selected_activity_window'],
 'dog_heat_04': ['known_or_user_selected_activity_window'],
 'dog_rain_01': ['known_or_user_selected_activity_window'],
 'dog_rain_03': ['known_or_user_selected_activity_window'],
 'dog_rain_05': ['known_or_user_selected_activity_window'],
 'dog_rain_06': ['known_or_user_selected_activity_window'],
 'dog_wind_01': ['known_or_user_selected_activity_window'],
 'dog_wind_02': ['known_or_user_selected_activity_window'],
 'dog_wind_03': ['known_or_user_selected_activity_window'],
 'dog_wind_06': ['known_or_user_selected_activity_window'],
 'fog_outing_03': ['walking_activity_context'],
 'forecast_unavailable_02': ['current_forecast_context'],
 'snow_outing_05': ['walking_activity_context']}

GLOBAL_REQUIRED = ['correct_location_scope', 'correct_time_scope', 'source_freshness', 'field_availability', 'provider_semantics', 'units_or_named_index', 'precision_no_greater_than_source']
GLOBAL_EXCLUSIONS = ['applicable_urgent_official_hazard_requires_priority', 'contradicting_fresh_observation', 'expired_evidence', 'expired_action_window', 'irreconcilable_source_conflict']
PREDICATE_DEFINITIONS = ['complete_comparison_windows', 'cycling_activity_context', 'dog_activity_context', 'driving_commute_context', 'explicit_outdoor_event', 'known_cycling_activity_interval', 'known_dog_activity_interval', 'known_or_user_selected_activity_window', 'local_sunset_or_night_evidence', 'notable_gusts_outlook', 'refresh_may_resolve_absence', 'walking_activity_context', 'warm_or_hot_outlook']

FAMILY_IDS = set(FAMILY_CONTRACTS)
TEMPLATE_IDS = {f"{family}_{number:02d}" for family in FAMILY_IDS for number in range(1, 7)}
KNOWN_GUARDS = {
    guard for family in FAMILY_CONTRACTS.values() for guard in family['requiredEvidence']
} | {guard for guards in VARIANT_GUARDS.values() for guard in guards}
KNOWN_EXCLUSIONS = {
    guard for family in FAMILY_CONTRACTS.values() for guard in family['excludedWhen']
}
KNOWN_SURFACES = {
    'today_summary', 'current_detail', 'hourly_detail', 'day_detail',
    'plancast_summary', 'event_detail',
}
CATALOG_FIELDS = {'schemaVersion', 'catalogVersion', 'locale', 'editorialStatus', 'templates'}
CONTRACT_FIELDS = {
    'schemaVersion', 'catalogVersion', 'locale', 'status', 'purpose',
    'globalPolicy', 'families', 'variantOverrides', 'predicateDefinitions',
}
FAMILY_FIELDS = {
    'id', 'title', 'activity', 'allowedSurfaces', 'priorityBand',
    'requiredEvidence', 'excludedWhen', 'claimLimit', 'semanticDedupeKey', 'cooldownPolicy',
}
GLOBAL_FIELDS = {
    'zeroIncrementalRequests', 'requiredForEveryWeatherClaim', 'ordinaryTipExclusions',
    'alerts', 'activityBinding', 'locationBinding', 'probabilityBands', 'comparisons',
    'freshness', 'weatherOnlyCommutes', 'catalogDelivery', 'variantRule',
}
AUDIT_FIELDS = {
    'schemaVersion', 'catalogVersion', 'reviewType', 'reviewedTemplateCount',
    'reviewedFamilyCount', 'sourceOverrideCount', 'revisedTemplateCount', 'sourceSha256', 'variants', 'families',
}
AUDIT_VARIANT_FIELDS = {
    'templateId', 'familyId', 'disposition', 'originalText', 'reviewedText',
    'requiredEvidence', 'requiredGuards', 'excludedWhen', 'claimReview', 'activityReview', 'actionFocus',
}


def normalize(value: str) -> str:
    return ' '.join(re.findall(r"[a-z0-9]+", value.casefold()))


def read_json(path: Path) -> Any:
    raw = path.read_bytes()
    if len(raw) > MAX_FILE_BYTES:
        raise ValueError(f'{path.name}: exceeds {MAX_FILE_BYTES} byte limit')

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f'{path.name}: duplicate JSON field {key!r}')
            value[key] = item
        return value

    def reject_constant(value: str) -> None:
        raise ValueError(f'{path.name}: non-finite JSON number {value}')

    return json.loads(raw.decode('utf-8'), object_pairs_hook=unique_object,
                      parse_constant=reject_constant)


def validate(catalog: Any, contracts: Any, audit: Any = None) -> list[str]:
    errors: list[str] = []

    def require(condition: bool, label: str) -> None:
        if not condition:
            errors.append(label)

    def obj(value: Any, keys: set[str], at: str) -> bool:
        if not isinstance(value, dict):
            errors.append(f'{at}: expected object')
            return False
        require(set(value) == keys, f'{at}: unknown or missing fields {set(value) ^ keys}')
        return keys <= set(value)

    def string(value: Any, at: str, limit: int = 4096) -> bool:
        valid = isinstance(value, str) and bool(value.strip()) and value == value.strip()
        require(valid, f'{at}: expected nonempty trimmed string')
        if valid:
            require(len(value) <= limit, f'{at}: exceeds {limit} characters')
        return valid

    def strings(value: Any, at: str, allowed: set[str] | None = None) -> bool:
        valid = isinstance(value, list) and all(isinstance(v, str) for v in value)
        require(valid, f'{at}: expected string list')
        if not valid:
            return False
        require(len(value) == len(set(value)), f'{at}: duplicate values')
        if allowed is not None:
            require(set(value) <= allowed, f'{at}: unknown IDs {set(value) - allowed}')
        return True

    if not obj(catalog, CATALOG_FIELDS, 'catalog') or not obj(contracts, CONTRACT_FIELDS, 'contracts'):
        return errors
    for label, value in [('catalog', catalog), ('contracts', contracts)]:
        require(type(value['schemaVersion']) is int and value['schemaVersion'] == 1,
                f'{label}: unsupported schemaVersion')
        require(value['locale'] == 'en-US', f'{label}: unsupported locale')
        require(isinstance(value['catalogVersion'], str) and
                re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', value['catalogVersion']) is not None,
                f'{label}: catalogVersion must be a semantic version')
    require(catalog['catalogVersion'] == contracts['catalogVersion'], 'catalog/contract version mismatch')
    require(catalog['editorialStatus'] == 'repository_reviewed', 'catalog: unreviewed editorialStatus')
    require(contracts['status'] == 'repository_reviewed_contracts', 'contracts: unreviewed status')
    string(contracts['purpose'], 'contracts.purpose')

    policy = contracts['globalPolicy']
    if obj(policy, GLOBAL_FIELDS, 'globalPolicy'):
        require(policy['zeroIncrementalRequests'] is True, 'globalPolicy: local-only invariant changed')
        require(policy['requiredForEveryWeatherClaim'] == GLOBAL_REQUIRED,
                'globalPolicy: required evidence registry changed')
        require(policy['ordinaryTipExclusions'] == GLOBAL_EXCLUSIONS,
                'globalPolicy: exclusion registry changed')
        for key in GLOBAL_FIELDS - {'zeroIncrementalRequests', 'requiredForEveryWeatherClaim',
                                    'ordinaryTipExclusions', 'probabilityBands'}:
            string(policy[key], f'globalPolicy.{key}')
        bands = policy['probabilityBands']
        if obj(bands, {'possible', 'likely', 'note'}, 'probabilityBands'):
            for name, keys, expected in [
                ('possible', {'minInclusive', 'maxExclusive'}, {'minInclusive': 0.3, 'maxExclusive': 0.6}),
                ('likely', {'minInclusive', 'maxInclusive'}, {'minInclusive': 0.6, 'maxInclusive': 1}),
            ]:
                if obj(bands[name], keys, f'probabilityBands.{name}'):
                    require(all(type(x) in (int, float) for x in bands[name].values()) and bands[name] == expected,
                            f'probabilityBands.{name}: unsupported thresholds')
            string(bands['note'], 'probabilityBands.note')

    definitions = contracts['predicateDefinitions']
    if obj(definitions, set(PREDICATE_DEFINITIONS), 'predicateDefinitions'):
        for key, definition in definitions.items():
            string(definition, f'predicateDefinitions.{key}')

    families: dict[str, dict[str, Any]] = {}
    if not isinstance(contracts['families'], list):
        errors.append('families: expected list')
    else:
        for index, family in enumerate(contracts['families']):
            at = f'families[{index}]'
            if not obj(family, FAMILY_FIELDS, at):
                continue
            fid = family['id']
            if not isinstance(fid, str) or fid not in FAMILY_IDS:
                errors.append(f'{at}: unknown family ID')
                continue
            require(fid not in families, f'{at}: duplicate family ID {fid}')
            families[fid] = family
            at = fid
            for key in ('title', 'claimLimit', 'cooldownPolicy', 'semanticDedupeKey'):
                string(family[key], f'{at}.{key}')
            for key, allowed in [('allowedSurfaces', KNOWN_SURFACES),
                                 ('requiredEvidence', KNOWN_GUARDS), ('excludedWhen', KNOWN_EXCLUSIONS)]:
                strings(family[key], f'{at}.{key}', allowed)
            for key, expected in FAMILY_CONTRACTS[fid].items():
                # Removing a required guard or expanding a surface needs a coordinated code review.
                require(family[key] == expected, f'{at}.{key}: registered family contract changed')
    require(set(families) == FAMILY_IDS, 'families: missing registered family')

    overrides: dict[str, list[str]] = {}
    if not isinstance(contracts['variantOverrides'], list):
        errors.append('variantOverrides: expected list')
    else:
        for index, override in enumerate(contracts['variantOverrides']):
            at = f'variantOverrides[{index}]'
            if not obj(override, {'templateId', 'additionalRequiredEvidence', 'reason'}, at):
                continue
            tid = override['templateId']
            if not isinstance(tid, str) or tid not in VARIANT_GUARDS:
                errors.append(f'{at}: unknown override ID')
                continue
            require(tid not in overrides, f'{at}: duplicate override ID')
            strings(override['additionalRequiredEvidence'], at, KNOWN_GUARDS)
            overrides[tid] = override['additionalRequiredEvidence']
            string(override['reason'], f'{at}.reason')
    require(overrides == VARIANT_GUARDS, 'variantOverrides: original narrower guards changed or missing')

    templates: dict[str, dict[str, Any]] = {}
    normalized_texts: dict[str, str] = {}
    if not isinstance(catalog['templates'], list):
        errors.append('templates: expected list')
    else:
        for index, template in enumerate(catalog['templates']):
            at = f'templates[{index}]'
            if not obj(template, {'id', 'familyId', 'text', 'requiredGuards'}, at):
                continue
            tid, fid = template['id'], template['familyId']
            if not isinstance(tid, str) or tid not in TEMPLATE_IDS:
                errors.append(f'{at}: unknown template ID')
                continue
            require(tid not in templates, f'{at}: duplicate template ID {tid}')
            templates[tid] = template
            require(isinstance(fid, str) and fid in FAMILY_IDS and tid.rsplit('_', 1)[0] == fid,
                    f'{tid}: unknown or mismatched family ID')
            if strings(template['requiredGuards'], f'{tid}.requiredGuards', KNOWN_GUARDS):
                require(set(VARIANT_GUARDS.get(tid, [])) <= set(template['requiredGuards']),
                        f'{tid}: missing narrower variant guard')
            content = template['text']
            if not string(content, f'{tid}.text', MAX_TEXT_CHARS):
                continue
            require(6 <= len(content.split()) <= MAX_TEXT_WORDS, f'{tid}: outside 6–28 word budget')
            require('\n' not in content and '\r' not in content, f'{tid}: multiline content')
            require(not re.search(r'[{}<>]|\$\w|\{\{|\}\}|%\w|https?://|\[.+?\]', content),
                    f'{tid}: unsupported placeholder, markup, or URL')
            require(not re.search(r'\d|\b(?:guaranteed|risk-free|all-clear)\b', content, re.I),
                    f'{tid}: unsupported fixed numeric value or certainty claim')
            norm = normalize(content)
            require(norm not in normalized_texts, f'{tid}: duplicate wording with {normalized_texts.get(norm)}')
            normalized_texts[norm] = tid
            if 'umbrella' in content.lower() and fid in families:
                require('umbrella_conflict' in families[fid]['excludedWhen'],
                        f'{tid}: umbrella advice lacks gust/conflict exclusion')
        valid_items = [(tid, normalize(t['text'])) for tid, t in templates.items() if isinstance(t['text'], str)]
        for index, (left_id, left) in enumerate(valid_items):
            for right_id, right in valid_items[index + 1:]:
                if left_id.rsplit('_', 1)[0] != right_id.rsplit('_', 1)[0]:
                    continue
                if difflib.SequenceMatcher(None, left, right).ratio() >= 0.90:
                    errors.append(f'{left_id}/{right_id}: near-duplicate wording requires editorial revision')
    require(set(templates) == TEMPLATE_IDS, 'templates: missing registered template IDs (240 required)')

    if audit is not None and obj(audit, AUDIT_FIELDS, 'claim review'):
        require(audit['schemaVersion'] == 1 and type(audit['schemaVersion']) is int,
                'claim review: unsupported schema')
        require(audit['catalogVersion'] == catalog['catalogVersion'], 'claim review: version mismatch')
        require(audit['reviewedTemplateCount'] == 240 and audit['reviewedFamilyCount'] == 40 and
                audit['sourceOverrideCount'] == 35, 'claim review: review counts mismatch')
        string(audit['reviewType'], 'claim review.reviewType')
        hashes = audit['sourceSha256']
        if obj(hashes, {CATALOG_NAME, CONTRACT_NAME}, 'claim review.sourceSha256'):
            require(all(isinstance(v, str) and re.fullmatch(r'[a-f0-9]{64}', v) for v in hashes.values()),
                    'claim review: invalid source hashes')
        reviewed_families: set[str] = set()
        if not isinstance(audit['families'], list):
            errors.append('claim review.families: expected list')
        else:
            for row in audit['families']:
                if not obj(row, {'familyId', 'disposition', 'claimLimit', 'reviewNote', 'variantIds'},
                           'family review'):
                    continue
                fid = row['familyId']
                if not isinstance(fid, str) or fid not in families:
                    errors.append('family review: unknown family ID')
                    continue
                require(fid not in reviewed_families, f'{fid}: duplicate family review')
                reviewed_families.add(fid)
                require(row['claimLimit'] == families[fid]['claimLimit'], f'{fid}: stale family claim review')
                require(row['disposition'] == 'editorial_and_schema_reviewed_runtime_tests_separate',
                        f'{fid}: invalid family review disposition')
                string(row['reviewNote'], f'{fid}.reviewNote')
                if strings(row['variantIds'], f'{fid}.variantIds', TEMPLATE_IDS):
                    require(set(row['variantIds']) == {f'{fid}_{i:02d}' for i in range(1, 7)},
                            f'{fid}: incomplete family variant review')
            require(reviewed_families == FAMILY_IDS, 'family review: not every contract reviewed')
        reviewed: set[str] = set()
        focus: dict[str, set[str]] = {}
        revised = 0
        if not isinstance(audit['variants'], list):
            errors.append('claim review.variants: expected list')
        else:
            for index, row in enumerate(audit['variants']):
                at = f'claim review[{index}]'
                if not obj(row, AUDIT_VARIANT_FIELDS, at):
                    continue
                tid = row['templateId']
                if not isinstance(tid, str) or tid not in templates:
                    errors.append(f'{at}: unknown review ID')
                    continue
                require(tid not in reviewed, f'{at}: duplicate review ID')
                reviewed.add(tid)
                template = templates[tid]
                fid = template['familyId']
                if fid not in families:
                    continue
                family = families[fid]
                require(row['familyId'] == fid and row['reviewedText'] == template['text'],
                        f'{tid}: stale claim review text/family')
                for key in ('requiredEvidence', 'excludedWhen'):
                    require(row[key] == family[key], f'{tid}: stale claim review {key}')
                require(row['requiredGuards'] == template['requiredGuards'], f'{tid}: stale guard review')
                for key in ('originalText', 'claimReview', 'activityReview', 'actionFocus'):
                    string(row[key], f'{tid}.{key}')
                require(row['disposition'] in {'revised', 'retained_with_evidence_contract'},
                        f'{tid}: invalid review disposition')
                revised += row['disposition'] == 'revised'
                if isinstance(row['actionFocus'], str):
                    action = normalize(row['actionFocus'])
                    require(action not in focus.setdefault(fid, set()), f'{tid}: repeated action focus')
                    focus[fid].add(action)
            require(reviewed == TEMPLATE_IDS, 'claim review: not every variant reviewed')
            require(audit['revisedTemplateCount'] == revised, 'claim review: revised count mismatch')
    return errors


def self_test(catalog: dict, contracts: dict, audit: dict) -> int:
    """Mutate the valid fixture at the boundary; every malformed pack must fail closed."""
    mutations = [
        ('unknown catalog field', lambda c, f, a: c.update(remoteUrl='https://invalid.example')),
        ('unknown contract field', lambda c, f, a: f.update(execute='code')),
        ('unknown template field', lambda c, f, a: c['templates'][0].update(execute='code')),
        ('unknown family field', lambda c, f, a: f['families'][0].update(execute='code')),
        ('unknown template ID', lambda c, f, a: c['templates'][0].update(id='new_unregistered_01')),
        ('unknown family ID', lambda c, f, a: c['templates'][0].update(familyId='unknown')),
        ('unknown guard', lambda c, f, a: c['templates'][0].update(requiredGuards=['invented'])),
        ('unknown surface', lambda c, f, a: f['families'][0]['allowedSurfaces'].append('notification')),
        ('unknown priority', lambda c, f, a: f['families'][0].update(priorityBand='urgent')),
        ('placeholder', lambda c, f, a: c['templates'][0].update(text='Bring a coat because it will be {temperature} outside.')),
        ('duplicate wording', lambda c, f, a: c['templates'][0].update(text=c['templates'][1]['text'])),
        ('duplicate ID', lambda c, f, a: c['templates'][0].update(id=c['templates'][1]['id'])),
        ('overlong text', lambda c, f, a: c['templates'][0].update(text='Bring a coat. ' * 30)),
        ('missing family', lambda c, f, a: f['families'].pop()),
        ('missing variant', lambda c, f, a: c['templates'].pop()),
        ('changed band', lambda c, f, a: f['globalPolicy']['probabilityBands']['likely'].update(minInclusive=0.1)),
        ('boolean schema', lambda c, f, a: c.update(schemaVersion=True)),
        ('guard removed', lambda c, f, a: next(t for t in c['templates'] if t['id'] == 'dog_rain_01').update(requiredGuards=[])),
        ('missing source override', lambda c, f, a: f['variantOverrides'].pop()),
        ('weakened family evidence', lambda c, f, a: f['families'][0]['requiredEvidence'].pop()),
        ('stale review text', lambda c, f, a: a['variants'][0].update(reviewedText='Out of date')),
        ('missing review', lambda c, f, a: a['variants'].pop()),
        ('repeated action focus', lambda c, f, a: a['variants'][0].update(actionFocus=a['variants'][1]['actionFocus'])),
        ('network flag enabled', lambda c, f, a: f['globalPolicy'].update(zeroIncrementalRequests=False)),
    ]
    for name, mutate in mutations:
        c, f, a = copy.deepcopy((catalog, contracts, audit))
        mutate(c, f, a)
        if not validate(c, f, a):
            raise AssertionError(f'Validator accepted invalid case: {name}')
    return len(mutations)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=REPO_ROOT / 'assets/guidance')
    parser.add_argument('--audit', type=Path, default=REPO_ROOT / 'docs/guidance/variant_claim_review.json')
    parser.add_argument('--report', type=Path, help='Write deterministic validation and payload measurements as JSON')
    parser.add_argument('--self-test', action='store_true', help='Also reject 24 deliberately malformed catalog copies')
    args = parser.parse_args()
    try:
        catalog = read_json(args.directory / CATALOG_NAME)
        contracts = read_json(args.directory / CONTRACT_NAME)
        audit = read_json(args.audit)
        errors = validate(catalog, contracts, audit)
        if errors:
            print('\n'.join(errors), file=sys.stderr)
            return 1
        negative_cases = self_test(catalog, contracts, audit) if args.self_test else 0
        measurements = {}
        for name in (CATALOG_NAME, CONTRACT_NAME):
            raw = (args.directory / name).read_bytes()
            measurements[name] = {
                'rawBytes': len(raw), 'gzipBytes': len(gzip.compress(raw, compresslevel=9, mtime=0)),
                'sha256': hashlib.sha256(raw).hexdigest(),
            }
        report = {
            'valid': True, 'schemaVersion': catalog['schemaVersion'],
            'catalogVersion': catalog['catalogVersion'], 'templateCount': len(catalog['templates']),
            'familyCount': len(contracts['families']), 'sourceOverrideCount': len(VARIANT_GUARDS),
            'guardCount': len(KNOWN_GUARDS), 'reviewedTemplateCount': audit['reviewedTemplateCount'],
            'revisedTemplateCount': audit['revisedTemplateCount'],
            'maxTextChars': max(len(t['text']) for t in catalog['templates']),
            'maxTextWords': max(len(t['text'].split()) for t in catalog['templates']),
            'negativeValidationCasesPassed': negative_cases, 'files': measurements,
            'combinedRawBytes': sum(m['rawBytes'] for m in measurements.values()),
            'combinedGzipBytes': sum(m['gzipBytes'] for m in measurements.values()),
            'gzipMeasurement': 'Each checked-in UTF-8 JSON file compressed independently with gzip level 9 and mtime 0.',
        }
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
        print(json.dumps(report, indent=2))
        return 0
    except (OSError, UnicodeError, ValueError, TypeError, KeyError, AssertionError) as error:
        print(f'Catalog validation failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
