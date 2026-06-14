import 'package:flutter/material.dart';

enum DMWeatherTone {
  clear,
  sunrise,
  cloudy,
  rain,
  storm,
  snow,
  heat,
  night,
}

abstract final class DMColors {
  const DMColors._();

  static const Color deepNavy = Color(0xFF081426);
  static const Color midnightNavy = Color(0xFF0D1B32);
  static const Color stormNavy = Color(0xFF13243D);
  static const Color twilightNavy = Color(0xFF172B51);

  static const Color cloudWhite = Color(0xFFF8FBFF);
  static const Color cloudBlue = Color(0xFFE9F6FF);
  static const Color mist = Color(0xFFD7E6F7);
  static const Color slate = Color(0xFF8496B0);

  static const Color skyBlue = Color(0xFF47C7FF);
  static const Color skyBlueSoft = Color(0xFF9FE4FF);
  static const Color skyBlueDeep = Color(0xFF1498E5);
  static const Color electricBlue = Color(0xFF5B8CFF);

  static const Color sunriseYellow = Color(0xFFFFD76A);
  static const Color sunriseAmber = Color(0xFFFFAA42);
  static const Color sunrisePeach = Color(0xFFFFC09B);

  static const Color lavenderGlass = Color(0xFFBBA7FF);
  static const Color lavenderMist = Color(0xFFE4DBFF);
  static const Color lavenderDeep = Color(0xFF7D6CFF);

  static const Color playfulPink = Color(0xFFFF6FAE);
  static const Color playfulPinkSoft = Color(0xFFFFB4D6);
  static const Color coral = Color(0xFFFF705F);

  static const Color mintGreen = Color(0xFF66E6B2);
  static const Color mintSoft = Color(0xFFA8F4D5);
  static const Color mintDeep = Color(0xFF24B47E);

  static const Color frostCyan = Color(0xFFA9F4FF);
  static const Color rainTeal = Color(0xFF42D9D0);
  static const Color stormViolet = Color(0xFF8B8CFF);
  static const Color alertRed = Color(0xFFFF5368);
  static const Color alertOrange = Color(0xFFFF8A4B);

  static const Color surface = Color(0xFF10213A);
  static const Color surfaceElevated = Color(0xFF172B49);
  static const Color surfaceRaised = Color(0xFF203657);
  static const Color surfaceDisabled = Color(0xFF26364D);

  static const Color glass = Color(0x24FFFFFF);
  static const Color glassStrong = Color(0x3DFFFFFF);
  static const Color glassNavy = Color(0xB312243D);
  static const Color glassBorder = Color(0x42FFFFFF);
  static const Color glassBorderStrong = Color(0x66FFFFFF);

  static const Color textPrimary = cloudWhite;
  static const Color textSecondary = Color(0xCCF8FBFF);
  static const Color textMuted = Color(0x99F8FBFF);
  static const Color textDisabled = Color(0x66F8FBFF);
  static const Color textInverse = deepNavy;

  static const Color outline = Color(0x57FFFFFF);
  static const Color outlineVariant = Color(0x29FFFFFF);
  static const Color divider = Color(0x1FFFFFFF);

  static const Color shadow = Color(0x66030A14);
  static const Color shadowSoft = Color(0x33030A14);
  static const Color skyGlow = Color(0x5247C7FF);
  static const Color sunGlow = Color(0x5CFFD76A);
  static const Color pinkGlow = Color(0x4DFF6FAE);
  static const Color mintGlow = Color(0x4D66E6B2);

  static const Color conditionClear = skyBlue;
  static const Color conditionSunrise = sunriseYellow;
  static const Color conditionCloudy = lavenderGlass;
  static const Color conditionRain = rainTeal;
  static const Color conditionStorm = stormViolet;
  static const Color conditionSnow = frostCyan;
  static const Color conditionHeat = coral;
  static const Color conditionNight = twilightNavy;

  static Color weatherTone(DMWeatherTone tone) {
    return switch (tone) {
      DMWeatherTone.clear => conditionClear,
      DMWeatherTone.sunrise => conditionSunrise,
      DMWeatherTone.cloudy => conditionCloudy,
      DMWeatherTone.rain => conditionRain,
      DMWeatherTone.storm => conditionStorm,
      DMWeatherTone.snow => conditionSnow,
      DMWeatherTone.heat => conditionHeat,
      DMWeatherTone.night => conditionNight,
    };
  }

  static Color opacity(Color color, double value) {
    final alpha = (value.clamp(0.0, 1.0) * 255).round();
    return color.withAlpha(alpha);
  }
}
