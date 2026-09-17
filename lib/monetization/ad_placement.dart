import 'package:flutter/foundation.dart';

/// Logical IDs never depend on a network's app or unit identifier.
enum AdPlacement {
  forecastBanner('forecast_banner'),
  roastsHistoryMrec('roasts_history_mrec'),
  funHubMrec('fun_hub_mrec'),
  memeLibraryMrec('meme_library_mrec'),
  funCompleteInterstitial('fun_complete_interstitial');

  const AdPlacement(this.id);
  final String id;
  bool get isDisplay => this != funCompleteInterstitial;
}

@immutable
class DisplaySize {
  const DisplaySize(this.width, this.height);
  final int width;
  final int height;

  static DisplaySize? forPlacement(AdPlacement placement, double usableWidth) {
    if (!usableWidth.isFinite || !placement.isDisplay) return null;
    if (placement == AdPlacement.forecastBanner) {
      if (usableWidth >= 728) return const DisplaySize(728, 90);
      if (usableWidth >= 320) return const DisplaySize(320, 50);
      // Omit rather than compress a creative or request a large adaptive unit.
      return null;
    }
    return usableWidth >= 300 ? const DisplaySize(300, 250) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is DisplaySize && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

bool hasEligibleContent(AdPlacement placement, int count,
    {bool sample = false, bool available = true}) {
  if (sample || !available) return false;
  return switch (placement) {
    AdPlacement.roastsHistoryMrec => count >= 4,
    AdPlacement.memeLibraryMrec => count >= 6,
    AdPlacement.funHubMrec || AdPlacement.forecastBanner => count >= 1,
    AdPlacement.funCompleteInterstitial => false,
  };
}
