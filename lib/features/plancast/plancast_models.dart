import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/weather_models.dart';
import 'smart_location_models.dart';

export 'smart_location_models.dart';

/// Hashes are opaque navigation/storage keys, never calendar titles or addresses.
String planCastId(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 24);

enum EventEnvironment { unknown, indoor, outdoor, online }

enum ForecastCoverage {
  loading,
  hourly,
  daily,
  partial,
  stale,
  tooEarly,
  unavailable,
  deferred,
  needsLocation,
  online
}

enum WeatherImpact { low, watch, disruption, unavailable }

extension WeatherImpactLabel on WeatherImpact {
  String get label => switch (this) {
        WeatherImpact.low => 'Low weather impact expected',
        WeatherImpact.watch => 'Worth watching',
        WeatherImpact.disruption => 'Weather disruption possible',
        WeatherImpact.unavailable => 'Forecast unavailable',
      };
}

class DeviceCalendar {
  const DeviceCalendar({required this.id, required this.name});
  final String id;
  final String name;
  factory DeviceCalendar.fromMap(Map<String, dynamic> value) => DeviceCalendar(
      id: value['id'].toString(), name: value['name'] as String? ?? 'Calendar');
}

/// Timed events keep true UTC instants plus IANA context. All-day dates are
/// floating civil dates with an EXCLUSIVE end, not midnight appointments.
class CalendarEvent {
  const CalendarEvent(
      {required this.id,
      required this.nativeId,
      required this.calendarId,
      required this.title,
      required this.startUtc,
      required this.endUtc,
      required this.timeZone,
      this.locationText = '',
      this.isAllDay = false,
      this.allDayStart,
      this.allDayEnd,
      this.latitude,
      this.longitude,
      this.nativeFingerprint,
      this.recurringId,
      this.legacyRecurringId,
      this.legacyLocationText,
      this.mapUrl,
      this.isRecurring = false,
      this.isDetached = false,
      this.originalStartUtc,
      this.tentative = false});
  final String id, nativeId, calendarId, title, timeZone, locationText;
  final DateTime startUtc, endUtc;
  final bool isAllDay, tentative;
  final DateTime? allDayStart, allDayEnd;
  final double? latitude, longitude;
  final String? recurringId;

  /// Read-only migration metadata; new rules always use [seriesKey].
  final String? legacyRecurringId, legacyLocationText;
  final String? nativeFingerprint;
  final String? mapUrl;
  final bool isRecurring, isDetached;
  final DateTime? originalStartUtc;

  String get displayTitle => title.trim().isEmpty ? 'Untitled plan' : title;
  String get recurringKey => planCastId(
      '$calendarId|${recurringId ?? nativeId}|${locationText.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}');
  String get legacyRecurringKey => planCastId(
      '$calendarId|${legacyRecurringId ?? recurringId ?? nativeId}|${(legacyLocationText ?? locationText).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}');
  bool matchesLegacyRecurringKey(String key) =>
      key == recurringKey || key == legacyRecurringKey;
  String get seriesKey => planCastId('$calendarId|${recurringId ?? nativeId}');
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      LocationCandidate.hasValidCoordinatePair(latitude!, longitude!);
  bool get hasDuration => endUtc.isAfter(startUtc);
  static CalendarEvent? fromMap(Map<String, dynamic> value) {
    final status = value['status']?.toString().toLowerCase();
    if (value['deleted'] == true ||
        value['deleted'] == 1 ||
        status == 'deleted' ||
        status == 'canceled' ||
        status == 'cancelled' ||
        status == 'declined') {
      return null;
    }
    final startMs = value['startMs'];
    final endMs = value['endMs'];
    if (startMs is! num ||
        endMs is! num ||
        !startMs.isFinite ||
        !endMs.isFinite ||
        startMs.abs() > 8640000000000000 ||
        endMs.abs() > 8640000000000000) {
      return null;
    }
    final start =
        DateTime.fromMillisecondsSinceEpoch(startMs.toInt(), isUtc: true);
    final end = DateTime.fromMillisecondsSinceEpoch(endMs.toInt(), isUtc: true);
    if (end.isBefore(start)) return null;
    final calendar = value['calendarId']?.toString() ?? '';
    final nativeId = value['id']?.toString() ?? '';
    if (nativeId.isEmpty || calendar.isEmpty) return null;
    final allDay = value['isAllDay'] == true;
    final first = _civilDate(value['allDayStart'] ?? value['startDate']);
    final last = _civilDate(value['allDayEnd'] ?? value['endDateExclusive']);
    // Reject malformed civil dates instead of silently shifting the event.
    if (allDay && (first == null || last == null || !last.isAfter(first))) {
      return null;
    }
    return CalendarEvent(
        id: planCastId('$calendar|$nativeId|${start.millisecondsSinceEpoch}'),
        nativeId: value['nativeEventId']?.toString() ?? nativeId,
        nativeFingerprint: value['nativeFingerprint'] as String?,
        calendarId: calendar,
        title: value['title'] as String? ?? '',
        startUtc: start,
        endUtc: end,
        timeZone: value['timeZone'] as String? ?? 'UTC',
        locationText: value['location'] as String? ?? '',
        isAllDay: allDay,
        allDayStart: first,
        allDayEnd: last,
        latitude: (value['latitude'] as num?)?.toDouble(),
        longitude: (value['longitude'] as num?)?.toDouble(),
        recurringId: value['recurringId']?.toString(),
        legacyRecurringId: value['legacyRecurringId']?.toString(),
        legacyLocationText: value['legacyLocation'] as String?,
        mapUrl: value['mapUrl'] as String?,
        isRecurring: value['isRecurring'] == true,
        isDetached: value['isDetached'] == true,
        originalStartUtc: value['originalStartMs'] is num &&
                (value['originalStartMs'] as num).isFinite &&
                (value['originalStartMs'] as num).abs() <= 8640000000000000
            ? DateTime.fromMillisecondsSinceEpoch(
                (value['originalStartMs'] as num).toInt(),
                isUtc: true)
            : null,
        tentative: status == 'tentative');
  }

  static DateTime? _civilDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        parsed.year != int.parse(value.substring(0, 4)) ||
        parsed.month != int.parse(value.substring(5, 7)) ||
        parsed.day != int.parse(value.substring(8, 10))) {
      return null;
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}

class EventOverride {
  const EventOverride(
      {this.venue,
      this.environment = EventEnvironment.unknown,
      this.remindersEnabled = true,
      required this.expiresAt});
  final LocationCandidate? venue;
  final EventEnvironment environment;
  final bool remindersEnabled;
  final DateTime expiresAt;
  Map<String, dynamic> toJson() => {
        'venue': venue?.toJson(),
        'environment': environment.name,
        'remindersEnabled': remindersEnabled,
        'expiresAt': expiresAt.toIso8601String()
      };
  factory EventOverride.fromJson(Map<String, dynamic> value) => EventOverride(
      venue: value['venue'] is Map
          ? LocationCandidate.fromJson(
              Map<String, dynamic>.from(value['venue'] as Map))
          : null,
      environment: EventEnvironment.values.firstWhere(
          (e) => e.name == value['environment'],
          orElse: () => EventEnvironment.unknown),
      remindersEnabled: value['remindersEnabled'] != false,
      expiresAt: DateTime.tryParse(value['expiresAt']?.toString() ?? '') ??
          DateTime.utc(1970));
}

class PlanCastPreferences {
  const PlanCastPreferences(
      {this.notifications = false,
      this.morningMinute = 420,
      this.evening = false,
      this.eveningMinute = 1080,
      this.eventHeadsUp = true,
      this.eventLeadMinutes = 120,
      this.dayBefore = false,
      this.quietStartMinute = 1320,
      this.quietEndMinute = 420,
      this.detailedNotificationPreviews = false,
      this.spokenPrivateTitles = false,
      this.bufferMinutes = 30});
  final bool notifications,
      evening,
      eventHeadsUp,
      dayBefore,
      detailedNotificationPreviews,
      spokenPrivateTitles;
  final int morningMinute,
      eveningMinute,
      eventLeadMinutes,
      quietStartMinute,
      quietEndMinute,
      bufferMinutes;
  PlanCastPreferences copyWith(
          {bool? notifications,
          int? morningMinute,
          bool? evening,
          int? eveningMinute,
          bool? eventHeadsUp,
          int? eventLeadMinutes,
          bool? dayBefore,
          int? quietStartMinute,
          int? quietEndMinute,
          bool? detailedNotificationPreviews,
          bool? spokenPrivateTitles,
          int? bufferMinutes}) =>
      PlanCastPreferences(
          notifications: notifications ?? this.notifications,
          morningMinute: morningMinute ?? this.morningMinute,
          evening: evening ?? this.evening,
          eveningMinute: eveningMinute ?? this.eveningMinute,
          eventHeadsUp: eventHeadsUp ?? this.eventHeadsUp,
          eventLeadMinutes: eventLeadMinutes ?? this.eventLeadMinutes,
          dayBefore: dayBefore ?? this.dayBefore,
          quietStartMinute: quietStartMinute ?? this.quietStartMinute,
          quietEndMinute: quietEndMinute ?? this.quietEndMinute,
          detailedNotificationPreviews:
              detailedNotificationPreviews ?? this.detailedNotificationPreviews,
          spokenPrivateTitles: spokenPrivateTitles ?? this.spokenPrivateTitles,
          bufferMinutes: bufferMinutes ?? this.bufferMinutes);
  Map<String, dynamic> toJson() => {
        'notifications': notifications,
        'morningMinute': morningMinute,
        'evening': evening,
        'eveningMinute': eveningMinute,
        'eventHeadsUp': eventHeadsUp,
        'eventLeadMinutes': eventLeadMinutes,
        'dayBefore': dayBefore,
        'quietStartMinute': quietStartMinute,
        'quietEndMinute': quietEndMinute,
        'detailedNotificationPreviews': detailedNotificationPreviews,
        'spokenPrivateTitles': spokenPrivateTitles,
        'bufferMinutes': bufferMinutes
      };
  factory PlanCastPreferences.fromJson(Map<String, dynamic> value) =>
      PlanCastPreferences(
          notifications: value['notifications'] == true,
          morningMinute: _minute(value['morningMinute'], 420),
          evening: value['evening'] == true,
          eveningMinute: _minute(value['eveningMinute'], 1080),
          eventHeadsUp: value['eventHeadsUp'] != false,
          eventLeadMinutes:
              ((value['eventLeadMinutes'] as num?)?.toInt() ?? 120)
                  .clamp(0, 1440),
          dayBefore: value['dayBefore'] == true,
          quietStartMinute: _minute(value['quietStartMinute'], 1320),
          quietEndMinute: _minute(value['quietEndMinute'], 420),
          detailedNotificationPreviews:
              value['detailedNotificationPreviews'] == true,
          spokenPrivateTitles: value['spokenPrivateTitles'] == true,
          bufferMinutes:
              ((value['bufferMinutes'] as num?)?.toInt() ?? 30).clamp(0, 180));
  static int _minute(Object? value, int fallback) =>
      ((value as num?)?.toInt() ?? fallback).clamp(0, 1439);
}

class EventWeatherAssessment {
  const EventWeatherAssessment(
      {required this.coverage,
      required this.impact,
      required this.explanation,
      this.advice = '',
      this.condition = 'Unknown',
      this.weatherIcon,
      this.peakPrecipitationChance,
      this.minTemperatureC,
      this.maxTemperatureC,
      this.maxWindKph,
      this.maxGustKph,
      this.forecastUpdatedAt,
      this.validUntil,
      this.alerts = const [],
      this.uncertainties = const [],
      this.arrival,
      this.leaving,
      this.dailyOnly = false,
      this.segments = const []});
  final ForecastCoverage coverage;
  final WeatherImpact impact;
  final String explanation, advice, condition;
  final String? weatherIcon;
  final int? peakPrecipitationChance;
  final double? minTemperatureC, maxTemperatureC, maxWindKph, maxGustKph;
  final DateTime? forecastUpdatedAt, validUntil;
  final List<WeatherAlert> alerts;
  final List<String> uncertainties;
  final EventWeatherAssessment? arrival, leaving;
  final List<EventWeatherSegment> segments;
  final bool dailyOnly;
  bool get isDaily => dailyOnly || coverage == ForecastCoverage.daily;
  bool get usable =>
      impact != WeatherImpact.unavailable &&
      (coverage == ForecastCoverage.hourly ||
          coverage == ForecastCoverage.daily ||
          coverage == ForecastCoverage.partial);
  bool get materiallyAffected =>
      impact == WeatherImpact.watch || impact == WeatherImpact.disruption;
  bool get serious => alerts.isNotEmpty || impact == WeatherImpact.disruption;
  String get precipitationLabel => isDaily
      ? 'Peak daily precipitation chance'
      : 'Peak hourly precipitation chance during your event';
}

class EventWeatherSegment {
  const EventWeatherSegment(
      {required this.label,
      required this.startUtc,
      required this.endUtc,
      required this.assessment});
  final String label;
  final DateTime startUtc, endUtc;
  final EventWeatherAssessment assessment;
}

class PlanCastEventWeather {
  const PlanCastEventWeather(
      {required this.event,
      required this.assessment,
      this.venue,
      this.resolvedLocation,
      this.participation = EventParticipation.unknown,
      this.venueTimeZone,
      this.venueTimeZoneOffset,
      this.environment = EventEnvironment.unknown,
      this.remindersEnabled = true});
  final CalendarEvent event;
  final EventWeatherAssessment assessment;
  final LocationCandidate? venue;
  final ResolvedLocation? resolvedLocation;
  final EventParticipation participation;
  final String? venueTimeZone;
  final int? venueTimeZoneOffset;
  final EventEnvironment environment;
  final bool remindersEnabled;
  bool get needsLocation =>
      !isOnline &&
      (resolvedLocation != null
          ? !resolvedLocation!.hasWeatherBasis
          : assessment.coverage == ForecastCoverage.needsLocation);
  bool get isOnline =>
      participation == EventParticipation.online ||
      environment == EventEnvironment.online;
  bool get automaticLocation => resolvedLocation?.automatic ?? false;
}

class PlanCastBriefing {
  const PlanCastBriefing(
      {required this.yourDay,
      required this.worthWatching,
      required this.beforeYouGo,
      this.tomorrow,
      this.personaLine,
      required this.generatedAt,
      required this.usableWeatherCount,
      required this.needsLocationCount,
      this.automaticLocationCount = 0,
      this.reviewLocationCount = 0});
  final String yourDay, worthWatching, beforeYouGo;
  final String? tomorrow, personaLine;
  final DateTime generatedAt;
  final int usableWeatherCount, needsLocationCount;
  final int automaticLocationCount, reviewLocationCount;
  String get text => [
        'Your day. $yourDay',
        'Worth watching. $worthWatching',
        'Before you go. $beforeYouGo',
        if (tomorrow != null) 'Tomorrow. $tomorrow',
        if (personaLine != null) 'One last opinion. $personaLine'
      ].join('\n\n');
}
