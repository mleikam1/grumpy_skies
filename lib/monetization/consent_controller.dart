import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP owns consent persistence. NPA is never used to bypass this gate.
class ConsentController extends ChangeNotifier {
  bool canRequestAds = false;
  bool resolved = false;
  bool privacyOptionsRequired = false;
  bool operationActive = false;
  Future<void>? _initialization;
  bool _disposed = false;
  Future<void> initialize() => _initialization ??= _update();

  Future<void> _update() async {
    operationActive = true;
    _notify();
    final done = Completer<void>();
    bool finishing = false;
    Future<void> finish() async {
      if (finishing) return;
      finishing = true;
      await recheck();
      operationActive = false;
      _notify();
      if (!done.isCompleted) done.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
          unawaited(finish());
        }),
        (_) {
          unawaited(finish());
        },
      );
      // Weather is already rendered. If networking stalls, keep ads unresolved
      // and the modal gate closed until UMP's actual terminal callback arrives.
      await done.future.timeout(const Duration(seconds: 40));
    } catch (_) {
      canRequestAds = false;
      resolved = false;
      _notify();
    }
  }

  Future<void> recheck() async {
    try {
      canRequestAds = await ConsentInformation.instance.canRequestAds();
      privacyOptionsRequired = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      resolved = true;
    } catch (_) {
      canRequestAds = false;
      resolved = false;
    }
    _notify();
  }

  Future<void> showPrivacyOptions() async {
    if (!privacyOptionsRequired || operationActive) return;
    operationActive = true;
    canRequestAds = false;
    _notify();
    final done = Completer<void>();
    try {
      ConsentForm.showPrivacyOptionsForm((_) {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
      await recheck();
    } finally {
      operationActive = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
