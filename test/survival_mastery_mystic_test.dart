import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mystic's tree, and the rules that do not need the game to evaluate.
void main() {
  bool Function(String) holding(Set<String> owned) => owned.contains;

  group('Every family has two paths', () {
    test('Mystic holds two, four nodes each', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mystic);
      expect(tree.paths, hasLength(2));
      for (final path in tree.paths) {
        expect(path.nodes, hasLength(4));
      }
    });

    test('Wing and Kin are down to two as well', () {
      for (final family in [CreatureFamily.wing, CreatureFamily.kin]) {
        expect(
          FamilyMasteryCatalog.treeFor(family).paths,
          hasLength(2),
          reason: family.name,
        );
      }
    });
  });

  group('Quickening drives the world\'s acts', () {
    test('Quickening is the opener, and it gives Ice its act', () {
      expect(mysticQuickens(hasNode: holding({})), isFalse);
      expect(
        mysticQuickens(hasNode: holding({MysticNodes.quickening})),
        isTrue,
      );
      expect(mysticIceActs(hasNode: holding({})), isFalse);
      expect(mysticIceActs(hasNode: holding({MysticNodes.nativeAir})), isFalse);
      expect(
        mysticIceActs(hasNode: holding({MysticNodes.quickening})),
        isTrue,
      );
    });

    test('an act readies one repeat, and the next death calls for it', () {
      final state = MysticMasteryState();
      final landed = <double>[];
      // A death before the world has acted calls for nothing.
      state.noteDeath();
      expect(state.takeQuickening(), isNull);

      state.noteAct(landed.add);
      expect(state.takeQuickening(), isNull, reason: 'nobody has died yet');
      state.noteDeath();
      state.noteDeath();
      state.takeQuickening()?.call(MysticTuning.quickenStrength);
      expect(landed, [MysticTuning.quickenStrength]);
      expect(state.quickenings, 1);

      // However many more die, nothing more until it acts again.
      state.noteDeath();
      expect(state.takeQuickening(), isNull);
      state.noteAct(landed.add);
      state.noteDeath();
      expect(state.takeQuickening(), isNotNull);
      expect(state.quickenings, 2);
    });

    test('the repeat is the latest act', () {
      final state = MysticMasteryState();
      final which = <String>[];
      state.noteAct((_) => which.add('first'));
      state.noteAct((_) => which.add('second'));
      state.noteDeath();
      state.takeQuickening()?.call(1);
      expect(which, ['second']);
    });

    test('Aftershock and Relentless Sky each repeat an act once', () {
      expect(mysticWorldReplays(hasNode: holding({})), isEmpty);
      final after = mysticWorldReplays(
        hasNode: holding({MysticNodes.aftershock}),
      );
      expect(after, hasLength(1));
      expect(after.single.delay, MysticTuning.aftershockDelay);
      expect(after.single.strength, MysticTuning.aftershockStrength);
      final both = mysticWorldReplays(
        hasNode: holding({MysticNodes.aftershock, MysticNodes.relentlessSky}),
      );
      expect(both, hasLength(2));
      // Relentless Sky's comes first and whole.
      expect(both.first.strength, 1.0);
      expect(both.first.delay, lessThan(both.last.delay));
    });

    test('First Light turns on exactly its own part', () {
      expect(mysticActsOnIgnition(hasNode: holding({})), isFalse);
      expect(
        mysticActsOnIgnition(hasNode: holding({MysticNodes.firstLight})),
        isTrue,
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
        MysticNodes.aftershock,
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
