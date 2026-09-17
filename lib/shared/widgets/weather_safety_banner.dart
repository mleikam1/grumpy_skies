import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/weather_models.dart';
import '../../services/weather_location_controller.dart';

/// Compact persistent access to official warnings outside the Forecast view.
/// Newly received warnings expand the summary, including after an SDK ad closes.
class WeatherSafetyBanner extends StatefulWidget {
  const WeatherSafetyBanner({super.key, this.onModalChanged});
  final ValueChanged<bool>? onModalChanged;

  @override
  State<WeatherSafetyBanner> createState() => _WeatherSafetyBannerState();
}

class _WeatherSafetyBannerState extends State<WeatherSafetyBanner> {
  String? _collapsedFingerprint;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<WeatherLocationController?>()?.activeAlerts ??
        const <WeatherAlert>[];
    if (alerts.isEmpty) return const SizedBox.shrink();
    final fingerprint = alerts
        .map((alert) =>
            '${alert.senderName}|${alert.event}|${alert.start}|${alert.end}|${alert.description}')
        .join(';');
    final collapsed = _collapsedFingerprint == fingerprint;
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            collapsed
                                ? '${alerts.length} weather alert${alerts.length == 1 ? '' : 's'}'
                                : alerts.first.event,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer))),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: () => _showDetails(alerts),
                        child: const Text('Details')),
                    if (!collapsed)
                      IconButton(
                          tooltip: 'Collapse alert summary',
                          onPressed: () => setState(
                              () => _collapsedFingerprint = fingerprint),
                          icon: const Icon(Icons.expand_less)),
                  ]),
                ]),
          )),
    );
  }

  Future<void> _showDetails(List<WeatherAlert> alerts) async {
    widget.onModalChanged?.call(true);
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => FractionallySizedBox(
                heightFactor: 0.8,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text('Official weather alerts',
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                          IconButton(
                              tooltip: 'Close alert details',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close))
                        ]),
                        for (final alert in alerts) ...[
                          Text(alert.event,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('Source: ${alert.senderName}'),
                          if (alert.area?.isNotEmpty == true)
                            Text('Area: ${alert.area}'),
                          if (alert.start != null)
                            Text('Starts: ${alert.start!.toLocal()}'),
                          if (alert.end != null)
                            Text('Expires: ${alert.end!.toLocal()}'),
                          const SizedBox(height: 8),
                          if (alert.instructions?.isNotEmpty == true)
                            Text(alert.instructions!),
                          Text(alert.description.isEmpty
                              ? 'No additional details were provided.'
                              : alert.description),
                          const Divider(height: 32),
                        ],
                      ],
                    )),
              ));
    } finally {
      widget.onModalChanged?.call(false);
    }
  }
}
