import 'package:flutter/material.dart';
import '../../../design/dm_theme.dart';
import '../../../shared/widgets/dm_approved_components.dart';

class ForecastHeader extends StatelessWidget {
  const ForecastHeader(
      {super.key,
      required this.location,
      required this.onChangeLocation,
      this.onNotificationsPressed,
      this.status = 'Updated'});
  final String location;
  final VoidCallback? onNotificationsPressed;
  final VoidCallback onChangeLocation;
  final String status;
  @override
  Widget build(BuildContext context) => Column(children: [
        const DmPageHeader(),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
              child: InkWell(
                  onTap: onChangeLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(location,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700))),
                        const Icon(Icons.expand_more, size: 20),
                      ])))),
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  border: Border.all(color: context.dmColors.border),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(status.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1))),
        ]),
      ]);
}
