import '../models/weather_models.dart';

const radarStepSeconds = 10 * 60;
const radarHistorySeconds = 120 * 60;
const radarUsForecastSeconds = 5 * 60 * 60;

int roundToNearestPastTenMinuteUnix([DateTime? date]) {
  final value = date ?? DateTime.now();
  return value.millisecondsSinceEpoch ~/
      1000 ~/
      radarStepSeconds *
      radarStepSeconds;
}

DateTime dateTimeFromUnixSeconds(int seconds) {
  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
}

List<RadarFrame> generateRadarFrames({
  required RadarMode mode,
  bool includeForecast = true,
  DateTime? now,
}) {
  final latest = roundToNearestPastTenMinuteUnix(now);
  final min = latest - radarHistorySeconds;
  final max = includeForecast ? latest + radarUsForecastSeconds : latest;
  final frames = <RadarFrame>[];

  for (var timestamp = min; timestamp <= max; timestamp += radarStepSeconds) {
    final offsetSeconds = timestamp - latest;
    final isLatest = offsetSeconds == 0;
    frames.add(
      RadarFrame(
        timestamp: timestamp,
        label: isLatest ? 'Latest' : _frameOffsetLabel(offsetSeconds),
        type: offsetSeconds < 0
            ? RadarFrameType.history
            : offsetSeconds > 0
                ? RadarFrameType.forecast
                : RadarFrameType.latest,
        isLatest: isLatest,
      ),
    );
  }

  return List.unmodifiable(frames);
}

String _frameOffsetLabel(int offsetSeconds) {
  final prefix = offsetSeconds.isNegative ? '-' : '+';
  final minutes = offsetSeconds.abs() ~/ 60;
  if (minutes < 60) return '$prefix$minutes min';

  final hours = minutes ~/ 60;
  final extraMinutes = minutes % 60;
  if (extraMinutes == 0) return '$prefix${hours}h';
  return '$prefix${hours}h ${extraMinutes}m';
}
