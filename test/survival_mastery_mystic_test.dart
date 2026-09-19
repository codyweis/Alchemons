import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mystic's tree, and the rules that do not need the game to evaluate.
void main() {
  bool Function(String) holding(Set<String> owned) => owned.contains;

  group('Mystic is the one family with two paths', () {
    test('the catalog holds two, and the validator accepts them', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mystic);
      expect(tree.paths, hasLength(2));
      for (final path in tree.paths) {
        expect(path.nodes, hasLength(4));
      }
      // Whatever validation the catalog runs must still pass with two.
      expect(FamilyMasteryCatalog.validate(), isEmpty);
    });

    test('every other family still has three', () {
      for (final family in CreatureFamily.values) {
        if (family == CreatureFamily.mystic) continue;
        expect(
          FamilyMasteryCatalog.treeFor(family).paths,
          hasLength(3),
          reason: family.name,
        );
      }
    });
  });

  group('Quickening drives the world faster', () {
    test('an unequipped world keeps the interval it was authored with', () {
      expect(
        mysticWorldInterval(hasNode: holding({}), authoredInterval: 4.0),
        4.0,
      );
    });

    test('the opener speeds it up and the capstone more so', () {
      final quick = mysticWorldInterval(
        hasNode: holding({MysticNodes.quickening}),
        authoredInterval: 4.0,
      );
      final relentless = mysticWorldInterval(
        hasNode: holding({MysticNodes.quickening, MysticNodes.relentlessSky}),
        authoredInterval: 4.0,
      );
      expect(quick, closeTo(4.0 / MysticTuning.quickeningRate, 0.001));
      expect(relentless, lessThan(quick));
      // The capstone is stated against where the world started, so it
      // replaces the opener's rate rather than compounding with it.
      expect(relentless, closeTo(4.0 / MysticTuning.relentlessRate, 0.001));
    });

    test('no stacking can drive a world to act every frame', () {
      // A world acting every frame is not a faster world, it is a frame-time
      // bug with a nice name.
      for (final authored in [0.5, 0.4, 0.2, 0.05]) {
        final driven = mysticWorldInterval(
          hasNode: holding({
            MysticNodes.quickening,
            MysticNodes.relentlessSky,
          }),
          authoredInterval: authored,
        );
        expect(driven, greaterThanOrEqualTo(
          authored < MysticTuning.minimumInterval
              ? authored
              : MysticTuning.minimumInterval,
        ));
        expect(driven, lessThanOrEqualTo(authored));
      }
    });

    test('a world with no clock is left alone', () {
      expect(
        mysticWorldInterval(
          hasNode: holding({MysticNodes.relentlessSky}),
          authoredInterval: 0,
        ),
        0,
      );
    });

    test('the other two nodes turn on exactly their own part', () {
      expect(mysticActsOnIgnition(hasNode: holding({})), isFalse);
      expect(
        mysticActsOnIgnition(hasNode: holding({MysticNodes.firstLight})),
        isTrue,
      );
      expect(mysticWorldPower(hasNode: holding({})), 1.0);
      expect(
        mysticWorldPower(hasNode: holding({MysticNodes.weightOfHeaven})),
        closeTo(MysticTuning.weightOfHeaven, 0.001),
      );
    });
  });

  group('Firmament shelters whoever stands inside', () {
    test('nothing without the opener', () {
      final none = mysticFirmament(hasNode: holding({}));
      expect(none.mitigation, 1.0);
      expect(none.power, 1.0);
      expect(none.mends, isFalse);
      expect(none.lendsElement, isFalse);
    });

    test('each node turns on exactly its own part', () {
      final one = mysticFirmament(hasNode: holding({MysticNodes.nativeAir}));
      expect(one.mitigation, lessThan(1.0));
      expect(one.power, 1.0);

      final all = mysticFirmament(
        hasNode: holding({
          MysticNodes.nativeAir,
          MysticNodes.homeGround,
          MysticNodes.tended,
          MysticNodes.sanctum,
        }),
      );
      expect(all.power, greaterThan(1.0));
      expect(all.mends, isTrue);
      expect(all.lendsElement, isTrue);
    });

    test('the mend pays on its own clock, not every frame', () {
      final state = MysticMasteryState();
      var paid = 0;
      for (var i = 0; i < 60 * 10; i++) {
        if (state.takeTendedTick(1 / 60)) paid++;
      }
      expect(paid, closeTo(10 / MysticTuning.tendedInterval, 1));
    });
  });

  group('the tree itself', () {
    test('every node id the game references exists in the catalog', () {
      const referenced = [
        MysticNodes.quickening,
        MysticNodes.firstLight,
        MysticNodes.weightOfHeaven,
        MysticNodes.relentlessSky,
        MysticNodes.nativeAir,
        MysticNodes.homeGround,
        MysticNodes.tended,
        MysticNodes.sanctum,
      ];
      for (final id in referenced) {
        expect(
          FamilyMasteryCatalog.entryForNode(id),
          isNotNull,
          reason: '$id is not in the catalog',
        );
      }
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mystic);
      expect({
        for (final path in tree.paths)
          for (final node in path.nodes) node.id,
      }, referenced.toSet());
    });

    test('Mystic claims nothing five other families already own', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mystic);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) '${node.name}: ${node.description}',
      ].join('\n').toLowerCase();

      const claimed = {
        'insight': "War Rhythm, for the fifth family running",
        'stack': 'Mane banks Rhythm',
        'every 3rd': 'Let, Pip and Mane own four every-Nth nodes',
        'every 4th': 'Let, Pip and Mane own four every-Nth nodes',
        'every 5th': 'Let, Pip and Mane own four every-Nth nodes',
        'marked': "Pip banks Pins and Let marks Sighted",
        'seed': 'Mask places the things that sit and pulse',
        'all 3 bolts': "Mane's Crosscut and Wing's Double Tap",
      };
      for (final entry in claimed.entries) {
        expect(
          copy.contains(entry.key),
          isFalse,
          reason: 'Mystic tree says "${entry.key}" — ${entry.value}',
        );
      }
    });
  });

  test('mastery is only owed the share it actually added', () {
    expect(mysticUpliftFraction(1.0), 0);
    expect(mysticUpliftFraction(1.3), closeTo(0.2308, 0.001));
  });
}
