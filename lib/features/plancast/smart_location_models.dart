import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/weather_models.dart';

String smartLocationSignature(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString().substring(0, 24);

String normalizeLocationText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Shared banner, preview and application scope. Timed events must fit wholly
/// inside the chosen interval. Floating all-day dates use the device civil
/// dates displayed by the picker, with an exclusive, upward-rounded end.
bool locationIntervalFits(
    {required DateTime start,
    required DateTime end,
    required DateTime windowStart,
    required DateTime windowEnd,
    DateTime? allDayStart,
    DateTime? allDayEnd}) {
  if (!windowEnd.isAfter(windowStart)) return false;
  if (allDayStart != null || allDayEnd != null) {
    if (allDayStart == null ||
        allDayEnd == null ||
        !allDayEnd.isAfter(allDayStart)) {
      return false;
    }
    final localStart = windowStart.toLocal(), localEnd = windowEnd.toLocal();
    final first =
        DateTime.utc(localStart.year, localStart.month, localStart.day);
    var exclusiveEnd =
        DateTime.utc(localEnd.year, localEnd.month, localEnd.day);
    final midnight = localEnd.hour == 0 &&
        localEnd.minute == 0 &&
        localEnd.second == 0 &&
        localEnd.millisecond == 0 &&
        localEnd.microsecond == 0;
    if (!midnight) exclusiveEnd = exclusiveEnd.add(const Duration(days: 1));
    final eventFirst =
        DateTime.utc(allDayStart.year, allDayStart.month, allDayStart.day);
    final eventEnd =
        DateTime.utc(allDayEnd.year, allDayEnd.month, allDayEnd.day);
    return !eventFirst.isBefore(first) && !eventEnd.isAfter(exclusiveEnd);
  }
  return end.isAfter(start) &&
      !start.isBefore(windowStart) &&
      !end.isAfter(windowEnd);
}

enum LocationSource {
  userOverride,
  calendarCoordinates,
  calendarAddress,
  inferredVenue,
  inferredCity,
  recurringRule,
  savedPlace,
  calendarDefault,
  confirmedTrip,
  currentArea,
  lastKnownArea,
  defaultArea,
  unavailable
}

enum LocationPrecision { venue, address, coordinates, city, area, unknown }

enum LocationEvidenceQuality {
  confirmed,
  supported,
  assumed,
  unresolved,
  conflict
}

enum EventParticipation { unknown, physical, online, hybrid }

enum LocationRuleScope { occurrence, seriesMissing, calendarDefault, legacy }

enum LocationChoiceKind { place, currentArea, online, savedPlace }

enum LocationLookupKind { city, address, venue }

enum LocationLookupStatus {
  matched,
  ambiguous,
  unavailable,
  unsupported,
  failed
}

/// A genuine device observation, independent of the browsed Today location.
class DeviceAreaSample {
  const DeviceAreaSample(
      {required this.candidate,
      required this.observedAt,
      required this.accuracyMeters,
      this.locality,
      this.permissionGranted = true,
      this.approximate = false,
      this.provenance = 'device'});
  final LocationCandidate candidate;
  final DateTime observedAt;
  final double accuracyMeters;
  final String? locality;
  final bool permissionGranted, approximate;
  final String provenance;
  bool get hasValidCoordinates =>
      candidate.hasValidCoordinates &&
      accuracyMeters.isFinite &&
      accuracyMeters >= 0;
  Map<String, dynamic> toJson() => {
        'candidate': candidate.toJson(),
        'observedAt': observedAt.toUtc().toIso8601String(),
        'accuracyMeters': accuracyMeters,
        'locality': locality,
        'permissionGranted': permissionGranted,
        'approximate': approximate,
        'provenance': provenance,
      };
  factory DeviceAreaSample.fromJson(Map<String, dynamic> json) =>
      DeviceAreaSample(
          candidate: LocationCandidate.fromJson(
              Map<String, dynamic>.from(json['candidate'] as Map)),
          observedAt: DateTime.parse(json['observedAt'] as String).toUtc(),
          accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
          locality: json['locality'] as String?,
          permissionGranted: json['permissionGranted'] != false,
          approximate: json['approximate'] == true,
          provenance: json['provenance'] as String? ?? 'device');
}

/// Derived event evidence. Resolution time is deliberately excluded from the
/// signature, so a rebuild cannot invalidate identical weather or briefing copy.
class ResolvedLocation {
  ResolvedLocation(
      {this.candidate,
      required this.source,
      required this.precision,
      required this.evidenceQuality,
      required this.reason,
      required this.resolvedAt,
      this.provider = 'local',
      this.observedAt,
      this.validFrom,
      this.validUntil,
      this.provisional = false,
      this.reviewSuggested = false,
      String evidenceKey = ''})
      : signature = smartLocationSignature([
          source.name,
          precision.name,
          evidenceQuality.name,
          candidate?.lat.toStringAsFixed(5),
          candidate?.lon.toStringAsFixed(5),
          candidate?.displayName,
          provider,
          observedAt?.toUtc().toIso8601String(),
          validFrom?.toUtc().toIso8601String(),
          validUntil?.toUtc().toIso8601String(),
          provisional,
          reviewSuggested,
          evidenceKey
        ]);
  final LocationCandidate? candidate;
  final LocationSource source;
  final LocationPrecision precision;
  final LocationEvidenceQuality evidenceQuality;
  final String reason, provider, signature;
  final DateTime resolvedAt;
  final DateTime? observedAt, validFrom, validUntil;
  final bool provisional, reviewSuggested;
  bool get hasWeatherBasis =>
      candidate?.hasValidCoordinates == true &&
      source != LocationSource.unavailable &&
      evidenceQuality != LocationEvidenceQuality.conflict &&
      evidenceQuality != LocationEvidenceQuality.unresolved;
  bool get venueConfirmed =>
      hasWeatherBasis &&
      evidenceQuality == LocationEvidenceQuality.confirmed &&
      {
        LocationPrecision.venue,
        LocationPrecision.address,
        LocationPrecision.coordinates
      }.contains(precision);
  bool get areaAssumed =>
      hasWeatherBasis && evidenceQuality == LocationEvidenceQuality.assumed;
  bool get automatic =>
      hasWeatherBasis && source != LocationSource.userOverride;
  String get displayLabel => candidate?.displayName ?? 'Location unavailable';
  String get sourceLabel => switch (source) {
        LocationSource.userOverride => 'You chose this',
        LocationSource.calendarCoordinates ||
        LocationSource.calendarAddress =>
          'From calendar',
        LocationSource.inferredVenue ||
        LocationSource.inferredCity =>
          'Found in event',
        LocationSource.recurringRule => 'Series location',
        LocationSource.savedPlace => 'Saved place',
        LocationSource.calendarDefault => 'Calendar default',
        LocationSource.confirmedTrip => 'Trip area',
        LocationSource.currentArea => 'Using your area',
        LocationSource.lastKnownArea => 'Last known area',
        LocationSource.defaultArea => 'Your default area',
        LocationSource.unavailable => 'Location needed',
      };
}

class LocationChoice {
  const LocationChoice.place(LocationCandidate this.candidate)
      : kind = LocationChoiceKind.place,
        savedPlaceId = null;
  const LocationChoice.currentArea()
      : kind = LocationChoiceKind.currentArea,
        candidate = null,
        savedPlaceId = null;
  const LocationChoice.online()
      : kind = LocationChoiceKind.online,
        candidate = null,
        savedPlaceId = null;
  const LocationChoice.savedPlace(String id)
      : kind = LocationChoiceKind.savedPlace,
        candidate = null,
        savedPlaceId = id;
  final LocationChoiceKind kind;
  final LocationCandidate? candidate;
  final String? savedPlaceId;
  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'candidate': candidate?.toJson(),
        'savedPlaceId': savedPlaceId
      };
  static LocationChoice? fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'place':
        final place = _candidate(json['candidate']);
        return place == null ? null : LocationChoice.place(place);
      case 'currentArea':
        return const LocationChoice.currentArea();
      case 'online':
        return const LocationChoice.online();
      case 'savedPlace':
        final id = json['savedPlaceId'];
        return id is String && id.isNotEmpty
            ? LocationChoice.savedPlace(id)
            : null;
      default:
        return null;
    }
  }
}

class SavedPlanCastPlace {
  const SavedPlanCastPlace(
      {required this.id,
      required this.label,
      required this.candidate,
      required this.createdAt,
      this.aliases = const [],
      this.provider = 'user',
      this.providerPlaceId,
      this.providerExpiresAt});
  final String id, label, provider;
  final String? providerPlaceId;
  final LocationCandidate candidate;
  final DateTime createdAt;
  final DateTime? providerExpiresAt;
  final List<String> aliases;
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'candidate': candidate.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'aliases': aliases,
        'provider': provider,
        'providerPlaceId': providerPlaceId,
        'providerExpiresAt': providerExpiresAt?.toUtc().toIso8601String()
      };
  static SavedPlanCastPlace? fromJson(Map<String, dynamic> json) {
    final place = _candidate(json['candidate']);
    final created = _date(json['createdAt']);
    if (place == null || created == null || json['id'] is! String) return null;
    return SavedPlanCastPlace(
        id: json['id'] as String,
        label: json['label'] as String? ?? place.name,
        candidate: place,
        createdAt: created,
        aliases: _strings(json['aliases']).toList(),
        provider: json['provider'] as String? ?? 'user',
        providerPlaceId: json['providerPlaceId'] as String?,
        providerExpiresAt: _date(json['providerExpiresAt']));
  }
}

/// Persistent user intent is separate from a provider response's expiry.
class ScopedLocationRule {
  const ScopedLocationRule(
      {required this.id,
      required this.scope,
      required this.targetId,
      required this.choice,
      required this.createdAt,
      this.enabled = true,
      this.useAutomatic = false,
      this.providerExpiresAt});
  final String id, targetId;
  final LocationRuleScope scope;
  final LocationChoice choice;
  final DateTime createdAt;
  final bool enabled;

  /// An occurrence-only reset can bypass migrated series intent without
  /// deleting the user's choice for sibling occurrences. The placeholder
  /// [choice] is ignored while this flag is true.
  final bool useAutomatic;
  final DateTime? providerExpiresAt;
  Map<String, dynamic> toJson() => {
        'id': id,
        'scope': scope.name,
        'targetId': targetId,
        'choice': choice.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'enabled': enabled,
        if (useAutomatic) 'useAutomatic': true,
        'providerExpiresAt': providerExpiresAt?.toUtc().toIso8601String()
      };
  static ScopedLocationRule? fromJson(Map<String, dynamic> json) {
    final choice = json['choice'] is Map
        ? LocationChoice.fromJson(
            Map<String, dynamic>.from(json['choice'] as Map))
        : null;
    final created = _date(json['createdAt']);
    final scope = LocationRuleScope.values
        .where((value) => value.name == json['scope'])
        .firstOrNull;
    if (choice == null ||
        created == null ||
        scope == null ||
        json['id'] is! String ||
        json['targetId'] is! String) {
      return null;
    }
    return ScopedLocationRule(
        id: json['id'] as String,
        scope: scope,
        targetId: json['targetId'] as String,
        choice: choice,
        createdAt: created,
        enabled: json['enabled'] != false,
        useAutomatic: scope == LocationRuleScope.occurrence &&
            json['useAutomatic'] == true,
        providerExpiresAt: _date(json['providerExpiresAt']));
  }
}

class ConfirmedTripContext {
  const ConfirmedTripContext(
      {required this.id,
      required this.label,
      required this.candidate,
      required this.startUtc,
      required this.endUtc,
      required this.calendarIds,
      required this.createdAt,
      this.eventIds = const {}});
  final String id, label;
  final LocationCandidate candidate;
  final DateTime startUtc, endUtc, createdAt;
  final Set<String> calendarIds, eventIds;
  bool applies(
          {required String calendarId,
          required String eventId,
          required DateTime start,
          required DateTime end,
          required DateTime now,
          DateTime? allDayStart,
          DateTime? allDayEnd}) =>
      candidate.hasValidCoordinates &&
      endUtc.isAfter(now) &&
      calendarIds.contains(calendarId) &&
      (eventIds.isEmpty || eventIds.contains(eventId)) &&
      locationIntervalFits(
          start: start,
          end: end,
          windowStart: startUtc,
          windowEnd: endUtc,
          allDayStart: allDayStart,
          allDayEnd: allDayEnd);
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'candidate': candidate.toJson(),
        'startUtc': startUtc.toUtc().toIso8601String(),
        'endUtc': endUtc.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'calendarIds': calendarIds.toList()..sort(),
        'eventIds': eventIds.toList()..sort()
      };
  static ConfirmedTripContext? fromJson(Map<String, dynamic> json) {
    final candidate = _candidate(json['candidate']);
    final start = _date(json['startUtc']);
    final end = _date(json['endUtc']);
    final created = _date(json['createdAt']);
    if (candidate == null ||
        start == null ||
        end == null ||
        created == null ||
        !end.isAfter(start) ||
        json['id'] is! String) {
      return null;
    }
    return ConfirmedTripContext(
        id: json['id'] as String,
        label: json['label'] as String? ?? candidate.name,
        candidate: candidate,
        startUtc: start,
        endUtc: end,
        createdAt: created,
        calendarIds: _strings(json['calendarIds']),
        eventIds: _strings(json['eventIds']));
  }
}

class SmartLocationState {
  const SmartLocationState(
      {this.onlineMatchingEnabled = false,
      this.currentAreaFallbackEnabled = true,
      this.defaultArea,
      this.savedPlaces = const [],
      this.rules = const [],
      this.trips = const [],
      this.dismissedTravelNotices = const {},
      this.explanationShown = false});
  static const version = 2;
  final bool onlineMatchingEnabled,
      currentAreaFallbackEnabled,
      explanationShown;
  final LocationCandidate? defaultArea;
  final List<SavedPlanCastPlace> savedPlaces;
  final List<ScopedLocationRule> rules;
  final List<ConfirmedTripContext> trips;
  final Set<String> dismissedTravelNotices;
  SmartLocationState copyWith(
          {bool? onlineMatchingEnabled,
          bool? currentAreaFallbackEnabled,
          LocationCandidate? defaultArea,
          bool clearDefaultArea = false,
          List<SavedPlanCastPlace>? savedPlaces,
          List<ScopedLocationRule>? rules,
          List<ConfirmedTripContext>? trips,
          Set<String>? dismissedTravelNotices,
          bool? explanationShown}) =>
      SmartLocationState(
          onlineMatchingEnabled:
              onlineMatchingEnabled ?? this.onlineMatchingEnabled,
          currentAreaFallbackEnabled:
              currentAreaFallbackEnabled ?? this.currentAreaFallbackEnabled,
          defaultArea:
              clearDefaultArea ? null : defaultArea ?? this.defaultArea,
          savedPlaces: savedPlaces ?? this.savedPlaces,
          rules: rules ?? this.rules,
          trips: trips ?? this.trips,
          dismissedTravelNotices:
              dismissedTravelNotices ?? this.dismissedTravelNotices,
          explanationShown: explanationShown ?? this.explanationShown);
  SmartLocationState prune(DateTime now) =>
      copyWith(trips: trips.where((t) => t.endUtc.isAfter(now)).toList());
  Map<String, dynamic> toJson() => {
        'version': version,
        'onlineMatchingEnabled': onlineMatchingEnabled,
        'currentAreaFallbackEnabled': currentAreaFallbackEnabled,
        'defaultArea': defaultArea?.toJson(),
        'savedPlaces': savedPlaces.map((p) => p.toJson()).toList(),
        'rules': rules.map((r) => r.toJson()).toList(),
        'trips': trips.map((t) => t.toJson()).toList(),
        'dismissedTravelNotices': dismissedTravelNotices.toList()..sort(),
        'explanationShown': explanationShown
      };
  factory SmartLocationState.fromStorage(Map<String, dynamic> storage) {
    final json = storage['smartLocations'] is Map
        ? Map<String, dynamic>.from(storage['smartLocations'] as Map)
        : storage;
    final rules = _rows(json['rules'])
        .map(ScopedLocationRule.fromJson)
        .whereType<ScopedLocationRule>()
        .toList();
    // Old hashed keys can be occurrence keys or unchanged-venue recurring keys.
    // Keep both until an actual event identifies their scope; never use titles.
    if (json['version'] != version && storage['overrides'] is Map) {
      final old = Map<String, dynamic>.from(storage['overrides'] as Map);
      for (final entry in old.entries) {
        if (entry.value is! Map) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        final venue = _candidate(value['venue']);
        final choice = value['environment'] == 'online'
            ? const LocationChoice.online()
            : venue == null
                ? null
                : LocationChoice.place(venue);
        if (choice != null) {
          rules.add(ScopedLocationRule(
              id: 'legacy-${entry.key}',
              scope: LocationRuleScope.legacy,
              targetId: entry.key,
              choice: choice,
              createdAt: DateTime.utc(1970),
              providerExpiresAt: _date(value['expiresAt'])));
        }
      }
    }
    return SmartLocationState(
        onlineMatchingEnabled: json['onlineMatchingEnabled'] == true,
        currentAreaFallbackEnabled: json['currentAreaFallbackEnabled'] != false,
        defaultArea: _candidate(json['defaultArea']),
        savedPlaces: _rows(json['savedPlaces'])
            .map(SavedPlanCastPlace.fromJson)
            .whereType<SavedPlanCastPlace>()
            .toList(),
        rules: rules,
        trips: _rows(json['trips'])
            .map(ConfirmedTripContext.fromJson)
            .whereType<ConfirmedTripContext>()
            .toList(),
        dismissedTravelNotices: _strings(json['dismissedTravelNotices']),
        explanationShown: json['explanationShown'] == true);
  }
}

class LocationLookupRequest {
  LocationLookupRequest(
      {required this.kind, required this.query, this.cityHint})
      : key = smartLocationSignature([
          kind.name,
          normalizeLocationText(query),
          cityHint == null ? null : normalizeLocationText(cityHint)
        ]);
  final LocationLookupKind kind;
  final String query;
  final String? cityHint;
  final String key;
}

class LocationLookupResult {
  const LocationLookupResult(
      {required this.status,
      required this.provider,
      required this.observedAt,
      required this.expiresAt,
      this.candidates = const [],
      this.precision = LocationPrecision.unknown,
      this.reason = ''});
  final LocationLookupStatus status;
  final String provider, reason;
  final DateTime observedAt, expiresAt;
  final List<LocationCandidate> candidates;
  final LocationPrecision precision;
  bool usableAt(DateTime now) =>
      status == LocationLookupStatus.matched &&
      candidates.length == 1 &&
      candidates.single.hasValidCoordinates &&
      expiresAt.isAfter(now) &&
      !observedAt.isAfter(now.add(const Duration(minutes: 5)));
}

class EventLocationEvidence {
  const EventLocationEvidence(
      {this.coordinates,
      this.addressQuery,
      this.venueQuery,
      this.cityQuery,
      this.virtualOnly = false,
      this.hybrid = false,
      this.conflicting = false,
      this.fromCalendarField = false,
      this.unresolvedMapDestination = false,
      this.reason = '',
      this.isStay = false});
  final LocationCandidate? coordinates;
  final String? addressQuery, venueQuery, cityQuery;
  final bool virtualOnly,
      hybrid,
      conflicting,
      fromCalendarField,
      isStay,
      unresolvedMapDestination;
  final String reason;
  bool get hasDestinationEvidence =>
      unresolvedMapDestination ||
      coordinates != null ||
      addressQuery != null ||
      venueQuery != null ||
      cityQuery != null;
  String get signature => smartLocationSignature([
        coordinates?.lat,
        coordinates?.lon,
        addressQuery,
        venueQuery,
        cityQuery,
        virtualOnly,
        hybrid,
        conflicting,
        unresolvedMapDestination
      ]);
  List<LocationLookupRequest> get requests => [
        if (addressQuery != null)
          LocationLookupRequest(
              kind: LocationLookupKind.address,
              query: addressQuery!,
              cityHint: cityQuery),
        if (venueQuery != null)
          LocationLookupRequest(
              kind: LocationLookupKind.venue,
              query: venueQuery!,
              cityHint: cityQuery),
        if (cityQuery != null)
          LocationLookupRequest(
              kind: LocationLookupKind.city, query: cityQuery!),
      ];
}

class LocationResolution {
  const LocationResolution(
      {required this.location,
      required this.participation,
      required this.evidence,
      this.lookupRequests = const []});
  final ResolvedLocation location;
  final EventParticipation participation;
  final EventLocationEvidence evidence;
  final List<LocationLookupRequest> lookupRequests;
  bool get isOnline => participation == EventParticipation.online;
}

LocationCandidate? _candidate(Object? value) {
  if (value is! Map) return null;
  try {
    final candidate =
        LocationCandidate.fromJson(Map<String, dynamic>.from(value));
    return candidate.hasValidCoordinates ? candidate : null;
  } catch (_) {
    return null;
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
Set<String> _strings(Object? value) => value is List
    ? value.whereType<String>().where((s) => s.isNotEmpty).toSet()
    : {};
List<Map<String, dynamic>> _rows(Object? value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
