import '../../../design/dm_theme.dart';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../design/dm_gradients.dart';
import '../../../design/dm_motion.dart';
import '../../../design/dm_radius.dart';
import '../../../design/dm_spacing.dart';
import '../../../design/dm_typography.dart';
import '../../../shared/widgets/daymaker_components.dart';

class AdvancedRoastRevealCard extends StatelessWidget {
  const AdvancedRoastRevealCard({
    super.key,
    required this.revealed,
    required this.personaName,
    required this.avatarAsset,
    required this.roastText,
    required this.xpReward,
    required this.onToggleReveal,
    required this.onRevealGesture,
    required this.onShare,
  });

  final bool revealed;
  final String personaName;
  final String avatarAsset;
  final String roastText;
  final int xpReward;
  final VoidCallback onToggleReveal;
  final VoidCallback onRevealGesture;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final duration = DMMotion.resolve(context, DMMotion.standard);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleReveal,
      onPanStart: (_) => onRevealGesture(),
      onPanUpdate: (_) => onRevealGesture(),
      child: DmGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: DMRadius.card,
        semanticLabel: revealed
            ? 'Revealed advanced roast'
            : 'Hidden advanced roast. Clear the clouds to reveal your roast.',
        child: ClipRRect(
          borderRadius: DMRadius.card,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: DMMotion.easeOut,
            switchOutCurve: DMMotion.easeIn,
            child: revealed
                ? _RevealedRoastContent(
                    key: const ValueKey('revealed-roast'),
                    personaName: personaName,
                    avatarAsset: avatarAsset,
                    roastText: roastText,
                    xpReward: xpReward,
                    onShare: onShare,
                  )
                : const _HiddenRoastContent(
                    key: ValueKey('hidden-roast'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _HiddenRoastContent extends StatelessWidget {
  const _HiddenRoastContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 308),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration:
                  BoxDecoration(gradient: context.dmColors.grandpaGradient),
            ),
          ),
          const Positioned(
            top: 28,
            left: 24,
            child: _CloudGlyph(size: 52, opacity: 0.72),
          ),
          const Positioned(
            right: 34,
            top: 54,
            child: _CloudGlyph(size: 74, opacity: 0.62),
          ),
          const Positioned(
            left: 52,
            bottom: 44,
            child: _CloudGlyph(size: 70, opacity: 0.54),
          ),
          const Positioned(
            right: 28,
            bottom: 26,
            child: _CloudGlyph(size: 48, opacity: 0.48),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DMColors.opacity(DMColors.cloudWhite, 0.16),
                  border: Border.all(color: context.dmColors.glassBorderStrong),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DMSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: DMColors.opacity(DMColors.deepNavy, 0.34),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: context.dmColors.glassBorderStrong),
                  ),
                  child: const Icon(
                    Icons.cloud_queue_rounded,
                    color: DMColors.cloudWhite,
                    size: 40,
                  ),
                ),
                const SizedBox(height: DMSpacing.lg),
                const Text(
                  'Clear the clouds to reveal your roast',
                  textAlign: TextAlign.center,
                  style: DMTypography.headingSmall,
                ),
                const SizedBox(height: DMSpacing.xs),
                const Text(
                  'Tap or drag the fogged glass.',
                  textAlign: TextAlign.center,
                  style: DMTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealedRoastContent extends StatelessWidget {
  const _RevealedRoastContent({
    super.key,
    required this.personaName,
    required this.avatarAsset,
    required this.roastText,
    required this.xpReward,
    required this.onShare,
  });

  final String personaName;
  final String avatarAsset;
  final String roastText;
  final int xpReward;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 308),
      decoration: BoxDecoration(gradient: context.dmColors.grandpaGradient),
      padding: const EdgeInsets.all(DMSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final avatar = _PersonaAvatar(
            personaName: personaName,
            avatarAsset: avatarAsset,
          );
          final body = _RoastBody(
            roastText: roastText,
            xpReward: xpReward,
            onShare: onShare,
          );

          if (wide) {
            return Row(
              children: [
                avatar,
                const SizedBox(width: DMSpacing.xl),
                Expanded(child: body),
              ],
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(height: DMSpacing.lg),
              body,
            ],
          );
        },
      ),
    );
  }
}

class _PersonaAvatar extends StatelessWidget {
  const _PersonaAvatar({
    required this.personaName,
    required this.avatarAsset,
  });

  final String personaName;
  final String avatarAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.dmColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: DmAssetImage(
            assetPath: avatarAsset,
            width: 106,
            height: 106,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            borderRadius: BorderRadius.circular(16),
            semanticLabel: '$personaName avatar',
            placeholderGradient: DMGradients.sunrise,
            placeholderIcon: Icons.person_rounded,
          ),
        ),
        const SizedBox(height: DMSpacing.sm),
        Text(
          personaName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DMTypography.labelLarge.copyWith(
            color: context.dmColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RoastBody extends StatelessWidget {
  const _RoastBody({
    required this.roastText,
    required this.xpReward,
    required this.onShare,
  });

  final String roastText;
  final int xpReward;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roastText,
          textAlign: TextAlign.left,
          style: DMTypography.headingMedium,
        ),
        const SizedBox(height: DMSpacing.lg),
        Wrap(
          spacing: DMSpacing.sm,
          runSpacing: DMSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (xpReward > 0)
              Container(
                constraints: const BoxConstraints(minHeight: 42),
                padding: const EdgeInsets.symmetric(
                  horizontal: DMSpacing.md,
                  vertical: DMSpacing.xs,
                ),
                decoration: const BoxDecoration(
                  color: DMColors.mintGreen,
                  borderRadius: DMRadius.full,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '+$xpReward XP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DMTypography.labelLarge.copyWith(
                      color: DMColors.deepNavy,
                    ),
                  ),
                ),
              ),
            DmPillButton(
              label: 'Share',
              semanticLabel: 'Share revealed roast',
              leading: const Icon(Icons.ios_share_rounded),
              onPressed: onShare,
              variant: DmPillButtonVariant.glass,
            ),
          ],
        ),
      ],
    );
  }
}

class _CloudGlyph extends StatelessWidget {
  const _CloudGlyph({
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Icon(
        Icons.cloud_rounded,
        size: size,
        color: DMColors.opacity(DMColors.cloudWhite, opacity),
      ),
    );
  }
}
