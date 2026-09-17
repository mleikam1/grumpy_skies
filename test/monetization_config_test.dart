import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/monetization/ad_config.dart';
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/ad_reporting.dart';

void main() {
  Map<AdPlacement, String> units(String publisher) => {
        for (var i = 0; i < AdPlacement.values.length; i++)
          AdPlacement.values[i]: 'ca-app-pub-$publisher/${1000000000 + i}'
      };

  test(
      'unconfigured production fails closed and official test units remain native only',
      () {
    expect(const AdConfig().nativeReady, isFalse);
    expect(const AdConfig(enabled: true).nativeReady, isFalse);
    const test = AdConfig(enabled: true, testMode: true);
    expect(test.nativeReady, isTrue);
    for (final placement in AdPlacement.values) {
      final android = test.nativeUnit(placement, TargetPlatform.android);
      final ios = test.nativeUnit(placement, TargetPlatform.iOS);
      expect(android, contains('3940256099942544'));
      expect(ios, contains('3940256099942544'));
      expect(ios, isNot(android));
      expect(test.nativeUnit(placement, TargetPlatform.linux), isNull);
      expect(test.nativeUnit(placement, TargetPlatform.macOS), isNull);
    }
    expect(test.webReady, isFalse);
  });

  test('app metadata and ad unit syntax are distinct and reject test publisher',
      () {
    expect(
        AdConfig.validAppId('ca-app-pub-1234567890123456~1234567890'), isTrue);
    expect(
        AdConfig.validUnit('ca-app-pub-1234567890123456/1234567890'), isTrue);
    expect(
        AdConfig.validAppId('ca-app-pub-1234567890123456/1234567890'), isFalse);
    expect(
        AdConfig.validUnit('ca-app-pub-1234567890123456~1234567890'), isFalse);
    expect(
        AdConfig.validAppId('ca-app-pub-3940256099942544~1234567890'), isFalse);
    expect(
        AdConfig.validUnit('ca-app-pub-3940256099942544/1234567890'), isFalse);
    expect(AdConfig.validUnit(null), isFalse);
  });

  test(
      'production activation requires declarations and distinct platform inventory',
      () {
    final android = units('1111111111111111');
    final ios = units('2222222222222222');
    AdConfig configured(
            {bool audience = true,
            bool privacy = true,
            bool refresh = true,
            Map<AdPlacement, String>? iosOverride}) =>
        AdConfig(
            enabled: true,
            productionReady: true,
            audienceDeclared: audience,
            privacyReady: privacy,
            refreshDisabledConfirmed: refresh,
            androidUnits: android,
            iosUnits: iosOverride ?? ios);
    expect(configured().nativeReady, isTrue);
    expect(configured(audience: false).nativeReady, isFalse);
    expect(configured(privacy: false).nativeReady, isFalse);
    expect(configured(refresh: false).nativeReady, isFalse);
    expect(configured(iosOverride: android).nativeReady, isFalse);
    expect(configured(iosOverride: {}).nativeReady, isFalse);
    expect(
        AdConfig.validProductionUnits(
            {for (final p in AdPlacement.values) p: android.values.first}),
        isFalse);
  });

  test('per-placement switch disables only the requested inventory', () {
    const config = AdConfig(
        enabled: true,
        testMode: true,
        disabledPlacements: {AdPlacement.funHubMrec});
    expect(config.nativeUnit(AdPlacement.funHubMrec, TargetPlatform.android),
        isNull);
    expect(
        config.nativeUnit(AdPlacement.forecastBanner, TargetPlatform.android),
        isNotNull);
  });

  test('placement content counts represent actual publisher items', () {
    expect(hasEligibleContent(AdPlacement.roastsHistoryMrec, 3), isFalse);
    expect(hasEligibleContent(AdPlacement.roastsHistoryMrec, 4), isTrue);
    expect(hasEligibleContent(AdPlacement.memeLibraryMrec, 5), isFalse);
    expect(hasEligibleContent(AdPlacement.memeLibraryMrec, 6), isTrue);
    expect(hasEligibleContent(AdPlacement.memeLibraryMrec, 60, sample: true),
        isFalse);
    expect(hasEligibleContent(AdPlacement.funHubMrec, 0), isFalse);
    expect(hasEligibleContent(AdPlacement.funHubMrec, 1, available: false),
        isFalse);
    expect(
        hasEligibleContent(AdPlacement.funCompleteInterstitial, 100), isFalse);
  });

  test('paid values preserve currency, precision and micros conversion', () {
    const paid =
        PaidValue(micros: 1250000, currency: 'EUR', precision: 'precise');
    expect(paid.amount, 1.25);
    expect(paid.currency, 'EUR');
    expect(paid.micros, 1250000);
    expect(paid.precision, 'precise');
  });
}
