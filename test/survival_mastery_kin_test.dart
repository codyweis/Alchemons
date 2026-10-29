import 'package:alchemons/games/cosmic_survival/survival_mastery_kin.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kin's tree, and the rules that do not need the game to evaluate.
void main() {
  bool Function(String) holding(Set<String> owned) => owned.contains;

  group('Conduction carries help down the same line', () {
    test('nothing without the opener', () {
      final none = kinConduction(
        hasNode: holding({}),
        laserDamage: 500,
        allyMaxHp: 1000,
        allyHealthFraction: 1.0,
      );
      expect(none.shield, 0);
      expect(none.heal, 0);
    });

    test('a healthy ally is shielded, a hurt one is healed', () {
      final owned = holding({KinNodes.liveCurrent, KinNodes.lifeline});
      final healthy = kinConduction(
        hasNode: owned,
        laserDamage: 200,
        allyMaxHp: 10000,
        allyHealthFraction: 1.0,
      );
      expect(healthy.shield, greaterThan(0));
      expect(healthy.heal, 0);

      final hurt = kinConduction(
        hasNode: owned,
        laserDamage: 200,
        allyMaxHp: 10000,
        allyHealthFraction: 0.2,
      );
      expect(hurt.heal, greaterThan(healthy.shield));
      expect(hurt.shield, 0);
    });

    test('without Lifeline a hurt ally still only gets a shield', () {
      final opener = holding({KinNodes.liveCurrent});
      final hurt = kinConduction(
        hasNode: opener,
        laserDamage: 200,
        allyMaxHp: 10000,
        allyHealthFraction: 0.1,
      );
      expect(hurt.shield, greaterThan(0));
      expect(hurt.heal, 0);
    });

    test('one enormous shot cannot hand over a whole health bar', () {
      final owned = holding({KinNodes.liveCurrent});
      final huge = kinConduction(
        hasNode: owned,
        laserDamage: 999999,
        allyMaxHp: 1000,
        allyHealthFraction: 1.0,
      );
      expect(
        huge.shield,
        closeTo(1000 * KinTuning.conductionShieldCapFraction, 0.001),
      );
    });

    test('Transfusion is worth more and reaches off the line', () {
      final plain = kinConduction(
        hasNode: holding({KinNodes.liveCurrent}),
        laserDamage: 200,
        allyMaxHp: 100000,
        allyHealthFraction: 1.0,
      );
      final full = kinConduction(
        hasNode: holding({KinNodes.liveCurrent, KinNodes.transfusion}),
        laserDamage: 200,
        allyMaxHp: 100000,
        allyHealthFraction: 1.0,
      );
      expect(plain.radius, 0);
      expect(full.radius, greaterThan(0));
      expect(full.shield, greaterThan(plain.shield));
    });
  });

  group('Benediction carries the support to the team', () {
    test('an unequipped Kin changes nothing', () {
      final none = kinBenediction(hasNode: holding({}));
      expect(none.kindred, isFalse);
      expect(none.vigil, isFalse);
      expect(none.survivesDeath, isFalse);
      expect(none.allyRange, 0);
    });

    test('each node turns on exactly its own part', () {
      final kindred = kinBenediction(hasNode: holding({KinNodes.kindred}));
      expect(kindred.kindred, isTrue);
      expect(kindred.vigil, isFalse);
      expect(
        kinBenediction(hasNode: holding({KinNodes.vigil})).vigil,
        isTrue,
      );
      expect(
        kinBenediction(hasNode: holding({KinNodes.unbroken})).survivesDeath,
        isTrue,
      );
      expect(
        kinBenediction(hasNode: holding({KinNodes.communion})).allyRange,
        greaterThan(0),
      );
    });

    test('Vigil doubles the recharge only while an ally is below half', () {
      final vigil = holding({KinNodes.vigil});
      expect(kinVigilRate(hasNode: vigil, lowestAllyHealth: 0.49), 2.0);
      expect(kinVigilRate(hasNode: vigil, lowestAllyHealth: 0.5), 1.0);
      expect(kinVigilRate(hasNode: vigil, lowestAllyHealth: 1.0), 1.0);
      expect(kinVigilRate(hasNode: holding({}), lowestAllyHealth: 0.1), 1.0);
    });
  });

  group('the tree itself', () {
    test('every node id the game references exists in the catalog', () {
      const referenced = [
        KinNodes.liveCurrent,
        KinNodes.lifeline,
        KinNodes.grounding,
        KinNodes.transfusion,
        KinNodes.kindred,
        KinNodes.vigil,
        KinNodes.unbroken,
        KinNodes.communion,
      ];
      for (final id in referenced) {
        expect(
          FamilyMasteryCatalog.entryForNode(id),
          isNotNull,
          reason: '$id is not in the catalog',
        );
      }
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.kin);
      expect({
        for (final path in tree.paths)
          for (final node in path.nodes) node.id,
      }, referenced.toSet());
    });

    test('Kin claims nothing another family or its own elements own', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.kin);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) '${node.name}: ${node.description}',
      ].join('\n').toLowerCase();

      const claimed = {
        'marks': 'Pip banks Pins and Let marks Sighted',
        'chain': "Kin/Lightning's tesla charge is what chains",
        'attack speed': "Kin/Steam's boiler is the attack-speed buff",
        'every 4th': 'Let, Pip and Mane own four every-Nth nodes',
        'stack': 'Mane banks Rhythm',
      };
      for (final entry in claimed.entries) {
        expect(
          copy.contains(entry.key),
          isFalse,
          reason: 'Kin tree says "${entry.key}" — ${entry.value}',
        );
      }
    });

    test('the Rare Support family still supports', () {
      // The draft's first path turned Kin into a damage dealer, which is the
      // one thing its design board explicitly did not want. At least one path
      // has to be about helping the team.
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.kin);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) node.description,
      ].join('\n').toLowerCase();
      expect(
        copy.contains('shield') ||
            copy.contains('heal') ||
            copy.contains('all'),
        isTrue,
      );
    });
  });

  test('mastery is only owed the share it actually added', () {
    expect(kinUpliftFraction(1.0), 0);
    expect(kinUpliftFraction(1.4), closeTo(0.2857, 0.001));
  });
}
