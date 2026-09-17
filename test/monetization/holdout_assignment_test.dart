import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:grumpy_skies/monetization/holdout_assignment.dart';

import 'monetization_test_helpers.dart';

class BucketRandom implements Random {
  BucketRandom(this.bucket);
  final int bucket;
  int samples = 0;
  @override
  int nextInt(int max) {
    samples++;
    return bucket;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('exact ten of the100 stable buckets are in the initial holdout',
      () async {
    var held = 0;
    for (var bucket = 0; bucket < 100; bucket++) {
      final assignment = HoldoutAssignment(
          storage: MemoryMonetizationStorage(), random: BucketRandom(bucket));
      if (await assignment.resolve(measurementPermitted: true)) held++;
    }
    expect(held, 10);
  });

  test('deduplicated allocation and restart preserve the original bucket',
      () async {
    final storage = MemoryMonetizationStorage();
    final random = BucketRandom(5);
    final first = HoldoutAssignment(storage: storage, random: random);
    expect(
        await Future.wait([
          first.resolve(measurementPermitted: true),
          first.resolve(measurementPermitted: true)
        ]),
        [true, true]);
    expect(random.samples, 1);
    final replacementRandom = BucketRandom(99);
    final restored =
        HoldoutAssignment(storage: storage, random: replacementRandom);
    expect(await restored.resolve(measurementPermitted: true), isTrue);
    expect(replacementRandom.samples, 0);
  });

  test('no measurement permission allocates no experiment data', () async {
    final storage = MemoryMonetizationStorage();
    final random = BucketRandom(5);
    final assignment = HoldoutAssignment(storage: storage, random: random);
    expect(await assignment.resolve(measurementPermitted: false), isFalse);
    expect(storage.values, isEmpty);
    expect(random.samples, 0);
    expect(await assignment.resolve(measurementPermitted: true), isTrue);
    expect(random.samples, 1);
    expect(await assignment.resolve(measurementPermitted: false), isFalse);
  });

  test('configuration may grow but cannot remove the baseline holdout',
      () async {
    final assignment = HoldoutAssignment(
        storage: MemoryMonetizationStorage(), random: BucketRandom(9));
    expect(await assignment.resolve(measurementPermitted: true, percent: 0),
        isTrue);
    final larger = HoldoutAssignment(
        storage: MemoryMonetizationStorage(), random: BucketRandom(29));
    expect(await larger.resolve(measurementPermitted: true), isFalse);
    expect(
        await larger.resolve(measurementPermitted: true, percent: 30), isTrue);
  });

  test('corrupt or unwritable assignment suppresses inventory conservatively',
      () async {
    final bad = MemoryMonetizationStorage();
    bad.values[HoldoutAssignment.storageKey] = '{"version":1,"bucket":-2}';
    expect(
        await HoldoutAssignment(storage: bad)
            .resolve(measurementPermitted: true),
        isTrue);
    final unavailable = MemoryMonetizationStorage()..failWrites = true;
    expect(
        await HoldoutAssignment(storage: unavailable, random: BucketRandom(99))
            .resolve(measurementPermitted: true),
        isTrue);
  });
}
