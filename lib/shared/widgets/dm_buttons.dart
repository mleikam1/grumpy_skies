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

class DmPillButton extends StatefulWidget {
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
  State<DmPillButton> createState() => _DmPillButtonState();
}

class _DmPillButtonState extends State<DmPillButton> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final style = _DmPillStyle.resolve(
      widget.variant,
      widget.selected,
      enabled,
    );
    final motion = DMMotion.resolve(context, DMMotion.fast);

    final labelWidget = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DMTypography.labelLarge.copyWith(color: style.foreground),
    );

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final flexibleLabel = widget.expand || constraints.maxWidth.isFinite;

        return Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.loading) ...[
              SizedBox.square(
                dimension: DMSpacing.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: style.foreground,
                ),
              ),
              const SizedBox(width: DMSpacing.xs),
            ] else if (widget.leading != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: style.foreground,
                  size: DMSpacing.iconMd,
                ),
                child: widget.leading!,
              ),
              const SizedBox(width: DMSpacing.xs),
            ],
            if (flexibleLabel) Flexible(child: labelWidget) else labelWidget,
            if (widget.trailing != null) ...[
              const SizedBox(width: DMSpacing.xs),
              IconTheme(
                data: IconThemeData(
                  color: style.foreground,
                  size: DMSpacing.iconMd,
                ),
                child: widget.trailing!,
              ),
            ],
          ],
        );
      },
    );

    content = AnimatedContainer(
      duration: motion,
      curve: DMMotion.easeOut,
      constraints: const BoxConstraints(
        minWidth: DMSpacing.tapTarget,
        minHeight: DMSpacing.tapTarget,
      ),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: style.background,
        gradient: style.gradient,
        border: _focusedBorder(style.border, _focused),
        borderRadius: DMRadius.full,
        boxShadow: _focusedShadows(style.shadows, _focused),
      ),
      child: content,
    );

    content = Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const StadiumBorder(),
        focusColor: DMColors.opacity(DMColors.sunriseYellow, 0.18),
        hoverColor: DMColors.opacity(DMColors.cloudWhite, 0.08),
        onFocusChange: (focused) => setState(() => _focused = focused),
        onTap: enabled ? widget.onPressed : null,
        child: content,
      ),
    );

    if (widget.expand) {
      content = SizedBox(width: double.infinity, child: content);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel ?? widget.label,
      child: ExcludeSemantics(child: content),
    );
  }
}

class DmIconButton extends StatefulWidget {
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
  State<DmIconButton> createState() => _DmIconButtonState();
}

class _DmIconButtonState extends State<DmIconButton> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final style = _DmIconStyle.resolve(
      widget.variant,
      widget.selected,
      enabled,
    );
    final motion = DMMotion.resolve(context, DMMotion.fast);

    Widget button = AnimatedContainer(
      duration: motion,
      curve: DMMotion.easeOut,
      width:
          widget.size < DMSpacing.tapTarget ? DMSpacing.tapTarget : widget.size,
      height:
          widget.size < DMSpacing.tapTarget ? DMSpacing.tapTarget : widget.size,
      decoration: BoxDecoration(
        color: style.background,
        border: _focusedBorder(style.border, _focused),
        shape: BoxShape.circle,
        boxShadow: _focusedShadows(style.shadows, _focused),
      ),
      child: IconTheme(
        data: IconThemeData(color: style.foreground, size: widget.iconSize),
        child: Center(child: widget.icon),
      ),
    );

    button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        focusColor: DMColors.opacity(DMColors.sunriseYellow, 0.18),
        hoverColor: DMColors.opacity(DMColors.cloudWhite, 0.08),
        onFocusChange: (focused) => setState(() => _focused = focused),
        onTap: enabled ? widget.onPressed : null,
        child: button,
      ),
    );

    button = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: ExcludeSemantics(child: button),
    );

    return Tooltip(
      message: widget.tooltip ?? widget.semanticLabel,
      child: button,
    );
  }
}

BoxBorder? _focusedBorder(BoxBorder? fallback, bool focused) {
  return focused
      ? Border.all(color: DMColors.sunriseYellow, width: 2)
      : fallback;
}

List<BoxShadow> _focusedShadows(List<BoxShadow> shadows, bool focused) {
  if (!focused) return shadows;

  return [
    ...shadows,
    BoxShadow(
      color: DMColors.opacity(DMColors.sunriseYellow, 0.34),
      blurRadius: 18,
      spreadRadius: 1,
    ),
  ];
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
