import 'package:flutter/material.dart';

import '../../design/dm_colors.dart';
import '../../design/dm_gradients.dart';
import '../../design/dm_radius.dart';
import '../../design/dm_spacing.dart';

class DmAssetImage extends StatelessWidget {
  const DmAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.placeholderGradient = DMGradients.twilight,
    this.placeholderIcon = Icons.image_outlined,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.medium,
  });

  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Gradient placeholderGradient;
  final IconData placeholderIcon;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final path = assetPath?.trim();
    final image = path == null || path.isEmpty
        ? _placeholder(context)
        : Image.asset(
            path,
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
            color: color,
            colorBlendMode: colorBlendMode,
            filterQuality: filterQuality,
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }

  Widget _placeholder(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      constraints: BoxConstraints(
        minWidth: width == null ? DMSpacing.tapTarget : 0,
        minHeight: height == null ? DMSpacing.tapTarget : 0,
      ),
      decoration: BoxDecoration(
        gradient: placeholderGradient,
        borderRadius: borderRadius ?? DMRadius.medium,
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          color: DMColors.textSecondary,
          size: DMSpacing.iconLg,
        ),
      ),
    );

    if (excludeFromSemantics) {
      return ExcludeSemantics(child: fallback);
    }

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Missing image asset',
      child: ExcludeSemantics(child: fallback),
    );
  }
}
