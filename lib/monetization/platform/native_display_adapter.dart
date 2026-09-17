import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ad_placement.dart';
import '../ad_reporting.dart';
import 'ad_platform.dart';

class NativeDisplayAdapter implements DisplayAdAdapter {
  const NativeDisplayAdapter();
  @override
  Future<DisplayAdHandle?> load(
      {required String unitId,
      required DisplaySize size,
      required AdPlacement placement,
      required AdReporter reporter}) async {
    final result = Completer<DisplayAdHandle?>();
    final ad = BannerAd(
      adUnitId: unitId,
      size: size.width == 300
          ? AdSize.mediumRectangle
          : size.width == 728
              ? AdSize.leaderboard
              : AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          reporter.report(AdEvent(AdEventKind.loaded, placement));
          if (!result.isCompleted) {
            result.complete(_NativeDisplay(ad as BannerAd));
          } else {
            ad.dispose();
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          reporter.report(AdEvent(AdEventKind.loadFailure, placement,
              reason: 'sdk_${error.code}'));
          if (!result.isCompleted) result.complete(null);
        },
        onAdImpression: (_) =>
            reporter.report(AdEvent(AdEventKind.impression, placement)),
        onPaidEvent: (_, micros, precision, currency) => reporter.report(
            AdEvent(AdEventKind.paid, placement,
                paid: PaidValue(
                    micros: micros,
                    currency: currency,
                    precision: precision.name))),
      ),
    );
    reporter.report(AdEvent(AdEventKind.request, placement));
    try {
      await ad.load();
    } catch (_) {
      ad.dispose();
      if (!result.isCompleted) result.complete(null);
    }
    return result.future.timeout(const Duration(seconds: 30), onTimeout: () {
      if (!result.isCompleted) result.complete(null);
      ad.dispose();
      return null;
    });
  }
}

class _NativeDisplay implements DisplayAdHandle {
  _NativeDisplay(this.ad);
  final BannerAd ad;
  bool _disposed = false;
  @override
  Widget get widget => AdWidget(ad: ad);
  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      ad.dispose();
    }
  }
}
