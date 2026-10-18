import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_theme.dart';
import '../../../design/dm_typography.dart';
import 'plancast_briefing_surface.dart';
import '../plancast_controller.dart';

/// The existing sky surface now presents only a factual weather briefing.
/// This widget only presents a resolved readout; it never loads weather.
class PlanCastBriefingCard extends StatefulWidget {
  const PlanCastBriefingCard({
    super.key,
    required this.readout,
    this.compact = false,
    this.onListen,
    this.listening = false,
    this.expandedContent,
    this.contextLabel,
    this.guidance,
  });

  final PlanCastReadout readout;
  final bool compact;
  final VoidCallback? onListen;
  final bool listening;
  final Widget? expandedContent;
  final String? contextLabel;
  final Widget? guidance;

  @override
  State<PlanCastBriefingCard> createState() => _PlanCastBriefingCardState();
}

class _PlanCastBriefingCardState extends State<PlanCastBriefingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.dmRoastColors;
    final compact = widget.compact;
    final copy = Text(
      compact ? widget.readout.compactText : widget.readout.text,
      style: (compact ? DMTypography.bodySmall : DMTypography.body).copyWith(
        color: colors.textPrimary,
        fontSize: compact ? 13 : 14,
        height: 1.35,
      ),
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.contextLabel != null && compact) ...[
          Text(widget.contextLabel!,
              style: DMTypography.label.copyWith(color: colors.textSecondary)),
          const SizedBox(height: DMSpacing.xxs),
        ],
        Text("Your day ahead",
            style: DMTypography.labelLarge.copyWith(
                color: colors.textPrimary, fontWeight: FontWeight.w800)),
      ],
    );
    return PlanCastBriefingSurface(
      key: const ValueKey('plancast-briefing-card'),
      colors: colors,
      borderRadius: BorderRadius.circular(compact ? 16 : 22),
      padding: EdgeInsets.all(compact ? DMSpacing.xs : DMSpacing.sm),
      child: LayoutBuilder(builder: (context, constraints) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: DMSpacing.xs),
              copy,
              if (widget.guidance != null) widget.guidance!,
              if (widget.onListen != null ||
                  widget.expandedContent != null) ...[
                const SizedBox(height: DMSpacing.xxs),
                Wrap(
                    spacing: DMSpacing.xs,
                    runSpacing: DMSpacing.xxs,
                    children: [
                      if (widget.onListen != null)
                        TextButton.icon(
                          onPressed: widget.onListen,
                          icon: Icon(widget.listening
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_outlined),
                          label: Text(widget.listening ? 'Stop' : 'Listen'),
                          style: TextButton.styleFrom(
                              foregroundColor: colors.textPrimary,
                              minimumSize: const Size(48, 48)),
                        ),
                      if (widget.expandedContent != null)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          icon: Icon(_expanded
                              ? Icons.expand_less
                              : Icons.expand_more),
                          label: Text(_expanded ? 'Less' : 'Full readout'),
                          style: TextButton.styleFrom(
                              foregroundColor: colors.textPrimary,
                              minimumSize: const Size(48, 48)),
                        ),
                    ]),
              ],
              if (_expanded && widget.expandedContent != null) ...[
                const SizedBox(height: DMSpacing.xs),
                widget.expandedContent!,
              ],
            ]);
      }),
    );
  }
}

/// Counts and rows consume the same resolved snapshot. Automatic location is
/// deliberately labelled as a subset, never added to the total plan count.
class PlanCastSummaryRow extends StatelessWidget {
  const PlanCastSummaryRow({
    super.key,
    required PlanCastDaySummary summary,
    this.onCalendars,
    this.calendarCount = 0,
    this.compact = false,
  })  : _summary = summary,
        _items = null;

  const PlanCastSummaryRow.fromItems({
    super.key,
    required List<PlanCastEventWeather> items,
    this.onCalendars,
    this.calendarCount = 0,
    this.compact = false,
  })  : _items = items,
        _summary = null;

  final PlanCastDaySummary? _summary;
  final List<PlanCastEventWeather>? _items;
  final VoidCallback? onCalendars;
  final int calendarCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (_summary?.state == PlanCastDayState.loading) {
      return PlanCastLoadingPreview(compact: compact);
    }
    final colors = context.dmColors;
    final items = _items ?? _summary!.events;
    final total = _summary?.planCount ?? items.length;
    final weather = _summary?.weatherCount ??
        items.where((e) => !e.isOnline && e.assessment.usable).length;
    final online =
        _summary?.onlineCount ?? items.where((e) => e.isOnline).length;
    final automatic = _summary?.automaticCount ??
        items.where((e) => !e.isOnline && e.automaticLocation).length;
    final stats = <({String label, int count, IconData icon, Color color})>[
      (
        label: 'Plans',
        count: total,
        icon: Icons.event_note_outlined,
        color: colors.insightIcon
      ),
      if (weather > 0)
        (
          label: 'With weather',
          count: weather,
          icon: Icons.wb_sunny_outlined,
          color: DMColors.sunriseYellow
        ),
      if (online > 0)
        (
          label: 'Online',
          count: online,
          icon: Icons.laptop_mac_outlined,
          color: colors.link
        ),
      if (automatic > 0 && !compact)
        (
          label: 'Auto-located',
          count: automatic,
          icon: Icons.place_outlined,
          color: colors.insightIcon
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(13) > 18;
        final columns = largeText || constraints.maxWidth < 280
            ? stats.length.clamp(1, 2)
            : stats.length;
        final width =
            (constraints.maxWidth - (columns - 1) * DMSpacing.xs) / columns;
        final tiles = <Widget>[
          for (final stat in stats)
            SizedBox(
              width: width,
              child: Semantics(
                container: true,
                label: '${stat.count} ${stat.label.toLowerCase()}'
                    '${stat.label == 'Auto-located' ? ', included in plans' : ''}',
                excludeSemantics: true,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: DMSpacing.xxs,
                      vertical: compact ? DMSpacing.xs : DMSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (compact)
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(stat.icon, size: 16, color: stat.color),
                                const SizedBox(width: DMSpacing.xxs),
                                Text('${stat.count}',
                                    style: DMTypography.labelLarge.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w800)),
                              ])
                        else ...[
                          Icon(stat.icon, size: 20, color: stat.color),
                          const SizedBox(height: DMSpacing.xxs),
                          Text('${stat.count}',
                              style: DMTypography.labelLarge.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w800)),
                        ],
                        const SizedBox(height: 2),
                        Text(stat.label,
                            textAlign: TextAlign.center,
                            style: DMTypography.bodySmall
                                .copyWith(color: colors.textSecondary)),
                      ]),
                ),
              ),
            ),
        ];
        return Column(children: [
          for (var start = 0; start < tiles.length; start += columns) ...[
            if (start > 0) const SizedBox(height: DMSpacing.xs),
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (var i = start;
                      i < (start + columns).clamp(0, tiles.length);
                      i++) ...[
                    if (i > start) const SizedBox(width: DMSpacing.xs),
                    tiles[i],
                  ],
                ])),
          ],
        ]);
      }),
      if (onCalendars != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onCalendars,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
                '$calendarCount ${calendarCount == 1 ? 'calendar' : 'calendars'}'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
    ]);
  }
}

/// Stable first-load geometry, with no fictional plan count or sunny icon.
class PlanCastLoadingPreview extends StatelessWidget {
  const PlanCastLoadingPreview({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading your plans and event forecasts',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Finding your plans…', style: DMTypography.labelLarge),
          const SizedBox(height: DMSpacing.sm),
          for (final width in [1.0, .7, .85])
            Padding(
              padding: const EdgeInsets.only(bottom: DMSpacing.xs),
              child: FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: compact ? 12 : 20,
                  decoration: BoxDecoration(
                    color: context.dmColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(DMSpacing.xs),
                  ),
                ),
              ),
            ),
        ]),
      );
}
