import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../shared/widgets/daymaker_components.dart';
import 'widgets/fun_feature_tile.dart';
import 'widgets/fun_poll_results.dart';
import 'widgets/fun_wheel_visual.dart';

class FunZoneScreen extends StatefulWidget {
  const FunZoneScreen({super.key});

  @override
  State<FunZoneScreen> createState() => _FunZoneScreenState();
}

class _FunZoneScreenState extends State<FunZoneScreen> {
  static const _fortunes = [
    'Your umbrella has main-character energy today.',
    'Clouds are planning a dramatic entrance after lunch.',
    'A suspiciously cheerful breeze is headed your way.',
    'Your sunglasses will feel smug by 3 PM.',
  ];

  static const _predictions = [
    '74% chance of accidental sparkle.',
    '58% chance of snack-weather alignment.',
    '91% chance of sidewalk weather commentary.',
    '66% chance the forecast changes its mind.',
  ];

  static const _menaces = [
    'Sunbeam Instigator',
    'Drizzle Diplomat',
    'Wind Gust Showoff',
    'Humidity Headliner',
  ];

  static const _pollOptions = [
    FunPollOption(
      label: 'Sunny',
      percent: 56,
      color: DMColors.sunriseYellow,
    ),
    FunPollOption(
      label: 'Cloudy',
      percent: 28,
      color: DMColors.lavenderGlass,
    ),
    FunPollOption(
      label: 'Rainy',
      percent: 16,
      color: DMColors.rainTeal,
    ),
  ];

  var _fortuneIndex = -1;
  var _predictionIndex = -1;
  var _menaceIndex = -1;
  var _hasCrackedFortune = false;
  var _hasSpun = false;
  var _hasFoundMenace = false;

  void _crackFortune() {
    setState(() {
      _hasCrackedFortune = true;
      _fortuneIndex = (_fortuneIndex + 1) % _fortunes.length;
    });
    // TODO(haptics): Add a gentle success tick when the cookie opens.
    _showSnackBar('Fortune cookie cracked. Weather reveal ready.');
  }

  void _spinPrediction() {
    setState(() {
      _hasSpun = true;
      _predictionIndex = (_predictionIndex + 1) % _predictions.length;
    });
  }

  void _findMenace() {
    setState(() {
      _hasFoundMenace = true;
      _menaceIndex = (_menaceIndex + 1) % _menaces.length;
    });
  }

  void _showPollVoteMessage() {
    // TODO(haptics): Add selection feedback once poll votes persist.
    _showSnackBar('Vote counted for today.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _openMemeGenerator() {
    context.go(AppRoutes.memeGenerator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: _funZoneGradient,
        color: DMColors.deepNavy,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final breakpoint = DMBreakpoints.fromWidth(width);
              final maxWidth = switch (breakpoint) {
                DMBreakpoint.compact => double.infinity,
                DMBreakpoint.medium => 840.0,
                DMBreakpoint.expanded => 1180.0,
              };
              final gap = breakpoint.isExpanded ? DMSpacing.xl : DMSpacing.md;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: DMSpacing.pagePaddingForWidth(width).copyWith(
                  bottom: DMSpacing.x2,
                ),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FunZoneHeader(),
                          SizedBox(height: gap),
                          if (breakpoint.isCompact)
                            _buildCompactLayout(gap)
                          else if (breakpoint.isMedium)
                            _buildMediumLayout(gap)
                          else
                            _buildExpandedLayout(gap),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(double gap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fortuneTile(featured: true),
        SizedBox(height: gap),
        _pollTile(),
        SizedBox(height: gap),
        _predictorTile(),
        SizedBox(height: gap),
        _menaceTile(),
        SizedBox(height: gap),
        _memeTile(),
      ],
    );
  }

  Widget _buildMediumLayout(double gap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fortuneTile(featured: true, minHeight: 284),
        SizedBox(height: gap),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: 500,
          ),
          children: [
            _pollTile(),
            _predictorTile(compactWheel: true),
            _menaceTile(),
            _memeTile(),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedLayout(double gap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fortuneTile(featured: true, minHeight: 318),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _pollTile(minHeight: 278),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _predictorTile(minHeight: 380),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _menaceTile(minHeight: 206),
                  SizedBox(height: gap),
                  _memeTile(minHeight: 190),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fortuneTile({
    bool featured = false,
    double? minHeight,
  }) {
    return FunFeatureTile(
      icon: Icons.auto_awesome_rounded,
      title: 'Weather Fortune Cookie',
      subtitle: 'Crack a cookie. Get a weather reveal.',
      actionLabel: 'Crack One',
      actionSemanticLabel: 'Crack fortune cookie',
      onAction: _crackFortune,
      accentColor: DMColors.sunriseYellow,
      featured: featured,
      minHeight: minHeight,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DMColors.surfaceElevated,
          DMColors.twilightNavy,
          DMColors.deepNavy,
        ],
      ),
      body: _RevealPill(
        label: _hasCrackedFortune ? 'Reveal' : 'Ready',
        value: _hasCrackedFortune
            ? _fortunes[_fortuneIndex]
            : 'Tap Crack One for today\'s hint.',
        color: DMColors.sunriseYellow,
      ),
    );
  }

  Widget _pollTile({double? minHeight}) {
    return FunFeatureTile(
      icon: Icons.poll_outlined,
      title: 'Daily Weather Poll',
      actionLabel: 'Vote Now',
      actionSemanticLabel: 'Vote in daily weather poll',
      onAction: _showPollVoteMessage,
      accentColor: DMColors.mintGreen,
      minHeight: minHeight,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const FunPollResults(options: _pollOptions),
          const SizedBox(height: DMSpacing.md),
          Text(
            '1,842 votes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DMTypography.label.copyWith(color: DMColors.skyBlueSoft),
          ),
        ],
      ),
    );
  }

  Widget _predictorTile({
    bool compactWheel = false,
    double? minHeight,
  }) {
    return FunFeatureTile(
      icon: Icons.cyclone_outlined,
      title: 'Crazy Day Predictor',
      actionLabel: 'Spin Now',
      actionSemanticLabel: 'Spin crazy day predictor',
      onAction: _spinPrediction,
      accentColor: DMColors.playfulPink,
      minHeight: minHeight,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FunWheelVisual(size: compactWheel ? 112 : 144),
          const SizedBox(height: DMSpacing.md),
          _RevealPill(
            label: _hasSpun ? 'Prediction' : 'Forecast mood',
            value: _hasSpun
                ? _predictions[_predictionIndex]
                : 'Currently spinning up nonsense.',
            color: DMColors.playfulPink,
          ),
        ],
      ),
    );
  }

  Widget _menaceTile({double? minHeight}) {
    return FunFeatureTile(
      icon: Icons.person_search_outlined,
      title: 'Weather Menace',
      subtitle: 'What kind of weather menace are you?',
      actionLabel: 'Find Out',
      actionSemanticLabel: 'Find your weather menace type',
      onAction: _findMenace,
      accentColor: DMColors.lavenderGlass,
      minHeight: minHeight,
      body: _RevealPill(
        label: _hasFoundMenace ? 'Type' : 'Mystery',
        value: _hasFoundMenace ? _menaces[_menaceIndex] : 'Identity pending.',
        color: DMColors.lavenderGlass,
      ),
    );
  }

  Widget _memeTile({double? minHeight}) {
    return FunFeatureTile(
      icon: Icons.image_outlined,
      title: 'Meme Generator',
      actionLabel: 'Make a Meme',
      actionSemanticLabel: 'Open meme generator',
      onAction: _openMemeGenerator,
      accentColor: DMColors.skyBlue,
      minHeight: minHeight,
      body: const _MemePreviewStrip(),
    );
  }
}

class _FunZoneHeader extends StatelessWidget {
  const _FunZoneHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DMRadius.large,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            DMColors.opacity(DMColors.sunriseYellow, 0.22),
            DMColors.opacity(DMColors.playfulPink, 0.18),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DMSpacing.md,
          DMSpacing.sm,
          DMSpacing.md,
          DMSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: DMSpacing.tapTarget,
              height: DMSpacing.tapTarget,
              decoration: const BoxDecoration(
                gradient: DMGradients.primaryAction,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DMColors.sunGlow,
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_emotions_rounded,
                color: DMColors.deepNavy,
              ),
            ),
            const SizedBox(width: DMSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fun Zone',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DMTypography.brandDisplay,
                  ),
                  SizedBox(height: DMSpacing.xs),
                  Text(
                    'Play. Predict. Laugh. Repeat.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DMTypography.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealPill extends StatelessWidget {
  const _RevealPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DMColors.opacity(color, 0.12),
        borderRadius: DMRadius.large,
        border: Border.all(color: DMColors.opacity(color, 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DMSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelSmall.copyWith(color: color),
            ),
            const SizedBox(height: DMSpacing.xs),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DMTypography.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemePreviewStrip extends StatelessWidget {
  const _MemePreviewStrip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _MemePreviewSwatch(color: DMColors.sunriseYellow),
        SizedBox(width: DMSpacing.xs),
        _MemePreviewSwatch(color: DMColors.playfulPink),
        SizedBox(width: DMSpacing.xs),
        _MemePreviewSwatch(color: DMColors.skyBlue),
      ],
    );
  }
}

class _MemePreviewSwatch extends StatelessWidget {
  const _MemePreviewSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DMColors.opacity(color, 0.8),
          borderRadius: DMRadius.medium,
          border: Border.all(color: DMColors.glassBorderStrong),
        ),
        child: const SizedBox(height: 48),
      ),
    );
  }
}

const _funZoneGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    DMColors.skyBlueDeep,
    DMColors.lavenderDeep,
    DMColors.playfulPink,
    DMColors.deepNavy,
  ],
  stops: [0, 0.36, 0.68, 1],
);
