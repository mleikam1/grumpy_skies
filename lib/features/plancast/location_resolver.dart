import '../../models/weather_models.dart';
import 'plancast_models.dart';

class SmartLocationPolicy {
  const SmartLocationPolicy(
      {this.currentAreaAge = const Duration(minutes: 30),
      this.lastKnownAreaAge = const Duration(hours: 24),
      this.maximumAccuracyMeters = 25000,
      this.provisionalAfter = const Duration(hours: 48)});
  final Duration currentAreaAge, lastKnownAreaAge, provisionalAfter;
  final double maximumAccuracyMeters;
  bool accepts(DeviceAreaSample? sample, DateTime now,
      {required bool current}) {
    if (sample == null ||
        !sample.hasValidCoordinates ||
        sample.accuracyMeters > maximumAccuracyMeters ||
        (current && !sample.permissionGranted)) {
      return false;
    }
    final age = now.difference(sample.observedAt);
    return age >= const Duration(minutes: -5) &&
        age <= (current ? currentAreaAge : lastKnownAreaAge);
  }
}

/// Local extraction only. Event titles are never themselves lookup requests.
class EventLocationExtractor {
  const EventLocationExtractor();
  static final _url =
      RegExp(r'(?:https?://|geo:)[^\s<>]+', caseSensitive: false);
  static final _virtual = RegExp(
      r'https?://(?:[\w-]+\.)?(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|whereby\.com)(?:[/?:#]|$)',
      caseSensitive: false);
  static final _placeholder = RegExp(
      r'^(?:tbd|tba|to be determined|none|n/a|room\s*[\w-]*|conference room(?:\s+\w+)?|online|virtual|remote|video call|zoom|teams)$',
      caseSensitive: false);
  static final _street = RegExp(
      r'\b\d{1,6}\s+[\w .’-]+\s(?:street|st|avenue|ave|road|rd|boulevard|blvd|drive|dr|lane|ln|court|ct|way|parkway|pkwy)\b',
      caseSensitive: false);
  static const _knownCities = {
    'miami beach',
    'miami',
    'new york',
    'new york city',
    'chicago',
    'los angeles',
    'san francisco',
    'san diego',
    'seattle',
    'boston',
    'austin',
    'dallas',
    'denver',
    'atlanta',
    'london',
    'paris',
    'tokyo',
    'sydney',
    'toronto',
    'vancouver',
    'overland park',
    'kansas city',
    'washington dc',
    'las vegas'
  };

  EventLocationEvidence extract(CalendarEvent event) {
    final field = event.locationText.trim();
    final urls = [
      ..._url.allMatches(field).map((m) => m.group(0)!),
      if (event.mapUrl != null) event.mapUrl!
    ];
    final mapLinks = urls.where(_isMapLink).toList();
    LocationCandidate? coordinates;
    var mapConflict = false;
    for (final url in mapLinks) {
      final point = coordinatesFromMapLink(url);
      if (point != null) {
        if (coordinates != null &&
            ((coordinates.lat - point.lat).abs() > 0.00001 ||
                (coordinates.lon - point.lon).abs() > 0.00001)) {
          mapConflict = true;
        }
        coordinates ??= point;
      }
    }
    if (mapConflict) coordinates = null;
    final virtual = _virtual.hasMatch(field) ||
        RegExp(r'^(?:online|virtual|remote|zoom|teams|video call)(?:\s+(?:meeting|appointment|call|session))?$',
                caseSensitive: false)
            .hasMatch(field);
    var physical = field
        .replaceAll(_url, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[,;|]+|[,;|]+$'), '')
        .trim();
    if (physical.isEmpty && coordinates == null && !mapConflict) {
      final queries =
          mapLinks.map(_mapDestinationText).whereType<String>().toList();
      if (queries.map(normalizeLocationText).toSet().length > 1) {
        mapConflict = true;
      } else if (queries.isNotEmpty) {
        physical = queries.first;
      }
    }
    String? address, venue, city;
    if (physical.isNotEmpty && !_placeholder.hasMatch(physical)) {
      if (_street.hasMatch(physical)) {
        address = _bounded(physical);
        city = _cityFromParts(physical.split(','), skipFirst: true);
      } else if (_knownCities.contains(normalizeLocationText(physical))) {
        city = physical;
      } else {
        venue = _bounded(physical.split(',').first.trim());
        city = _cityFromParts(physical.split(','), skipFirst: true);
      }
    }
    final fromCalendar = mapLinks.isNotEmpty ||
        event.hasCoordinates ||
        coordinates != null ||
        address != null ||
        venue != null ||
        city != null;
    final title = event.title.trim();
    final stay = RegExp(
            r'\b(?:reservation|hotel|check[ -]?in|check[ -]?out|stay|lodging)\b',
            caseSensitive: false)
        .hasMatch(title);
    if (!fromCalendar) {
      final booking = RegExp(
              r'\b(?:reservation|booking|stay|check[ -]?in)\s+(?:at|in)\s+(.+)$',
              caseSensitive: false)
          .firstMatch(title);
      if (booking != null) {
        final parts =
            booking.group(1)!.split(',').map((s) => s.trim()).toList();
        venue = _bounded(parts.first);
        city = _cityFromParts(parts, skipFirst: true, knownOnly: true);
        if (city == null &&
            _knownCities.contains(normalizeLocationText(parts.first))) {
          city = parts.first;
          venue = null;
        }
      } else {
        final destination = RegExp(
                r'^(?:dinner|lunch|breakfast|meeting|conference|concert|wedding|vacation|trip|travel|flight|arrival)\b.{0,80}?\b(?:in|to)\s+([A-Za-zÀ-ž .’-]+)$',
                caseSensitive: false)
            .firstMatch(title);
        if (destination != null) {
          final phrase = destination.group(1)!.trim();
          if (_knownCities.contains(normalizeLocationText(phrase))) {
            city = _bounded(phrase);
          } else {
            final alternatives = phrase.split(
                RegExp(r'\s(?:or|versus|vs\.?)\s', caseSensitive: false));
            final conflictingCities = alternatives.length > 1 &&
                alternatives.any((part) =>
                    _knownCities.contains(normalizeLocationText(part)));
            final strongTravel = RegExp(
                    r'^(?:vacation|trip|travel|flight|arrival)\b',
                    caseSensitive: false)
                .hasMatch(title);
            if (conflictingCities || strongTravel) {
              // Preserve explicit destination intent without treating arbitrary
              // names as cities or sending them through the city-only adapter.
              venue = _bounded(phrase);
            }
          }
        }
      }
    }
    final conflict = mapConflict ||
        [address, venue, city].whereType<String>().any((v) => RegExp(
                r'\s(?:or|versus|vs\.?|instead of)\s|\s/\s',
                caseSensitive: false)
            .hasMatch(v));
    final hasPhysical = mapLinks.isNotEmpty ||
        event.hasCoordinates ||
        coordinates != null ||
        address != null ||
        venue != null ||
        city != null;
    final titleVirtual = RegExp(
            r'\b(?:online|virtual|zoom|video call|remote meeting)\b',
            caseSensitive: false)
        .hasMatch(title);
    return EventLocationEvidence(
        coordinates: coordinates,
        addressQuery: address,
        venueQuery: venue,
        cityQuery: city,
        fromCalendarField: fromCalendar,
        unresolvedMapDestination: mapLinks.isNotEmpty &&
            coordinates == null &&
            address == null &&
            venue == null &&
            city == null,
        virtualOnly: (virtual || titleVirtual) && !hasPhysical,
        hybrid: (virtual || titleVirtual) && hasPhysical,
        conflicting: conflict,
        isStay: stay,
        reason: fromCalendar
            ? 'Physical location evidence in the calendar location field.'
            : hasPhysical
                ? 'A destination phrase was extracted locally from this event.'
                : 'No reliable destination evidence.');
  }

  static String? _bounded(String value) =>
      value.length >= 2 && value.length <= 200 ? value : null;
  static bool _cityShape(String value) =>
      value.trim().length >= 2 &&
      value.trim().length <= 70 &&
      RegExp(r'^[A-Za-zÀ-ž][A-Za-zÀ-ž .’-]*$').hasMatch(value.trim()) &&
      !RegExp(r'\b(?:collection|hotel|resort|marriott|hilton|hyatt|room|office|home|unknown|online)\b',
              caseSensitive: false)
          .hasMatch(value);
  static String? _cityFromParts(List<String> parts,
      {required bool skipFirst, bool knownOnly = false}) {
    for (final part in parts.skip(skipFirst ? 1 : 0)) {
      final value = part.trim();
      if (value.length <= 3 ||
          !_cityShape(value) ||
          (knownOnly && !_knownCities.contains(normalizeLocationText(value)))) {
        continue;
      }
      return _bounded(value);
    }
    return null;
  }

  static bool _isMapLink(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() == 'geo') return true;
    if (!{'https', 'http'}.contains(uri.scheme.toLowerCase())) return false;
    final host = uri.host.toLowerCase();
    return {
          'maps.apple.com',
          'maps.google.com',
          'maps.app.goo.gl',
          'maps.google.goo.gl',
          'openstreetmap.org',
          'www.openstreetmap.org'
        }.contains(host) ||
        ({'google.com', 'www.google.com'}.contains(host) &&
            uri.path.startsWith('/maps')) ||
        (host == 'goo.gl' && uri.path.startsWith('/maps/'));
  }

  /// Only literal geographic query/path text from recognized maps is read.
  /// Short links stay unresolved; no URL is fetched or followed.
  static String? _mapDestinationText(String raw) {
    if (!_isMapLink(raw)) return null;
    final uri = Uri.parse(raw);
    final text = uri.queryParameters['q'] ??
        uri.queryParameters['query'] ??
        uri.queryParameters['destination'] ??
        uri.queryParameters['daddr'];
    if (text != null &&
        !RegExp(r'https?://|geo:', caseSensitive: false).hasMatch(text)) {
      return _bounded(text.trim());
    }
    final parts = uri.pathSegments;
    final index = parts.indexOf('place');
    if ({'google.com', 'www.google.com', 'maps.google.com'}
            .contains(uri.host.toLowerCase()) &&
        index >= 0 &&
        parts.length > index + 1) {
      return _bounded(parts[index + 1].replaceAll('+', ' ').trim());
    }
    return null;
  }

  /// Parse destination coordinates only. Never fetch a URL, follow a short link,
  /// or mistake a Google map viewport's @camera coordinates for a destination.
  static LocationCandidate? coordinatesFromMapLink(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    String? pair;
    if (uri.scheme.toLowerCase() == 'geo') {
      pair = uri.queryParameters['q'] ?? uri.path.split(';').first;
    } else if ({'https', 'http'}.contains(uri.scheme.toLowerCase())) {
      final host = uri.host.toLowerCase();
      final allowed = host == 'maps.apple.com' ||
          host == 'maps.google.com' ||
          {'openstreetmap.org', 'www.openstreetmap.org'}.contains(host) ||
          ({'google.com', 'www.google.com'}.contains(host) &&
              uri.path.startsWith('/maps'));
      if (!allowed) return null;
      pair = uri.queryParameters['q'] ??
          uri.queryParameters['query'] ??
          uri.queryParameters['destination'] ??
          uri.queryParameters['daddr'];
      if ({'openstreetmap.org', 'www.openstreetmap.org'}.contains(host) &&
          uri.queryParameters.containsKey('mlat') &&
          uri.queryParameters.containsKey('mlon')) {
        pair = '${uri.queryParameters['mlat']},${uri.queryParameters['mlon']}';
      }
      // Apple's ll denotes a pin only in combination with an explicit query.
      if (host == 'maps.apple.com' && uri.queryParameters.containsKey('q')) {
        pair = uri.queryParameters['ll'] ?? pair;
      }
    }
    if (pair == null) return null;
    final match = RegExp(
            r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)(?:\s*\([^)]*\))?\s*$')
        .firstMatch(pair);
    if (match == null) return null;
    final lat = double.tryParse(match[1]!);
    final lon = double.tryParse(match[2]!);
    if (lat == null ||
        lon == null ||
        !LocationCandidate.hasValidCoordinatePair(lat, lon)) {
      return null;
    }
    return LocationCandidate(
        name: 'Calendar map location',
        country: '',
        lat: lat,
        lon: lon,
        source: 'calendar-map');
  }
}

/// Pure precedence and evidence validation. Lookup results are injected so no
/// rebuild, event title, calendar identifier or event schedule starts a request.
class SmartLocationResolver {
  const SmartLocationResolver(
      {this.policy = const SmartLocationPolicy(),
      this.extractor = const EventLocationExtractor()});
  final SmartLocationPolicy policy;
  final EventLocationExtractor extractor;

  // Existing search returns city/ZIP centroids. A user selecting that result
  // confirms the choice, not precision of an unknown venue within the area.
  static LocationPrecision _candidatePrecision(LocationCandidate candidate) => {
        'city',
        'zip',
        'manual',
        'geocoding',
        'openweather',
        'reverse'
      }.contains(candidate.source.toLowerCase())
          ? LocationPrecision.city
          : {'device', 'browser'}.contains(candidate.source.toLowerCase())
              ? LocationPrecision.area
              : LocationPrecision.coordinates;
  LocationResolution resolve(
      {required CalendarEvent event,
      required DateTime now,
      required SmartLocationState state,
      EventOverride? occurrenceOverride,
      DeviceAreaSample? deviceArea,
      DeviceAreaSample? lastKnownArea,
      Map<String, LocationLookupResult> lookupResults = const {}}) {
    final evidence = extractor.extract(event);
    var participation = evidence.hybrid
        ? EventParticipation.hybrid
        : EventParticipation.unknown;
    final ordered = [...state.rules.where((r) => r.enabled)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final occurrence = ordered
        .where((r) =>
            (r.scope == LocationRuleScope.occurrence ||
                r.scope == LocationRuleScope.legacy) &&
            r.targetId == event.id)
        .firstOrNull;
    ResolvedLocation unresolved(String reason,
            {bool conflict = false, bool review = true}) =>
        ResolvedLocation(
            source: LocationSource.unavailable,
            precision: LocationPrecision.unknown,
            evidenceQuality: conflict
                ? LocationEvidenceQuality.conflict
                : LocationEvidenceQuality.unresolved,
            reason: reason,
            resolvedAt: now,
            validFrom: event.startUtc,
            validUntil: event.endUtc,
            reviewSuggested: review,
            evidenceKey: evidence.signature);
    LocationResolution finish(ResolvedLocation location,
            {bool online = false, List<LocationLookupRequest>? requests}) =>
        LocationResolution(
            location: location,
            participation: online ? EventParticipation.online : participation,
            evidence: evidence,
            lookupRequests: requests ?? const []);
    ResolvedLocation point(LocationCandidate candidate, LocationSource source,
            {LocationPrecision precision = LocationPrecision.coordinates,
            LocationEvidenceQuality quality = LocationEvidenceQuality.confirmed,
            String? reason,
            String provider = 'user',
            DateTime? observedAt,
            DateTime? expiresAt,
            bool review = false,
            bool provisional = false}) =>
        ResolvedLocation(
            candidate: candidate,
            source: source,
            precision: precision,
            evidenceQuality: quality,
            reason: reason ??
                'An intentional location choice applies to this event.',
            resolvedAt: now,
            provider: provider,
            observedAt: observedAt,
            validFrom: event.startUtc,
            validUntil: expiresAt ?? event.endUtc,
            reviewSuggested: review,
            provisional: provisional,
            evidenceKey:
                '${event.id}|${event.startUtc.toUtc()}|${event.endUtc.toUtc()}|${event.timeZone}|${evidence.signature}');
    ResolvedLocation fallback({bool deliberatelyCurrent = false}) {
      DeviceAreaSample? sample;
      var source = LocationSource.currentArea;
      if (policy.accepts(deviceArea, now, current: true)) {
        sample = deviceArea;
      } else {
        final candidates = [lastKnownArea, deviceArea]
            .whereType<DeviceAreaSample>()
            .where((s) => policy.accepts(s, now, current: false))
            .toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
        if (candidates.isNotEmpty) {
          sample = candidates.first;
          source = LocationSource.lastKnownArea;
        }
      }
      final provisional =
          event.startUtc.difference(now) > policy.provisionalAfter;
      if (sample != null) {
        return ResolvedLocation(
            candidate: sample.candidate,
            source: source,
            precision: LocationPrecision.area,
            evidenceQuality: LocationEvidenceQuality.assumed,
            reason: source == LocationSource.currentArea
                ? 'No stronger destination applies. Weather uses your observed area${sample.approximate ? ' with approximate location' : ''}${provisional ? '; this future-plan assumption is provisional' : ''}.'
                : 'Using an acceptable last-known device area; this is not a current location observation.',
            provider: sample.provenance,
            observedAt: sample.observedAt,
            resolvedAt: now,
            validFrom: event.startUtc,
            validUntil: sample.observedAt.add(
                source == LocationSource.currentArea
                    ? policy.currentAreaAge
                    : policy.lastKnownAreaAge),
            provisional: provisional,
            reviewSuggested: source == LocationSource.lastKnownArea,
            evidenceKey:
                '${event.id}|${event.startUtc.toUtc()}|${event.endUtc.toUtc()}|${event.timeZone}');
      }
      if (!deliberatelyCurrent &&
          state.defaultArea?.hasValidCoordinates == true) {
        return point(state.defaultArea!, LocationSource.defaultArea,
            precision: LocationPrecision.city,
            quality: LocationEvidenceQuality.assumed,
            provisional: provisional,
            reason:
                'Using the PlanCast default area you selected for missing-location plans.');
      }
      return unresolved(deliberatelyCurrent
          ? 'Your current area is unavailable. Allow foreground location or choose another area.'
          : 'Choose one PlanCast default area for all plans without a usable location.');
    }

    ResolvedLocation? choice(LocationChoice choice, LocationSource source,
        {DateTime? providerExpiry}) {
      if (choice.kind == LocationChoiceKind.currentArea) {
        return fallback(deliberatelyCurrent: true);
      }
      if (choice.kind == LocationChoiceKind.online) return null;
      final saved = state.savedPlaces
          .where((p) => p.id == choice.savedPlaceId)
          .firstOrNull;
      final candidate = choice.candidate ?? saved?.candidate;
      if (candidate == null || !candidate.hasValidCoordinates) {
        return unresolved('This saved location needs to be chosen again.');
      }
      return point(candidate, source,
          precision: _candidatePrecision(candidate),
          quality: source == LocationSource.calendarDefault
              ? LocationEvidenceQuality.assumed
              : LocationEvidenceQuality.confirmed,
          provider: saved?.provider ?? candidate.source,
          review: (providerExpiry ?? saved?.providerExpiresAt)?.isBefore(now) ==
              true,
          reason: (providerExpiry ?? saved?.providerExpiresAt)?.isBefore(now) ==
                  true
              ? 'Your location choice is retained. Its provider details are old; reviewing the place would help.'
              : null);
    }

    if (occurrenceOverride?.environment == EventEnvironment.online ||
        occurrence?.choice.kind == LocationChoiceKind.online) {
      return finish(
          unresolved('Online participation was explicitly selected.',
              review: false),
          online: true);
    }
    final explicitlyPhysical =
        occurrenceOverride?.environment == EventEnvironment.indoor ||
            occurrenceOverride?.environment == EventEnvironment.outdoor;
    if (explicitlyPhysical) {
      participation = EventParticipation.physical;
    }
    if (occurrence != null) {
      return finish(choice(occurrence.choice, LocationSource.userOverride,
          providerExpiry: occurrence.providerExpiresAt)!);
    }
    if (occurrenceOverride?.venue?.hasValidCoordinates == true) {
      return finish(point(
          occurrenceOverride!.venue!, LocationSource.userOverride,
          precision: _candidatePrecision(occurrenceOverride.venue!)));
    }
    // Migrated reuse choices were explicitly confirmed for a series AND its
    // unchanged calendar location, including corrections to a populated field.
    // Their historical identity must not become a new broadly matching rule.
    final hasNewSeriesChoice = !evidence.fromCalendarField &&
        event.isRecurring &&
        ordered.any((r) =>
            r.scope == LocationRuleScope.seriesMissing &&
            r.targetId == event.seriesKey);
    final legacySeries = ordered
        .where((r) =>
            r.scope == LocationRuleScope.legacy &&
            event.matchesLegacyRecurringKey(r.targetId))
        .firstOrNull;
    if (!hasNewSeriesChoice &&
        legacySeries != null &&
        !(explicitlyPhysical &&
            legacySeries.choice.kind == LocationChoiceKind.online)) {
      if (legacySeries.choice.kind == LocationChoiceKind.online) {
        return finish(
            unresolved(
                'Online participation was saved for this unchanged calendar location.',
                review: false),
            online: true);
      }
      return finish(choice(legacySeries.choice, LocationSource.recurringRule,
          providerExpiry: legacySeries.providerExpiresAt)!);
    }
    if (evidence.virtualOnly && participation != EventParticipation.physical) {
      return finish(
          unresolved(
              'Clearly virtual-only participation; no venue weather is needed.',
              review: false),
          online: true);
    }
    if (event.hasCoordinates) {
      return finish(point(
          LocationCandidate(
              name: event.locationText.isEmpty
                  ? 'Calendar venue'
                  : event.locationText,
              country: '',
              lat: event.latitude!,
              lon: event.longitude!,
              source: 'calendar'),
          LocationSource.calendarCoordinates,
          provider: 'device-calendar',
          reason: 'Structured coordinates came from this calendar event.'));
    }
    if (evidence.coordinates != null) {
      return finish(point(
          evidence.coordinates!, LocationSource.calendarCoordinates,
          provider: 'calendar-map-link',
          reason:
              'Destination coordinates were parsed locally from a recognized map link.'));
    }
    ResolvedLocation? lookedUp(EventLocationEvidence input) {
      for (final request in input.requests) {
        final result = lookupResults[request.key];
        if (result?.usableAt(now) != true) continue;
        return point(
            result!.candidates.single,
            input.fromCalendarField
                ? LocationSource.calendarAddress
                : request.kind == LocationLookupKind.city
                    ? LocationSource.inferredCity
                    : LocationSource.inferredVenue,
            precision: result.precision,
            quality: LocationEvidenceQuality.supported,
            provider: result.provider,
            observedAt: result.observedAt,
            expiresAt: result.expiresAt,
            review: result.precision == LocationPrecision.city &&
                input.venueQuery != null,
            reason: result.precision == LocationPrecision.city
                ? 'Destination city resolved; this is area weather, not an exact venue forecast.'
                : 'An unambiguous event location was resolved.');
      }
      return null;
    }

    final aliasText =
        normalizeLocationText(evidence.venueQuery ?? event.locationText);
    final aliases = state.savedPlaces
        .where((place) => [place.label, ...place.aliases].any((a) =>
            normalizeLocationText(a) == aliasText && aliasText.isNotEmpty))
        .toList();
    if (evidence.fromCalendarField && !evidence.conflicting) {
      final matched = lookedUp(evidence);
      if (matched != null) return finish(matched);
    }
    if (aliases.length == 1) {
      return finish(point(aliases.single.candidate, LocationSource.savedPlace,
          precision: _candidatePrecision(aliases.single.candidate),
          provider: aliases.single.provider,
          reason: 'This location matches a saved alias you created.'));
    }
    if (aliases.length > 1) {
      return finish(unresolved(
          'More than one saved place uses this alias. Choose the intended place.',
          conflict: true));
    }
    if (!evidence.fromCalendarField) {
      final series = ordered
          .where((r) =>
              r.scope == LocationRuleScope.seriesMissing &&
              r.targetId == event.seriesKey &&
              event.isRecurring)
          .firstOrNull;
      if (series != null &&
          !(explicitlyPhysical &&
              series.choice.kind == LocationChoiceKind.online)) {
        if (series.choice.kind == LocationChoiceKind.online) {
          return finish(
              unresolved(
                  'Online participation applies to this missing-location series.',
                  review: false),
              online: true);
        }
        return finish(choice(series.choice, LocationSource.recurringRule,
            providerExpiry: series.providerExpiresAt)!);
      }
    }
    if (evidence.hasDestinationEvidence) {
      if (evidence.conflicting) {
        return finish(unresolved(
            'Conflicting destinations need review; local weather would not describe the intended destination.',
            conflict: true));
      }
      final matched = lookedUp(evidence);
      if (matched != null) return finish(matched);
      final ambiguous = evidence.requests.any((r) =>
          lookupResults[r.key]?.status == LocationLookupStatus.ambiguous);
      return finish(
          unresolved(
              ambiguous
                  ? 'Destination matches are ambiguous. Choose the correct area; your current city is not substituted.'
                  : state.onlineMatchingEnabled
                      ? 'Destination evidence is available, but an unambiguous location is not resolved. City matching is supported; exact venue/address matching is not configured.'
                      : 'A destination was found locally. Enable optional minimal location matching or choose its city; unrelated current-area weather is not substituted.',
              conflict: ambiguous),
          requests: state.onlineMatchingEnabled ? evidence.requests : const []);
    }
    final calendar = ordered
        .where((r) =>
            r.scope == LocationRuleScope.calendarDefault &&
            r.targetId == event.calendarId)
        .firstOrNull;
    if (calendar != null &&
        !(explicitlyPhysical &&
            calendar.choice.kind == LocationChoiceKind.online)) {
      if (calendar.choice.kind == LocationChoiceKind.online) {
        return finish(
            unresolved('This calendar default is Online.', review: false),
            online: true);
      }
      return finish(choice(calendar.choice, LocationSource.calendarDefault,
          providerExpiry: calendar.providerExpiresAt)!);
    }
    final trips = state.trips
        .where((t) => t.applies(
            calendarId: event.calendarId,
            eventId: event.id,
            start: event.startUtc,
            end: event.endUtc,
            now: now,
            allDayStart: event.allDayStart,
            allDayEnd: event.allDayEnd))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (trips.isNotEmpty) {
      return finish(point(trips.first.candidate, LocationSource.confirmedTrip,
          precision: LocationPrecision.city,
          quality: LocationEvidenceQuality.assumed,
          reason:
              'A confirmed trip area applies only to these calendars and dates.',
          expiresAt: trips.first.endUtc));
    }
    if (state.currentAreaFallbackEnabled) return finish(fallback());
    if (state.defaultArea?.hasValidCoordinates == true) {
      return finish(point(state.defaultArea!, LocationSource.defaultArea,
          precision: LocationPrecision.city,
          quality: LocationEvidenceQuality.assumed,
          provisional: event.startUtc.difference(now) > policy.provisionalAfter,
          reason: 'Using your explicitly selected PlanCast default area.'));
    }
    return finish(unresolved(
        'Automatic area fallback is off. Choose a PlanCast default area.'));
  }
}
