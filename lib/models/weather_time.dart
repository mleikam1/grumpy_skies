import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _zonesReady = false;

/// IANA conversion honors DST at the target instant. An offset is valid only
/// for the current observation period; it cannot predict future DST transitions.
DateTime? weatherLocalTime(DateTime instant, String? zone, int? offset,
    {bool forecast = false}) {
  if (zone != null && zone.isNotEmpty) {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
    try {
      return tz.TZDateTime.from(instant.toUtc(), tz.getLocation(zone));
    } on tz.LocationNotFoundException {
      // Unknown zones remain unknown instead of using the device's location.
    }
  }
  if (offset != null && !forecast) {
    return DateTime.fromMillisecondsSinceEpoch(
        instant.toUtc().millisecondsSinceEpoch + offset * 1000,
        isUtc: true);
  }
  return null;
}
