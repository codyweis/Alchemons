// You are turned away at the door, not at the locked one inside.
//
// Unsealing a planet with the alchemical recipe used to be enough to descend:
// the element trio got you in, and a missing family key was something you
// discovered later, standing in front of a gate with no way through it. The
// descent now refuses a party that cannot open what is behind it.
//
// That only works if the requirement the placard shows and the requirement the
// dungeon enforces are the same requirement, which is why the demands are
// DERIVED from the authored gates rather than listed a second time by hand.
// These tests pin that they cannot come apart.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: '',
  element: element,
  family: family.toLowerCase(),
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

/// A party built from the planet's own ideal trio — element and family per
/// index-aligned slot. This is the team §4 promises clears everything.
List<CosmicPartyMember> _idealParty(String element) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  return [for (var i = 0; i < els.length; i++) _m(els[i], fams[i])];
}

void main() {
  group('the demands are derived from the gates, never re-listed', () {
    test('every declared gate produces exactly one demand', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        final keys = layout.familyGates
            .map((g) => '${g.element}/${g.family}')
            .toSet();
        expect(
          dungeonEntryDemands(element).length,
          keys.length,
          reason: '$element: one demand per distinct gate key',
        );
      });
    });

    test('a demand names an element only when its gate does', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final d in dungeonEntryDemands(element)) {
          final gate = layout.familyGates.firstWhere(
            (g) => g.family == d.family,
          );
          expect(
            d.element,
            gate.needsElement ? gate.element : isNull,
            reason: '$element/${d.family}',
          );
        }
      });
    });

    test('a planet with no gates demands nothing extra', () {
      // Fire, Lightning and Steam are element-only planets; the descent must
      // not invent a family requirement they never authored.
      for (final element in ['Fire', 'Lightning', 'Steam']) {
        expect(kPlanetDungeonLayouts[element]!.familyGates, isEmpty);
        expect(dungeonEntryDemands(element), isEmpty, reason: element);
      }
    });
  });

  group('the ideal trio can always descend', () {
    test('every planet: its own ideal trio meets every demand', () {
      // The §4 contract. If this fails, a planet is authored so that the team
      // the game itself recommends cannot get in.
      for (final element in kPlanetDungeonLayouts.keys) {
        expect(
          unmetEntryDemands(element, _idealParty(element)),
          isEmpty,
          reason: '$element: the ideal trio cannot satisfy its own gates',
        );
      }
    });
  });

  group('a party that cannot open a gate is refused', () {
    test('right elements, wrong families — turned away', () {
      // The exact case the change exists for: the element multiset passes, so
      // the old check let this party descend into gates it could never open.
      for (final element in kPlanetDungeonLayouts.keys) {
        final demands = dungeonEntryDemands(element);
        if (demands.isEmpty) continue;
        final els = kCosmicPlanetEntry[element]!;
        // 'let' is not a gate family anywhere in the game.
        final wrong = [for (final e in els) _m(e, 'let')];
        expect(
          cosmicPartySatisfiesEntry(wrong, els),
          isTrue,
          reason: '$element: elements alone should still pass',
        );
        expect(
          unmetEntryDemands(element, wrong).length,
          demands.length,
          reason: '$element: every gate should be unmet',
        );
      }
    });

    test('a verb-only gate accepts the family from ANY element', () {
      // Dust's armillary and rite are both verb-only. A party carrying the
      // right families on entirely the wrong elements still clears them.
      final demands = dungeonEntryDemands('Dust');
      expect(demands, isNotEmpty);
      expect(
        demands.every((d) => d.element == null),
        isTrue,
        reason: 'both Dust gates were re-audited to verb-only',
      );
      final oddballs = [_m('Blood', 'wing'), _m('Plant', 'horn')];
      expect(unmetEntryDemands('Dust', oddballs), isEmpty);
    });

    test('an element+family gate is not fooled by the family alone', () {
      // Plant's altar sun is Light+MASK. A Mask of the wrong element must not
      // satisfy it, or the distinction the audit drew would be meaningless.
      final demands = dungeonEntryDemands('Plant');
      final sun = demands.firstWhere((d) => d.family == 'Mask');
      expect(sun.element, 'Light');
      expect(sun.satisfiedBy([_m('Mud', 'mask')]), isFalse);
      expect(sun.satisfiedBy([_m('Light', 'mask')]), isTrue);
    });

    test('an unmet demand can name itself on the placard', () {
      // The label is what the player reads instead of walking into the gate.
      for (final element in kPlanetDungeonLayouts.keys) {
        for (final d in dungeonEntryDemands(element)) {
          expect(d.label, isNotEmpty, reason: element);
          expect(
            d.label.startsWith('any ') || d.label.contains(' '),
            isTrue,
            reason:
                '$element: "${d.label}" should read as element + FAMILY '
                'or "any FAMILY"',
          );
        }
      }
    });
  });

  group('verb-only gates stamp a readable id', () {
    test('no gate stamps an id with an empty element in it', () {
      // 'gate:_wing' would be the naive result of dropping the element.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final g in layout.familyGates) {
          expect(g.discoveryId, isNot(contains(':_')), reason: element);
          expect(
            g.discoveryId,
            g.needsElement
                ? 'gate:${g.element.toLowerCase()}_${g.family.toLowerCase()}'
                : 'gate:any_${g.family.toLowerCase()}',
          );
        }
      });
    });

    test('kAnyElement never reaches an interaction as a real element', () {
      // evaluateInteraction must treat it as "no element requirement", not as
      // an element named "" that nothing can ever match.
      const req = DungeonInteractionRequirement(
        element: kAnyElement,
        requiredFamily: DungeonAbility.heavyForce,
      );
      expect(req.isFamilyOnly, isTrue);
      expect(req.isElementAndFamily, isFalse);
      expect(
        evaluateInteraction(_m('Blood', 'horn'), req),
        InteractionResult.passed,
      );
      expect(
        evaluateInteraction(_m('Blood', 'wing'), req),
        InteractionResult.blockedFamily,
      );
    });
  });
}
