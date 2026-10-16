import 'plancast_models.dart';

class PlanCastBriefingComposer {
  const PlanCastBriefingComposer();
  PlanCastBriefing compose(
      {required List<PlanCastEventWeather> today,
      required List<PlanCastEventWeather> tomorrow,
      required DateTime now,
      String? personaLine,
      bool privateTitles = true}) {
    final usable = today.where((e) => e.assessment.usable).length;
    final missing = today.where((e) => e.needsLocation).length;
    final affected = today
        .where((e) => e.assessment.materiallyAffected && e.assessment.usable)
        .toList()
      ..sort((a, b) =>
          b.assessment.impact.index.compareTo(a.assessment.impact.index));
    String eventLabel(PlanCastEventWeather item) => privateTitles
        ? (item.event.isAllDay
            ? 'An all-day plan'
            : 'Your ${_time(item.event.startUtc.toLocal())} plan')
        : item.event.displayTitle;
    final watch = affected
        .take(2)
        .map((item) => '${eventLabel(item)}: ${item.assessment.explanation}')
        .join(' ');
    final nextDay = tomorrow
        .where((e) => e.assessment.usable && e.assessment.materiallyAffected)
        .toList();
    return PlanCastBriefing(
        yourDay: today.isEmpty
            ? 'No plans in your selected calendars for this day.'
            : 'You have ${today.length} upcoming or in-progress ${today.length == 1 ? 'plan' : 'plans'}. $usable ${usable == 1 ? 'has' : 'have'} usable venue weather.${missing == 0 ? '' : ' $missing ${missing == 1 ? 'needs' : 'need'} a confirmed location.'}',
        worthWatching: watch.isNotEmpty
            ? watch
            : usable == 0 && today.isNotEmpty
                ? 'Weather coverage is not available yet. Review the event details for the missing information.'
                : 'No material weather issue appears in the available event forecasts.',
        beforeYouGo: affected.isNotEmpty
            ? affected.first.assessment.advice
            : missing > 0
                ? 'Confirm locations to get weather for your actual venues.'
                : 'Check the latest forecast before leaving.',
        tomorrow: nextDay.isEmpty
            ? null
            : '${nextDay.length} ${nextDay.length == 1 ? 'plan has' : 'plans have'} weather worth watching. ${nextDay.first.assessment.advice}',
        // Serious weather overrides optional presentation humor. Titles are never
        // supplied to a roast engine by this composer.
        personaLine: today.any((e) => e.assessment.serious) || usable == 0
            ? null
            : personaLine,
        generatedAt: now,
        usableWeatherCount: usable,
        needsLocationCount: missing);
  }

  static String _time(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
