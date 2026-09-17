import 'package:grumpy_skies/monetization/interstitial_policy.dart';

class MemoryMonetizationStorage implements MonetizationStorage {
  final Map<String, String> values = {};
  bool failWrites = false;
  @override
  String? read(String key) => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Unavailable storage');
    values[key] = value;
  }
}

class PolicyTime {
  DateTime wall = DateTime.utc(2026, 9, 17, 12);
  Duration monotonic = Duration.zero;
  void advance(Duration duration) {
    wall = wall.add(duration);
    monotonic += duration;
  }
}

class PolicyFixture {
  PolicyFixture() {
    policy = restore();
  }
  final storage = MemoryMonetizationStorage();
  final time = PolicyTime();
  late InterstitialPolicy policy;
  InterstitialPolicy restore() => InterstitialPolicy(
      storage: storage,
      clock: () => time.wall,
      monotonicClock: () => time.monotonic);
  Future<void> startSecondSession() async {
    await policy.initialize();
    await nextSession();
  }

  Future<void> nextSession() async {
    await policy.setForeground(false);
    time.advance(const Duration(minutes: 31));
    await policy.setForeground(true);
  }

  Future<void> completeThree({int offset = 0}) async {
    for (var i = offset; i < offset + 3; i++) {
      await policy.recordCompletion(
          documentId: 'doc$i', revisionId: 'rev1', safelyPersisted: true);
    }
  }

  Future<void> makeEligible() async {
    await startSecondSession();
    await completeThree();
    time.advance(const Duration(minutes: 3));
  }
}

const allowedGates = InterstitialGates(
    nativePlatform: true,
    consentAllowed: true,
    configEnabled: true,
    foreground: true,
    modalActive: false,
    safetyKnown: true,
    safetyFresh: true,
    severeWarning: false);

InterstitialGates testGates(
        {bool nativePlatform = true,
        bool consentAllowed = true,
        bool configEnabled = true,
        bool foreground = true,
        bool modalActive = false,
        bool safetyKnown = true,
        bool safetyFresh = true,
        bool severeWarning = false,
        bool adFree = false,
        bool holdout = false,
        bool onboarding = false}) =>
    InterstitialGates(
        nativePlatform: nativePlatform,
        consentAllowed: consentAllowed,
        configEnabled: configEnabled,
        foreground: foreground,
        modalActive: modalActive,
        safetyKnown: safetyKnown,
        safetyFresh: safetyFresh,
        severeWarning: severeWarning,
        adFree: adFree,
        holdout: holdout,
        onboarding: onboarding);
