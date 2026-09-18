import 'package:alchemons/games/cosmic_survival/survival_mastery_horn.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Horn's tree, and the rules that do not need the game to evaluate.
///
/// The draft this replaced spent six of twelve nodes on mechanics its own
/// elements already owned — knockback (Air, Steam), blocking enemy shots
/// (Crystal, Ice, Light), armor cracking (Dark) and stagger (Earth) — and its
/// third path was Mane's War Rhythm down to the numbers. The first test here
/// is the one that would have caught that.
void main() {
  bool Function(String) holding(Set<String> owned) => owned.contains;

  group('the tree itself', () {
    test('every node id the game references exists in the catalog', () {
      const referenced = [
        HornNodes.ironhead,
        HornNodes.weightBehindIt,
        HornNodes.braced,
        HornNodes.anvil,
        HornNodes.guardedShot,
        HornNodes.bodyguard,
        HornNodes.shieldWall,
        HornNodes.lastStand,
        HornNodes.secondEffort,
        HornNodes.fullWeight,
        HornNodes.relentless,
        HornNodes.secondFront,
      ];
      for (final id in referenced) {
        expect(
          FamilyMasteryCatalog.entryForNode(id),
          isNotNull,
          reason: '$id is not in the catalog',
        );
      }

      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.horn);
      final catalogued = {
        for (final path in tree.paths)
          for (final node in path.nodes) node.id,
      };
      expect(catalogued, referenced.toSet());
    });

    test('Horn claims no mechanic one of its own elements already owns', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.horn);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) '${node.name}: ${node.description}',
      ].join('\n').toLowerCase();

      // Each of these belongs to an element, and a path built on it would
      // erase the one Horn it belonged to.
      const claimed = {
        'knock': 'Air pushes enemies as its entire passive; Steam pushes too',
        'push': 'Air pushes enemies as its entire passive',
        'stagger': 'Earth owns stagger in the payload table',
        'blocks the next': 'Crystal shards, Ice walls and Light barriers all '
            'already intercept enemy shots',
      };
      for (final entry in claimed.entries) {
        expect(
          copy.contains(entry.key),
          isFalse,
          reason: 'Horn tree says "${entry.key}" — ${entry.value}',
        );
      }
    });

    test('no path is a stacking counter, which is Mane\'s', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.horn);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) node.description,
      ].join('\n').toLowerCase();
      // The draft's third path was War Rhythm renamed: a named resource that
      // builds on hits, pays a per-stack bonus, and is spent on the special.
      // A shield that "stacks up to 6%" is not that, so the check is for the
      // shape of the mechanic rather than the word.
      expect(copy.contains('momentum'), isFalse);
      expect(copy.contains('each momentum'), isFalse);
      expect(copy.contains('per stack'), isFalse);
      expect(copy.contains('spends'), isFalse, reason: 'Mane spends Rhythm');
      expect(copy.contains('builds'), isFalse, reason: 'Mane builds Rhythm');
    });
  });

  group('Bulwark turns bulk into damage', () {
    test('nothing without the opener', () {
      expect(
        hornBulwarkBonus(
          hasNode: holding({}),
          maxHp: 1000,
          currentHp: 1000,
          isSpecial: false,
        ),
        0,
      );
    });

    test('an auto-attack carries a share of maximum HP', () {
      expect(
        hornBulwarkBonus(
          hasNode: holding({HornNodes.ironhead}),
          maxHp: 1000,
          currentHp: 1000,
          isSpecial: false,
        ),
        closeTo(25, 0.001),
      );
    });

    test('the special carries nothing until the second node', () {
      final one = holding({HornNodes.ironhead});
      expect(
        hornBulwarkBonus(
          hasNode: one,
          maxHp: 1000,
          currentHp: 1000,
          isSpecial: true,
        ),
        0,
      );

      final two = holding({HornNodes.ironhead, HornNodes.weightBehindIt});
      expect(
        hornBulwarkBonus(
          hasNode: two,
          maxHp: 1000,
          currentHp: 1000,
          isSpecial: true,
        ),
        closeTo(15, 0.001),
      );
    });

    test('Braced rides current health, and never divides by a dead body', () {
      final owned = holding({HornNodes.ironhead, HornNodes.braced});
      double at(double hp, {double maxHp = 1000}) => hornBulwarkBonus(
        hasNode: owned,
        maxHp: maxHp,
        currentHp: hp,
        isSpecial: false,
      );

      expect(at(1000), closeTo(25 * 1.5, 0.001));
      expect(at(0), closeTo(25 * 0.5, 0.001));
      expect(at(500), closeTo(25 * 1.0, 0.001));
      expect(at(400), lessThan(at(900)));
      // A zero-HP chassis must not produce NaN.
      expect(at(0, maxHp: 0), 0);
    });
  });

  group('Bastion takes the hits', () {
    test('the shield banks per shot toward a ceiling', () {
      final none = hornGuardShield(hasNode: holding({}), maxHp: 1000);
      expect(none.perShot, 0);

      final held = hornGuardShield(
        hasNode: holding({HornNodes.guardedShot}),
        maxHp: 1000,
      );
      expect(held.perShot, closeTo(15, 0.001));
      expect(held.cap, closeTo(60, 0.001));
      expect(held.cap / held.perShot, closeTo(4, 0.001));
    });

    test('Bodyguard leaves the team ahead, not merely moves the damage', () {
      final split = hornBodyguardSplit(
        hasNode: holding({HornNodes.bodyguard}),
        incoming: 100,
        distanceToOrb: 100,
      );
      expect(split.toOrb, closeTo(75, 0.001));
      expect(split.toHorn, closeTo(15, 0.001));
      expect(
        split.toOrb + split.toHorn,
        lessThan(100),
        reason: 'a tank that only relocates damage is not worth a path',
      );
    });

    test('it only pays while the Horn is actually standing between', () {
      final far = hornBodyguardSplit(
        hasNode: holding({HornNodes.bodyguard}),
        incoming: 100,
        distanceToOrb: HornTuning.bodyguardRange + 1,
      );
      expect(far.toOrb, 100);
      expect(far.toHorn, 0);
    });

    test('an unheld path changes nothing', () {
      final split = hornBodyguardSplit(
        hasNode: holding({}),
        incoming: 100,
        distanceToOrb: 0,
      );
      expect(split.toOrb, 100);
      expect(split.toHorn, 0);
    });
  });

  group('Juggernaut runs the cast twice', () {
    test('nothing is pending without the opener', () {
      expect(hornSecondRun(hasNode: holding({})).power, 0);
    });

    test('Relentless makes the second run the strong one', () {
      final weak = hornSecondRun(hasNode: holding({HornNodes.secondEffort}));
      final strong = hornSecondRun(
        hasNode: holding({HornNodes.secondEffort, HornNodes.relentless}),
      );
      expect(weak.power, closeTo(0.45, 0.001));
      expect(strong.power, greaterThan(weak.power));
      expect(weak.coverage, 1.0);
    });

    test('Second Front widens only the second run', () {
      final wide = hornSecondRun(
        hasNode: holding({HornNodes.secondEffort, HornNodes.secondFront}),
      );
      expect(wide.coverage, closeTo(1.40, 0.001));
    });

    test('a second run cannot arm a third', () {
      final state = HornMasteryState();
      expect(state.armSecondRun(), isTrue);
      expect(
        state.armSecondRun(),
        isFalse,
        reason: 'this is the one place the path could recurse',
      );

      // Tick it out; it fires exactly once.
      var fired = 0;
      for (var i = 0; i < 120; i++) {
        if (state.takeSecondRun(1 / 60)) fired++;
      }
      expect(fired, 1);
    });

    test('a passive Horn pulses instead, and faster with Relentless', () {
      int pulses({required bool relentless}) {
        final state = HornMasteryState();
        var n = 0;
        for (var i = 0; i < 60 * 30; i++) {
          if (state.takePassivePulse(1 / 60, relentless: relentless)) n++;
        }
        return n;
      }

      final plain = pulses(relentless: false);
      expect(plain, greaterThan(0));
      expect(pulses(relentless: true), greaterThan(plain));
    });
  });

  test('mastery is only owed the share it actually added', () {
    expect(hornUpliftFraction(100, 0), 0);
    expect(hornUpliftFraction(0, 0), 0);
    expect(hornUpliftFraction(75, 25), closeTo(0.25, 0.001));
  });
}
