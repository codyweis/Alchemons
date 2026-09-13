import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Horn against its design board, element by element.
///
/// The board (memory: project-horn-specials-design) is unusually specific:
/// Horn is a Bulky Defense Tank whose CAST PATTERN varies by element — heavy
/// charge, wind-up dash, always-on passive, or stationary channel — and it says
/// outright: "do NOT change what the structural pattern is without flagging
/// it". That makes the pattern the part worth pinning down, because it is the
/// thing a well-meaning tuning pass is most likely to erase by accident.
///
/// Damage and visuals are deliberately not asserted here. Those are meant to
/// move.
void main() {
  CosmicSpecialResult cast(String element) => createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: 'horn',
    element: element,
    damage: 40,
    maxHp: 120,
    casterPower: 5,
    casterBeauty: 5,
    casterIntelligence: 5,
    casterStrength: 5,
    targetPos: const Offset(120, 0),
  );

  // "PASSIVE" on the board means exactly that: the cast itself does not ram.
  //   Mud  — drops slowing sludge wherever the horn moves.
  //   Air  — pushes nearby enemies radially outward, always.
  const passives = {'Mud', 'Air'};

  // "NO ram. Stops moving and channels a stationary light barrier for ~5s."
  const channels = {'Light'};

  // Elements the board gives an explicit wind-up before the dash.
  //   Crystal 1.2s gathering shards, Spirit 2.0s phasing, Dark 5.0s void-suck.
  const windUps = {'Crystal': 1.2, 'Spirit': 2.0, 'Dark': 5.0};

  test('the passives do not charge', () {
    for (final element in passives) {
      expect(
        cast(element).chargeTimer,
        0,
        reason:
            'horn/$element is a PASSIVE on the board and has grown a charge — '
            'that is a structural change, not a tuning one',
      );
    }
  });

  test('Light channels instead of ramming', () {
    // The one Horn that does not move at all. Its value is the barrier: it
    // reflects projectiles, bounces enemies off the perimeter, and cuts ally
    // damage inside by 70%.
    expect(
      cast('Light').chargeTimer,
      0,
      reason: 'horn/Light rams now — the board says NO ram, it channels',
    );
    expect(
      cast('Light').shieldHp,
      greaterThan(0),
      reason: 'horn/Light channels nothing — the barrier IS the ability',
    );
  });

  test('every other element charges', () {
    for (final element in kCosmicAbilityElements) {
      if (passives.contains(element) || channels.contains(element)) continue;
      expect(
        cast(element).chargeTimer,
        greaterThan(0),
        reason:
            'horn/$element stopped charging — Horn is a tank that closes '
            'distance, and an element that does not is a different family',
      );
    }
  });

  test('the wind-up elements wind up, and the rest do not', () {
    windUps.forEach((element, expected) {
      expect(
        cast(element).windUpTime,
        greaterThan(0),
        reason: 'horn/$element lost its wind-up',
      );
    });
    for (final element in kCosmicAbilityElements) {
      if (windUps.containsKey(element)) continue;
      if (passives.contains(element) || channels.contains(element)) continue;
      expect(
        cast(element).windUpTime,
        0,
        reason:
            'horn/$element gained a wind-up it is not supposed to have — the '
            'board gives wind-ups to Crystal, Spirit and Dark only',
      );
    }
  });

  test('Dark winds up longest, because its wind-up IS the ability', () {
    // 5s of dragging everything within 260px toward the horn before the dash.
    // If this ever shortens to the others' length the capture stops working.
    final dark = cast('Dark').windUpTime;
    expect(dark, greaterThan(cast('Spirit').windUpTime));
    expect(dark, greaterThan(cast('Crystal').windUpTime));
  });
}
