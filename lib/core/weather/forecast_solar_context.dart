import 'dart:math' as math;

/// Approximate daylight for a forecast instant at already-loaded coordinates.
/// Used only when the provider did not supply that hour's day/night metadata.
///
/// Implements NOAA's General Solar Position equations (fractional year,
/// declination, equation of time and zenith). Longitude is positive east.
/// https://gml.noaa.gov/grad/solcalc/solareqns.PDF
/// The -0.833 degree horizon includes the standard solar-disc/refraction
/// approximation used for sunrise/sunset. This is an icon choice, not a claim
/// about measured light, terrain, or an exact sunrise/sunset time.
/// https://gml.noaa.gov/grad/solcalc/calcdetails.html
///
/// Uses the target UTC date and location, so DST, date-line crossings and polar
/// day/night need no phone clock, timezone heuristic or reused solar events.
bool? forecastIsDaylight({
  required DateTime instant,
  double? latitude,
  double? longitude,
}) {
  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }
  final utc = instant.toUtc();
  final yearStart = DateTime.utc(utc.year);
  final daysInYear = DateTime.utc(utc.year + 1).difference(yearStart).inDays;
  final dayOfYear =
      DateTime.utc(utc.year, utc.month, utc.day).difference(yearStart).inDays +
          1;
  final utcMinutes = utc.hour * 60 + utc.minute + utc.second / 60;
  final yearAngle =
      2 * math.pi / daysInYear * (dayOfYear - 1 + (utcMinutes / 60 - 12) / 24);
  final equationOfTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(yearAngle) -
          0.032077 * math.sin(yearAngle) -
          0.014615 * math.cos(2 * yearAngle) -
          0.040849 * math.sin(2 * yearAngle));
  final declination = 0.006918 -
      0.399912 * math.cos(yearAngle) +
      0.070257 * math.sin(yearAngle) -
      0.006758 * math.cos(2 * yearAngle) +
      0.000907 * math.sin(2 * yearAngle) -
      0.002697 * math.cos(3 * yearAngle) +
      0.00148 * math.sin(3 * yearAngle);
  final solarMinutes = (utcMinutes + equationOfTime + 4 * longitude) % 1440;
  final hourAngle = _radians(solarMinutes / 4 - 180);
  final lat = _radians(latitude);
  final sineElevation = math.sin(lat) * math.sin(declination) +
      math.cos(lat) * math.cos(declination) * math.cos(hourAngle);
  return sineElevation >= math.sin(_radians(-0.833));
}

double _radians(double degrees) => degrees * math.pi / 180;
