import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_spacing.dart';

class DmSvgIcon extends StatelessWidget {
  const DmSvgIcon({
    super.key,
    required this.assetPath,
    this.fallbackIcon = Icons.image_outlined,
    this.size = DMSpacing.iconLg,
    this.color,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.fit = BoxFit.contain,
  });

  final String? assetPath;
  final IconData fallbackIcon;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = assetPath?.trim();
    final visual = path == null || path.isEmpty
        ? _fallbackVisual(context)
        : _svgVisual(context, path);

    if (excludeFromSemantics || semanticLabel == null) {
      return ExcludeSemantics(child: visual);
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: visual),
    );
  }

  Widget _svgVisual(BuildContext context, String path) {
    final iconColor =
        color ?? IconTheme.of(context).color ?? DMColors.textPrimary;
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      fit: fit,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      placeholderBuilder: (_) => _fallbackVisual(context),
      errorBuilder: (_, error, stackTrace) => _fallbackVisual(context),
    );
  }

  Widget _fallbackVisual(BuildContext context) {
    return Icon(
      fallbackIcon,
      size: size,
      color: color ?? IconTheme.of(context).color ?? DMColors.textPrimary,
    );
  }
}
