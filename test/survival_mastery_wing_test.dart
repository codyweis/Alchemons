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

    test('past the threshold it pays, the same all the way out', () {
      final flat = wingLongshotBonus(
        hasNode: holding({WingNodes.rangefinder}),
        distance: range * 0.9,
        range: range,
        nearestEnemyDistance: range * 0.9,
      );
      expect(flat, closeTo(WingTuning.rangefinderBonus, 0.001));
      // Long Lens no longer climbs the bonus: it aims (wingLeadPoint).
      final lens = holding({WingNodes.rangefinder, WingNodes.longLens});
      for (final at in [0.65, 1.0]) {
        expect(
          wingLongshotBonus(
            hasNode: lens,
            distance: range * at,
            range: range,
            nearestEnemyDistance: range * at,
          ),
          closeTo(WingTuning.rangefinderBonus, 0.001),
        );
      }
    });

    test('the far reach is the band from 60% of range to its edge', () {
      expect(wingInFarReach(distance: range * 0.59, range: range), isFalse);
      expect(wingInFarReach(distance: range * 0.61, range: range), isTrue);
      expect(wingInFarReach(distance: range, range: range), isTrue);
      expect(wingInFarReach(distance: range * 1.01, range: range), isFalse);
      expect(wingInFarReach(distance: 10, range: 0), isFalse);
    });

    test('Long Lens aims where a moving body will be', () {
      // A body 400 out, walking across the line of fire at 100 a second.
      final aim = wingLeadPoint(
        fromX: 0,
        fromY: 0,
        targetX: 400,
        targetY: 0,
        velocityX: 0,
        velocityY: 100,
        shotSpeed: 800,
      );
      expect(aim.dx, closeTo(400, 0.001));
      // About half a second of its walk ahead.
      expect(aim.dy, closeTo(100 * 400 / 800, 5));
      // A still body is aimed at where it stands.
      final still = wingLeadPoint(
        fromX: 0,
        fromY: 0,
        targetX: 400,
        targetY: 0,
        velocityX: 0,
        velocityY: 0,
        shotSpeed: 800,
      );
      expect((still.dx, still.dy), (400.0, 0.0));
      // A very slow shot cannot lead a body off the map.
      final slow = wingLeadPoint(
        fromX: 0,
        fromY: 0,
        targetX: 400,
        targetY: 0,
        velocityX: 0,
        velocityY: 100,
        shotSpeed: 1,
      );
      expect(slow.dy, lessThanOrEqualTo(100 * WingTuning.leadCap + 0.001));
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
        closeTo(WingTuning.rangefinderBonus, 0.001),
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
      // Overwatch watches the reach Long Lens bought; it adds none.
      expect(
        wingRangeMultiplier(
          hasNode: holding({WingNodes.longLens, WingNodes.overwatch}),
        ),
        closeTo(WingTuning.longLensRange, 0.001),
      );
    });

    test('Overwatch shoots each body once, out of a bank', () {
      final state = WingMasteryState();
      final a = Object();
      final b = Object();
      expect(state.takeOverwatchShot(a), isTrue);
      expect(state.takeOverwatchShot(a), isFalse, reason: 'once each');
      expect(state.takeOverwatchShot(b), isTrue);
      expect(state.overwatchFired, 2);
      // A flood empties the bank and waits for it to refill.
      var fired = 0;
      for (var i = 0; i < 100; i++) {
        if (state.takeOverwatchShot(Object())) fired++;
      }
      expect(fired, lessThanOrEqualTo(WingTuning.overwatchBurst));
      expect(state.takeOverwatchShot(Object()), isFalse);
      // A quarter of a second's refill buys a quarter second's worth.
      for (var i = 0; i < 15; i++) {
        state.tickOverwatch(1 / 60);
      }
      fired = 0;
      for (var i = 0; i < 100; i++) {
        if (state.takeOverwatchShot(Object())) fired++;
      }
      expect(fired, closeTo(WingTuning.overwatchShotsPerSecond / 4, 1));
      // A long wait fills the bank, and no further.
      for (var i = 0; i < 600; i++) {
        state.tickOverwatch(1 / 60);
      }
      fired = 0;
      for (var i = 0; i < 100; i++) {
        if (state.takeOverwatchShot(Object())) fired++;
      }
      expect(fired, WingTuning.overwatchBurst.floor());
    });

    test('a body taking aim is shot every time it does, out of the same bank',
        () {
      final state = WingMasteryState();
      final brute = Object();
      expect(state.takeOverwatchShot(brute), isTrue);
      // Its far-band shot is spent; taking aim still draws one, each time.
      expect(state.takeOverwatchAimShot(), isTrue);
      expect(state.takeOverwatchAimShot(), isTrue);
      expect(state.overwatchAimShots, 2);
      expect(state.overwatchFired, 3);
      while (state.takeOverwatchAimShot()) {}
      expect(state.overwatchShots, lessThan(1), reason: 'the bank is shared');
    });

    test('Overwatch watches twice the range for a body taking aim, and only '
        'the capstone does', () {
      expect(wingOverwatchReach(hasNode: holding({})), 0);
      expect(
        wingOverwatchReach(
          hasNode: holding({
            WingNodes.rangefinder,
            WingNodes.longLens,
            WingNodes.standoff,
          }),
        ),
        0,
      );
      expect(
        wingOverwatchReach(hasNode: holding({WingNodes.overwatch})),
        WingTuning.overwatchReach,
      );
      expect(WingTuning.overwatchReach, greaterThan(1));
    });

    test('Overwatch looks a few times a second, not every frame', () {
      final state = WingMasteryState();
      var looks = 0;
      for (var i = 0; i < 60; i++) {
        if (state.tickOverwatch(1 / 60)) looks++;
      }
      expect(looks, closeTo(1 / WingTuning.overwatchScanInterval, 1));
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

    test('Loaded Beam banks onto the beam; Hot Barrel leaves the numbers', () {
      final two = wingTracer(
        hasNode: holding({WingNodes.tracerRounds, WingNodes.loadedBeam}),
        beamRunning: false,
      );
      expect(two.extend, closeTo(WingTuning.rangingExtend, 0.001));
      final hot = wingTracer(
        hasNode: holding({
          WingNodes.tracerRounds,
          WingNodes.loadedBeam,
          WingNodes.hotBarrel,
        }),
        beamRunning: false,
      );
      expect((hot.shave, hot.extend, hot.cap), (two.shave, two.extend, two.cap));
    });

    test('Hot Barrel doubles the attacks only while the beam fires', () {
      final hot = holding({WingNodes.tracerRounds, WingNodes.hotBarrel});
      expect(
        wingBasicCooldownMultiplier(hasNode: hot, beamRunning: true),
        closeTo(0.5, 0.001),
      );
      expect(wingBasicCooldownMultiplier(hasNode: hot, beamRunning: false), 1);
      expect(
        wingBasicCooldownMultiplier(
          hasNode: holding({WingNodes.tracerRounds}),
          beamRunning: true,
        ),
        1,
      );
    });

    test('Loaded Beam keeps the id it was sold under', () {
      final node = FamilyMasteryCatalog.entryForNode(WingNodes.loadedBeam)!;
      expect(node.node.name, 'Loaded Beam');
      expect(node.node.id, 'wing.tracer.ranging_shots');
    });

    test('Live Feed only redirects while a beam is actually running', () {
      final owned = holding({
        WingNodes.tracerRounds,
        WingNodes.loadedBeam,
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
          hasNode: holding({WingNodes.tracerRounds, WingNodes.loadedBeam}),
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
        WingNodes.rangefinder,
        WingNodes.longLens,
        WingNodes.standoff,
        WingNodes.overwatch,
        WingNodes.tracerRounds,
        WingNodes.loadedBeam,
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
        'echo': "a repeat of the special was Horn's, and was cut as filler",
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
