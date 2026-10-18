import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/features/plancast/forecast_change_detector.dart';
import 'package:grumpy_skies/features/plancast/plancast_briefing.dart';
import 'package:grumpy_skies/features/plancast/plancast_models.dart';
import 'package:grumpy_skies/features/plancast/plancast_notification_planner.dart';
import 'package:grumpy_skies/models/weather_models.dart';

final now = DateTime.utc(2026, 10, 16, 12);
const privateTitle = 'Private tree trimming appointment';
const areaName = 'Overland Park';

CalendarEvent event(
        {DateTime? start, String zone = 'UTC', String locationText = ''}) =>
    CalendarEvent(
        id: 'opaque-event',
        nativeId: 'native-id',
        calendarId: 'selected',
        title: privateTitle,
        locationText: locationText,
        startUtc: start ?? now.add(const Duration(hours: 2)),
        endUtc: (start ?? now.add(const Duration(hours: 2)))
            .add(const Duration(hours: 1)),
        timeZone: zone);

ResolvedLocation location(
        {LocationSource source = LocationSource.currentArea,
        LocationPrecision precision = LocationPrecision.area,
        LocationEvidenceQuality quality = LocationEvidenceQuality.assumed,
        bool provisional = false,
        bool review = false,
        String name = areaName,
        double lat = 38.9,
        DateTime? observed,
        DateTime? resolved,
        DateTime? until}) =>
    ResolvedLocation(
        candidate: LocationCandidate(
            name: name, country: 'US', lat: lat, lon: -94.7, source: 'device'),
        source: source,
        precision: precision,
        evidenceQuality: quality,
        reason: 'Derived weather area',
        resolvedAt: resolved ?? now,
        observedAt: observed ?? now,
        validUntil: until,
        provisional: provisional,
        reviewSuggested: review);

EventWeatherAssessment assessment(
        {ForecastCoverage coverage = ForecastCoverage.hourly,
        WeatherImpact impact = WeatherImpact.watch,
        int rain = 70,
        DateTime? updated,
        List<EventWeatherSegment> segments = const []}) =>
    EventWeatherAssessment(
        coverage: coverage,
        impact: impact,
        condition: 'Rain',
        explanation: 'Peak precipitation chance is $rain%.',
        advice: 'Bring a rain layer.',
        peakPrecipitationChance: rain,
        forecastUpdatedAt: updated ?? now,
        validUntil: now.add(const Duration(hours: 6)),
        segments: segments);

PlanCastEventWeather item(
        {ResolvedLocation? resolution,
        EventWeatherAssessment? weather,
        CalendarEvent? plan,
        String? venueZone,
        int? venueOffset,
        EventParticipation participation = EventParticipation.physical}) =>
    PlanCastEventWeather(
        event: plan ?? event(),
        assessment: weather ?? assessment(),
        venue: resolution?.candidate,
        resolvedLocation: resolution,
        venueTimeZone: venueZone,
        venueTimeZoneOffset: venueOffset,
        participation: participation);

PlanCastBriefing brief(List<PlanCastEventWeather> plans) =>
    const PlanCastBriefingComposer()
        .compose(today: plans, tomorrow: [], now: now);

Map<String, dynamic> eventNotice(PlanCastEventWeather plan,
        {bool detailed = false, DateTime? sync}) =>
    const PlanCastNotificationPlanner()
        .plan(
            now: now,
            calendarSyncedAt: sync ?? now,
            events: [plan],
            preferences: PlanCastPreferences(
                notifications: true,
                eventLeadMinutes: 60,
                detailedNotificationPreviews: detailed,
                quietStartMinute: 0,
                quietEndMinute: 0))
        .singleWhere((notice) => notice['nativeEventId'] != null);

void main() {
  group('shared briefing evidence', () {
    test('private briefings redact precise labels in today and tomorrow copy',
        () {
      for (final precision in [
        LocationPrecision.venue,
        LocationPrecision.address,
        LocationPrecision.coordinates,
        LocationPrecision.unknown
      ]) {
        final plan = item(
            resolution: location(
                name: 'Private medical office, 123 Confidential Street',
                source: LocationSource.calendarCoordinates,
                precision: precision,
                quality: LocationEvidenceQuality.confirmed));
        final result = const PlanCastBriefingComposer().compose(
            today: [plan], tomorrow: [plan], now: now, privateTitles: true);
        expect(result.text, isNot(contains('Private medical office')));
        expect(result.text, isNot(contains('123 Confidential Street')));
        expect(result.text, isNot(contains(privateTitle)));
        expect(result.worthWatching, contains('event’s weather location'));
        expect(result.tomorrow, contains('event’s weather location'));
        expect(result.text, contains('70%'));
      }
    });

    test('explicit private-detail opt-in retains exact venue context', () {
      final plan = item(
          resolution: location(
              name: 'Private medical office',
              source: LocationSource.calendarCoordinates,
              precision: LocationPrecision.coordinates,
              quality: LocationEvidenceQuality.confirmed));
      final result = const PlanCastBriefingComposer().compose(
          today: [plan], tomorrow: [plan], now: now, privateTitles: false);
      expect(result.text, contains('Private medical office'));
      expect(result.text, contains(privateTitle));
      expect(eventNotice(plan, detailed: true)['body'],
          contains('Private medical office'));
    });

    test(
        'current-area forecast is useful without confirmed venue or title exposure',
        () {
      final result = brief([item(resolution: location())]);
      expect(result.usableWeatherCount, 1);
      expect(result.needsLocationCount, 0);
      expect(result.automaticLocationCount, 1);
      expect(result.reviewLocationCount, 0);
      expect(result.text, contains('Using your area: Overland Park'));
      expect(result.text, contains('event window'));
      expect(result.text, isNot(contains(privateTitle)));
      expect(result.text, isNot(contains('confirmed location')));
    });

    test('inferred-city review remains separate from unavailable weather', () {
      final result = brief([
        item(
            resolution: location(
                source: LocationSource.inferredCity,
                precision: LocationPrecision.city,
                quality: LocationEvidenceQuality.supported,
                review: true))
      ]);
      expect(result.usableWeatherCount, 1);
      expect(result.needsLocationCount, 0);
      expect(result.reviewLocationCount, 1);
      expect(result.text, contains('Found in event: Overland Park, US area'));
    });

    test(
        'low-impact briefing still reports real weather for the event interval',
        () {
      final result = brief([
        item(
            resolution: location(),
            weather: assessment(impact: WeatherImpact.low, rain: 10))
      ]);
      expect(result.worthWatching, contains('Rain'));
      expect(result.worthWatching, contains('10%'));
      expect(result.worthWatching, contains('calendar time'));
      expect(
          result.worthWatching, isNot(contains('No material weather issue')));
    });

    test(
        'daily and partial outlooks are useful but never fabricated hourly coverage',
        () {
      final result = brief([
        item(
            resolution: location(),
            weather: assessment(coverage: ForecastCoverage.daily)),
        item(
            resolution: location(),
            weather: assessment(coverage: ForecastCoverage.partial)),
      ]);
      expect(result.usableWeatherCount, 2);
      expect(result.needsLocationCount, 0);
      expect(result.text, contains('Broad day outlook'));
      expect(result.text, contains('event-hour weather is unavailable'));
      expect(result.text, contains('Partial coverage'));
    });

    test('loading, horizon and online states do not become location failures',
        () {
      final result = brief([
        item(
            resolution: location(),
            weather: assessment(
                coverage: ForecastCoverage.loading,
                impact: WeatherImpact.unavailable)),
        item(
            resolution: location(),
            weather: assessment(
                coverage: ForecastCoverage.tooEarly,
                impact: WeatherImpact.unavailable)),
        item(
            participation: EventParticipation.online,
            weather: assessment(
                coverage: ForecastCoverage.online,
                impact: WeatherImpact.unavailable)),
        item(
            weather: assessment(
                coverage: ForecastCoverage.needsLocation,
                impact: WeatherImpact.unavailable)),
      ]);
      expect(result.usableWeatherCount, 0);
      expect(result.needsLocationCount, 1);
      expect(result.text, contains('Weather coverage is not available yet'));
      expect(result.text, isNot(contains('No material')));
      expect(result.text, isNot(contains('One last opinion')));
      expect(result.beforeYouGo, contains('one default area'));
    });

    test(
        'unresolved destinations do not request a default for valid area forecasts',
        () {
      for (final destination in [
        '123 Unresolved Street',
        'Hotel in Miami Beach',
      ]) {
        final result = brief([
          item(
              resolution: location(),
              weather: assessment(impact: WeatherImpact.low, rain: 10)),
          item(
              plan: event(locationText: destination),
              weather: assessment(
                  coverage: ForecastCoverage.needsLocation,
                  impact: WeatherImpact.unavailable)),
        ]);
        expect(result.usableWeatherCount, 1);
        expect(result.needsLocationCount, 1);
        expect(
            result.beforeYouGo, contains('Review the unresolved destination'));
        expect(result.beforeYouGo, isNot(contains('default area')));
      }
    });

    test('conflicting evidence is reviewed instead of replaced by a default',
        () {
      final result = brief([
        item(
            resolution: location(quality: LocationEvidenceQuality.conflict),
            weather: assessment(
                coverage: ForecastCoverage.needsLocation,
                impact: WeatherImpact.unavailable)),
      ]);
      expect(result.beforeYouGo, contains('Review the unresolved destination'));
      expect(result.beforeYouGo, isNot(contains('default area')));
    });

    test('online-only day neither fails location nor claims clear weather', () {
      final result = brief([
        item(
            participation: EventParticipation.online,
            weather: assessment(
                coverage: ForecastCoverage.online,
                impact: WeatherImpact.unavailable))
      ]);
      expect(result.needsLocationCount, 0);
      expect(result.worthWatching, 'Online plans do not need venue weather.');
    });

    test('multi-day segments retain separate arrival and departure facts', () {
      final result = brief([
        item(
            resolution: location(provisional: true),
            weather: assessment(segments: [
              EventWeatherSegment(
                  label: 'Arrival',
                  startUtc: now,
                  endUtc: now.add(const Duration(hours: 2)),
                  assessment: assessment(rain: 80)),
              EventWeatherSegment(
                  label: 'Departure',
                  startUtc: now.add(const Duration(days: 2)),
                  endUtc: now.add(const Duration(days: 2, hours: 2)),
                  assessment: assessment(rain: 10)),
            ]))
      ]);
      expect(result.text, contains('Arrival:'));
      expect(result.text, contains('Departure:'));
      expect(result.text, contains('80%'));
      expect(result.text, contains('10%'));
      expect(result.text, contains('provisional for this plan'));
    });
  });

  group('meteorological change comparability', () {
    const detector = ForecastChangeDetector();
    PlanCastEventWeather prior() => item(
        resolution: location(),
        weather: assessment(
            rain: 30, updated: now.subtract(const Duration(hours: 1))));

    test(
        'fresh observation timestamps alone do not suppress a real rain change',
        () {
      final current = item(
          resolution: location(
              observed: now.add(const Duration(minutes: 1)),
              resolved: now.add(const Duration(minutes: 2))),
          weather: assessment(rain: 80));
      expect(detector.materiallyChanged(prior(), current, now), isTrue);
    });

    test('observation-derived area expiry alone does not hide a weather change',
        () {
      final old = item(
          resolution: location(until: now.add(const Duration(minutes: 15))),
          weather: assessment(
              rain: 30, updated: now.subtract(const Duration(hours: 1))));
      final newer = item(
          resolution: location(
              observed: now.add(const Duration(minutes: 5)),
              until: now.add(const Duration(minutes: 35))),
          weather: assessment(rain: 80));
      expect(detector.materiallyChanged(old, newer, now), isTrue);
    });

    test(
        'new source, precision, evidence quality or coordinates is not a forecast change',
        () {
      for (final resolution in [
        location(source: LocationSource.lastKnownArea),
        location(precision: LocationPrecision.city),
        location(quality: LocationEvidenceQuality.confirmed),
        location(lat: 25.8),
        location(provisional: true),
      ]) {
        expect(
            detector.materiallyChanged(
                prior(),
                item(resolution: resolution, weather: assessment(rain: 80)),
                now),
            isFalse);
      }
    });

    test('event interval or calendar/venue timezone changes reset comparison',
        () {
      final old = prior();
      for (final current in [
        item(
            resolution: location(),
            plan: event(start: now.add(const Duration(hours: 3)))),
        item(resolution: location(), plan: event(zone: 'America/New_York')),
        item(resolution: location(), venueZone: 'America/New_York'),
        item(resolution: location(), venueOffset: -14400),
      ]) {
        expect(detector.materiallyChanged(old, current, now), isFalse);
      }
    });

    test('daily/partial forecasts never become precise hourly change alerts',
        () {
      for (final coverage in [
        ForecastCoverage.daily,
        ForecastCoverage.partial
      ]) {
        expect(
            detector.materiallyChanged(
                prior(),
                item(
                    resolution: location(),
                    weather: assessment(coverage: coverage, rain: 80)),
                now),
            isFalse);
      }
    });
  });

  group('notification location privacy and freshness', () {
    test(
        'opt-in detailed copy identifies assumed area, interval and provisional state',
        () {
      final notice = eventNotice(item(resolution: location(provisional: true)),
          detailed: true);
      expect(notice['detailed'], isTrue);
      expect(notice['body'], contains(privateTitle));
      expect(notice['body'], contains('Using your area: Overland Park'));
      expect(notice['body'], contains('provisional for this plan'));
      expect(notice['body'], contains('calendar time'));
      expect(notice['body'], contains('Last checked'));
    });

    test('expired area applicability downgrades and bounds detailed reminders',
        () {
      final expired = eventNotice(
          item(
              resolution:
                  location(until: now.add(const Duration(minutes: 30)))),
          detailed: true);
      expect(expired['detailed'], isFalse);
      expect(expired['body'], isNot(contains(areaName)));
      final until = now.add(const Duration(hours: 1, minutes: 30));
      final bounded =
          eventNotice(item(resolution: location(until: until)), detailed: true);
      expect(bounded['detailed'], isTrue);
      expect(bounded['expiresAtMs'], until.millisecondsSinceEpoch);
    });

    test('generic notification has no event title or private area', () {
      final notice = eventNotice(item(resolution: location()));
      expect(notice['detailed'], isFalse);
      expect(jsonEncode(notice), isNot(contains(privateTitle)));
      expect(jsonEncode(notice), isNot(contains(areaName)));
      expect(notice['body'], contains('event weather'));
    });

    test('old or future-dated forecast and sync downgrade detailed text', () {
      for (final updated in [
        now.subtract(const Duration(hours: 7)),
        now.add(const Duration(hours: 2))
      ]) {
        final notice = eventNotice(
            item(resolution: location(), weather: assessment(updated: updated)),
            detailed: true);
        expect(notice['detailed'], isFalse);
        expect(notice['body'], isNot(contains(areaName)));
      }
      expect(
          eventNotice(item(resolution: location()),
              detailed: true,
              sync: now.add(const Duration(hours: 2)))['detailed'],
          isFalse);
    });

    test('daily and partial details remain generic', () {
      for (final coverage in [
        ForecastCoverage.daily,
        ForecastCoverage.partial
      ]) {
        final notice = eventNotice(
            item(
                resolution: location(),
                weather: assessment(coverage: coverage)),
            detailed: true);
        expect(notice['detailed'], isFalse);
        expect(notice['body'], isNot(contains(areaName)));
      }
    });
  });
}
