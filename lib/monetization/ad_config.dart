import 'package:flutter/foundation.dart';

import 'ad_placement.dart';
import 'interstitial_policy.dart';

/// Versioned LOCAL configuration. No remote kill-switch endpoint is claimed.
/// The build validator independently enforces release ID/metadata constraints.
class AdConfig {
  const AdConfig({
    this.enabled = false,
    this.testMode = false,
    this.productionReady = false,
    this.audienceDeclared = false,
    this.privacyReady = false,
    this.refreshDisabledConfirmed = false,
    this.adjacentHumor = true,
    this.holdoutPercent = 10,
    this.androidUnits = const {},
    this.iosUnits = const {},
    this.disabledPlacements = const {},
    this.webProviderApproved = false,
    this.webUnits = const {},
    this.webHumorReviewed = false,
    this.engagementSeconds = 180,
    this.completions = 3,
    this.cooldownSeconds = 300,
    this.sessionCap = 1,
    this.dailyCap = 3,
  });
  static const version = 1;
  final bool enabled, testMode, productionReady, audienceDeclared, privacyReady;
  final bool refreshDisabledConfirmed, adjacentHumor, webProviderApproved;
  final bool webHumorReviewed;
  final int holdoutPercent;
  final int engagementSeconds,
      completions,
      cooldownSeconds,
      sessionCap,
      dailyCap;
  InterstitialLimits get interstitialLimits => InterstitialLimits(
      foregroundEngagement: Duration(seconds: engagementSeconds),
      meaningfulCompletions: completions,
      cooldown: Duration(seconds: cooldownSeconds),
      perSession: sessionCap,
      perRollingDay: dailyCap);
  final Map<AdPlacement, String> androidUnits, iosUnits, webUnits;
  final Set<AdPlacement> disabledPlacements;

  factory AdConfig.fromEnvironment() {
    const android = String.fromEnvironment('DAYMAKER_ANDROID_AD_UNITS');
    const ios = String.fromEnvironment('DAYMAKER_IOS_AD_UNITS');
    const web = String.fromEnvironment('DAYMAKER_GPT_UNITS');
    Map<AdPlacement, String> parse(String raw) {
      final values = raw.split(',');
      return {
        for (var i = 0; i < values.length && i < AdPlacement.values.length; i++)
          AdPlacement.values[i]: values[i].trim()
      };
    }

    const disabled = String.fromEnvironment('DAYMAKER_DISABLED_PLACEMENTS');
    return AdConfig(
      engagementSeconds: const int.fromEnvironment(
          'DAYMAKER_AD_ENGAGEMENT_SECONDS',
          defaultValue: 180),
      completions:
          const int.fromEnvironment('DAYMAKER_AD_COMPLETIONS', defaultValue: 3),
      cooldownSeconds: const int.fromEnvironment('DAYMAKER_AD_COOLDOWN_SECONDS',
          defaultValue: 300),
      sessionCap:
          const int.fromEnvironment('DAYMAKER_AD_SESSION_CAP', defaultValue: 1),
      dailyCap:
          const int.fromEnvironment('DAYMAKER_AD_DAILY_CAP', defaultValue: 3),
      enabled: const bool.fromEnvironment('DAYMAKER_ADS_ENABLED'),
      testMode:
          !kReleaseMode && const bool.fromEnvironment('DAYMAKER_TEST_ADS'),
      productionReady: const bool.fromEnvironment('DAYMAKER_ADS_READY'),
      audienceDeclared:
          const bool.fromEnvironment('DAYMAKER_AUDIENCE_DECLARED'),
      privacyReady: const bool.fromEnvironment('DAYMAKER_PRIVACY_READY'),
      refreshDisabledConfirmed:
          const bool.fromEnvironment('DAYMAKER_REFRESH_DISABLED'),
      adjacentHumor:
          const bool.fromEnvironment('DAYMAKER_AD_HUMOR', defaultValue: true),
      androidUnits: parse(android),
      iosUnits: parse(ios),
      webUnits: parse(web),
      webProviderApproved: const bool.fromEnvironment('DAYMAKER_WEB_APPROVED'),
      disabledPlacements: AdPlacement.values
          .where((p) => disabled.split(',').contains(p.id))
          .toSet(),
    );
  }

  bool get nativeReady =>
      enabled &&
      (testMode ||
          (productionReady &&
              audienceDeclared &&
              privacyReady &&
              refreshDisabledConfirmed &&
              validProductionUnits(androidUnits) &&
              validProductionUnits(iosUnits) &&
              androidUnits.values
                  .toSet()
                  .intersection(iosUnits.values.toSet())
                  .isEmpty));
  // Web consent also requires a connected certified CMP adapter, absent at launch.
  bool get webReady =>
      enabled &&
      !testMode &&
      productionReady &&
      audienceDeclared &&
      privacyReady &&
      webProviderApproved &&
      AdPlacement.values.where((p) => p.isDisplay).every(
          (p) => RegExp(r'^/\d+/[A-Za-z0-9_/-]+$').hasMatch(webUnits[p] ?? ''));
  bool permits(AdPlacement placement) =>
      !disabledPlacements.contains(placement);

  String? nativeUnit(AdPlacement placement, TargetPlatform platform) {
    if (!nativeReady || !permits(placement)) return null;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return null;
    }
    if (testMode) {
      if (placement == AdPlacement.funCompleteInterstitial) {
        return platform == TargetPlatform.android
            ? 'ca-app-pub-3940256099942544/1033173712'
            : 'ca-app-pub-3940256099942544/4411468910';
      }
      return platform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }
    return (platform == TargetPlatform.android
        ? androidUnits
        : iosUnits)[placement];
  }

  static bool validProductionUnits(Map<AdPlacement, String> units) =>
      AdPlacement.values.every((p) => validUnit(units[p])) &&
      units.values.toSet().length == AdPlacement.values.length;
  static bool validUnit(String? id) =>
      id != null &&
      RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(id) &&
      !id.contains('3940256099942544');
  static bool validAppId(String? id) =>
      id != null &&
      RegExp(r'^ca-app-pub-\d{16}~\d{10}$').hasMatch(id) &&
      !id.contains('3940256099942544');
}
