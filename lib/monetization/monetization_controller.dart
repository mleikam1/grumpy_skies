import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/weather_location_controller.dart';
import 'ad_config.dart';
import 'ad_placement.dart';
import 'ad_reporting.dart';
import 'consent_controller.dart';
import 'interstitial_policy.dart';
import 'interstitial_coordinator.dart';
import 'platform/ad_platform.dart';
import 'platform/native_display_adapter.dart';
import 'platform/native_interstitial_adapter.dart';
import 'platform/web_ad_consent.dart';
import 'platform/web_display_adapter.dart';
import 'sponsor_copy.dart';
import 'holdout_assignment.dart';

/// Advertising observes weather safety but never owns a weather repository or
/// performs weather requests. All startup work happens after runApp.
class MonetizationController extends ChangeNotifier
    with WidgetsBindingObserver {
  MonetizationController(
      {required this.config,
      required this.weather,
      AdReporter reporter = const NoopAdReporter(),
      DisplayAdAdapter? displayAdapter,
      this.verifiedAdFree = false,
      this.measurementPermitted = false,
      this.personaId,
      ConsentController? consent,
      WebAdConsent? webConsent})
      : reporter = SafeAdReporter(reporter),
        consent = consent ?? ConsentController(),
        webConsent = webConsent ?? UnconfiguredWebAdConsent() {
    this.displayAdapter = displayAdapter ??
        (kIsWeb
            ? WebDisplayAdapter(
                consent: this.webConsent, placementAllowed: displayAllowed)
            : const NativeDisplayAdapter());
    weather.addListener(_safetyChanged);
    this.consent.addListener(_consentChanged);
    this.webConsent.addListener(_webConsentChanged);
  }
  final AdConfig config;
  final WeatherLocationController weather;
  final AdReporter reporter;
  late final DisplayAdAdapter displayAdapter;
  final ConsentController consent;
  final WebAdConsent webConsent;

  /// Inject only a verified entitlement; this app currently has no purchase SDK.
  bool verifiedAdFree;
  final bool measurementPermitted;
  final String Function()? personaId;
  bool holdout = false;
  bool foreground = true;
  bool _sdkReady = false, _disposed = false;
  int _operations = 0, _modals = 0;
  String _route = '/splash';
  Future<void>? _start;
  Future<void>? _sdkInitialization;
  InterstitialPolicy? _policy;
  InterstitialCoordinator? _interstitial;
  SponsorCopySelector? _copy;
  Timer? _checkpoint;
  bool _presenting = false;
  bool get native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get modalActive =>
      _operations > 0 || _modals > 0 || consent.operationActive;
  bool get privacyOptionsRequired =>
      kIsWeb ? webConsent.cmpConfigured : consent.privacyOptionsRequired;
  String get statusDescription {
    if (verifiedAdFree) return 'Your verified ad-free access is active.';
    if (!config.enabled) return 'Advertising is disabled in this build.';
    if (kIsWeb && (!config.webReady || !webConsent.cmpConfigured)) {
      return 'Web advertising is unavailable until provider and consent setup are verified.';
    }
    if (!kIsWeb && !config.nativeReady) {
      return 'Advertising is awaiting inventory and privacy setup.';
    }
    if (config.testMode) {
      return 'Development test ads only. No purchases are offered.';
    }
    if (kIsWeb ? !webConsent.canRequestAds : !consent.canRequestAds) {
      return 'Ads are paused by privacy or consent requirements.';
    }
    if (holdout) return 'No ads are shown in your comparison group.';
    return 'Eligible content may show clearly labeled advertisements.';
  }

  Future<void> start() => _start ??= _initialize();
  Future<void> _initialize() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed) return;
      final storage = SharedPreferencesMonetizationStorage(preferences);
      final policy = InterstitialPolicy(
          storage: storage, limits: config.interstitialLimits);
      _policy = policy;
      await policy.initialize(foreground: foreground);
      _copy = await SponsorCopySelector.load(
          storage: storage, sessionId: policy.sessionId);
      holdout = await HoldoutAssignment(storage: storage).resolve(
          measurementPermitted: measurementPermitted,
          percent: config.holdoutPercent);
      if (_disposed) return;
      _checkpoint = Timer.periodic(const Duration(seconds: 60), (_) {
        if (foreground) unawaited(policy.checkpoint());
        _safetyChanged(); // Re-evaluate time-based safety expiry; never show ads.
      });
      if (kIsWeb) {
        if (config.webReady) await webConsent.initialize();
        _notify();
        return;
      }
      if (!native ||
          !config.nativeReady ||
          verifiedAdFree ||
          holdout ||
          _disposed) {
        _notify();
        return;
      }
      await consent.initialize();
      await _ensureSdkReady();
      _notify();
    } catch (_) {
      // Missing storage, SDK/UMP/script errors never become forecast errors.
      _sdkReady = false;
      _notify();
    }
  }

  Future<void> _ensureSdkReady() {
    if (!native ||
        !config.nativeReady ||
        !consent.canRequestAds ||
        _disposed ||
        verifiedAdFree ||
        holdout ||
        _policy == null) {
      return Future.value();
    }
    return _sdkInitialization ??= _initializeSdk();
  }

  Future<void> _initializeSdk() async {
    final policy = _policy!;
    try {
      if (!consent.canRequestAds || _disposed) return;
      // Content rating is conservative, not a promise every creative is suitable.
      // Age tags remain unspecified pending an actual audience determination.
      await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
      if (_disposed || !consent.canRequestAds || verifiedAdFree || holdout) {
        return;
      }
      await MobileAds.instance.initialize();
      if (_disposed) return;
      _sdkReady = true;
      _interstitial = InterstitialCoordinator(
          policy: policy,
          loader: NativeInterstitialLoader(
              unitId: () => config.nativeUnit(
                  AdPlacement.funCompleteInterstitial, defaultTargetPlatform)!,
              reporter: reporter),
          gates: _gates,
          report: (event, reason) {
            final kind = switch (event) {
              'request' => AdEventKind.request,
              'loaded' => AdEventKind.loaded,
              'shown' => AdEventKind.shown,
              'dismissal' => AdEventKind.dismissal,
              'show_failure' => AdEventKind.showFailure,
              'load_failure' => AdEventKind.loadFailure,
              'opportunity' => AdEventKind.opportunity,
              _ => AdEventKind.suppression,
            };
            if (event == 'shown') {
              _presenting = true;
              unawaited(policy.setForeground(false, externalOperation: true));
            }
            if (event == 'dismissal' || event == 'show_failure') {
              _presenting = false;
              unawaited(policy.setForeground(foreground));
            }
            reporter.report(AdEvent(kind, AdPlacement.funCompleteInterstitial,
                reason: reason));
          },
          onAfterDismissal: _notify);
      _notify();
    } catch (_) {
      _sdkReady = false;
      _notify();
    } finally {
      // Consent/ad-free gates can change across platform awaits. A later
      // explicitly permitted attempt must not be stuck with an aborted future.
      if (!_sdkReady) _sdkInitialization = null;
    }
  }

  bool displayAllowed(AdPlacement placement) {
    final routeMatches = switch (placement) {
      AdPlacement.forecastBanner => _route == '/forecast',
      AdPlacement.roastsHistoryMrec => _route == '/roasts',
      AdPlacement.funHubMrec => _route == '/fun',
      AdPlacement.memeLibraryMrec => _route == '/fun/meme',
      AdPlacement.funCompleteInterstitial => false,
    };
    final platformReady = kIsWeb
        ? config.webReady &&
            webConsent.cmpConfigured &&
            webConsent.resolved &&
            webConsent.canRequestAds
        : native &&
            _sdkReady &&
            config.nativeReady &&
            consent.resolved &&
            consent.canRequestAds;
    return platformReady &&
        config.permits(placement) &&
        routeMatches &&
        foreground &&
        !modalActive &&
        !_presenting &&
        !verifiedAdFree &&
        !holdout &&
        weather.safetyStatus == WeatherSafetyStatus.clear;
  }

  Future<DisplayAdHandle?> loadDisplay(
      AdPlacement placement, DisplaySize size) async {
    if (!displayAllowed(placement)) return null;
    final id = kIsWeb
        ? config.webUnits[placement]
        : config.nativeUnit(placement, defaultTargetPlatform);
    if (id == null) return null;
    try {
      return await displayAdapter.load(
          unitId: id, size: size, placement: placement, reporter: reporter);
    } catch (_) {
      return null;
    }
  }

  Future<String?> asideForVisit(String visitId) async {
    final copy = _copy, policy = _policy;
    if (copy == null || policy == null) return null;
    await copy.setSession(policy.sessionId);
    return (await copy.chooseForVisit(
            visitId: visitId,
            personaId: personaId?.call() ?? 'general',
            enabled: config.adjacentHumor,
            isWeb: kIsWeb,
            severeWarning: weather.safetyStatus != WeatherSafetyStatus.clear))
        ?.text;
  }

  Future<void> recordMemeCompletion(
      {required String documentId, required String revisionId}) async {
    await _policy?.recordCompletion(
        documentId: documentId, revisionId: revisionId, safelyPersisted: true);
    if (!modalActive) unawaited(_interstitial?.preload());
  }

  Future<void> completeMemeTransition(
      {required VoidCallback continueNavigation}) async {
    final coordinator = _interstitial;
    if (coordinator == null) {
      continueNavigation();
      return;
    }
    _presenting = true;
    _notify();
    try {
      await coordinator.completeTransition(
          continueNavigation: continueNavigation);
    } finally {
      _presenting = false;
      _notify();
    }
  }

  InterstitialGates _gates() => InterstitialGates(
      nativePlatform: native,
      consentAllowed: consent.resolved && consent.canRequestAds && _sdkReady,
      configEnabled: (_route == '/fun' || _route == '/fun/meme') &&
          config.nativeReady &&
          config.permits(AdPlacement.funCompleteInterstitial),
      foreground: foreground,
      modalActive: modalActive,
      safetyKnown: weather.safetyStatus != WeatherSafetyStatus.unknown,
      safetyFresh: weather.safetyStatus == WeatherSafetyStatus.clear ||
          weather.safetyStatus == WeatherSafetyStatus.activeAlert,
      severeWarning: weather.safetyStatus == WeatherSafetyStatus.activeAlert,
      adFree: verifiedAdFree,
      holdout: holdout,
      onboarding: _route == '/splash');

  void setRoute(String route, {bool deferNotification = false}) {
    if (_route == route) return;
    _route = route;
    if (route != '/fun/meme') _interstitial?.invalidate();
    // A route listener never calls show. Preload is permitted only off critical
    // weather/editor/consent rendering and all policy gates must already pass.
    if (route == '/fun') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && _route == '/fun') unawaited(_interstitial?.preload());
      });
    }
    if (deferNotification) {
      _notifyDeferred();
    } else {
      _notify();
    }
  }

  void beginOperation({bool deferNotification = false}) {
    _operations++;
    if (deferNotification) {
      _notifyDeferred();
    } else {
      _notify();
    }
  }

  void endOperation({bool deferNotification = false}) {
    if (_operations > 0) _operations--;
    if (deferNotification) {
      _notifyDeferred();
    } else {
      _notify();
    }
  }

  void setModalCount(int count) {
    _modals = count < 0 ? 0 : count;
    _notify();
  }

  Future<void> showPrivacyOptions() async {
    if (!kIsWeb) {
      await consent.showPrivacyOptions();
      return;
    }
    beginOperation();
    try {
      await webConsent.showPrivacyOptions();
    } finally {
      endOperation();
    }
  }

  void setVerifiedAdFree(bool value) {
    verifiedAdFree = value;
    if (value) _interstitial?.invalidate();
    _notify();
  }

  void _safetyChanged() {
    if (weather.safetyStatus != WeatherSafetyStatus.clear) {
      _interstitial?.invalidate();
    }
    _notify();
  }

  void _webConsentChanged() {
    _notify();
  }

  void _consentChanged() {
    if (kIsWeb ? !webConsent.canRequestAds : !consent.canRequestAds) {
      _interstitial?.invalidate();
    } else if (!consent.operationActive) {
      unawaited(_ensureSdkReady());
    }
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    unawaited(_policy?.setForeground(foreground && !_presenting,
        externalOperation: modalActive || _presenting));
    if (!foreground) _interstitial?.invalidate();
    _notify();
    if (foreground &&
        native &&
        config.nativeReady &&
        !consent.operationActive) {
      unawaited(consent.recheck());
    }
  }

  void _notifyDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _checkpoint?.cancel();
    weather.removeListener(_safetyChanged);
    consent.removeListener(_consentChanged);
    consent.dispose();
    webConsent.removeListener(_webConsentChanged);
    webConsent.dispose();
    _interstitial?.dispose();
    super.dispose();
  }
}
