const radarStepSeconds = 10 * 60;
const radarHistorySeconds = 48 * 60 * 60;
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
