import '../models/weather_models.dart';

const radarStepSeconds = 10 * 60;
const radarNoaaStepSeconds = 5 * 60;
const radarHistorySeconds = 90 * 60;
const radarGlobalHistorySeconds = 120 * 60;
const radarUsForecastSeconds = 6 * 60 * 60;

int roundToNearestPastTenMinuteUnix([DateTime? date]) {
  final value = date ?? DateTime.now();
  return value.millisecondsSinceEpoch ~/
      1000 ~/
      radarStepSeconds *
      radarStepSeconds;
}

int roundToNearestPastFiveMinuteUnix([DateTime? date]) {
  final value = date ?? DateTime.now();
  return value.millisecondsSinceEpoch ~/
      1000 ~/
      radarNoaaStepSeconds *
      radarNoaaStepSeconds;
}

int roundToNearestPastRadarUnix({
  required RadarMode mode,
  DateTime? date,
}) {
  return mode == RadarMode.usForecast
      ? roundToNearestPastFiveMinuteUnix(date)
      : roundToNearestPastTenMinuteUnix(date);
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
  final latest = roundToNearestPastRadarUnix(mode: mode, date: now);
  final step =
      mode == RadarMode.usForecast ? radarNoaaStepSeconds : radarStepSeconds;
  final history = switch (mode) {
    RadarMode.usForecast => radarHistorySeconds,
    RadarMode.futureCast => 0,
    RadarMode.global => radarGlobalHistorySeconds,
  };
  final min = latest - history;
  final max = mode == RadarMode.futureCast || includeForecast
      ? latest + radarUsForecastSeconds
      : latest;
  final frames = <RadarFrame>[];

  for (var timestamp = min; timestamp <= max; timestamp += step) {
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
