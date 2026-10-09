import 'package:flutter/material.dart';
import '../../design/dm_metric_colors.dart';

/// A content-sized metric tile shared by Today summary and detail grids.
/// Values wrap at larger text sizes; unavailable data keeps readable contrast.
class DmMetricChip extends StatelessWidget {
  const DmMetricChip(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.leading,
      this.tone = DMMetricTone.cool,
      this.status,
      this.available = true,
      this.onTap,
      this.semanticLabel})
      : assert(icon != null || leading != null);

  final String label;
  final String value;
  final String? status;
  final IconData? icon;
  final Widget? leading;
  final DMMetricTone tone;
  final bool available;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DMMetricColors.of(context, tone);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              IconTheme(
                  data: IconThemeData(color: colors.accent, size: 20),
                  child: leading ?? Icon(icon)),
              const SizedBox(width: 7),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          color: colors.label))),
            ]),
            const SizedBox(height: 9),
            Text(value,
                style: TextStyle(
                    fontSize: available ? 20 : 13,
                    height: 1.2,
                    fontWeight: available ? FontWeight.w700 : FontWeight.w500,
                    color: available ? colors.value : colors.unavailable)),
            if (status != null && status!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(status!,
                  style: TextStyle(
                      fontSize: 12, height: 1.3, color: colors.status)),
            ],
          ]),
    );
    return Semantics(
      button: onTap != null,
      label: semanticLabel ??
          [label, value, if (status != null) status!].join(', '),
      child: ExcludeSemantics(
          child: onTap == null
              ? content
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: onTap,
                      child: content))),
    );
  }
}
