// The moves that answer each guardian's planet rule, the way a player makes
// them: shared by the raid tests and the dungeon guardian harness. Each
// reads the room the party is in, so a dungeon's guardian room and a raid
// arena are answered the same way.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_crystal.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_lava.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'dart:math' show atan2, max, pi;

import 'package:flutter/painting.dart';

/// Where to stand against Solarin, the way a player walks it: the nearest
/// square within two of it that its light does not burn (strike from
/// there); while there is none, as it swings, the nearest square that does
/// not burn. Read with the shadow floor's own rules, for the body called
/// [name] on the floor: Light (the one played, in these harnesses), unless
/// a raid's played body takes its own element's name (see [raidShadowName]).
Offset solarinShadow(PlanetDungeonGame g, {String name = 'Light'}) {
  final def = g.currentRoom.hall!.def!;
  final s = g.archive.state(def.id);
  final lamp = shadowSolarinLamp(def, s);
  final here = s.pos[name]!;
  Offset? best;
  var bestScore = double.infinity;
  for (var y = 0; y < def.rows; y++) {
    for (var x = 0; x < def.cols; x++) {
      if (shadowSolid(def, x, y, s)) continue;
      final t = s.moved(name, sq(x, y));
      if (shadowSolarinBurns(def, t, name)) continue;
      final strikes = lamp != null && shadowSolarinReach(def, t, name);
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

/// The next square to walk to against Solarin, the way a player walks the
/// shadow floor: toward the nearest square that does not burn and strikes
/// (else only does not burn), by the route that crosses the least lit glass.
/// A lit square on the way costs [litCost] steps; a square that only shades
/// costs [shadeOnly] more than one that strikes, so a player crosses up to
/// three lit squares to strike, but will not run the floor's width over glass.
/// Returns the centre of the next square on that route (the destination
/// itself once it is the next square). For the body called [name]. While
/// Solarin swings its shadows sweep, so a player stops chasing a square to
/// strike from and keeps to the nearest shade, far from the lamp (the
/// squares beside it flip from shade to light and back as it moves).
Offset solarinShadedStep(
  PlanetDungeonGame g, {
  String name = 'Light',
  int litCost = 12,
  int shadeOnly = 40,
}) {
  final def = g.currentRoom.hall!.def!;
  final s = g.archive.state(def.id);
  final lamp = shadowSolarinLamp(def, s);
  final here = s.pos[name]!;
  final sun = s.sun; // non-null only while it swings
  final cols = def.cols;
  final n = def.rows * cols;
  final burns = List<bool>.filled(n, false);
  final open = List<bool>.filled(n, false);
  final strikes = List<bool>.filled(n, false);
  for (var y = 0; y < def.rows; y++) {
    for (var x = 0; x < cols; x++) {
      final i = y * cols + x;
      if (shadowSolid(def, x, y, s)) continue;
      open[i] = true;
      final t = s.moved(name, sq(x, y));
      burns[i] = shadowSolarinBurns(def, t, name);
      strikes[i] =
          !burns[i] && lamp != null && shadowSolarinReach(def, t, name);
    }
  }
  // Dijkstra from here (the grid is 21×13 at most).
  final start = here.y * cols + here.x;
  final dist = List<int>.filled(n, 1 << 30);
  final prev = List<int>.filled(n, -1);
  final done = List<bool>.filled(n, false);
  dist[start] = 0;
  for (;;) {
    var u = -1;
    for (var i = 0; i < n; i++) {
      if (!done[i] && dist[i] < (1 << 30) && (u < 0 || dist[i] < dist[u])) {
        u = i;
      }
    }
    if (u < 0) break;
    done[u] = true;
    final ux = u % cols, uy = u ~/ cols;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final vx = ux + dx, vy = uy + dy;
      if (vx < 0 || vy < 0 || vx >= cols || vy >= def.rows) continue;
      final v = vy * cols + vx;
      if (!open[v]) continue;
      final w = dist[u] + (burns[v] ? litCost : 1);
      if (w < dist[v]) {
        dist[v] = w;
        prev[v] = u;
      }
    }
  }
  var best = -1;
  var bestScore = 1 << 30;
  for (var i = 0; i < n; i++) {
    if (!open[i] || burns[i] || dist[i] >= (1 << 30)) continue;
    // Squares within four of a swinging lamp flip as it moves: avoid them.
    final fromSun = sun == null
        ? 4
        : max((i % cols - sun.x).abs(), (i ~/ cols - sun.y).abs()).round();
    final score = sun != null
        ? dist[i] + 4 * max<int>(0, 4 - fromSun)
        : dist[i] + (strikes[i] ? 0 : shadeOnly);
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  if (best < 0 || best == start) return shadowCentre(here.x, here.y);
  var step = best;
  while (prev[step] != start && prev[step] >= 0) {
    step = prev[step];
  }
  return shadowCentre(step % cols, step ~/ cols);
}

/// The shadow-floor name of the body a raid squad plays: its own element's,
/// when that is one of the floor's three, else the first (the game's
/// `_raidShadowNames`, which names the played body first).
String raidShadowName(DungeonCreature played) =>
    kShadowNames.contains(played.member.element)
    ? played.member.element
    : kShadowNames.first;

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

/// A body's walking pace on dungeon and raid floors (the game's `_speed`).
const double kHarnessWalkSpeed = 187.5;

/// Moves [c] one frame of [dt] toward [to] at walking pace, the way a
/// player's stick carries it, and says whether it is there. (Straight
/// line: the raid arenas are open floors.)
bool walkTo(DungeonCreature c, Offset to, double dt) {
  final d = to - c.position;
  final step = kHarnessWalkSpeed * dt;
  final at = d.distance <= step ? to : c.position + d / d.distance * step;
  c
    ..position = at
    ..lastSafe = at;
  return at == to;
}

/// Whether a press at [guardianAnswerAt] would do anything now, the way a
/// player reads the prop and the hint before walking in: false while the
/// rule already stands answered (the pillar up, the floor hard, the cut
/// clear, the gap under it, the arena right) or would refuse the press (the
/// pillar regrowing, sand settling, the trunk surging, the heads coming back
/// up, the chime cold). A player waits out of the guardian's reach meanwhile.
bool guardianAnswerReady(PlanetDungeonGame g) => switch (g.layout.element) {
  'Ice' => !g.hoarfrostWhole && !g.hoarfrostRegrowing,
  'Mud' => !g.bog.field.anchorFirm,
  'Dust' => !g.ruins.hollowOpen && !g.hollowSettling,
  'Crystal' => g.prism.choirHollow != kKeepHeartCell,
  'Spirit' => g.funeral.chimeWarm && !g.funeral.chimeHeld,
  'Plant' => g.greenhouse.arena != null,
  'Lightning' => g.raikumaFed && !g.raikumaSurging,
  'Lava' => g.works.headCool <= 0 && g.works.beached <= 0,
  _ => true,
};

/// The ring head Magmara's conveyor brings it to next: where a player who
/// has to walk waits for it (the nearest head flips as it rides past).
Offset magmaraNextHead(PlanetDungeonGame g) {
  double ahead(Offset head) {
    final d = head - kLavaHeartCentre;
    return (atan2(d.dy, d.dx) - g.works.ride) % (2 * pi);
  }

  return kLavaHeartHeads.reduce((a, b) => ahead(a) <= ahead(b) ? a : b);
}

/// A ring head only catches Magmara within this of it (the game's
/// `_kHeadCatch`): press as it comes past, not before.
const double kHarnessHeadCatch = 170;

/// One step of Blightfang's loop, the way a player plays it: with a brew in
/// hand, take it to Blightfang and dose; otherwise give the next ingredient
/// at the pot. Alternates the Pure Vial (Poison twice) with Poison and Plant,
/// because it will not take the same brew twice running. [poison] and
/// [plant] are the squad slots holding those elements. Returns false, and
/// does nothing, when the hand the next step needs is down. With [walkDt],
/// the hand walks there (one frame of it) and presses once it arrives,
/// instead of being set down there.
bool blightfangStep(
  PlanetDungeonGame g,
  int poison,
  int plant, {
  double? walkDt,
}) {
  final m = g.monastery;
  final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
  if (boss == null) return false;
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
  if (!g.creatures[slot].alive) return false;
  if (g.activeIndex != slot) g.setActive(slot);
  if (walkDt != null) {
    if (walkTo(g.creatures[slot], at, walkDt)) g.activateAbility();
    return true;
  }
  g.creatures[slot]
    ..position = at
    ..lastSafe = at;
  g.activateAbility();
  return true;
}
