import 'package:flutter/material.dart';

import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_spacing.dart';
import '../../shared/widgets/daymaker_components.dart';
import 'widgets/radar_alert_cards.dart';
import 'widgets/radar_header_card.dart';
import 'widgets/radar_map_controls.dart';
import 'widgets/radar_map_placeholder.dart';
import 'widgets/radar_timeline_scrubber.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  var _lightningEnabled = true;
  var _futureCastEnabled = true;
  var _playing = true;
  var _timelineValue = 1.0;

  void _showPlaceholderAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is ready for the future radar provider.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: DMGradients.storm,
        color: DMColors.deepNavy,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final breakpoint = DMBreakpoints.fromWidth(width);

            return Stack(
              fit: StackFit.expand,
              children: [
                RadarMapPlaceholder(
                  lightningEnabled: _lightningEnabled,
                  futureCastEnabled: _futureCastEnabled,
                  scanActive: _playing,
                  timelineIndex: _timelineValue.round(),
                ),
                if (breakpoint.isExpanded)
                  _ExpandedRadarChrome(
                    lightningEnabled: _lightningEnabled,
                    futureCastEnabled: _futureCastEnabled,
                    playing: _playing,
                    timelineValue: _timelineValue,
                    onTimelineChanged: (value) {
                      setState(() => _timelineValue = value);
                    },
                    onPlayPause: () => setState(() => _playing = !_playing),
                    onLightningChanged: (enabled) {
                      setState(() => _lightningEnabled = enabled);
                    },
                    onFutureCastChanged: (enabled) {
                      setState(() => _futureCastEnabled = enabled);
                    },
                    onZoomIn: () => _showPlaceholderAction('Zoom in'),
                    onZoomOut: () => _showPlaceholderAction('Zoom out'),
                    onLocate: () => _showPlaceholderAction('Location'),
                    onLayers: () => _showPlaceholderAction('Layers'),
                  )
                else
                  _CompactRadarChrome(
                    lightningEnabled: _lightningEnabled,
                    futureCastEnabled: _futureCastEnabled,
                    playing: _playing,
                    timelineValue: _timelineValue,
                    onTimelineChanged: (value) {
                      setState(() => _timelineValue = value);
                    },
                    onPlayPause: () => setState(() => _playing = !_playing),
                    onLightningChanged: (enabled) {
                      setState(() => _lightningEnabled = enabled);
                    },
                    onFutureCastChanged: (enabled) {
                      setState(() => _futureCastEnabled = enabled);
                    },
                    onZoomIn: () => _showPlaceholderAction('Zoom in'),
                    onZoomOut: () => _showPlaceholderAction('Zoom out'),
                    onLocate: () => _showPlaceholderAction('Location'),
                    onLayers: () => _showPlaceholderAction('Layers'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactRadarChrome extends StatelessWidget {
  const _CompactRadarChrome({
    required this.lightningEnabled,
    required this.futureCastEnabled,
    required this.playing,
    required this.timelineValue,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLightningChanged,
    required this.onFutureCastChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.onLayers,
  });

  final bool lightningEnabled;
  final bool futureCastEnabled;
  final bool playing;
  final double timelineValue;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final ValueChanged<bool> onLightningChanged;
  final ValueChanged<bool> onFutureCastChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapBreathingRoom =
              (constraints.maxHeight * 0.16).clamp(84.0, 156.0).toDouble();

          return SingleChildScrollView(
            padding: DMSpacing.pagePaddingForWidth(constraints.maxWidth)
                .copyWith(bottom: DMSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RadarHeaderCard(),
                const SizedBox(height: DMSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: RadarMapControls(
                    compact: true,
                    lightningEnabled: lightningEnabled,
                    futureCastEnabled: futureCastEnabled,
                    onLightningChanged: onLightningChanged,
                    onFutureCastChanged: onFutureCastChanged,
                    onZoomIn: onZoomIn,
                    onZoomOut: onZoomOut,
                    onLocate: onLocate,
                    onLayers: onLayers,
                  ),
                ),
                SizedBox(height: mapBreathingRoom),
                RadarTimelineScrubber(
                  playing: playing,
                  value: timelineValue,
                  onChanged: onTimelineChanged,
                  onPlayPause: onPlayPause,
                ),
                const SizedBox(height: DMSpacing.sm),
                const RadarAlertCards(layout: RadarAlertCardsLayout.compact),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpandedRadarChrome extends StatelessWidget {
  const _ExpandedRadarChrome({
    required this.lightningEnabled,
    required this.futureCastEnabled,
    required this.playing,
    required this.timelineValue,
    required this.onTimelineChanged,
    required this.onPlayPause,
    required this.onLightningChanged,
    required this.onFutureCastChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.onLayers,
  });

  final bool lightningEnabled;
  final bool futureCastEnabled;
  final bool playing;
  final double timelineValue;
  final ValueChanged<double> onTimelineChanged;
  final VoidCallback onPlayPause;
  final ValueChanged<bool> onLightningChanged;
  final ValueChanged<bool> onFutureCastChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: DMSpacing.pagePaddingForWidth(MediaQuery.sizeOf(context).width)
            .copyWith(bottom: DMSpacing.lg),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final controlsBelowHeader = constraints.maxWidth < 720;

                      return Stack(
                        children: [
                          const Positioned(
                            top: 0,
                            left: 0,
                            child: SizedBox(
                              width: 360,
                              child: RadarHeaderCard(),
                            ),
                          ),
                          Positioned(
                            top: controlsBelowHeader ? 126 : 0,
                            right: 0,
                            child: RadarMapControls(
                              compact: false,
                              lightningEnabled: lightningEnabled,
                              futureCastEnabled: futureCastEnabled,
                              onLightningChanged: onLightningChanged,
                              onFutureCastChanged: onFutureCastChanged,
                              onZoomIn: onZoomIn,
                              onZoomOut: onZoomOut,
                              onLocate: onLocate,
                              onLayers: onLayers,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            left: 0,
                            child: RadarTimelineScrubber(
                              playing: playing,
                              value: timelineValue,
                              onChanged: onTimelineChanged,
                              onPlayPause: onPlayPause,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: DMSpacing.xl),
                const SizedBox(
                  width: 344,
                  child:
                      RadarAlertCards(layout: RadarAlertCardsLayout.expanded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
