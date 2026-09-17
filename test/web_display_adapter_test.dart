@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/ad_reporting.dart';
import 'package:grumpy_skies/monetization/platform/ad_platform.dart';
import 'package:grumpy_skies/monetization/platform/web_ad_consent.dart';
import 'package:grumpy_skies/monetization/platform/web_display_adapter.dart';

// Browser boundary unit tests. Actual renderer/DOM mounting is exercised by
// integration_test/web_ad_harness.dart, not the mocked widget-test platform view.
void main() {
  test('unconfigured CMP rejects inventory before any bridge or DOM work',
      () async {
    final consent = UnconfiguredWebAdConsent();
    final handle =
        await WebDisplayAdapter(consent: consent, placementAllowed: (_) => true)
            .load(
                unitId: '/123456/daymaker_fixture',
                size: const DisplaySize(300, 250),
                placement: AdPlacement.funHubMrec,
                reporter: const NoopAdReporter());
    expect(handle, isNull);
    consent.dispose();
  });
  test('AdMob IDs and web interstitials cannot enter the web adapter',
      () async {
    final consent = _TestConsent();
    final adapter =
        WebDisplayAdapter(consent: consent, placementAllowed: (_) => true);
    for (final entry in [
      ('ca-app-pub-3940256099942544/6300978111', AdPlacement.forecastBanner),
      ('/123456/daymaker_fixture', AdPlacement.funCompleteInterstitial),
    ]) {
      expect(
          await adapter.load(
              unitId: entry.$1,
              size: const DisplaySize(320, 50),
              placement: entry.$2,
              reporter: const NoopAdReporter()),
          isNull);
    }
    consent.dispose();
  });
  test('missing or rejected placement gate cannot prepare a web slot',
      () async {
    final consent = _TestConsent();
    for (final adapter in [
      WebDisplayAdapter(consent: consent),
      WebDisplayAdapter(consent: consent, placementAllowed: (_) => false),
    ]) {
      expect(
          await adapter.load(
              unitId: '/123456/daymaker_fixture',
              size: const DisplaySize(300, 250),
              placement: AdPlacement.funHubMrec,
              reporter: const NoopAdReporter()),
          isNull);
    }
    consent.dispose();
  });
  test('preparing a handle performs no request and revocation closes it',
      () async {
    final consent = _TestConsent(), reporter = _Reporter();
    final handle = (await WebDisplayAdapter(
            consent: consent, placementAllowed: (_) => true)
        .load(
            unitId: '/123456/daymaker_fixture',
            size: const DisplaySize(300, 250),
            placement: AdPlacement.memeLibraryMrec,
            reporter: reporter))! as DeferredDisplayAdHandle;
    expect(reporter.events, isEmpty);
    consent.revoke();
    expect(handle.failed, isTrue);
    expect(reporter.events.single.kind, AdEventKind.loadFailure);
    handle.dispose();
    handle.dispose();
    consent.dispose();
  });
}

class _TestConsent extends WebAdConsent {
  bool allowed = true;
  @override
  bool get cmpConfigured => true;
  @override
  bool get resolved => true;
  @override
  bool get canRequestAds => allowed;
  void revoke() {
    allowed = false;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> showPrivacyOptions() async {}
}

class _Reporter implements AdReporter {
  final events = <AdEvent>[];
  @override
  void report(AdEvent event) => events.add(event);
}
