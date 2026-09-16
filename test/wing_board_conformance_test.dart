import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wing against its design board, element by element.
///
/// The board (memory: project-wing-specials-design) is the contract: "Wing
/// family theme: Beams. All Wing specials shoot a laser. The element layers a
/// targeting or effect behaviour on top... do NOT change what the targeting/
/// effect contract is."
///
/// Prose in a memory file cannot stop code drifting away from it. This turns
/// the contract into assertions, so a change that quietly redefines an element
/// fails here instead of being discovered in a balance pass months later.
///
/// What this CAN check is the effect contract. What it cannot check is
/// presentation and feel — that a Lava scar looks like a scar on the ground,
/// or that Fire's sweep reads as sweeping. Those still need eyes.
void main() {
  CosmicSpecialResult cast(String element) => createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: 'wing',
    element: element,
    damage: 40,
    maxHp: 120,
    casterPower: 5,
    casterBeauty: 5,
    casterIntelligence: 5,
    casterStrength: 5,
    targetPos: const Offset(120, 0),
  );

  /// The board's promise for each element, as the effect that has to be on the
  /// beam for that promise to be kept.
  const contract = <String, AbilityEffectKind>{
    // "blows back enemies hit by the beam"
    'Air': AbilityEffectKind.knockback,
    // "surrounds enemy with dust; disorients them"
    'Dust': AbilityEffectKind.suppressShooting,
    // "leaves a glowing scar; enemies passing through take damage"
    'Lava': AbilityEffectKind.burn,
    // "shoots laser all around creating a poison ring"
    'Poison': AbilityEffectKind.poison,
    // "locks onto the lowest-health enemy and executes"
    'Blood': AbilityEffectKind.execute,
    // "if the beam kills, it refracts into two smaller beams"
    'Light': AbilityEffectKind.refraction,
    // "laser damage heals the orb"
    'Crystal': AbilityEffectKind.leech,
    // "targets lowest-health ally or ship and heals"
    'Water': AbilityEffectKind.leech,
    // "charges for a duration, then unleashes one big blast"
    'Lightning': AbilityEffectKind.chargeBlast,
    // "kills first enemy it touches and creates 5-10 steam clouds"
    'Steam': AbilityEffectKind.geyser,
    // "beam builds frost; if held long enough enemies freeze"
    'Ice': AbilityEffectKind.slow,
    // "permanently slows enemies the beam touches"
    'Mud': AbilityEffectKind.slow,
    // "enemies killed turn into flowers"
    'Plant': AbilityEffectKind.flower,
  };

  test('every wing beam carries the effect its board promises', () {
    final broken = <String>[];
    contract.forEach((element, expected) {
      final beams = cast(element).beams;
      if (beams.isEmpty) {
        broken.add('$element: casts no beam at all');
        return;
      }
      final kinds = beams.map((b) => b.tickEffect).toSet();
      if (!kinds.contains(expected)) {
        broken.add('$element: expected $expected, beam carries $kinds');
      }
    });
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  test('every wing element actually fires a beam', () {
    // The one thing true of the whole family, and the thing that would make an
    // element stop being a Wing at all.
    for (final element in kCosmicAbilityElements) {
      expect(
        cast(element).beams,
        isNotEmpty,
        reason: 'wing/$element fires no beam — the family theme IS beams',
      );
    }
  });

  test(
    'Dark is the passive one, and pays for it by carrying no beam effect',
    () {
      // "PASSIVE — dark wing pulses its laser; both the laser and the dark
      // wing's auto-attacks fire twice as fast."
      //
      // The rate itself lives in CosmicSurvivalGame as a 0.5 cooldown
      // multiplier on both the basic and the special. What belongs here is the
      // other half of that bargain: Dark buys its rate by having no rider on the
      // beam, and if one is ever added it is silently the strongest wing twice
      // over — which is exactly how it measured before anyone looked.
      final kinds = cast('Dark').beams.map((b) => b.tickEffect).toSet();
      expect(
        kinds.every((k) => k == AbilityEffectKind.none),
        isTrue,
        reason:
            'wing/Dark gained a beam effect on top of its doubled fire rate: '
            '$kinds',
      );
    },
  );

  test('Earth co-fires from the orb and Spirit tethers to the ship', () {
    // Both of these were reported as unimplemented in the first pass of this
    // audit, and only one of them was.
    //
    // Earth's orb co-fire was there all along — keyed off the beam ELEMENT
    // inside _activateWingBeamEffects with an anchorToOrb flag, which the
    // grep that went looking for it ("orbBeam", "Earth.*orb") could never have
    // matched. A search that finds nothing is not the same as a thing that is
    // not there.
    //
    // Spirit's ship tether genuinely was missing and is built now: the beam
    // anchors to the ship, which then fires at whatever is nearest. The two
    // differ in the way that matters — the orb never moves, so Earth is a
    // fixed second line, where Spirit turns the thing the player steers into
    // the weapon.
    //
    // Neither is visible in the ability table, which is why this checks the
    // descriptors that survival keys off rather than the returned result.
    expect(
      cast('Earth').beams,
      isNotEmpty,
      reason: 'Earth casts no beam for the orb to mirror',
    );
    expect(
      cast('Spirit').beams,
      isNotEmpty,
      reason: 'Spirit casts no beam for the ship to tether to',
    );
    expect(
      cast('Earth').beams.every((b) => b.element == 'Earth'),
      isTrue,
      reason:
          'the orb co-fire is dispatched on beam.element — if that stops being '
          '"Earth" the second beam silently disappears',
    );
    expect(
      cast('Spirit').beams.every((b) => b.element == 'Spirit'),
      isTrue,
      reason:
          'the ship tether is dispatched on beam.element — if that stops being '
          '"Spirit" the tether silently disappears',
    );
  });
}
