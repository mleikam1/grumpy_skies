import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:grumpy_skies/monetization/consent_controller.dart';

class FakeConsentInformation implements ConsentInformation {
  int updates = 0;
  bool allowed = false;
  bool failChecks = false;
  bool requiredPrivacy = false;
  OnConsentInfoUpdateSuccessListener? success;
  OnConsentInfoUpdateFailureListener? failure;
  @override
  void requestConsentInfoUpdate(
      ConsentRequestParameters params,
      OnConsentInfoUpdateSuccessListener successListener,
      OnConsentInfoUpdateFailureListener failureListener) {
    updates++;
    success = successListener;
    failure = failureListener;
  }

  @override
  Future<bool> canRequestAds() async {
    if (failChecks) throw StateError('Consent check unavailable');
    return allowed;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
      getPrivacyOptionsRequirementStatus() async => requiredPrivacy
          ? PrivacyOptionsRequirementStatus.required
          : PrivacyOptionsRequirementStatus.notRequired;
  @override
  Future<ConsentStatus> getConsentStatus() async =>
      allowed ? ConsentStatus.obtained : ConsentStatus.required;
  @override
  Future<bool> isConsentFormAvailable() async => true;
  @override
  Future<void> reset() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/google_mobile_ads/ump');
  late ConsentInformation original;
  late FakeConsentInformation information;
  late ConsentController controller;
  late List<String> forms;
  Completer<void>? privacyForm;
  setUp(() {
    original = ConsentInformation.instance;
    information = FakeConsentInformation();
    ConsentInformation.instance = information;
    controller = ConsentController();
    forms = [];
    privacyForm = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      forms.add(call.method);
      if (call.method == 'UserMessagingPlatform#showPrivacyOptionsForm') {
        await privacyForm?.future;
      }
      return null;
    });
  });
  tearDown(() {
    controller.dispose();
    ConsentInformation.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'launch deduplicates information update and required form before permitting ads',
      () async {
    information.allowed = true;
    final first = controller.initialize();
    final second = controller.initialize();
    expect(identical(first, second), isTrue);
    expect(information.updates, 1);
    expect(controller.operationActive, isTrue);
    expect(controller.canRequestAds, isFalse);
    information.success!();
    await first;
    expect(forms, ['UserMessagingPlatform#loadAndShowConsentFormIfRequired']);
    expect(controller.operationActive, isFalse);
    expect(controller.resolved, isTrue);
    expect(controller.canRequestAds, isTrue);
  });

  test('form success alone never bypasses the UMP canRequestAds result',
      () async {
    final initialized = controller.initialize();
    information.success!();
    await initialized;
    expect(controller.resolved, isTrue);
    expect(controller.canRequestAds, isFalse);
  });

  test(
      'required privacy options revoke immediately and permit a later explicit grant',
      () async {
    information.allowed = true;
    information.requiredPrivacy = true;
    final initialized = controller.initialize();
    information.success!();
    await initialized;
    expect(controller.privacyOptionsRequired, isTrue);
    privacyForm = Completer<void>();
    final shown = controller.showPrivacyOptions();
    expect(controller.canRequestAds, isFalse);
    expect(controller.operationActive, isTrue);
    await controller.showPrivacyOptions();
    information.allowed = false;
    privacyForm!.complete();
    await shown;
    expect(controller.canRequestAds, isFalse);
    expect(forms.where((name) => name.contains('showPrivacyOptionsForm')),
        hasLength(1));
    privacyForm = null;
    information.allowed = true;
    await controller.showPrivacyOptions();
    expect(controller.canRequestAds, isTrue);
    expect(controller.operationActive, isFalse);
  });

  test('resume consent refresh fails closed after SDK/storage failure',
      () async {
    information.allowed = true;
    await controller.recheck();
    expect(controller.canRequestAds, isTrue);
    information.failChecks = true;
    await controller.recheck();
    expect(controller.canRequestAds, isFalse);
    expect(controller.resolved, isFalse);
  });

  testWidgets(
      'slow UMP timeout stays blocked until the actual late form callback',
      (tester) async {
    final initialized = controller.initialize();
    await tester.pump(const Duration(seconds: 41));
    await initialized;
    expect(controller.canRequestAds, isFalse);
    expect(controller.resolved, isFalse);
    expect(controller.operationActive, isTrue);
    information.allowed = true;
    information.success!();
    await tester.pump();
    await tester.pump();
    expect(controller.operationActive, isFalse);
    expect(controller.canRequestAds, isTrue);
  });
}
