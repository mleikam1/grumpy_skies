import 'dart:convert';
import 'dart:developer';

import '../../../services/network_counters.dart';
import '../../fun/meme/meme_weather.dart';
import '../content/roast_selector.dart';
import '../controllers/local_roast_controller.dart';

/// Registered only inside an assert in main. Invoke from Flutter DevTools:
/// ext.grumpyskies.roasts. This inspector does not select, fetch, or upload.
void registerRoastInspector(
    LocalRoastController controller, DisplayedRoastRegistry registry) {
  registerExtension('ext.grumpyskies.roasts', (_, __) async {
    final selection = registry.choices.firstOrNull?.selection;
    final pack = controller.pack;
    final context = controller.lastContext;
    final data = {
      'displayed': selection == null
          ? null
          : {
              'id': selection.id,
              'family': selection.familyId,
              'rule': selection.ruleId,
              'mood': selection.mood.name,
              'pack': selection.packVersion,
              'source': selection.source,
              'reason': selection.reason,
              'weather_timestamp':
                  selection.weatherTimestamp?.toUtc().toIso8601String(),
            },
      'context': context?.diagnostics,
      'history': [
        for (final entry in controller.exposures)
          {
            'id': entry.id,
            'family': entry.familyId,
            'persona': entry.persona,
            'mood': entry.mood.name,
            'shown_at': entry.selectedAt?.toUtc().toIso8601String(),
          }
      ],
      if (selection != null && pack != null && context != null)
        'eligibility_failures': {
          for (final line in const RoastSelector()
              .candidates(pack, selection.persona, selection.line.type))
            line.id: const RoastSelector().eligibilityFailures(
                line: line,
                pack: pack,
                context: context,
                persona: selection.persona,
                type: selection.line.type,
                maxLevel: controller.intensity,
                disabledIds: controller.repository.disabledIds),
        },
      'network_counters': NetworkCounters.instance.snapshot,
      'note':
          'Local counters; backend requests are not upstream provider call estimates.',
    };
    return ServiceExtensionResponse.result(jsonEncode(data));
  });
}
