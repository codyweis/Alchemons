// The moves that answer each guardian's planet rule, the way a player makes
// them: shared by the raid tests and the dungeon guardian harness. Each
// reads the room the party is in, so a dungeon's guardian room and a raid
// arena are answered the same way.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flutter/painting.dart';

/// Where to stand against Solarin, the way a player walks it: the nearest
/// square within two of it that its light does not burn (strike from
/// there); while there is none, as it swings, the nearest square that does
/// not burn. Read with the shadow floor's own rules, for the body named
/// Light (the one played, in these harnesses).
Offset solarinShadow(PlanetDungeonGame g) {
  final def = g.currentRoom.hall!.def!;
  final s = g.archive.state(def.id);
  final lamp = shadowSolarinLamp(def, s);
  final here = s.pos['Light']!;
  Offset? best;
  var bestScore = double.infinity;
  for (var y = 0; y < def.rows; y++) {
    for (var x = 0; x < def.cols; x++) {
      if (shadowSolid(def, x, y, s)) continue;
      final t = s.moved('Light', sq(x, y));
      if (shadowSolarinBurns(def, t, 'Light')) continue;
      final strikes = lamp != null && shadowSolarinReach(def, t, 'Light');
      final walk = ((x - here.x).abs() + (y - here.y).abs()).toDouble();
      // A square to strike from beats any square that is only safe.
      final score = (strikes ? 0 : 1000) + walk;
      if (score < bestScore) {
        bestScore = score;
        best = shadowCentre(x, y);
      }
    }
  }
  return best ?? shadowCentre(here.x, here.y);
}

/// Where a guardian's planet rule is answered (the thing the key Alchemon
/// stands at and presses), or null where the shared clock, or a rule that
/// needs no hand, opens it. Reads the room the party is in, so it serves a
/// dungeon's guardian room and a raid arena alike.
Offset? guardianAnswerAt(PlanetDungeonGame g) {
  final room = g.currentRoom;
  switch (g.layout.element) {
    case 'Crystal':
      // Stand on the plate beside the gap that is nearest the heart plate.
      final floor = room.prism?.choir;
      if (floor == null) return null;
      int steps(int c) =>
          (c % 3 - kKeepHeartCell % 3).abs() +
          (c ~/ 3 - kKeepHeartCell ~/ 3).abs();
      final cell = keepNeighbours(
        g.prism.choirHollow,
      ).reduce((a, b) => steps(a) <= steps(b) ? a : b);
      return floor.plateCentre(cell);
    case 'Plant':
      final rings = room.grove?.arenaRings ?? const <Offset>[];
      return rings.isEmpty ? null : rings.first;
    case 'Lightning':
      return room.coreBreaker;
    case 'Light':
      return room.hall?.def?.orbit == null ? null : solarinShadow(g);
    case 'Ice':
      return room.rime?.hoarfrost;
    case 'Mud':
      return room.fen?.anchor;
    case 'Dust':
      return room.ruins?.hollowCut;
    case 'Spirit':
      return room.funeral?.chime;
    case 'Lava':
      // The head Magmara is nearest, to drop as it comes past.
      final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
      if (boss == null) return null;
      return kLavaHeartHeads.reduce(
        (a, b) =>
            (a - boss.position).distance < (b - boss.position).distance ? a : b,
      );
  }
  return null;
}

/// One step of Blightfang's loop, the way a player plays it: with a brew in
/// hand, take it to Blightfang and dose; otherwise give the next ingredient
/// at the pot. Alternates the Pure Vial (Poison twice) with Poison and Plant,
/// because it will not take the same brew twice running. [poison] and
/// [plant] are the squad slots holding those elements.
void blightfangStep(PlanetDungeonGame g, int poison, int plant) {
  final m = g.monastery;
  final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
  if (boss == null) return;
  Offset at;
  int slot;
  if (m.carriedPotion != null) {
    slot = poison;
    at = boss.position + const Offset(0, 60);
  } else {
    final wantPure = m.lastBrew != kPureVial.id;
    slot = m.pot.isEmpty || wantPure ? poison : plant;
    at = g.currentRoom.apothecary!.cistern;
  }
  if (g.activeIndex != slot) g.setActive(slot);
  g.creatures[slot]
    ..position = at
    ..lastSafe = at;
  g.activateAbility();
}
