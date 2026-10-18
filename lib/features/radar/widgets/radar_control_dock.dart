import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/dm_theme.dart';
import '../../../models/weather_models.dart';
import '../radar_playback_controller.dart';
import '../radar_presentation.dart';
import 'radar_color_scale.dart';

/// The same controls drive the normal dock and expanded playback strip.
class RadarControlDock extends StatelessWidget {
  const RadarControlDock(
      {super.key,
      required this.controller,
      required this.presentation,
      required this.expanded,
      required this.onDetails,
      required this.onLegend,
      this.status,
      this.loading = false});
  final RadarPlaybackController controller;
  final RadarPresentation presentation;
  final bool expanded;
  final VoidCallback onDetails;
  final VoidCallback onLegend;
  final String? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.dmColors;
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    final frame = controller.selectedFrame;
    return RadarSurface(
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!expanded) ...[
            _ModeSelector(controller: controller),
          ],
          Row(children: [
            Semantics(
              button: true,
              enabled: controller.frames.length >= 2,
              onTap: controller.frames.length >= 2
                  ? controller.togglePlayback
                  : null,
              label: controller.playing
                  ? 'Pause radar timeline'
                  : 'Play radar timeline',
              child: ExcludeSemantics(
                  child: IconButton.filled(
                tooltip: controller.playing ? 'Pause' : 'Play',
                style: IconButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    minimumSize: const Size(50, 50)),
                icon: Icon(
                    controller.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 30),
                onPressed: controller.frames.length < 2
                    ? null
                    : controller.togglePlayback,
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(presentation.title,
                      style: TextStyle(
                          fontSize: expanded ? 16 : 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  Text(status ?? presentation.subtitle,
                      style: TextStyle(
                          fontSize: 13, height: 1.25, color: c.textSecondary)),
                ])),
            if (expanded)
              IconButton(
                  onPressed: onDetails,
                  tooltip: 'Radar details',
                  icon: const Icon(Icons.chevron_right_rounded))
            else if (!large &&
                (controller.mode == RadarMode.futureCast ||
                    !controller.isLatest))
              _Shortcut(controller: controller),
          ]),
          if (large &&
              !expanded &&
              (controller.mode == RadarMode.futureCast || !controller.isLatest))
            Align(
                alignment: Alignment.centerRight,
                child: _Shortcut(controller: controller)),
          if (loading)
            const Padding(
                padding: EdgeInsets.only(top: 3),
                child: LinearProgressIndicator(minHeight: 2)),
          _Timeline(controller: controller, presentation: presentation),
          if (!expanded)
            Flex(
                direction: large ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: large
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  if (large)
                    RadarColorScale(
                        source: frame?.source ?? controller.mode.sourceParam,
                        onOpenGuide: onLegend)
                  else
                    Expanded(
                        child: RadarColorScale(
                            source:
                                frame?.source ?? controller.mode.sourceParam,
                            onOpenGuide: onLegend)),
                  if (!large) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                        height: 24, child: VerticalDivider(color: c.border)),
                  ],
                  TextButton(
                      onPressed: onDetails,
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Details', style: TextStyle(fontSize: 13)),
                        Icon(Icons.chevron_right_rounded, size: 20)
                      ])),
                ]),
        ]),
      ),
    );
  }
}

class RadarSurface extends StatelessWidget {
  const RadarSurface({super.key, required this.child, this.borderRadius = 24});
  final Widget child;
  final double borderRadius;
  @override
  Widget build(BuildContext context) => Material(
        color: context.dmColors.surface,
        elevation: 2,
        shadowColor: context.dmColors.shadow,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(color: context.dmColors.border)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});
  final RadarPlaybackController controller;
  @override
  Widget build(BuildContext context) {
    final c = context.dmColors;
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        for (final future in [false, true])
          Expanded(
              child: Semantics(
            selected: (controller.mode == RadarMode.futureCast) == future,
            button: true,
            label: future ? 'Show FutureCast' : 'Show Live Radar',
            onTap: () => controller
                .setMode(future ? RadarMode.futureCast : controller.liveMode),
            child: ExcludeSemantics(
                child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => controller
                  .setMode(future ? RadarMode.futureCast : controller.liveMode),
              child: Ink(
                decoration: BoxDecoration(
                    color: (controller.mode == RadarMode.futureCast) == future
                        ? c.surfaceSecondary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(future ? Icons.timeline_rounded : Icons.radar,
                              size: 24),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(future ? 'FutureCast' : 'Live Radar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary))),
                        ])),
              ),
            )),
          )),
      ]),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.controller});
  final RadarPlaybackController controller;
  @override
  Widget build(BuildContext context) {
    final future = controller.mode == RadarMode.futureCast;
    return TextButton(
        onPressed:
            !controller.canJumpToNow ? null : controller.jumpToLatestOrNow,
        child: Text(future ? 'Now' : 'Latest',
            style: const TextStyle(fontSize: 13)));
  }
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.controller, required this.presentation});
  final RadarPlaybackController controller;
  final RadarPresentation presentation;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _focus = FocusNode(debugLabel: 'Radar timeline');
  bool _hasFocus = false;
  RadarPlaybackController get controller => widget.controller;
  RadarPresentation get presentation => widget.presentation;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (controller.frames.length < 2 ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final int target;
    if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = controller.frames.length - 1;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight)) {
      target = controller.selectedIndex + 1;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft)) {
      target = controller.selectedIndex - 1;
    } else {
      return KeyEventResult.ignored;
    }
    // Step actual available frames, even across a wide metadata gap. Flutter's
    // continuous-slider keyboard increment can otherwise snap back forever.
    controller.selectIndex(target);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final frames = controller.frames;
    final frame = controller.selectedFrame;
    final first = frames.isEmpty ? 0 : frames.first.timestamp;
    final span = frames.isEmpty ? 0 : frames.last.timestamp - first;
    final value = frame == null || span == 0
        ? 0.0
        : ((frame.timestamp - first) / span).clamp(0.0, 1.0);
    final c = context.dmColors;
    final labelHeight = MediaQuery.textScalerOf(context).scale(11) *
        (presentation.timelineTicks.any((tick) => tick.label.length > 13)
            ? 2.5
            : 1.5);
    return SizedBox(
        height: 34 + labelHeight,
        child: Stack(children: [
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Semantics(
                enabled: frames.length >= 2,
                label: 'Radar timeline',
                value: presentation.timelineValue,
                increasedValue: controller.selectedIndex + 1 < frames.length
                    ? presentation
                        .timeLabelFor(frames[controller.selectedIndex + 1])
                    : null,
                decreasedValue: controller.selectedIndex > 0
                    ? presentation
                        .timeLabelFor(frames[controller.selectedIndex - 1])
                    : null,
                onIncrease: controller.selectedIndex + 1 < frames.length
                    ? () => controller.selectIndex(controller.selectedIndex + 1)
                    : null,
                onDecrease: controller.selectedIndex > 0
                    ? () => controller.selectIndex(controller.selectedIndex - 1)
                    : null,
                child: ExcludeSemantics(
                    child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: const Color(0xFF35C5F1),
                    inactiveTrackColor: c.border,
                    thumbColor: c.primary,
                    overlayColor: c.primary.withValues(alpha: .16),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Focus(
                    focusNode: _focus,
                    canRequestFocus: frames.length >= 2,
                    includeSemantics: false,
                    onKeyEvent: _handleKey,
                    onFocusChange: (value) => setState(() => _hasFocus = value),
                    child: Listener(
                      onPointerDown: (_) => _focus.requestFocus(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasFocus &&
                                    FocusManager.instance.highlightMode ==
                                        FocusHighlightMode.traditional
                                ? c.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: ExcludeFocus(
                          child: SizedBox(
                            height: 48,
                            child: Slider(
                              value: value,
                              min: 0,
                              max: 1,
                              onChanged: frames.length < 2
                                  ? null
                                  : (value) {
                                      final index =
                                          presentation.nearestFrameIndex(value);
                                      if (index != null) {
                                        controller.selectIndex(index);
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
              )),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                  child: LayoutBuilder(builder: (context, constraints) {
                final ticks = presentation.timelineTicks;
                if (ticks.isEmpty) return const SizedBox.shrink();
                // Endpoints remain readable; omit the midpoint when its actual position
                // or larger text would collide with either endpoint.
                final showMiddle = constraints.maxWidth >= 340 &&
                    MediaQuery.textScalerOf(context).scale(11) <= 16 &&
                    ticks.length == 3 &&
                    ticks[1].fraction > .3 &&
                    ticks[1].fraction < .7;
                final shown = [
                  ticks.first,
                  if (showMiddle) ticks[1],
                  if (ticks.length > 1) ticks.last
                ];
                return SizedBox(
                    height: labelHeight,
                    child: Stack(children: [
                      for (final tick in shown)
                        Align(
                            alignment: Alignment(tick.fraction * 2 - 1, -1),
                            child: SizedBox(
                                width: constraints.maxWidth /
                                    (showMiddle ? 3.2 : 2.1),
                                child: Text(tick.label,
                                    textAlign: tick == ticks.first
                                        ? TextAlign.left
                                        : tick == ticks.last
                                            ? TextAlign.right
                                            : TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11, color: c.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis))),
                    ]));
              }))),
        ]));
  }
}
