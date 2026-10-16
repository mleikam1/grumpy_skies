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
import 'plancast_location_controls.dart';

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
    final persona = settings?.selectedPersonaId;
    final unit = settings?.temperatureUnit ?? TemperatureUnit.fahrenheit;
    final today = controller.clock().toLocal();
    final items = controller.eventsForDay(today);
    final briefing = controller.briefingForDay(today,
        persona: persona, temperatureUnit: unit);
    return DmGlassCard(
      key: const ValueKey('plancast-card'),
      padding: const EdgeInsets.all(DMSpacing.md),
      shadows: const [],
      blurSigma: 0,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_note_outlined, color: context.dmColors.insightIcon),
          const SizedBox(width: DMSpacing.sm),
          const Expanded(
              child: Text('PlanCast', style: DMTypography.headingSmall)),
          if (!controller.connected)
            IconButton(
              tooltip: 'Dismiss PlanCast invitation',
              onPressed: controller.dismissInvitation,
              icon: const Icon(Icons.close),
            ),
        ]),
        const Text('Your plans. The sky’s opinion.',
            style: DMTypography.bodySmall),
        const SizedBox(height: DMSpacing.sm),
        if (!controller.supported)
          const Text(
              'Device calendars are available in the Android and iOS app. Your normal forecast works here on the web.')
        else if (!controller.connected) ...[
          const Text(
              'An optional daily weather readout for the calendars you choose. Read-only, with private details kept on this device.'),
          const SizedBox(height: DMSpacing.sm),
          FilledButton(
              onPressed: () => context.push(AppRoutes.planCast),
              child: const Text('Connect calendars')),
        ] else ...[
          const Text('Today', style: DMTypography.labelLarge),
          const SizedBox(height: DMSpacing.xs),
          Text(
              items.isEmpty
                  ? 'No plans for today.'
                  : planCastScopeSummary(items),
              style: DMTypography.bodySmall),
          PlanCastLocationNotice(items: items),
          for (final item in items.take(2))
            PlanCastEventTile(item: item, compact: true),
          if (briefing.personaLine != null)
            Text(briefing.personaLine!, style: DMTypography.bodySmall),
          TextButton(
              onPressed: () => context.push(AppRoutes.planCast),
              child: const Text('View my PlanCast')),
        ],
      ]),
    );
  }
}
