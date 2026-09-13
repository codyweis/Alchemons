import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mask against its design board, element by element.
///
/// The board (memory: project-mask-specials-design) gives a universal shape
/// before it gives per-element behaviour: "scattered placements (not a single
/// projectile). Each placement is a trap or aura that activates on enemy
/// contact... Unlike Let's one big meteor or Mane's one piercing projectile,
/// Mask scatters many things."
///
/// So the family identity is the SHAPE, and the element only decides what a
/// trap does when something walks into it. Both halves are pinned here.
void main() {
  CosmicSpecialResult cast(String element) => createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: 'mask',
    element: element,
    damage: 40,
    maxHp: 120,
    casterPower: 5,
    casterBeauty: 5,
    casterIntelligence: 5,
    casterStrength: 5,
    targetPos: const Offset(120, 0),
  );

  test('every mask placement stays where it is put', () {
    // A trap that travels is not a trap. This is the one rule that separates
    // the family from Let and Mane, and it holds for all seventeen.
    for (final element in kCosmicAbilityElements) {
      final projectiles = cast(element).projectiles;
      expect(projectiles, isNotEmpty, reason: 'mask/$element places nothing');
      expect(
        projectiles.every((p) => p.stationary),
        isTrue,
        reason:
            'mask/$element throws something that travels — Mask places traps, '
            'it does not fire projectiles',
      );
    }
  });

  test('the scatters scatter and the singles stay single', () {
    // The board is specific about which elements place MANY and which place
    // exactly one, and it matters: a single blood blob that became eight would
    // be a completely different ability at the same damage.
    const scatters = {
      'Air': 3, // "3-25 (stat-based) air traps"
      'Lava': 5, // "5-15 lava pools"
      'Poison': 3, // "scatters poison clouds"
      'Earth': 2, // "2-5 earth heal pools"
      'Spirit': 3, // "scatters spirit wisps"
      'Crystal': 3, // "3-7 (stat-based) large crystals"
      'Fire': 5, // "5-15 fire balls"
      'Steam': 3, // "mini geysers around the field"
      'Water': 3, // "throws out traps"
    };
    const singles = {
      'Plant', // "places a small vine" — grows by being fed, not by count
      'Blood', // "a blood blob"
      'Light', // "a light void"
      'Lightning', // "a lightning field" — grows with each enemy that hits it
      'Dark', // "a void hole"
      'Ice', // "a giant ice pillar"
    };

    scatters.forEach((element, atLeast) {
      expect(
        cast(element).projectiles.length,
        greaterThanOrEqualTo(atLeast),
        reason: 'mask/$element stopped scattering',
      );
    });
    for (final element in singles) {
      expect(
        cast(element).projectiles.length,
        1,
        reason:
            'mask/$element places more than one — the board gives it exactly '
            'one, and the ability is built around that',
      );
    }
  });

  test('each trap does what the board says it does on contact', () {
    // tickEffect for traps that work on things standing in them, hitEffect for
    // traps that resolve the moment something touches them.
    const onTick = <String, AbilityEffectKind>{
      'Lava': AbilityEffectKind.burn, // "DoT enemies who walk through"
      'Poison': AbilityEffectKind.poison, // "DoT to enemies in them"
      'Earth': AbilityEffectKind.zoneHeal, // "heal the ship or alchemons"
      'Mud': AbilityEffectKind.slow, // "slows enemies"
      'Plant': AbilityEffectKind.root, // "attacks enemies and slows"
      'Steam': AbilityEffectKind.geyser, // "geysers that shoot at enemies"
      'Dark': AbilityEffectKind.blackHole, // "enemies that enter are yeeted"
      'Ice': AbilityEffectKind.buff, // "their strength increases"
      'Lightning': AbilityEffectKind.chain, // "field that increases in size"
    };
    const onHit = <String, AbilityEffectKind>{
      'Air': AbilityEffectKind.knockback, // "blow back enemies on contact"
      'Blood': AbilityEffectKind.leech, // "life drained to all alchemons"
      'Light': AbilityEffectKind.execute, // "instantly kills that enemy"
      'Crystal': AbilityEffectKind.split, // "breaks into 3 smaller crystals"
      'Fire': AbilityEffectKind.burn, // "creates a fire pool that DoTs"
      'Water': AbilityEffectKind.splash, // "when enemies collide, splash"
      'Spirit': AbilityEffectKind.flower, // "ship collects them"
    };

    final broken = <String>[];
    onTick.forEach((element, expected) {
      final kinds = cast(element).projectiles.map((p) => p.tickEffect).toSet();
      if (!kinds.contains(expected)) {
        broken.add('mask/$element tick: expected $expected, got $kinds');
      }
    });
    onHit.forEach((element, expected) {
      final kinds = cast(element).projectiles.map((p) => p.hitEffect).toSet();
      if (!kinds.contains(expected)) {
        broken.add('mask/$element hit: expected $expected, got $kinds');
      }
    });
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  test('Dust is the one that reads differently here than on the board', () {
    // Board: "Surrounds EACH alchemon in the field with a dust cloud that
    // shields them and damages enemies who collide" — one per ally, up to five.
    //
    // The ability table returns a single placement carrying an alchemyBonus
    // tick, and the per-ally shields are built on the survival side instead
    // (_spawnMaskDustShields). So the contract IS kept, just not here, and this
    // records where to look rather than pretending the table tells the whole
    // story.
    final dust = cast('Dust').projectiles;
    expect(dust, hasLength(1));
    expect(dust.single.stationary, isTrue);
  });
}
