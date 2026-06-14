import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_motion.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_shadows.dart';
import '../../design/dm_spacing.dart';
import '../../design/dm_typography.dart';

enum DmPillButtonVariant {
  primary,
  secondary,
  glass,
  outline,
  danger,
}

enum DmIconButtonVariant {
  glass,
  filled,
  outline,
}

class DmPillButton extends StatelessWidget {
  const DmPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.semanticLabel,
    this.variant = DmPillButtonVariant.primary,
    this.selected = false,
    this.loading = false,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DMSpacing.xl,
      vertical: DMSpacing.sm,
    ),
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;
  final DmPillButtonVariant variant;
  final bool selected;
  final bool loading;
  final bool expand;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final style = _DmPillStyle.resolve(variant, selected, enabled);
    final motion = DMMotion.resolve(context, DMMotion.fast);

    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DMTypography.labelLarge.copyWith(color: style.foreground),
    );

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox.square(
            dimension: DMSpacing.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: style.foreground,
            ),
          ),
          const SizedBox(width: DMSpacing.xs),
        ] else if (leading != null) ...[
          IconTheme(
            data:
                IconThemeData(color: style.foreground, size: DMSpacing.iconMd),
            child: leading!,
          ),
          const SizedBox(width: DMSpacing.xs),
        ],
        if (expand) Flexible(child: labelWidget) else labelWidget,
        if (trailing != null) ...[
          const SizedBox(width: DMSpacing.xs),
          IconTheme(
            data:
                IconThemeData(color: style.foreground, size: DMSpacing.iconMd),
            child: trailing!,
          ),
        ],
      ],
    );

    content = AnimatedContainer(
      duration: motion,
      curve: DMMotion.easeOut,
      constraints: const BoxConstraints(
        minWidth: DMSpacing.tapTarget,
        minHeight: DMSpacing.tapTarget,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: style.background,
        gradient: style.gradient,
        border: style.border,
        borderRadius: DMRadius.full,
        boxShadow: style.shadows,
      ),
      child: content,
    );

    content = Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onPressed : null,
        child: content,
      ),
    );

    if (expand) {
      content = SizedBox(width: double.infinity, child: content);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(child: content),
    );
  }
}

class DmIconButton extends StatelessWidget {
  const DmIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tooltip,
    this.variant = DmIconButtonVariant.glass,
    this.selected = false,
    this.size = DMSpacing.tapTarget,
    this.iconSize = DMSpacing.iconLg,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? tooltip;
  final DmIconButtonVariant variant;
  final bool selected;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = _DmIconStyle.resolve(variant, selected, enabled);
    final motion = DMMotion.resolve(context, DMMotion.fast);

    Widget button = AnimatedContainer(
      duration: motion,
      curve: DMMotion.easeOut,
      width: size < DMSpacing.tapTarget ? DMSpacing.tapTarget : size,
      height: size < DMSpacing.tapTarget ? DMSpacing.tapTarget : size,
      decoration: BoxDecoration(
        color: style.background,
        border: style.border,
        shape: BoxShape.circle,
        boxShadow: style.shadows,
      ),
      child: IconTheme(
        data: IconThemeData(color: style.foreground, size: iconSize),
        child: Center(child: icon),
      ),
    );

    button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: button,
      ),
    );

    button = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel,
      child: ExcludeSemantics(child: button),
    );

    return Tooltip(
      message: tooltip ?? semanticLabel,
      child: button,
    );
  }
}

class _DmPillStyle {
  const _DmPillStyle({
    required this.foreground,
    this.background,
    this.gradient,
    this.border,
    this.shadows = DMShadows.none,
  });

  final Color foreground;
  final Color? background;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow> shadows;

  static _DmPillStyle resolve(
    DmPillButtonVariant variant,
    bool selected,
    bool enabled,
  ) {
    if (!enabled) {
      return const _DmPillStyle(
        foreground: DMColors.textDisabled,
        background: DMColors.surfaceDisabled,
      );
    }

    return switch (variant) {
      DmPillButtonVariant.primary => _DmPillStyle(
          foreground: DMColors.deepNavy,
          gradient: DMGradients.primaryAction,
          shadows: selected ? DMShadows.skyGlow : DMShadows.soft,
        ),
      DmPillButtonVariant.secondary => const _DmPillStyle(
          foreground: DMColors.deepNavy,
          background: DMColors.sunriseYellow,
          shadows: DMShadows.sunGlow,
        ),
      DmPillButtonVariant.glass => _DmPillStyle(
          foreground: DMColors.textPrimary,
          background: selected ? DMColors.glassStrong : DMColors.glass,
          border: Border.all(color: DMColors.glassBorder),
        ),
      DmPillButtonVariant.outline => _DmPillStyle(
          foreground: DMColors.textPrimary,
          background: Colors.transparent,
          border: Border.all(color: DMColors.glassBorderStrong),
        ),
      DmPillButtonVariant.danger => const _DmPillStyle(
          foreground: DMColors.cloudWhite,
          background: DMColors.alertRed,
        ),
    };
  }
}

class _DmIconStyle {
  const _DmIconStyle({
    required this.foreground,
    required this.background,
    this.border,
    this.shadows = DMShadows.none,
  });

  final Color foreground;
  final Color background;
  final BoxBorder? border;
  final List<BoxShadow> shadows;

  static _DmIconStyle resolve(
    DmIconButtonVariant variant,
    bool selected,
    bool enabled,
  ) {
    if (!enabled) {
      return const _DmIconStyle(
        foreground: DMColors.textDisabled,
        background: DMColors.surfaceDisabled,
      );
    }

    return switch (variant) {
      DmIconButtonVariant.glass => _DmIconStyle(
          foreground: selected ? DMColors.deepNavy : DMColors.textPrimary,
          background: selected ? DMColors.skyBlue : DMColors.glass,
          border: Border.all(color: DMColors.glassBorder),
          shadows: selected ? DMShadows.skyGlow : DMShadows.none,
        ),
      DmIconButtonVariant.filled => const _DmIconStyle(
          foreground: DMColors.deepNavy,
          background: DMColors.sunriseYellow,
          shadows: DMShadows.sunGlow,
        ),
      DmIconButtonVariant.outline => _DmIconStyle(
          foreground: DMColors.textPrimary,
          background: Colors.transparent,
          border: Border.all(color: DMColors.glassBorderStrong),
        ),
    };
  }
}
