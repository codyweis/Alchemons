import 'package:alchemons/games/cosmic_survival/survival_mastery_wing.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wing's tree, and the rules that do not need the game to evaluate.
///
/// The draft this replaced was Mane's tree with "shots" written over
/// "slashes", so the collision group is the one that would have caught it.
void main() {
  bool Function(String) holding(Set<String> owned) => owned.contains;

  group('Burn Through rewards holding the beam still', () {
    test('nothing without the opener', () {
      expect(
        wingBoreMultiplier(hasNode: holding({}), dwell: 10),
        1.0,
      );
    });

    test('the ramp climbs with dwell and stops at its ceiling', () {
      final owned = holding({WingNodes.bore});
      final short = wingBoreMultiplier(hasNode: owned, dwell: 0.5);
      final long = wingBoreMultiplier(hasNode: owned, dwell: 3.0);
      final absurd = wingBoreMultiplier(hasNode: owned, dwell: 600.0);

      expect(short, greaterThan(1.0));
      expect(long, greaterThan(short));
      expect(long, closeTo(1 + WingTuning.boreMax, 0.001));
      expect(absurd, long, reason: 'the ramp must not run away');
    });

    test('Deeper climbs faster and higher', () {
      final plain = holding({WingNodes.bore});
      final deeper = holding({WingNodes.bore, WingNodes.deeper});

      expect(
        wingBoreMultiplier(hasNode: deeper, dwell: 1.0),
        greaterThan(wingBoreMultiplier(hasNode: plain, dwell: 1.0)),
      );
      expect(
        wingBoreMultiplier(hasNode: deeper, dwell: 99),
        closeTo(1 + WingTuning.deeperMax, 0.001),
      );
    });

    test('No Reprieve is what stops a switch costing everything', () {
      expect(wingBoreCurve(hasNode: holding({WingNodes.bore})).fade, 0);
      expect(
        wingBoreCurve(
          hasNode: holding({WingNodes.bore, WingNodes.noReprieve}),
        ).fade,
        greaterThan(0),
      );
    });

    test('a carried ramp is handed over once, not kept', () {
      final state = WingMasteryState()..carriedRamp = 0.8;
      expect(state.takeCarriedRamp(), closeTo(0.8, 0.001));
      expect(state.takeCarriedRamp(), 0);
    });
  });

  group('Longshot pays for keeping away', () {
    const range = 400.0;

    test('nothing without the opener, and nothing up close', () {
      expect(
        wingLongshotBonus(
          hasNode: holding({}),
          distance: range,
          range: range,
          nearestEnemyDistance: range,
        ),
        0,
      );
      expect(
        wingLongshotBonus(
          hasNode: holding({WingNodes.rangefinder}),
          distance: range * 0.2,
          range: range,
          nearestEnemyDistance: range * 0.2,
        ),
        0,
      );
    });

    test('past the threshold it pays, and climbs with Long Lens', () {
      final flat = wingLongshotBonus(
        hasNode: holding({WingNodes.rangefinder}),
        distance: range * 0.9,
        range: range,
        nearestEnemyDistance: range * 0.9,
      );
      expect(flat, closeTo(WingTuning.rangefinderBonus, 0.001));

      final lens = holding({WingNodes.rangefinder, WingNodes.longLens});
      final near = wingLongshotBonus(
        hasNode: lens,
        distance: range * 0.65,
        range: range,
        nearestEnemyDistance: range * 0.65,
      );
      final edge = wingLongshotBonus(
        hasNode: lens,
        distance: range,
        range: range,
        nearestEnemyDistance: range,
      );
      expect(edge, greaterThan(near));
      expect(edge, closeTo(WingTuning.longLensBonus, 0.001));
    });

    test('Standoff pays up close only while nothing has closed in', () {
      final owned = holding({
        WingNodes.rangefinder,
        WingNodes.longLens,
        WingNodes.standoff,
      });
      // Target is close, but the field is clear: the path pays.
      expect(
        wingLongshotBonus(
          hasNode: owned,
          distance: range * 0.1,
          range: range,
          nearestEnemyDistance: range * 0.9,
        ),
        closeTo(WingTuning.longLensBonus, 0.001),
      );
      // Something has closed inside the threshold: it does not.
      expect(
        wingLongshotBonus(
          hasNode: owned,
          distance: range * 0.1,
          range: range,
          nearestEnemyDistance: range * 0.1,
        ),
        0,
      );
    });

    test('range only grows with the nodes that say so', () {
      expect(wingRangeMultiplier(hasNode: holding({})), 1.0);
      expect(
        wingRangeMultiplier(hasNode: holding({WingNodes.longLens})),
        closeTo(WingTuning.longLensRange, 0.001),
      );
      expect(
        wingRangeMultiplier(
          hasNode: holding({WingNodes.longLens, WingNodes.horizon}),
        ),
        closeTo(WingTuning.longLensRange * WingTuning.horizonRange, 0.001),
      );
    });

    test('a zero range cannot divide', () {
      expect(
        wingLongshotBonus(
          hasNode: holding({WingNodes.rangefinder}),
          distance: 100,
          range: 0,
          nearestEnemyDistance: 100,
        ),
        0,
      );
    });
  });

  group('Tracer makes the shots feed the beam', () {
    test('nothing without the opener', () {
      final none = wingTracer(hasNode: holding({}), beamRunning: false);
      expect(none.shave, 0);
      expect(none.extend, 0);
    });

    test('the opener shaves but banks nothing', () {
      final one = wingTracer(
        hasNode: holding({WingNodes.tracerRounds}),
        beamRunning: false,
      );
      expect(one.shave, closeTo(WingTuning.tracerShave, 0.001));
      expect(one.extend, 0);
    });

    test('Hot Barrel grows both, and the ceiling with them', () {
      final two = wingTracer(
        hasNode: holding({WingNodes.tracerRounds, WingNodes.rangingShots}),
        beamRunning: false,
      );
      final hot = wingTracer(
        hasNode: holding({
          WingNodes.tracerRounds,
          WingNodes.rangingShots,
          WingNodes.hotBarrel,
        }),
        beamRunning: false,
      );
      expect(hot.shave, greaterThan(two.shave));
      expect(hot.extend, greaterThan(two.extend));
      expect(hot.cap, greaterThan(two.cap));
    });

    test('Live Feed only redirects while a beam is actually running', () {
      final owned = holding({
        WingNodes.tracerRounds,
        WingNodes.rangingShots,
        WingNodes.liveFeed,
      });
      expect(
        wingTracer(hasNode: owned, beamRunning: false).intoRunningBeam,
        isFalse,
      );
      expect(
        wingTracer(hasNode: owned, beamRunning: true).intoRunningBeam,
        isTrue,
      );
      // Without the capstone it always banks, beam or no beam.
      expect(
        wingTracer(
          hasNode: holding({WingNodes.tracerRounds, WingNodes.rangingShots}),
          beamRunning: true,
        ).intoRunningBeam,
        isFalse,
      );
    });

    test('the bank respects its ceiling and empties when spent', () {
      final state = WingMasteryState();
      for (var i = 0; i < 200; i++) {
        state.bankBeamTime(WingTuning.rangingExtend, WingTuning.rangingCap);
      }
      expect(state.bankedBeamTime, closeTo(WingTuning.rangingCap, 0.001));
      expect(state.takeBankedBeamTime(), closeTo(WingTuning.rangingCap, 0.001));
      expect(state.bankedBeamTime, 0);
    });
  });

  group('the tree itself', () {
    test('every node id the game references exists in the catalog', () {
      const referenced = [
        WingNodes.bore,
        WingNodes.deeper,
        WingNodes.noReprieve,
        WingNodes.carryThrough,
        WingNodes.rangefinder,
        WingNodes.longLens,
        WingNodes.standoff,
        WingNodes.horizon,
        WingNodes.tracerRounds,
        WingNodes.rangingShots,
        WingNodes.hotBarrel,
        WingNodes.liveFeed,
      ];
      for (final id in referenced) {
        expect(
          FamilyMasteryCatalog.entryForNode(id),
          isNotNull,
          reason: '$id is not in the catalog',
        );
      }
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.wing);
      expect({
        for (final path in tree.paths)
          for (final node in path.nodes) node.id,
      }, referenced.toSet());
    });

    test('Wing is not Mane with the words changed', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.wing);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) '${node.name}: ${node.description}',
      ].join('\n').toLowerCase();

      const claimed = {
        'both shots hit the same': "Mane's Crosscut, word for word",
        'builds focus': "Mane banks Rhythm on exactly this trigger",
        'every 4th': 'Let, Pip and Mane own four every-Nth nodes',
        'every 5th': 'Let, Pip and Mane own four every-Nth nodes',
        'pierce': "Mane is the piercing family",
        'echo': "Horn's Juggernaut runs the special again",
      };
      for (final entry in claimed.entries) {
        expect(
          copy.contains(entry.key),
          isFalse,
          reason: 'Wing tree says "${entry.key}" — ${entry.value}',
        );
      }
    });

    test('no path takes an element signature', () {
      // Wing's own seventeen claim nearly every beam behaviour, so this is
      // the check that matters more than "is it unclaimed".
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.wing);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) node.description,
      ].join('\n').toLowerCase();

      const signatures = {
        'sweep': 'Fire sweeps the beam in a circle',
        'refract': 'Light refracts on a kill',
        'scar': 'Lava scars the ground',
        'freeze': 'Ice builds frost to a freeze',
        'execute': 'Blood executes the lowest-health enemy',
        'heals': 'Crystal lifesteals to the orb and Water heals allies',
      };
      for (final entry in signatures.entries) {
        expect(
          copy.contains(entry.key),
          isFalse,
          reason: 'Wing tree says "${entry.key}" — ${entry.value}',
        );
      }
    });
  });

  test('mastery is only owed the share it actually added', () {
    expect(wingUpliftFraction(1.0), 0);
    expect(wingUpliftFraction(0.5), 0);
    expect(wingUpliftFraction(1.25), closeTo(0.2, 0.001));
  });
}
