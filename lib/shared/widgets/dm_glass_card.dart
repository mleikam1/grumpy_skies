import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_shadows.dart';
import '../../design/dm_spacing.dart';

class DmGlassCard extends StatefulWidget {
  const DmGlassCard({
    super.key,
    required this.child,
    this.padding = DMSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
    this.borderRadius = DMRadius.card,
    this.gradient = DMGradients.glass,
    this.color,
    this.borderColor = DMColors.glassBorder,
    this.shadows = DMShadows.card,
    this.blurSigma = 14,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final Color? color;
  final Color borderColor;
  final List<BoxShadow> shadows;
  final double blurSigma;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<DmGlassCard> createState() => _DmGlassCardState();
}

class _DmGlassCardState extends State<DmGlassCard> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: widget.borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: widget.blurSigma,
          sigmaY: widget.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            gradient: widget.gradient,
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _focused ? DMColors.sunriseYellow : widget.borderColor,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? [
                    ...widget.shadows,
                    BoxShadow(
                      color: DMColors.opacity(DMColors.sunriseYellow, 0.32),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : widget.shadows,
          ),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      card = Semantics(
        button: true,
        enabled: true,
        label: widget.semanticLabel,
        explicitChildNodes: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius,
            focusColor: DMColors.opacity(DMColors.sunriseYellow, 0.16),
            hoverColor: DMColors.opacity(DMColors.cloudWhite, 0.08),
            onFocusChange: (focused) => setState(() => _focused = focused),
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: DMSpacing.tapTarget),
              child: card,
            ),
          ),
        ),
      );
    } else if (widget.semanticLabel != null) {
      card = Semantics(
        container: true,
        label: widget.semanticLabel,
        explicitChildNodes: true,
        child: card,
      );
    }

    if (widget.margin != EdgeInsets.zero) {
      card = Padding(padding: widget.margin, child: card);
    }

    return card;
  }
}

class DmDarkGlassCard extends StatelessWidget {
  const DmDarkGlassCard({
    super.key,
    required this.child,
    this.padding = DMSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
    this.borderRadius = DMRadius.card,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      gradient: DMGradients.glassNavy,
      borderColor: DMColors.glassBorder,
      shadows: DMShadows.card,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}

class DmLightGlassCard extends StatelessWidget {
  const DmLightGlassCard({
    super.key,
    required this.child,
    this.padding = DMSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
    this.borderRadius = DMRadius.card,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DmGlassCard(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DMColors.opacity(DMColors.cloudWhite, 0.28),
          DMColors.opacity(DMColors.cloudWhite, 0.12),
        ],
      ),
      borderColor: DMColors.glassBorderStrong,
      shadows: DMShadows.soft,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}
