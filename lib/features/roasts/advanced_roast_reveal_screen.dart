import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../data/daymaker_sample_data.dart';
import '../../design/dm_breakpoints.dart';
import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';
import '../../shared/widgets/daymaker_components.dart';
import 'widgets/advanced_roast_personas_row.dart';
import 'widgets/advanced_roast_reveal_card.dart';
import 'widgets/dm_achievement_badge.dart';

class AdvancedRoastRevealScreen extends StatefulWidget {
  const AdvancedRoastRevealScreen({super.key});

  @override
  State<AdvancedRoastRevealScreen> createState() =>
      _AdvancedRoastRevealScreenState();
}

class _AdvancedRoastRevealScreenState extends State<AdvancedRoastRevealScreen> {
  static const _roastText = 'You have more unopened tabs than opportunities.';
  static const _xpReward = 20;

  var _revealed = false;

  void _toggleReveal() {
    // TODO(haptics): Add a soft reveal tick on mobile.
    setState(() => _revealed = !_revealed);
  }

  void _revealFromGesture() {
    if (_revealed) return;
    // TODO(haptics): Trigger subtle feedback when drag reveal completes.
    setState(() => _revealed = true);
  }

  void _showHowItWorks() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tap or drag the fogged glass to reveal the roast.'),
        ),
      );
  }

  void _showPlaceholderMessage(String message) {
    // TODO(haptics): Add light tap feedback when these header actions exist.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareRoast() async {
    await Clipboard.setData(const ClipboardData(text: _roastText));
    if (!mounted) return;

    // TODO(haptics): Add success feedback after native share/copy completes.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Roast copied for sharing.')),
      );
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final router = GoRouter.maybeOf(context);
    router?.go(AppRoutes.roasts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DmAppBackground(
        gradient: DMGradients.appBackground,
        color: DMColors.deepNavy,
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final breakpoint = DMBreakpoints.fromWidth(width);
              final maxWidth = switch (breakpoint) {
                DMBreakpoint.compact => double.infinity,
                DMBreakpoint.medium => 760.0,
                DMBreakpoint.expanded => 960.0,
              };
              final gap = breakpoint.isExpanded ? DMSpacing.xl : DMSpacing.md;

              return ListView(
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
                          _Header(
                            onBackPressed: _goBack,
                            onLocationPressed: () => _showPlaceholderMessage(
                              'Location refresh is coming soon.',
                            ),
                            onNotificationsPressed: () =>
                                _showPlaceholderMessage(
                              'Roast notifications are coming soon.',
                            ),
                          ),
                          SizedBox(height: gap),
                          const _ProgressStrip(),
                          SizedBox(height: gap),
                          _AdvancedRoastIntro(onHowItWorks: _showHowItWorks),
                          const SizedBox(height: DMSpacing.md),
                          AdvancedRoastRevealCard(
                            revealed: _revealed,
                            personaName: DayMakerSampleData.persona.name,
                            avatarAsset: DayMakerSampleData.persona.avatarAsset,
                            roastText: _roastText,
                            xpReward: _xpReward,
                            onToggleReveal: _toggleReveal,
                            onRevealGesture: _revealFromGesture,
                            onShare: _shareRoast,
                          ),
                          SizedBox(height: gap),
                          const _SectionLabel('Personas'),
                          const SizedBox(height: DMSpacing.xs),
                          const AdvancedRoastPersonasRow(
                            personas: _personas,
                          ),
                          SizedBox(height: gap),
                          const _SectionLabel('Achievements'),
                          const SizedBox(height: DMSpacing.sm),
                          const _AchievementsRow(),
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
}

const _personas = <AdvancedRoastPersona>[
  AdvancedRoastPersona(
    name: 'Karen',
    unlocked: true,
    avatarAsset: 'assets/personas/karen.png',
    placeholderGradient: DMGradients.sunrise,
  ),
  AdvancedRoastPersona(
    name: 'Sunny',
    unlocked: true,
    placeholderGradient: DMGradients.clearSky,
    placeholderIcon: Icons.wb_sunny_rounded,
  ),
  AdvancedRoastPersona(
    name: 'Cloudy Carl',
    unlocked: false,
    lockLabel: 'Locked',
    placeholderGradient: DMGradients.twilight,
    placeholderIcon: Icons.cloud_rounded,
  ),
  AdvancedRoastPersona(
    name: 'Drizzle',
    unlocked: false,
    lockLabel: 'Locked',
    placeholderGradient: DMGradients.rain,
    placeholderIcon: Icons.grain_rounded,
  ),
  AdvancedRoastPersona(
    name: 'Thunder',
    unlocked: false,
    lockLabel: 'Locked',
    placeholderGradient: DMGradients.storm,
    placeholderIcon: Icons.thunderstorm_rounded,
  ),
];

class _Header extends StatelessWidget {
  const _Header({
    required this.onBackPressed,
    required this.onLocationPressed,
    required this.onNotificationsPressed,
  });

  final VoidCallback onBackPressed;
  final VoidCallback onLocationPressed;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DmIconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          semanticLabel: 'Back to Roasts',
          onPressed: onBackPressed,
        ),
        const SizedBox(width: DMSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DayMaker',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DMTypography.headingMedium,
              ),
              const SizedBox(height: DMSpacing.xxs),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: DMColors.textMuted,
                    size: DMSpacing.iconSm,
                  ),
                  const SizedBox(width: DMSpacing.xxs),
                  Flexible(
                    child: Text(
                      DayMakerSampleData.weatherSnapshot.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DMTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.my_location_rounded),
          semanticLabel: 'Use current location',
          tooltip: 'Use current location',
          onPressed: onLocationPressed,
          variant: DmIconButtonVariant.outline,
        ),
        const SizedBox(width: DMSpacing.xs),
        DmIconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          semanticLabel: 'Notifications',
          tooltip: 'Notifications',
          onPressed: onNotificationsPressed,
          variant: DmIconButtonVariant.glass,
        ),
      ],
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      _ProgressItem(
        label: 'Level 3',
        valueLabel: 'Current',
        value: 0.64,
        color: DMColors.sunriseYellow,
      ),
      _ProgressItem(
        label: '420 XP',
        valueLabel: '+20 ready',
        value: 0.42,
        color: DMColors.mintGreen,
      ),
      _ProgressItem(
        label: '5 day streak',
        valueLabel: 'Active',
        value: 0.72,
        color: DMColors.playfulPink,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              for (final item in items) ...[
                DmProgressPill(
                  value: item.value,
                  label: item.label,
                  valueLabel: item.valueLabel,
                  color: item.color,
                ),
                if (item != items.last) const SizedBox(height: DMSpacing.sm),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final item in items) ...[
              Expanded(
                child: DmProgressPill(
                  value: item.value,
                  label: item.label,
                  valueLabel: item.valueLabel,
                  color: item.color,
                ),
              ),
              if (item != items.last) const SizedBox(width: DMSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _ProgressItem {
  const _ProgressItem({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final double value;
  final Color color;
}

class _AdvancedRoastIntro extends StatelessWidget {
  const _AdvancedRoastIntro({required this.onHowItWorks});

  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return DmDarkGlassCard(
      padding: const EdgeInsets.all(DMSpacing.lg),
      borderRadius: DMRadius.large,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          const title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Advanced Roast',
                style: DMTypography.headingMedium,
              ),
              SizedBox(height: DMSpacing.xxs),
              Text(
                'Today\'s roast is extra toasty.',
                style: DMTypography.body,
              ),
            ],
          );
          final button = DmPillButton(
            label: 'How it works',
            leading: const Icon(Icons.help_outline_rounded),
            onPressed: onHowItWorks,
            variant: DmPillButtonVariant.glass,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: DMSpacing.md),
                button,
              ],
            );
          }

          return Row(
            children: [
              const Expanded(child: title),
              const SizedBox(width: DMSpacing.md),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: DMTypography.title,
    );
  }
}

class _AchievementsRow extends StatelessWidget {
  const _AchievementsRow();

  @override
  Widget build(BuildContext context) {
    const achievements = [
      DmAchievementBadge(
        label: 'Early Bird',
        icon: Icons.wb_twilight_rounded,
        progressLabel: 'Unlocked',
      ),
      DmAchievementBadge(
        label: 'Roast Master',
        icon: Icons.local_fire_department_rounded,
        progressLabel: 'Unlocked',
      ),
      DmAchievementBadge(
        label: 'Streak King',
        icon: Icons.workspace_premium_rounded,
        unlocked: false,
        progressLabel: '4/5',
      ),
      DmAchievementBadge(
        label: 'Cloud Clearer',
        icon: Icons.filter_drama_rounded,
        progressLabel: 'Unlocked',
      ),
      DmAchievementBadge(
        label: 'Mood Maker',
        icon: Icons.mood_rounded,
        unlocked: false,
        progressLabel: '2/3',
      ),
    ];

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: achievements.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DMSpacing.sm),
        itemBuilder: (context, index) => achievements[index],
      ),
    );
  }
}
