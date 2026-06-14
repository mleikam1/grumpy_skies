import 'package:flutter/material.dart';

import 'dm_colors.dart';

abstract final class DMGradients {
  const DMGradients._();

  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      DMColors.skyBlueDeep,
      DMColors.twilightNavy,
      DMColors.deepNavy,
    ],
    stops: <double>[0, 0.46, 1],
  );

  static const LinearGradient clearSky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.skyBlueSoft,
      DMColors.skyBlue,
      DMColors.electricBlue,
    ],
  );

  static const LinearGradient sunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.sunriseYellow,
      DMColors.sunrisePeach,
      DMColors.playfulPink,
    ],
  );

  static const LinearGradient twilight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.lavenderDeep,
      DMColors.twilightNavy,
      DMColors.deepNavy,
    ],
  );

  static const LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.glassStrong,
      DMColors.glass,
    ],
  );

  static const LinearGradient glassNavy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.surfaceRaised,
      DMColors.glassNavy,
    ],
  );

  static const LinearGradient premiumCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.surfaceElevated,
      DMColors.surface,
      DMColors.midnightNavy,
    ],
  );

  static const LinearGradient storm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.stormViolet,
      DMColors.stormNavy,
      DMColors.deepNavy,
    ],
  );

  static const LinearGradient rain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.rainTeal,
      DMColors.mintDeep,
      DMColors.twilightNavy,
    ],
  );

  static const LinearGradient frost = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.frostCyan,
      DMColors.lavenderMist,
      DMColors.skyBlue,
    ],
  );

  static const LinearGradient heat = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.sunriseYellow,
      DMColors.alertOrange,
      DMColors.coral,
    ],
  );

  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      DMColors.mintSoft,
      DMColors.mintGreen,
      DMColors.rainTeal,
    ],
  );

  static const LinearGradient primaryAction = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      DMColors.skyBlue,
      DMColors.sunriseYellow,
    ],
  );

  static LinearGradient weather(DMWeatherTone tone) {
    return switch (tone) {
      DMWeatherTone.clear => clearSky,
      DMWeatherTone.sunrise => sunrise,
      DMWeatherTone.cloudy => twilight,
      DMWeatherTone.rain => rain,
      DMWeatherTone.storm => storm,
      DMWeatherTone.snow => frost,
      DMWeatherTone.heat => heat,
      DMWeatherTone.night => twilight,
    };
  }
}
