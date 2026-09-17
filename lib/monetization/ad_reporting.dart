import 'ad_placement.dart';

enum AdEventKind {
  opportunity,
  request,
  loaded,
  impression,
  paid,
  shown,
  showFailure,
  loadFailure,
  dismissal,
  suppression
}

class PaidValue {
  const PaidValue(
      {required this.micros, required this.currency, required this.precision});
  final double micros;
  final String currency, precision;
  double get amount => micros / 1000000;
}

class AdEvent {
  const AdEvent(this.kind, this.placement, {this.reason, this.paid});
  final AdEventKind kind;
  final AdPlacement placement;
  final String? reason;
  final PaidValue? paid;
}

/// No analytics SDK exists in this app. Inject an approved, consent-aware sink.
/// Never include coordinates, captions, photo IDs, document IDs or creative data.
abstract interface class AdReporter {
  void report(AdEvent event);
}

class NoopAdReporter implements AdReporter {
  const NoopAdReporter();
  @override
  void report(AdEvent event) {}
}

/// Analytics is strictly ancillary to weather, consent, rendering and navigation.
class SafeAdReporter implements AdReporter {
  const SafeAdReporter(this.delegate);
  final AdReporter delegate;
  @override
  void report(AdEvent event) {
    try {
      delegate.report(event);
    } catch (_) {/* Fail independently. */}
  }
}
