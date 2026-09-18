import 'package:alchemons/games/cosmic_survival/survival_mastery_mask.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mask's tree, and the rules that do not need the game to evaluate.
///
/// The first group is the one that matters most. A Mask trap chain has already
/// brought this game to its knees once — it doubled per frame until a single
/// frame cost 2.2 seconds — and Deathmask spawns traps on kills, which is that
/// bug with a bow on it. Everything that keeps it bounded is pinned here.
void main() {
  bool Function(String) holding(Set<String> owned) => owned.contains;

  group('Deathmask cannot run away', () {
    final full = holding({
      MaskNodes.graveGoods,
      MaskNodes.openGrave,
      MaskNodes.coldGround,
      MaskNodes.necropolis,
    });

    test('a trap kill never leaves a grave, only a dart kill does', () {
      // This is the whole guard. Dart kills are bounded by attack speed;
      // a trap's kills are bounded by nothing, so a trap that spawns traps
      // doubles every frame.
      expect(
        maskGraveStrength(
          hasNode: full,
          fromAutoAttack: false,
          insideOwnTrap: true,
          gravesAlive: 0,
        ),
        0,
      );
      expect(
        maskGraveStrength(
          hasNode: full,
          fromAutoAttack: true,
          insideOwnTrap: false,
          gravesAlive: 0,
        ),
        greaterThan(0),
      );
    });

    test('the cap holds however fast the kills come', () {
      for (final alive in [
        MaskTuning.graveCap,
        MaskTuning.graveCap + 1,
        MaskTuning.graveCap * 10,
      ]) {
        expect(
          maskGraveStrength(
            hasNode: full,
            fromAutoAttack: true,
            insideOwnTrap: false,
            gravesAlive: alive,
          ),
          0,
          reason: 'placed a grave with $alive already alive',
        );
      }
    });

    test('the state refuses to track more graves than the cap', () {
      final state = MaskMasteryState();
      var placed = 0;
      for (var i = 0; i < MaskTuning.graveCap * 5; i++) {
        if (state.addGrave(i)) placed++;
      }
      expect(placed, MaskTuning.graveCap);
      expect(state.graves.length, MaskTuning.graveCap);

      // Dropping one makes room for exactly one more.
      state.dropFixture(0);
      expect(state.addGrave(9999), isTrue);
      expect(state.addGrave(10000), isFalse);
    });

    test('nothing is left without the opener', () {
      expect(
        maskGraveStrength(
          hasNode: holding({}),
          fromAutoAttack: true,
          insideOwnTrap: false,
          gravesAlive: 0,
        ),
        0,
      );
    });

    test('Necropolis only upgrades, it does not unlock', () {
      final opener = holding({MaskNodes.graveGoods});
      final capstone = holding({MaskNodes.graveGoods, MaskNodes.necropolis});

      final small = maskGraveStrength(
        hasNode: opener,
        fromAutoAttack: true,
        insideOwnTrap: true,
        gravesAlive: 0,
      );
      final full = maskGraveStrength(
        hasNode: capstone,
        fromAutoAttack: true,
        insideOwnTrap: true,
        gravesAlive: 0,
      );
      expect(small, closeTo(MaskTuning.graveStrength, 0.001));
      expect(full, greaterThan(small));

      // Outside a trap the capstone changes nothing.
      expect(
        maskGraveStrength(
          hasNode: capstone,
          fromAutoAttack: true,
          insideOwnTrap: false,
          gravesAlive: 0,
        ),
        closeTo(MaskTuning.graveStrength, 0.001),
      );
    });

    test('Open Grave widens the grave and nothing else', () {
      expect(maskGraveShape(hasNode: holding({})).scale, 1.0);
      final shape = maskGraveShape(
        hasNode: holding({MaskNodes.graveGoods, MaskNodes.openGrave}),
      );
      expect(shape.scale, greaterThan(1.0));
      expect(shape.life, greaterThan(1.0));
    });
  });

  group('Rearm stops a trap spending itself', () {
    test('a trap without the path is used up', () {
      expect(maskRearmDelay(hasNode: holding({})), 0);
    });

    test('Hair Trigger only shortens what Spring Again started', () {
      final slow = maskRearmDelay(hasNode: holding({MaskNodes.springAgain}));
      final fast = maskRearmDelay(
        hasNode: holding({MaskNodes.springAgain, MaskNodes.hairTrigger}),
      );
      expect(slow, closeTo(MaskTuning.rearmDelay, 0.001));
      expect(fast, lessThan(slow));

      // Held alone it does nothing; the opener is what re-arms.
      expect(maskRearmDelay(hasNode: holding({MaskNodes.hairTrigger})), 0);
    });

    test('Held Ground takes three triggers, and only with the node', () {
      final state = MaskMasteryState();
      var held = false;
      for (var i = 0; i < MaskTuning.heldGroundTriggers; i++) {
        held = state.noteTrigger(1, hasHeldGround: true);
      }
      expect(held, isTrue);
      expect(state.triggersOn(1), MaskTuning.heldGroundTriggers);

      final without = MaskMasteryState();
      var ever = false;
      for (var i = 0; i < 20; i++) {
        if (without.noteTrigger(1, hasHeldGround: false)) ever = true;
      }
      expect(ever, isFalse);
    });
  });

  group('Contagion cannot outlive its traps', () {
    final full = holding({
      MaskNodes.carrier,
      MaskNodes.spread,
      MaskNodes.virulence,
      MaskNodes.plague,
    });

    test('an infection stops jumping after a few generations', () {
      // Without this a dense crowd keeps re-infecting itself forever, long
      // after the trap that started it is gone.
      expect(maskInfection(hasNode: full, generation: 0).spreads, isTrue);
      expect(
        maskInfection(
          hasNode: full,
          generation: MaskTuning.maxGenerations,
        ).spreads,
        isFalse,
      );
      expect(
        maskInfection(
          hasNode: full,
          generation: MaskTuning.maxGenerations + 5,
        ).spreads,
        isFalse,
      );
    });

    test('nothing is infected without the opener', () {
      final none = maskInfection(hasNode: holding({}), generation: 0);
      expect(none.duration, 0);
      expect(none.spreads, isFalse);
      expect(none.ticks, isFalse);
      expect(none.bursts, isFalse);
    });

    test('each node turns on exactly its own part', () {
      final one = maskInfection(
        hasNode: holding({MaskNodes.carrier}),
        generation: 0,
      );
      expect(one.duration, greaterThan(0));
      expect(one.spreads, isFalse);
      expect(one.ticks, isFalse);
      expect(one.bursts, isFalse);

      final all = maskInfection(hasNode: full, generation: 0);
      expect(all.spreads, isTrue);
      expect(all.ticks, isTrue);
      expect(all.bursts, isTrue);
    });
  });

  group('the tree itself', () {
    test('every node id the game references exists in the catalog', () {
      const referenced = [
        MaskNodes.graveGoods,
        MaskNodes.openGrave,
        MaskNodes.coldGround,
        MaskNodes.necropolis,
        MaskNodes.springAgain,
        MaskNodes.hairTrigger,
        MaskNodes.snapShut,
        MaskNodes.heldGround,
        MaskNodes.carrier,
        MaskNodes.spread,
        MaskNodes.virulence,
        MaskNodes.plague,
      ];
      for (final id in referenced) {
        expect(
          FamilyMasteryCatalog.entryForNode(id),
          isNotNull,
          reason: '$id is not in the catalog',
        );
      }
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mask);
      expect({
        for (final path in tree.paths)
          for (final node in path.nodes) node.id,
      }, referenced.toSet());
    });

    test('Mask claims nothing another family already owns', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mask);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) '${node.name}: ${node.description}',
      ].join('\n').toLowerCase();

      const claimed = {
        'marked': 'Pip banks Pins and Let marks Sighted',
        'sigil': 'Pip banks Pins and Let marks Sighted',
        'every 3rd': 'Let, Pip and Mane own four every-Nth-attack nodes',
        'every 4th': 'Let, Pip and Mane own four every-Nth-attack nodes',
        'attack speed': 'Mane banks Rhythm and opens Encore',
        'pierc': "Mane is the piercing family; Mask's dart only happens to",
      };
      for (final entry in claimed.entries) {
        expect(
          copy.contains(entry.key),
          isFalse,
          reason: 'Mask tree says "${entry.key}" — ${entry.value}',
        );
      }
    });

    test('no path counts fixtures, because seven elements place one', () {
      // Light, Dark, Ice, Lightning, Blood, Plant and Mud each place exactly
      // one. A path keyed to "your many traps" is dead content for them.
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.mask);
      final copy = [
        for (final path in tree.paths)
          for (final node in path.nodes) node.description,
      ].join('\n').toLowerCase();
      expect(copy.contains('each of your traps'), isFalse);
      expect(copy.contains('all your traps'), isFalse);
      expect(copy.contains('nearest other trap'), isFalse);
    });
  });

  test('mastery is only owed the share it actually added', () {
    expect(maskUpliftFraction(100, 0), 0);
    expect(maskUpliftFraction(0, 0), 0);
    expect(maskUpliftFraction(60, 40), closeTo(0.4, 0.001));
  });
}
