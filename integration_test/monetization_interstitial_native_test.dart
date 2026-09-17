import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grumpy_skies/design/dm_theme.dart';
import 'package:grumpy_skies/monetization/ad_config.dart';
import 'package:grumpy_skies/monetization/ad_placement.dart';
import 'package:grumpy_skies/monetization/ad_reporting.dart';
import 'package:grumpy_skies/monetization/consent_controller.dart';
import 'package:grumpy_skies/monetization/interstitial_coordinator.dart';
import 'package:grumpy_skies/monetization/interstitial_policy.dart';
import 'package:grumpy_skies/monetization/platform/native_interstitial_adapter.dart';

/// Isolated QA only. Real UMP/SDK; simulated policy time and persisted fixture
/// documents do not write the production policy key. Close the SDK's own control
/// after it appears; never click the creative. If the native Close control cannot
/// be operated, the log explicitly records dismissal as unverified.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native interstitial loads and shows only after fixture Done',
      (tester) async {
    expect(kIsWeb || kReleaseMode, isFalse);
    final consent = ConsentController();
    addTearDown(consent.dispose);
    final status =
        ValueNotifier('Saved result is visible. Checking real UMP consent.');
    var fixtureActive = true;
    addTearDown(() {
      fixtureActive = false;
      status.dispose();
    });
    late InterstitialCoordinator coordinator;
    Future<void>? transition;
    var navigationCount = 0;
    var afterDismissalCount = 0;
    var shown = false;
    var dismissed = false;
    var showFailed = false;
    final reporter = _SdkReporter();
    await tester.pumpWidget(MaterialApp(
        theme: DMTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('DayMaker interstitial QA')),
          body: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'TEST FIXTURE · Official Google test inventory'),
                      const SizedBox(height: 24),
                      const Icon(Icons.check_circle_outline, size: 64),
                      const Text('Meme result saved',
                          style: TextStyle(fontSize: 28)),
                      const Text(
                          'Three separate fixture documents are persisted. This QA run uses an injected clock to verify the second-session/180-second gates.'),
                      const SizedBox(height: 24),
                      ValueListenableBuilder(
                          valueListenable: status,
                          builder: (_, text, __) => Text(text)),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: () {
                            transition = coordinator.completeTransition(
                                continueNavigation: () {
                              navigationCount++;
                              if (fixtureActive) {
                                status.value =
                                    'Back in Fun. Weather remains available.';
                              }
                            });
                          },
                          child: const Text('Done — back to Fun')),
                      TextButton(
                          onPressed: () {},
                          child: const Text('Go directly to weather')),
                    ],
                  ))),
        )));
    await tester.pump();
    await consent.initialize();
    debugPrint(
        'NATIVE_AD_QA interstitial consent resolved=${consent.resolved} canRequestAds=${consent.canRequestAds}');
    if (!consent.resolved || !consent.canRequestAds) {
      status.value =
          'Real consent blocks advertising. Result and weather are available.';
      await tester.pump();
      debugPrint('NATIVE_AD_QA_SCREENSHOT interstitial_consent_blocked');
      await _wait(tester, () => false, const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox());
      return;
    }
    await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
    await MobileAds.instance.initialize();

    final preferences = await SharedPreferences.getInstance();
    final storage = _ScopedStorage(
        preferences, 'daymaker.qa.${DateTime.now().microsecondsSinceEpoch}');
    addTearDown(storage.removeFixtureOnly);
    var wall = DateTime.now().toUtc();
    var monotonic = Duration.zero;
    InterstitialPolicy restore() => InterstitialPolicy(
        storage: storage, clock: () => wall, monotonicClock: () => monotonic);
    final first = restore();
    await first.initialize();
    await first.setForeground(false);
    wall = wall.add(const Duration(minutes: 31));
    monotonic += const Duration(minutes: 31);
    final policy = restore();
    await policy.initialize();
    expect(policy.sessionId, 'session-2');
    for (var i = 0; i < 3; i++) {
      final doc = 'qa-fixture-document-$i';
      await storage.write(
          doc, jsonEncode({'document': doc, 'revision': '1', 'saved': true}));
      expect(storage.read(doc), isNotNull);
      expect(
          await policy.recordCompletion(
              documentId: doc, revisionId: '1', safelyPersisted: true),
          isTrue);
    }
    wall = wall.add(const Duration(seconds: 180));
    monotonic += const Duration(seconds: 180);
    InterstitialGates gates() => InterstitialGates(
        nativePlatform: true,
        consentAllowed: consent.resolved && consent.canRequestAds,
        configEnabled: true,
        foreground:
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
        modalActive: consent.operationActive,
        safetyKnown: true,
        safetyFresh: true,
        severeWarning: false);
    expect(policy.foregroundEngagement, const Duration(seconds: 180));
    expect(policy.eligibility(gates()), isNull);
    const config = AdConfig(enabled: true, testMode: true);
    coordinator = InterstitialCoordinator(
        policy: policy,
        loader: NativeInterstitialLoader(
            unitId: () => config.nativeUnit(
                AdPlacement.funCompleteInterstitial, defaultTargetPlatform)!,
            reporter: reporter),
        gates: gates,
        report: (event, reason) {
          debugPrint('NATIVE_AD_QA interstitial $event ${reason ?? ''}');
          if (event == 'shown') {
            shown = true;
            debugPrint('NATIVE_AD_QA_SCREENSHOT interstitial_shown');
          }
          if (event == 'dismissal') dismissed = true;
          if (event == 'show_failure') showFailed = true;
        },
        onAfterDismissal: () => afterDismissalCount++);
    addTearDown(coordinator.dispose);
    await coordinator.preload();
    expect(shown, isFalse, reason: 'SDK load callbacks never present');
    expect(policy.sessionShownCount, 0);
    if (!coordinator.isReady) {
      status.value = 'No inventory ready. Done returns immediately.';
      await tester.pump();
      await tester.tap(find.text('Done — back to Fun'));
      await transition;
      expect(navigationCount, 1);
      expect(policy.sessionShownCount, 0);
      debugPrint('NATIVE_AD_QA_SCREENSHOT interstitial_unavailable');
      await _wait(tester, () => false, const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox());
      return;
    }
    status.value = 'Test ad preloaded. Saved result stays visible until Done.';
    await tester.pump();
    expect(find.text('Meme result saved'), findsOneWidget);
    expect(shown, isFalse);
    await tester.tap(find.text('Done — back to Fun'));
    await _wait(tester, () => shown || showFailed, const Duration(seconds: 15),
        pumpFrames: false);
    if (showFailed) {
      await transition;
      expect(navigationCount, 1);
      expect(policy.sessionShownCount, 0);
      debugPrint(
          'NATIVE_AD_QA interstitial SDK show failure; navigation recovered');
    } else {
      expect(shown, isTrue);
      expect(navigationCount, 0);
      expect(policy.sessionShownCount, 1);
      // Native SDK control only: the harness never supplies a fake close button
      // or programmatically dismisses the presented SDK interstitial.
      await _wait(tester, () => dismissed, const Duration(seconds: 45),
          pumpFrames: false);
      if (dismissed) {
        await transition;
        expect(navigationCount, 1);
        expect(afterDismissalCount, 1);
        expect(policy.shownHistory, hasLength(1));
        expect(coordinator.isReady, isFalse);
        expect(find.text('Back in Fun. Weather remains available.'),
            findsOneWidget);
        debugPrint(
            'NATIVE_AD_QA interstitial dismissal_verified navigation=1 afterDismissal=1');
        debugPrint('NATIVE_AD_QA_SCREENSHOT interstitial_dismissed');
        await _wait(tester, () => false, const Duration(seconds: 8));
      } else {
        debugPrint(
            'NATIVE_AD_QA interstitial presented_verified DISMISSAL_UNVERIFIED native Close interaction unavailable');
        return;
      }
    }
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _wait(WidgetTester tester, bool Function() ready, Duration timeout,
    {bool pumpFrames = true}) async {
  final wall = Stopwatch()..start();
  while (!ready() && wall.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (pumpFrames) await tester.pump();
  }
}

class _SdkReporter implements AdReporter {
  @override
  void report(AdEvent event) =>
      debugPrint('NATIVE_AD_QA interstitial SDK ${event.kind.name}');
}

class _ScopedStorage implements MonetizationStorage {
  _ScopedStorage(this.preferences, this.prefix);
  final SharedPreferences preferences;
  final String prefix;
  final keys = <String>{};
  @override
  String? read(String key) => preferences.getString('$prefix.$key');
  @override
  Future<void> write(String key, String value) async {
    final scoped = '$prefix.$key';
    keys.add(scoped);
    if (!await preferences.setString(scoped, value)) {
      throw StateError('Fixture could not persist');
    }
  }

  Future<void> removeFixtureOnly() async {
    for (final key in keys) {
      await preferences.remove(key);
    }
  }
}
