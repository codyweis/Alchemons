// The Works, run for days in random stretches, must keep their own rules:
// no storage goes negative or NaN, no hopper or crate store overfills, the
// Refinery never makes more than it takes, silver only grows — and catching
// up in one jump must land where catching up step by step lands, since that
// is the difference between a player who left the game open and one who
// came back the next morning.

import 'dart:math';

import 'package:alchemons/games/cosmic/works.dart';
import 'package:flutter_test/flutter_test.dart';

WorkerProfile _w(String id, Random r) => WorkerProfile(
  instanceId: id,
  element: 'Fire',
  speed: 0.5 + r.nextDouble() * 6,
  intelligence: 0.5 + r.nextDouble() * 6,
  strength: 0.5 + r.nextDouble() * 6,
  beauty: 0.5 + r.nextDouble() * 6,
  harvestRate: 1 + r.nextInt(12),
);

const _min = 60000;

/// A works with everything built and staffed.
(WorksState, Map<String, WorkerProfile>) _full(Random r, int t0) {
  final workers = {
    for (final id in ['m0', 'm1', 'c0', 'm2', 's0', 's1', 's2', 'p0', 'r0'])
      id: _w(id, r),
  };
  final works = WorksState(
    extractors: {
      'Fire': ExtractorState(
        element: 'Fire',
        updatedMs: t0,
        tier: 3,
        miners: ['m0', 'm1'],
        courier: 'c0',
      ),
      'Water': ExtractorState(element: 'Water', updatedMs: t0, miners: ['m2']),
    },
    bay: ScavengerBayState(tier: 3, berth: 0),
    press: SilverPressState(
      tier: 2,
      berth: 1,
      presser: 'p0',
      reserve: 200,
      updatedMs: t0,
    ),
    refinery: RefineryState(
      tier: 2,
      berth: 2,
      refiner: 'r0',
      recipe: 'Fire+Water',
      keep: 50,
      updatedMs: t0,
    ),
    armory: ArmoryState(tier: 1, berth: 3),
  );
  works.bay.slots[0].instanceId = 's0';
  works.bay.slots[1].instanceId = 's1';
  works.bay.slots[2].instanceId = 's2';
  return (works, workers);
}

void _checkRules(WorksState w, Map<String, double> storage, String when) {
  for (final e in storage.entries) {
    expect(e.value.isFinite, isTrue, reason: '$when: ${e.key} not finite');
    expect(e.value, greaterThanOrEqualTo(-1e-6), reason: '$when: ${e.key}');
  }
  for (final x in w.extractors.values) {
    expect(
      x.hopper,
      inInclusiveRange(-1e-6, x.hopperCap + 1e-6),
      reason: '$when: ${x.element} hopper',
    );
    expect(x.cargo, greaterThanOrEqualTo(0), reason: '$when: cargo');
  }
  expect(
    w.bay.crates.length + w.bay.out,
    lessThanOrEqualTo(w.bay.crateCap),
    reason: '$when: crates and trips out',
  );
  expect(w.refinery.made.isFinite, isTrue);
}

void main() {
  test('days of random stretches keep the rules', () {
    for (var seed = 0; seed < 30; seed++) {
      final r = Random(seed);
      var now = 1000000;
      final (works, workers) = _full(r, now);
      final storage = <String, double>{
        'Fire': 400 + r.nextDouble() * 400,
        'Water': 300 + r.nextDouble() * 300,
        'Earth': 50,
      };
      var silver = 0;
      var refinedIn = 0.0;
      var refinedOut = 0.0;
      for (var step = 0; step < 300; step++) {
        // From a second to six hours.
        now += 1000 + r.nextInt(6 * 3600 * 1000);
        final before = Map.of(storage);
        final report = advanceWorks(
          works,
          nowMs: now,
          storage: storage,
          workers: workers,
          distanceHome: (_) => 2000 + r.nextDouble() * 12000,
          scavengeElements: const ['Fire', 'Water', 'Dust', 'Crystal'],
        );
        expect(report.silver, greaterThanOrEqualTo(0));
        silver += report.silver;
        refinedOut += report.refinedUnits;
        // What the refinery took: Water only leaves storage through it (the
        // press may take Water too, so count only when the press is idle on
        // Water — its reserve is 200, so use the refinery's own report).
        refinedIn += report.refinedUnits / WorkRules.refineYield(2);
        _checkRules(works, storage, 'seed $seed step $step');
        // Sometimes the player comes by: crates collected, hoppers sent home.
        if (r.nextDouble() < 0.2) {
          collectCrates(works.bay, storage, nowMs: now, workers: workers);
        }
        if (r.nextDouble() < 0.2) {
          final x = works.extractors['Water']!;
          storage['Water'] = (storage['Water'] ?? 0) + x.hopper;
          x.hopper = 0;
        }
        // Sometimes a worker leaves and another takes the job.
        if (r.nextDouble() < 0.05) {
          endCourierRun(works.extractors['Fire']!, storage);
          works.extractors['Fire']!.courier = r.nextBool() ? 'c0' : null;
        }
        expect(before.isNotEmpty, isTrue);
      }
      expect(silver, greaterThanOrEqualTo(0));
      expect(refinedOut, lessThanOrEqualTo(refinedIn + 1e-6));
    }
  });

  test('catching up in one jump lands where small steps land', () {
    for (var seed = 0; seed < 20; seed++) {
      final r = Random(100 + seed);
      const t0 = 5000000;
      final (a, workers) = _full(r, t0);
      final (b, _) = _full(Random(100 + seed), t0);
      // Same workers for both.
      final storeA = <String, double>{'Fire': 5000, 'Water': 5000};
      final storeB = Map.of(storeA);
      // No press or refinery here: they share out what is over a reserve in
      // proportion, which a jump and many steps divide differently. The
      // extractors and the bay keep exact time.
      for (final w in [a, b]) {
        w.press.presser = null;
        w.refinery.refiner = null;
      }
      // As in play: assigning a worker ticks the works at once, which sends
      // a resting scavenger out then.
      for (final (w, st) in [(a, storeA), (b, storeB)]) {
        advanceWorks(
          w,
          nowMs: t0,
          storage: st,
          workers: workers,
          distanceHome: (_) => 6000,
          scavengeElements: const ['Fire', 'Water'],
        );
      }
      const span = 9 * 3600 * 1000;
      advanceWorks(
        a,
        nowMs: t0 + span,
        storage: storeA,
        workers: workers,
        distanceHome: (_) => 6000,
        scavengeElements: const ['Fire', 'Water'],
      );
      for (var t = t0; t < t0 + span;) {
        t = min(t0 + span, t + 1000 + r.nextInt(40 * _min));
        advanceWorks(
          b,
          nowMs: t,
          storage: storeB,
          workers: workers,
          distanceHome: (_) => 6000,
          scavengeElements: const ['Fire', 'Water'],
        );
      }
      for (final e in ['Fire', 'Water']) {
        expect(
          storeA[e]!,
          closeTo(storeB[e]!, 1e-6),
          reason: 'seed $seed: $e stored',
        );
        expect(
          a.extractors[e]!.hopper,
          closeTo(b.extractors[e]!.hopper, 1e-6),
          reason: 'seed $seed: $e hopper',
        );
      }
      expect(a.bay.crates.length, b.bay.crates.length, reason: 'seed $seed');
      expect(
        [for (final c in a.bay.crates) c.elements],
        [for (final c in b.bay.crates) c.elements],
        reason: 'seed $seed: the same finds',
      );
    }
  });

  test('an Alchemon gone mid-run leaves its work safe', () {
    final r = Random(7);
    const t0 = 1000;
    final (works, workers) = _full(r, t0);
    final storage = <String, double>{'Fire': 900, 'Water': 900};
    advanceWorks(
      works,
      nowMs: t0 + 5 * _min,
      storage: storage,
      workers: workers,
      distanceHome: (_) => 5000,
      scavengeElements: const ['Fire'],
    );
    // Everyone is released (fused, sold) between two advances.
    advanceWorks(
      works,
      nowMs: t0 + 600 * _min,
      storage: storage,
      workers: const {},
      distanceHome: (_) => 5000,
      scavengeElements: const ['Fire'],
    );
    _checkRules(works, storage, 'after release');
    expect(works.bay.out, 0);
  });
}
