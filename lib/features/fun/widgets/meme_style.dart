import 'package:flutter/material.dart';

import '../../../design/dm_colors.dart';
import '../../../shared/assets/dm_assets.dart';

enum MemeVisualStyle {
  epic,
  cute,
  sarcastic,
  cozy,
  retro,
}

extension MemeVisualStyleX on MemeVisualStyle {
  String get label {
    return switch (this) {
      MemeVisualStyle.epic => 'Epic',
      MemeVisualStyle.cute => 'Cute',
      MemeVisualStyle.sarcastic => 'Sarcastic',
      MemeVisualStyle.cozy => 'Cozy',
      MemeVisualStyle.retro => 'Retro',
    };
  }

  Color get accentColor {
    return switch (this) {
      MemeVisualStyle.epic => DMColors.sunriseYellow,
      MemeVisualStyle.cute => DMColors.playfulPinkSoft,
      MemeVisualStyle.sarcastic => DMColors.coral,
      MemeVisualStyle.cozy => DMColors.mintSoft,
      MemeVisualStyle.retro => DMColors.rainTeal,
    };
  }

  Color get textFill {
    return switch (this) {
      MemeVisualStyle.epic => DMColors.cloudWhite,
      MemeVisualStyle.cute => DMColors.cloudWhite,
      MemeVisualStyle.sarcastic => DMColors.sunriseYellow,
      MemeVisualStyle.cozy => DMColors.cloudBlue,
      MemeVisualStyle.retro => DMColors.cloudWhite,
    };
  }

  Color get strokeColor {
    return switch (this) {
      MemeVisualStyle.epic => Colors.black,
      MemeVisualStyle.cute => DMColors.deepNavy,
      MemeVisualStyle.sarcastic => Colors.black,
      MemeVisualStyle.cozy => DMColors.twilightNavy,
      MemeVisualStyle.retro => Colors.black,
    };
  }
}

class MemeBackgroundPreset {
  const MemeBackgroundPreset({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.accentColor,
    required this.assetPath,
  });

  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color accentColor;
  final String assetPath;
}

final memeBackgroundPresets = <MemeBackgroundPreset>[
  MemeBackgroundPreset(
    label: 'Storm Break',
    icon: Icons.thunderstorm_rounded,
    assetPath: DmAssets.memeBackgrounds.stormy,
    accentColor: DMColors.sunriseYellow,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DMColors.twilightNavy,
        DMColors.stormViolet,
        DMColors.skyBlueDeep,
      ],
      stops: [0, 0.48, 1],
    ),
  ),
  MemeBackgroundPreset(
    label: 'Soft Drizzle',
    icon: Icons.water_drop_rounded,
    assetPath: DmAssets.memeBackgrounds.rainy,
    accentColor: DMColors.playfulPinkSoft,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomRight,
      colors: [
        DMColors.lavenderDeep,
        DMColors.rainTeal,
        DMColors.deepNavy,
      ],
      stops: [0, 0.58, 1],
    ),
  ),
  MemeBackgroundPreset(
    label: 'Golden Hour',
    icon: Icons.wb_sunny_rounded,
    assetPath: DmAssets.memeBackgrounds.sunny,
    accentColor: DMColors.sunriseYellow,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DMColors.sunriseAmber,
        DMColors.playfulPink,
        DMColors.twilightNavy,
      ],
      stops: [0, 0.45, 1],
    ),
  ),
  MemeBackgroundPreset(
    label: 'Radar Glow',
    icon: Icons.radar_rounded,
    assetPath: DmAssets.memeBackgrounds.office,
    accentColor: DMColors.mintGreen,
    gradient: const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        DMColors.mintDeep,
        DMColors.skyBlueDeep,
        DMColors.midnightNavy,
      ],
      stops: [0, 0.52, 1],
    ),
  ),
];
