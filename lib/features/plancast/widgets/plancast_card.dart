import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../design/dm_spacing.dart';
import '../../../design/dm_theme.dart';
import '../../../models/temperature_unit.dart';
import '../../../config/app_routes.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/daymaker_components.dart';
import '../../../services/settings_controller.dart';
import '../plancast_controller.dart';
import '../screens/plancast_screen.dart';
import 'plancast_presentation.dart';
import 'plancast_guidance.dart';

/// A deliberately small entry point; calendar work never gates Today weather.
class PlanCastCard extends StatelessWidget {
  const PlanCastCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlanCastController?>();
    if (controller == null ||
        (!controller.connected && controller.invitationDismissed)) {
      return const SizedBox.shrink();
    }
    final settings = context.watch<SettingsController?>();
    final unit = settings?.temperatureUnit ?? TemperatureUnit.fahrenheit;
    final today = controller.clock().toLocal();
    final summary = controller.summaryForDay(today);
    final items = summary.events;
    final readout = controller.readoutForDay(today,
        temperatureUnit: unit, summary: summary);
    void open() => context.push(AppRoutes.planCast);
    return DmGlassCard(
      key: const ValueKey('plancast-card'),
      padding: const EdgeInsets.all(DMSpacing.md),
      shadows: const [],
      blurSigma: 0,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_note_outlined,
              size: 28, color: context.dmColors.insightIcon),
          const SizedBox(width: DMSpacing.sm),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('PlanCast', style: DMTypography.headingSmall)),
                if (controller.connected)
                  Text('Today',
                      style: DMTypography.label
                          .copyWith(color: context.dmColors.textSecondary)),
              ]),
              const SizedBox(height: DMSpacing.xxs),
              Text('Weather for your plans',
                  style: DMTypography.bodySmall
                      .copyWith(color: context.dmColors.textSecondary)),
            ]),
          ),
          if (controller.connected)
            IconButton(
              tooltip: 'Open PlanCast',
              onPressed: open,
              icon: const Icon(Icons.chevron_right),
            ),
          if (!controller.connected)
            IconButton(
              tooltip: 'Dismiss PlanCast invitation',
              onPressed: controller.dismissInvitation,
              icon: const Icon(Icons.close),
            ),
        ]),
        const SizedBox(height: DMSpacing.sm),
        if (!controller.supported)
          const Text(
              'Device calendars are available in the Android and iOS app. Your normal forecast works here on the web.')
        else if (!controller.connected) ...[
          const Text(
              'A daily take on your plans and their weather. Choose which device calendars to include.',
              style: DMTypography.bodySmall),
          const SizedBox(height: DMSpacing.sm),
          FilledButton(onPressed: open, child: const Text('Connect calendars')),
        ] else if (controller.loading && items.isEmpty) ...[
          const PlanCastLoadingPreview(compact: true),
        ] else ...[
          PlanCastBriefingCard(
              readout: readout,
              compact: true,
              guidance: PlanCastSummaryGuidance(summary: summary)),
          const SizedBox(height: DMSpacing.sm),
          PlanCastSummaryRow(summary: summary, compact: true),
          if (controller.loading)
            const Padding(
                padding: EdgeInsets.only(top: DMSpacing.xs),
                child: Text('Refreshing your plans…',
                    style: DMTypography.bodySmall)),
          if (controller.error != null)
            Padding(
                padding: const EdgeInsets.only(top: DMSpacing.xs),
                child: Text(controller.error!, style: DMTypography.bodySmall)),
          if (items.isNotEmpty) const SizedBox(height: DMSpacing.xs),
          for (final item in items.take(2)) ...[
            PlanCastEventTile(item: item, compact: true, day: today),
            if (items.take(2).last != item)
              Divider(height: 1, color: context.dmColors.divider),
          ],
          const SizedBox(height: DMSpacing.xxs),
          TextButton(
              onPressed: open,
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DMSpacing.xxs),
                  minimumSize: const Size(double.infinity, 48)),
              child: const Row(children: [
                Expanded(child: Text('View my PlanCast')),
                Icon(Icons.chevron_right),
              ])),
        ],
      ]),
    );
  }
}
