import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../guidance/domain/guidance.dart';
import '../../guidance/plancast_guidance_adapter.dart';
import '../../guidance/widgets/guidance_view.dart';
import '../plancast_controller.dart';
import '../screens/plancast_time_format.dart';

/// A display-only consumer of the event's already loaded forecast. Titles,
/// descriptions and decorative category icons never select an activity.
class PlanCastEventGuidance extends StatelessWidget {
  const PlanCastEventGuidance({
    super.key,
    required this.item,
    this.day,
    this.fallback,
  });

  final PlanCastEventWeather item;
  final DateTime? day;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlanCastController?>();
    if (controller == null) return fallback ?? const SizedBox.shrink();
    final input = PlanCastGuidanceAdapter.fromEventSnapshot(
      item: item,
      bundle: controller.cachedGuidanceWeatherForEvent(item),
      now: controller.clock(),
      day: day,
    );
    if (input == null) return fallback ?? const SizedBox.shrink();
    return GuidanceView(
      weather: input.weather,
      context: input.context,
      scopeKey: 'plancast-event:${input.eventId}',
      clock: controller.clock,
      fallback: fallback,
    );
  }
}

/// One optional event action in the existing factual daily readout. The shared
/// selection controller suppresses repeated actions in nearby event rows.
class PlanCastSummaryGuidance extends StatelessWidget {
  const PlanCastSummaryGuidance({super.key, required this.summary});
  final PlanCastDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlanCastController?>();
    if (controller == null) return const SizedBox.shrink();
    final items = [...summary.events]..sort((a, b) {
        final serious = (b.assessment.serious ? 1 : 0)
            .compareTo(a.assessment.serious ? 1 : 0);
        if (serious != 0) return serious;
        return a.event.startUtc.compareTo(b.event.startUtc);
      });
    for (final item in items) {
      if (item.environment != EventEnvironment.outdoor &&
          !item.assessment.serious) {
        continue;
      }
      final input = PlanCastGuidanceAdapter.fromEventSnapshot(
        item: item,
        bundle: controller.cachedGuidanceWeatherForEvent(item),
        now: controller.clock(),
        day: summary.day,
        surface: GuidanceSurface.plancastSummary,
      );
      if (input == null) continue;
      return GuidanceView(
        weather: input.weather,
        context: input.context,
        scopeKey: 'plancast-summary:${input.eventId}:${summary.day}',
        clock: controller.clock,
        heading:
            'For ${planCastEventTime(context, item.event, now: controller.clock())}',
      );
    }
    return const SizedBox.shrink();
  }
}
