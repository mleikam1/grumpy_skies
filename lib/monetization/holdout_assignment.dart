import 'dart:convert';
import 'dart:math';

import 'interstitial_policy.dart';

/// Stable local experiment bucket, allocated only with measurement permission.
/// No identifier is transmitted, and no fingerprint/device identifier is used.
class HoldoutAssignment {
  HoldoutAssignment({required this.storage, Random? random})
      : random = random ?? Random.secure();

  static const storageKey = 'daymaker.eligible-ad-holdout.v1';
  final MonetizationStorage storage;
  final Random random;
  Future<int?>? _bucket;

  Future<bool> resolve(
      {required bool measurementPermitted, int percent = 10}) async {
    if (!measurementPermitted) return false;
    final bucket = await (_bucket ??= _readOrAssign());
    // Missing durable assignment suppresses ads rather than silently moving a
    // user between the ad and no-ad groups at every restart.
    return bucket == null || bucket < percent.clamp(10, 100);
  }

  Future<int?> _readOrAssign() async {
    try {
      final raw = storage.read(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final bucket = data['bucket'];
        if (data['version'] != 1 ||
            bucket is! int ||
            bucket < 0 ||
            bucket >= 100) {
          return null;
        }
        return bucket;
      }
      final bucket = random.nextInt(100);
      await storage.write(
          storageKey, jsonEncode({'version': 1, 'bucket': bucket}));
      return bucket;
    } catch (_) {
      return null;
    }
  }
}
