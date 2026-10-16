import 'dart:math' as math;

import '../../models/weather_models.dart';
import 'location_resolver.dart';
import 'plancast_models.dart';

double locationDistanceMeters(LocationCandidate a, LocationCandidate b) {
  const radius = 6371000.0;
  double radians(double value) => value * math.pi / 180;
  final dLat = radians(b.lat - a.lat), dLon = radians(b.lon - a.lon);
  final square = math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(a.lat)) *
          math.cos(radians(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return radius *
      2 *
      math.atan2(
          math.sqrt(square.clamp(0, 1)), math.sqrt((1 - square).clamp(0, 1)));
}

class SmartTravelPolicy {
  const SmartTravelPolicy(
      {this.refreshDistanceMeters = 1500,
      this.travelDistanceMeters = 50000,
      this.corroborationDistanceMeters = 15000,
      this.stabilityDuration = const Duration(minutes: 5),
      this.nearTermWindow = const Duration(hours: 48),
      this.locationPolicy = const SmartLocationPolicy()});
  final double refreshDistanceMeters,
      travelDistanceMeters,
      corroborationDistanceMeters;
  final Duration stabilityDuration, nearTermWindow;
  final SmartLocationPolicy locationPolicy;
}

class DeviceAreaMovement {
  const DeviceAreaMovement(
      {required this.current,
      this.previous,
      this.refreshNeeded = false,
      this.travelConfirmed = false,
      this.distanceMeters = 0,
      this.reason = ''});
  final DeviceAreaSample current;
  final DeviceAreaSample? previous;
  final bool refreshNeeded, travelConfirmed;
  final double distanceMeters;
  final String reason;
}

/// Foreground observations only. Refresh and grouped travel notice thresholds
/// are separate; ignoring a notice never prevents using the new current area.
class SmartTravelTracker {
  SmartTravelTracker({this.policy = const SmartTravelPolicy()});
  final SmartTravelPolicy policy;
  DeviceAreaSample? _anchor, _lastRefresh, _candidate, _latestObservation;

  static String? _locality(DeviceAreaSample sample) {
    final name =
        normalizeLocationText(sample.locality ?? sample.candidate.name);
    return {'your area', 'current area', 'device location', ''}.contains(name)
        ? null
        : name;
  }

  bool _nearCandidate(DeviceAreaSample sample, DeviceAreaSample candidate) =>
      locationDistanceMeters(candidate.candidate, sample.candidate) <=
      policy.corroborationDistanceMeters +
          candidate.accuracyMeters +
          sample.accuracyMeters;

  DeviceAreaMovement observe(DeviceAreaSample sample, {required DateTime now}) {
    if (!policy.locationPolicy.accepts(sample, now, current: true)) {
      return DeviceAreaMovement(
          current: sample,
          reason: 'Observation is not current or is too uncertain.');
    }
    var anchor = _anchor;
    if (anchor == null) {
      _anchor = sample;
      _lastRefresh = sample;
      _latestObservation = sample;
      return DeviceAreaMovement(
          current: sample,
          refreshNeeded: true,
          reason: 'Initial usable device area.');
    }
    final latest = _latestObservation!;
    if (sample.observedAt.isBefore(latest.observedAt)) {
      return DeviceAreaMovement(
          current: sample, previous: anchor, reason: 'Older observation.');
    }
    final duplicate = sample.observedAt.isAtSameMomentAs(latest.observedAt);
    if (duplicate) {
      // Reverse-locality enrichment of one measurement is not a second fix.
      // It may label the anchor/candidate, but never corroborate travel alone.
      if (_locality(sample) != null) {
        if (anchor.observedAt.isAtSameMomentAs(sample.observedAt)) {
          _anchor = sample;
          anchor = sample;
        }
        if (_lastRefresh?.observedAt.isAtSameMomentAs(sample.observedAt) ==
            true) {
          _lastRefresh = sample;
        }
        if (_candidate?.observedAt.isAtSameMomentAs(sample.observedAt) ==
            true) {
          _candidate = sample;
        }
      }
    }
    _latestObservation = sample;
    final distance = locationDistanceMeters(anchor.candidate, sample.candidate);
    final lowerBound =
        math.max(0, distance - anchor.accuracyMeters - sample.accuracyMeters);
    final refreshBase = _lastRefresh ?? anchor;
    final refreshDistance =
        locationDistanceMeters(refreshBase.candidate, sample.candidate) -
            refreshBase.accuracyMeters -
            sample.accuracyMeters;
    final refresh =
        !duplicate && refreshDistance >= policy.refreshDistanceMeters;
    if (refresh) _lastRefresh = sample;
    var newLocality = _locality(sample);
    final candidate = _candidate;
    if (newLocality == null &&
        candidate != null &&
        _nearCandidate(sample, candidate)) {
      // A later raw fix can corroborate an already named destination area.
      newLocality = _locality(candidate);
    }
    final changedLocality =
        newLocality != null && newLocality != _locality(anchor);
    if (lowerBound < policy.travelDistanceMeters || !changedLocality) {
      if (newLocality != null || lowerBound < policy.travelDistanceMeters) {
        _candidate = null;
      }
      return DeviceAreaMovement(
          current: sample,
          previous: anchor,
          refreshNeeded: refresh,
          distanceMeters: distance,
          reason:
              'Local movement or boundary jitter does not need a travel notice.');
    }
    if (candidate == null ||
        !_nearCandidate(sample, candidate) ||
        _locality(candidate) != newLocality) {
      _candidate = sample;
      return DeviceAreaMovement(
          current: sample,
          previous: anchor,
          refreshNeeded: refresh,
          distanceMeters: distance,
          reason:
              'Waiting for a corroborating foreground observation before a grouped notice.');
    }
    if (duplicate ||
        sample.observedAt.difference(candidate.observedAt) <
            policy.stabilityDuration) {
      return DeviceAreaMovement(
          current: sample,
          previous: anchor,
          refreshNeeded: refresh,
          distanceMeters: distance,
          reason:
              'The new area is not yet corroborated by distinct measurements over the stability interval.');
    }
    final namedSample = _locality(sample) != null
        ? sample
        : DeviceAreaSample(
            candidate: LocationCandidate(
                name: candidate.candidate.name,
                country: candidate.candidate.country,
                state: candidate.candidate.state,
                lat: sample.candidate.lat,
                lon: sample.candidate.lon,
                source: sample.candidate.source),
            observedAt: sample.observedAt,
            accuracyMeters: sample.accuracyMeters,
            locality: candidate.locality,
            permissionGranted: sample.permissionGranted,
            approximate: sample.approximate,
            provenance: sample.provenance);
    _anchor = namedSample;
    _lastRefresh = namedSample;
    _candidate = null;
    return DeviceAreaMovement(
        current: namedSample,
        previous: anchor,
        refreshNeeded: true,
        travelConfirmed: true,
        distanceMeters: distance,
        reason:
            'A changed locality and accuracy-aware displacement were corroborated by foreground observations.');
  }

  void clear() {
    _anchor = null;
    _lastRefresh = null;
    _candidate = null;
    _latestObservation = null;
  }
}

class TravelNotice {
  const TravelNotice(
      {required this.id,
      required this.area,
      required this.windowStart,
      required this.windowEnd,
      required this.calendarIds,
      required this.eventIds,
      required this.createdAt});
  final String id;
  final LocationCandidate area;
  final DateTime windowStart, windowEnd, createdAt;
  final Set<String> calendarIds, eventIds;
  int get affectedCount => eventIds.length;
  String get message =>
      'Now using ${area.name} for $affectedCount ${affectedCount == 1 ? 'plan' : 'plans'} without a location.';
}

class SmartTravelNotices {
  const SmartTravelNotices({this.policy = const SmartTravelPolicy()});
  final SmartTravelPolicy policy;
  TravelNotice? build(
      {required DeviceAreaMovement movement,
      required List<PlanCastEventWeather> events,
      required SmartLocationState state,
      required DateTime now,
      DateTime? windowStart,
      DateTime? windowEnd,
      Set<String>? calendarIds}) {
    if (!movement.travelConfirmed) return null;
    final start = windowStart ?? now,
        end = windowEnd ?? now.add(policy.nearTermWindow);
    if (!end.isAfter(start)) return null;
    final affected = events
        .where((item) =>
            !item.isOnline &&
            {LocationSource.currentArea, LocationSource.lastKnownArea}
                .contains(item.resolvedLocation?.source) &&
            locationIntervalFits(
                start: item.event.startUtc,
                end: item.event.endUtc,
                windowStart: start,
                windowEnd: end,
                allDayStart: item.event.allDayStart,
                allDayEnd: item.event.allDayEnd) &&
            (calendarIds == null ||
                calendarIds.contains(item.event.calendarId)))
        .toList();
    if (affected.isEmpty) return null;
    final selected =
        calendarIds ?? affected.map((item) => item.event.calendarId).toSet();
    String day(DateTime value) =>
        '${value.toLocal().year}-${value.toLocal().month}-${value.toLocal().day}';
    final area = movement.current.candidate;
    final id = smartLocationSignature([
      'travel',
      area.lat.toStringAsFixed(1),
      area.lon.toStringAsFixed(1),
      day(start),
      day(end),
      selected.toList()..sort()
    ]);
    if (state.dismissedTravelNotices.contains(id)) return null;
    return TravelNotice(
        id: id,
        area: area,
        windowStart: start,
        windowEnd: end,
        calendarIds: selected,
        eventIds: affected.map((item) => item.event.id).toSet(),
        createdAt: now);
  }
}

class TripSuggestion {
  const TripSuggestion(
      {required this.id,
      required this.area,
      required this.startUtc,
      required this.endUtc,
      required this.calendarIds,
      required this.sourceEventId});
  final String id, sourceEventId;
  final LocationCandidate area;
  final DateTime startUtc, endUtc;
  final Set<String> calendarIds;
  String get message => 'Use ${area.name} for other plans during these dates?';
  static TripSuggestion? fromEvent(PlanCastEventWeather item) {
    final location = item.resolvedLocation;
    if (location?.hasWeatherBasis != true ||
        item.isOnline ||
        !item.event.hasDuration ||
        !const EventLocationExtractor().extract(item.event).isStay ||
        !{
          LocationSource.calendarAddress,
          LocationSource.calendarCoordinates,
          LocationSource.inferredCity,
          LocationSource.inferredVenue,
          LocationSource.userOverride
        }.contains(location!.source)) {
      return null;
    }
    return TripSuggestion(
        id: smartLocationSignature(
            ['trip-suggestion', item.event.id, location.signature]),
        area: location.candidate!,
        startUtc: item.event.startUtc,
        endUtc: item.event.endUtc,
        calendarIds: {item.event.calendarId},
        sourceEventId: item.event.id);
  }
}

/// Undo restores only the affected trip rule, preserving unrelated later edits.
class SmartLocationUndo {
  const SmartLocationUndo({required this.addedTripId, this.previousTrip});
  final String addedTripId;
  final ConfirmedTripContext? previousTrip;
  SmartLocationState apply(SmartLocationState current) =>
      current.copyWith(trips: [
        ...current.trips.where((trip) => trip.id != addedTripId),
        if (previousTrip != null) previousTrip!
      ]);
}

class SmartLocationMutation {
  const SmartLocationMutation({required this.state, required this.undo});
  final SmartLocationState state;
  final SmartLocationUndo undo;
}

SmartLocationMutation applyConfirmedTrip(
    SmartLocationState state, ConfirmedTripContext trip) {
  if (!trip.candidate.hasValidCoordinates ||
      trip.calendarIds.isEmpty ||
      !trip.endUtc.isAfter(trip.startUtc)) {
    throw ArgumentError(
        'A trip choice needs a valid area, explicit calendars, and a bounded interval.');
  }
  final previous = state.trips.where((item) => item.id == trip.id).firstOrNull;
  return SmartLocationMutation(
      state: state.copyWith(
          trips: [...state.trips.where((item) => item.id != trip.id), trip]),
      undo: SmartLocationUndo(addedTripId: trip.id, previousTrip: previous));
}
