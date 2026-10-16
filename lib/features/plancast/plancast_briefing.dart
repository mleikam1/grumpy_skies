import 'location_resolver.dart';
import 'plancast_event_copy.dart';
import 'plancast_models.dart';

class PlanCastBriefingComposer {
  const PlanCastBriefingComposer();
  PlanCastBriefing compose(
      {required List<PlanCastEventWeather> today,
      required List<PlanCastEventWeather> tomorrow,
      required DateTime now,
      String? personaLine,
      bool privateTitles = true}) {
    final available =
        today.where((e) => !e.isOnline && e.assessment.usable).toList();
    final usable = available.length;
    final missingPlans = today.where((e) => e.needsLocation).toList();
    final missing = missingPlans.length;
    const extractor = EventLocationExtractor();
    final needsDefaultArea = missingPlans.any((item) {
      final evidence = extractor.extract(item.event);
      return !evidence.hasDestinationEvidence &&
          !evidence.virtualOnly &&
          item.resolvedLocation?.evidenceQuality !=
              LocationEvidenceQuality.conflict;
    });
    final needsDestinationReview = missingPlans.any((item) =>
        extractor.extract(item.event).hasDestinationEvidence ||
        item.resolvedLocation?.evidenceQuality ==
            LocationEvidenceQuality.conflict);
    final automatic =
        today.where((e) => !e.isOnline && e.automaticLocation).length;
    final review = today
        .where((e) =>
            !e.isOnline &&
            e.resolvedLocation?.hasWeatherBasis == true &&
            e.resolvedLocation?.reviewSuggested == true)
        .length;
    final affected = available
        .where((e) => e.assessment.materiallyAffected)
        .toList()
      ..sort((a, b) =>
          b.assessment.impact.index.compareTo(a.assessment.impact.index));
    available.sort((a, b) => a.event.startUtc.compareTo(b.event.startUtc));
    final highlighted = affected.isNotEmpty ? affected : available;
    String eventLabel(PlanCastEventWeather item) => privateTitles
        ? (item.event.isAllDay
            ? 'An all-day plan'
            : 'Your ${PlanCastEventCopy.interval(item)} plan')
        : '${item.event.displayTitle} (${PlanCastEventCopy.interval(item)})';
    final watch = highlighted
        .take(2)
        .map((item) => [
              '${eventLabel(item)}:',
              PlanCastEventCopy.location(item, privateLabels: privateTitles),
              PlanCastEventCopy.weather(item.assessment),
            ].where((part) => part.isNotEmpty).join(' '))
        .join(' ');
    final nextDay = tomorrow
        .where((e) =>
            !e.isOnline &&
            e.assessment.usable &&
            e.assessment.materiallyAffected)
        .toList();
    final allOnline = today.isNotEmpty && today.every((e) => e.isOnline);
    return PlanCastBriefing(
        yourDay: today.isEmpty
            ? 'No plans in your selected calendars for this day.'
            : 'You have ${today.length} ${today.length == 1 ? 'plan' : 'plans'} in this view. $usable ${usable == 1 ? 'has' : 'have'} weather coverage.${automatic == 0 ? '' : ' $automatic ${automatic == 1 ? 'uses an automatic location' : 'use automatic locations'}.'}${review == 0 ? '' : ' $review ${review == 1 ? 'location can' : 'locations can'} be reviewed.'}${missing == 0 ? '' : ' $missing ${missing == 1 ? 'needs' : 'need'} a weather area.'}',
        worthWatching: watch.isNotEmpty
            ? watch
            : allOnline
                ? 'Online plans do not need venue weather.'
                : today.isNotEmpty
                    ? 'Weather coverage is not available yet. Event details distinguish loading, coverage limits, and location needs.'
                    : 'There are no event forecasts to review for this day.',
        beforeYouGo: affected.isNotEmpty &&
                affected.first.assessment.advice.isNotEmpty
            ? affected.first.assessment.advice
            : needsDefaultArea
                ? 'Choose one default area for plans without a location. Known destinations keep their own weather.'
                : needsDestinationReview
                    ? 'Review the unresolved destination for plans without weather. Your other forecasts remain available.'
                    : allOnline
                        ? 'Your online plans remain available without venue forecasts.'
                        : 'Check the latest event forecast before leaving.',
        tomorrow: nextDay.isEmpty
            ? null
            : '${nextDay.length} ${nextDay.length == 1 ? 'plan has' : 'plans have'} weather worth watching. ${PlanCastEventCopy.location(nextDay.first, privateLabels: privateTitles)} ${nextDay.first.assessment.advice}'
                .trim(),
        personaLine: today.any((e) => e.assessment.serious) || usable == 0
            ? null
            : personaLine,
        generatedAt: now,
        usableWeatherCount: usable,
        needsLocationCount: missing,
        automaticLocationCount: automatic,
        reviewLocationCount: review);
  }
}
