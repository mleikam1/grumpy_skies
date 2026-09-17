import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_placement.dart';
import '../ad_reporting.dart';
import '../interstitial_coordinator.dart';

class NativeInterstitialLoader implements InterstitialLoader {
  NativeInterstitialLoader({required this.unitId, required this.reporter});
  final String Function() unitId;
  final AdReporter reporter;
  static const placement = AdPlacement.funCompleteInterstitial;
  @override
  Future<LoadedInterstitial> load() async {
    final result = Completer<LoadedInterstitial>();
    await InterstitialAd.load(
        adUnitId: unitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.onPaidEvent = (_, micros, precision, currency) =>
                reporter.report(AdEvent(AdEventKind.paid, placement,
                    paid: PaidValue(
                        micros: micros,
                        currency: currency,
                        precision: precision.name)));
            if (result.isCompleted) {
              ad.dispose();
            } else {
              result.complete(_NativeInterstitial(ad, reporter));
            }
          },
          onAdFailedToLoad: (error) {
            if (!result.isCompleted) {
              result.completeError(StateError('sdk_${error.code}'));
            }
          },
        ));
    return result.future.timeout(const Duration(seconds: 30), onTimeout: () {
      // Late callbacks dispose their own handle and cannot acquire a new opportunity.
      if (!result.isCompleted) {
        result.completeError(TimeoutException('ad_load'));
      }
      throw TimeoutException('ad_load');
    });
  }
}

class _NativeInterstitial implements LoadedInterstitial {
  _NativeInterstitial(this.ad, this.reporter);
  final InterstitialAd ad;
  final AdReporter reporter;
  bool _disposed = false;
  @override
  Future<void> show(
      {required void Function() onShown,
      required void Function() onDismissed,
      required void Function(Object) onFailed}) async {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onShown(),
      onAdDismissedFullScreenContent: (_) => onDismissed(),
      onAdFailedToShowFullScreenContent: (_, error) =>
          onFailed(StateError('sdk_${error.code}')),
      onAdImpression: (_) => reporter.report(const AdEvent(
          AdEventKind.impression, AdPlacement.funCompleteInterstitial)),
    );
    await ad.show();
  }

  @override
  Future<void> dispose() async {
    if (!_disposed) {
      _disposed = true;
      await ad.dispose();
    }
  }
}
