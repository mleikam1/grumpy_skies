import '../../../models/weather_time.dart';

enum GuidanceSurface {
  todaySummary,
  currentDetail,
  hourlyDetail,
  dayDetail,
  plancastSummary,
  eventDetail;

  String get catalogId => switch (this) {
        todaySummary => 'today_summary',
        currentDetail => 'current_detail',
        hourlyDetail => 'hourly_detail',
        dayDetail => 'day_detail',
        plancastSummary => 'plancast_summary',
        eventDetail => 'event_detail',
      };
}

enum GuidanceActivity {
  outdoor,
  dogWalking,
  cycling,
  walking,
  drivingCommute,
  outdoorEvent
}

enum EvidenceKind { observation, forecast, preference }

enum EvidenceAvailability { available, missing, unsupported, invalid }

enum PrecipitationType { none, liquidRain, snow, freezing, mixed, unknown }

enum RainIntensity { light, moderate, heavy, unknown }

enum GuidanceField {
  temperatureC,
  lowTemperatureC,
  feelsLikeC,
  humidityPercent,
  dewPointC,
  windKph,
  gustKph,
  visibilityMeters,
  precipitationProbability,
  precipitationType,
  rainIntensity,
  rainMillimeters,
  conditionCode,
  daylight,
  uvIndex,
  aqi,
  severeHazard,
  sunset
}

class GuidanceInterval {
  const GuidanceInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;
  bool get isValid => end.isAfter(start);
  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);
  bool overlaps(GuidanceInterval other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
  bool covers(GuidanceInterval other) =>
      !start.isAfter(other.start) && !end.isBefore(other.end);
  String get signature =>
      '${start.toUtc().toIso8601String()}/${end.toUtc().toIso8601String()}';
}

class GuidanceLocation {
  const GuidanceLocation(
      {required this.key,
      required this.label,
      this.precision = 'forecast point',
      this.assumed = false,
      this.timezone,
      this.latitude,
      this.longitude,
      this.observedAt,
      this.validUntil});
  final String key;
  final String label;
  final String precision;
  final bool assumed;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  final DateTime? observedAt;
  final DateTime? validUntil;
  bool validAt(DateTime now) =>
      key.isNotEmpty &&
      (validUntil == null || now.isBefore(validUntil!)) &&
      (observedAt == null || !observedAt!.isAfter(now));
  DateTime? localTime(DateTime instant) =>
      weatherLocalTime(instant, timezone, null, forecast: true);
}

/// A value is usable only with its source timestamp, period and spatial scope.
/// fetchedAt is deliberately never an observation/issue freshness substitute.
class EvidenceField<T> {
  const EvidenceField(
      {required this.field,
      required this.value,
      required this.unit,
      required this.provider,
      required this.kind,
      required this.location,
      required this.interval,
      required this.sourceTime,
      this.fetchedAt,
      this.availability = EvidenceAvailability.available,
      this.sourcePrecision = 'point',
      this.timestampMeaning = 'provider observation',
      this.issueTime});
  final GuidanceField field;
  final T? value;
  final String unit;
  final String provider;
  final EvidenceKind kind;
  final GuidanceLocation location;
  final GuidanceInterval interval;
  final DateTime? sourceTime;
  final DateTime? issueTime;
  final DateTime? fetchedAt;
  final EvidenceAvailability availability;
  final String sourcePrecision;
  final String timestampMeaning;
  bool get available =>
      availability == EvidenceAvailability.available && value != null;
  String get signature =>
      '${field.name}:$value:$unit:${kind.name}:${sourceTime?.toUtc().toIso8601String()}:${interval.signature}:${location.key}:$sourcePrecision';
}

class WeatherEvidencePeriod {
  WeatherEvidencePeriod(
      {required this.interval,
      required Iterable<EvidenceField<Object>> fields,
      this.daily = false})
      : fields = List.unmodifiable(fields);
  final GuidanceInterval interval;
  final List<EvidenceField<Object>> fields;
  final bool daily;
  EvidenceField<Object>? field(GuidanceField key) {
    for (final item in fields) {
      if (item.field == key) return item;
    }
    return null;
  }
}

class GuidanceAlert {
  const GuidanceAlert(
      {required this.id,
      required this.event,
      required this.issuer,
      required this.description,
      required this.location,
      required this.interval,
      required this.checkedAt,
      this.instructions,
      this.area,
      this.severity});
  final String id, event, issuer, description;
  final GuidanceLocation location;
  final GuidanceInterval interval;
  final DateTime? checkedAt;
  final String? instructions, area, severity;
}

class WeatherEvidence {
  WeatherEvidence(
      {required this.location,
      this.current,
      Iterable<WeatherEvidencePeriod> hourly = const [],
      Iterable<WeatherEvidencePeriod> daily = const [],
      Iterable<GuidanceAlert> alerts = const [],
      this.alertCoverageVerified = false,
      this.alertsCheckedAt,
      this.locationMatched = true})
      : hourly = List.unmodifiable(hourly),
        daily = List.unmodifiable(daily),
        alerts = List.unmodifiable(alerts);
  final GuidanceLocation location;
  final WeatherEvidencePeriod? current;
  final List<WeatherEvidencePeriod> hourly, daily;
  final List<GuidanceAlert> alerts;
  final bool alertCoverageVerified, locationMatched;
  final DateTime? alertsCheckedAt;
}

class GuidanceContext {
  const GuidanceContext(
      {required this.surface,
      required this.location,
      this.activity = GuidanceActivity.outdoor,
      this.window,
      this.knownActivity = false,
      this.userSelectedWindow = false,
      this.allDay = false,
      this.allowRefresh = false,
      this.outingDuration = const Duration(minutes: 30),
      this.unsupported = false,
      this.permissionDenied = false});
  final GuidanceSurface surface;
  final GuidanceLocation location;
  final GuidanceActivity activity;
  final GuidanceInterval? window;
  final bool knownActivity,
      userSelectedWindow,
      allDay,
      allowRefresh,
      unsupported,
      permissionDenied;
  final Duration outingDuration;
}

/// Product heuristics, not medical, road-safety or universal dog limits.
class GuidancePolicy {
  const GuidancePolicy(
      {this.observationMaxAge = const Duration(minutes: 30),
      this.forecastMaxAge = const Duration(hours: 6),
      this.aqiMaxAge = const Duration(hours: 1),
      this.uvMaxAge = const Duration(minutes: 30),
      this.alertMaxAge = const Duration(minutes: 10),
      this.windowHorizon = const Duration(hours: 12),
      this.rainPossible = .30,
      this.rainLikely = .60,
      this.meaningfulRainDifference = .20,
      this.warmC = 27,
      this.hotC = 32,
      this.coldC = 7,
      this.coolC = 16,
      this.materialTemperatureDifferenceC = 6,
      this.notableGustKph = 32,
      this.umbrellaWindKph = 32,
      this.dangerousWindKph = 64,
      this.dangerousHeatC = 40,
      this.dangerousColdC = -23,
      this.lowVisibilityMeters = 1000,
      this.humidPercent = 70,
      this.humidDewPointC = 18,
      this.elevatedUv = 3});
  final Duration observationMaxAge,
      forecastMaxAge,
      aqiMaxAge,
      uvMaxAge,
      alertMaxAge,
      windowHorizon;
  final double rainPossible,
      rainLikely,
      meaningfulRainDifference,
      warmC,
      hotC,
      coldC,
      coolC,
      materialTemperatureDifferenceC,
      notableGustKph,
      umbrellaWindKph,
      dangerousWindKph,
      dangerousHeatC,
      dangerousColdC,
      lowVisibilityMeters,
      humidPercent,
      humidDewPointC,
      elevatedUv;
  Duration maxAge(EvidenceField<Object> field) => switch (field.field) {
        GuidanceField.aqi => aqiMaxAge,
        GuidanceField.uvIndex => uvMaxAge,
        _ => field.kind == EvidenceKind.forecast
            ? forecastMaxAge
            : observationMaxAge,
      };
  bool usable(EvidenceField<Object>? field, DateTime now,
      GuidanceLocation location, GuidanceInterval target) {
    if (field == null ||
        !field.available ||
        field.provider.isEmpty ||
        field.unit.isEmpty ||
        field.location.key != location.key ||
        !field.location.validAt(now) ||
        !field.interval.end.isAfter(now) ||
        !field.interval.overlaps(target)) {
      return false;
    }
    final time = field.sourceTime;
    if (time == null ||
        time.millisecondsSinceEpoch <= 0 ||
        time.isAfter(now) ||
        !now.isBefore(time.add(maxAge(field)))) {
      return false;
    }
    if (field.value is num && !(field.value as num).isFinite) return false;
    if (field.value == PrecipitationType.unknown ||
        field.value == RainIntensity.unknown) {
      return false;
    }
    return switch (field.field) {
      GuidanceField.temperatureC ||
      GuidanceField.lowTemperatureC ||
      GuidanceField.feelsLikeC ||
      GuidanceField.dewPointC =>
        field.unit.startsWith('°C') && field.value is num,
      GuidanceField.windKph ||
      GuidanceField.gustKph =>
        field.unit == 'km/h' && field.value is num && (field.value as num) >= 0,
      GuidanceField.precipitationProbability =>
        field.unit.startsWith('fraction') &&
            field.value is num &&
            (field.value as num) >= 0 &&
            (field.value as num) <= 1,
      GuidanceField.humidityPercent => field.unit == '%' &&
          field.value is num &&
          (field.value as num) >= 0 &&
          (field.value as num) <= 100,
      GuidanceField.visibilityMeters =>
        field.unit == 'm' && field.value is num && (field.value as num) >= 0,
      GuidanceField.uvIndex => field.unit == 'UV Index' &&
          field.value is num &&
          (field.value as num) >= 0 &&
          (field.value as num) <= 30,
      GuidanceField.precipitationType => field.value is PrecipitationType,
      GuidanceField.rainIntensity => field.value is RainIntensity,
      GuidanceField.sunset =>
        field.unit == 'UTC instant' && field.value is DateTime,
      GuidanceField.daylight ||
      GuidanceField.severeHazard =>
        field.value is bool,
      _ => true,
    };
  }

  DateTime expiry(EvidenceField<Object> field) {
    final ageEnd = field.sourceTime!.add(maxAge(field));
    var end = ageEnd.isBefore(field.interval.end) ? ageEnd : field.interval.end;
    if (field.location.validUntil case final value? when value.isBefore(end)) {
      end = value;
    }
    return end;
  }
}

double? normalizeProbability(num? value, {required bool percent}) {
  if (value == null || !value.isFinite) return null;
  final result = percent ? value / 100 : value.toDouble();
  return result < 0 || result > 1 ? null : result;
}

double celsiusFromFahrenheit(num value) => (value - 32) * 5 / 9;
double kilometersPerHourFromMph(num value) => value * 1.609344;

/// Stable across isolates/platforms; unlike Object.hash, suitable for local pins.
String guidanceFingerprint(String value) {
  var hash = 0x811c9dc5;
  for (final code in value.codeUnits) {
    hash = ((hash ^ code) * 16777619) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
