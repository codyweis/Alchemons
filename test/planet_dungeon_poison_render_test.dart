// THE ROOMS, DRAWN. A smoke render of every surface the cauldron redesign
// added — the pot with nothing in it, with one thing in it, and with a brew
// standing on its rim; and each ward's ingredient board.
//
// It asserts only that the painters run and put ink down, because that is the
// part a unit test cannot reach and the part that has broken most often. Pass
// `--dart-define=OUT=<dir>` to keep the PNGs and actually look at them, which
// is the whole reason this file exists.

import 'dart:io';
import 'dart:math' show cos, pi, sin;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the PNGs go, when anyone wants them.
///
/// A DIRECTORY THAT HAS TO ALREADY EXIST, rather than a --dart-define or an
/// environment variable: `flutter test` in this toolchain passes neither
/// through to the test isolate, so both spellings compiled fine, passed, and
/// wrote nothing anywhere. `mkdir -p build/poison_shots` and run the test to
/// get the pictures; CI has no such directory and writes none.
const String _out = 'build/poison_shots';

PlanetDungeonGame _game() {
  const els = ['Poison', 'Plant', 'Mud'];
  final party = [
    for (final e in els)
      CosmicPartyMember(
        instanceId: 'i$e',
        baseId: 'b$e',
        displayName: e,
        element: e,
        family: e == 'Poison' ? 'mask' : (e == 'Plant' ? 'horn' : 'mane'),
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: els.indexOf(e),
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: 'Poison',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.onGameResize(Vector2(900, 600));
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = const Offset(200, 300)
        ..lastSafe = const Offset(200, 300),
    );
  }
  return g;
}

/// Renders [room] and returns a checksum of the pixels. The whole canvas is
/// opaque, so counting lit pixels proves nothing (it is always 900×600) —
/// what matters is whether the ink CHANGED.
Future<int> _shot(
  PlanetDungeonGame g,
  String room,
  String name, {
  Offset? at,
  void Function()? poseAfterTick,
}) async {
  g.currentRoomId = room;
  final stand = at ?? poisonLayout.rooms[room]!.bounds.center;
  for (final c in g.creatures) {
    c.position = stand;
    c.lastSafe = stand;
  }
  // LET THE CAMERA GET THERE. It lerps toward the party, so a single tick
  // after moving them leaves the shot pointing at wherever the last one was
  // — which is how a picture captioned "the cross" came back showing the
  // font in the middle of the room.
  for (var i = 0; i < 24; i++) {
    g.update(1 / 60);
  }
  // Pose AFTER the ticks. The first attempt at the gate shots set the fight
  // up and then let `_shot` tick once, and the tick tore it straight back
  // down — three pictures of an empty corridor that still differed enough
  // from each other to pass a checksum comparison.
  poseAfterTick?.call();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  g.render(canvas);
  final img = await rec.endRecording().toImage(900, 600);
  if (Directory(_out).existsSync()) {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = raw!.buffer.asUint8List();
  var sum = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    sum =
        (sum + bytes[i] * 3 + bytes[i + 1] * 5 + bytes[i + 2] * 7) & 0x3FFFFFF;
  }
  return sum;
}

CosmicSurvivalEnemy _dummyBody(Offset at) => CosmicSurvivalEnemy(
  position: at,
  hp: 60,
  maxHp: 90,
  speed: 50,
  damage: 10,
  radius: 26,
  tier: EnemyTier.brute,
  element: 'Poison',
  conduct: EnemyConduct.charge,
  target: CosmicEnemyTarget.companion,
);

/// The raw pixels of a frame, for the one question a checksum cannot answer:
/// not "did anything change" but "can a person SEE it".
///
/// The gloom on this planet dims rather than blacks out, so a thing buried
/// under it still shifts every byte a little and still compares as different.
Future<Uint8List> _frame(
  PlanetDungeonGame g,
  String room, {
  Offset? at,
  void Function()? poseAfterTick,
}) async {
  g.currentRoomId = room;
  final stand = at ?? poisonLayout.rooms[room]!.bounds.center;
  for (final c in g.creatures) {
    c
      ..position = stand
      ..lastSafe = stand;
  }
  for (var i = 0; i < 24; i++) {
    g.update(1 / 60);
  }
  poseAfterTick?.call();
  final rec = ui.PictureRecorder();
  g.render(Canvas(rec));
  final img = await rec.endRecording().toImage(900, 600);
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return raw!.buffer.asUint8List();
}

/// How many pixels a person would actually notice between two frames.
int _visibleDelta(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() >= 12 ||
        (a[i + 1] - b[i + 1]).abs() >= 12 ||
        (a[i + 2] - b[i + 2]).abs() >= 12) {
      n++;
    }
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('the cauldron and the boards actually draw', (tester) async {
    await tester.runAsync(() async {
      final g = _game();
      final empty = await _shot(g, 'apothecary', 'p_pot_empty');
      expect(empty, isNonZero, reason: 'the room drew nothing at all');

      final still = poisonLayout.rooms['apothecary']!.apothecary!;
      final a = g.creatures.first..position = still.cistern;
      a.lastSafe = still.cistern;
      g.activeIndex = 0;
      g.activateAbility();
      expect(g.monastery.pot, hasLength(1));
      final one = await _shot(g, 'apothecary', 'p_pot_one');
      expect(
        one,
        isNot(empty),
        reason:
            'a give has to CHANGE the pot — an unchanged pot is why this '
            'read as pressing a button at a prop',
      );

      final b = g.creatures[1]..position = still.cistern;
      b.lastSafe = still.cistern;
      g.activeIndex = 1;
      g.activateAbility();
      expect(g.monastery.carriedPotion, isNotNull);
      final made = await _shot(g, 'apothecary', 'p_pot_made');
      expect(
        made,
        isNot(one),
        reason: 'a finished brew has to be visible on the rim',
      );

      for (final p in kPlaguePotions) {
        final lit = await _shot(g, p.wardId!, 'p_${p.wardId}');
        expect(lit, isNonZero, reason: '${p.wardId} drew nothing');
      }

      // The cross, empty and then full. An unlit cross beside a lit one is
      // the whole reward moment, and it is the one thing on this planet a
      // player walks the corridor three extra times for.
      // EVERY BREW, CARRIED. The one that actually shipped broken: making
      // the Pure Vial crashed the game outright, because the HUD readout
      // looked the carried brew up in `kPlaguePotions` — which is the three
      // plague brews and not the vial — and that lookup runs every frame.
      // Nothing here was a rendering problem; it was a list-membership
      // assumption, and only carrying each brew in turn finds it.
      for (final p in kAllBrews) {
        g.monastery
          ..bottled.add(p.id)
          ..carriedPotion = p.id;
        expect(
          () => g.progressReadout,
          returnsNormally,
          reason: 'carrying ${p.name} throws in the HUD readout',
        );
        expect(
          g.progressReadout?.value,
          p.name,
          reason: 'the readout has to name the brew in hand',
        );
        expect(
          await _shot(g, 'apothecary', 'p_carry_${p.id}'),
          isNonZero,
          reason: 'carrying ${p.name} throws in the render',
        );
        // …and poured on a plague, which is where a WRONG bottle lands.
        g.monastery
          ..pour = 0.5
          ..pourPotion = p.id
          ..pourAt = poisonLayout.rooms['ward_bell']!.ward!.heart;
        expect(
          await _shot(g, 'ward_bell', 'p_wrongpour_${p.id}'),
          isNonZero,
          reason: '${p.name} poured on a plague throws in the render',
        );
        g.monastery
          ..pour = 0
          ..pourPotion = null;
      }
      g.monastery
        ..carriedPotion = null
        ..bottled.clear();

      // THE SLEEPER AND THE BOSS, side by side in the shots: the same shape
      // in the ward and in the corridor, differing only in size and colour.
      // Three creatures playing one part is what this replaced.
      for (final p in kPlaguePotions) {
        g.monastery.triage.open(p.wardId!);
        // Let the wake finish. The veins are drawn to a FRACTION of their
        // length while a ward is coming awake, so a shot taken on the first
        // frame after arriving catches a creature that is barely there —
        // which is what made the first sleeper shots look empty.
        g.currentRoomId = p.wardId!;
        for (var i = 0; i < 60 * 3; i++) {
          g.update(1 / 60);
        }
        expect(
          await _shot(g, p.wardId!, 'p_sleeper_${p.id}'),
          isNonZero,
          reason: '${p.wardId} shows nothing asleep in it',
        );
      }

      // THE SAME PLAGUE, A SECOND APART. Two frames of one creature, so the
      // veins can be seen to have swung rather than just flickered.
      final walk0 = poisonLayout.rooms['ambulatory']!.bounds.center;
      for (final t in [0, 1]) {
        await _shot(
          g,
          'ambulatory',
          'p_alive_$t',
          at: walk0,
          poseAfterTick: () {
            g.monastery
              ..fighting = kPlaguePotions.first.id
              ..body = _dummyBody(walk0)
              ..bars = 3
              ..gated = false
              ..unfurl = 0
              ..marks.clear()
              ..lashes.clear()
              ..waves.clear()
              ..rot.clear()
              ..slam = -1;
          },
        );
        for (var i = 0; i < 60; i++) {
          g.update(1 / 60);
        }
      }

      // THE BODY, one shot per plague. Three plagues that arrive the same
      // colour are one plague, and the body has to look like the thing that
      // crawled in rather than the shared Poison blob.
      final bodies = <int>{};
      for (final p in kPlaguePotions) {
        bodies.add(
          await _shot(
            g,
            'ambulatory',
            'p_body_${p.id}',
            at: poisonLayout.rooms['ambulatory']!.bounds.center,
            poseAfterTick: () {
              g.monastery
                ..fighting = p.id
                ..body = _dummyBody(
                  poisonLayout.rooms['ambulatory']!.bounds.center,
                )
                ..bars = 3
                ..gated = false
                ..marks.clear();
            },
          ),
        );
      }
      expect(
        bodies.length,
        kPlaguePotions.length,
        reason: 'two plagues that look alike in the room are one plague',
      );

      // MID-ATTACK, one per plague: tendrils out, and each one's signature
      // over the top of them.
      final atk = <int>{};
      for (final p in kPlaguePotions) {
        final centre = poisonLayout.rooms['ambulatory']!.bounds.center;
        atk.add(
          await _shot(
            g,
            'ambulatory',
            'p_attack_${p.id}',
            at: centre,
            poseAfterTick: () {
              final b = _dummyBody(centre);
              g.monastery
                ..fighting = p.id
                ..body = b
                ..bars = 3
                ..gated = false
                ..marks.clear()
                ..lashes.clear()
                ..waves.clear()
                ..rot.clear()
                ..slam = -1;
              for (var i = 0; i < 3; i++) {
                g.monastery.lashes.add(
                  PlagueLash(
                    from: centre,
                    to: centre + Offset(120 * cos(i * 0.4), 120 * sin(i * 0.4)),
                    creep: p.pot == CauldronReaction.rot,
                  )..t = 0.85,
                );
              }
              switch (p.pot) {
                case CauldronReaction.bloom:
                  g.monastery.waves.addAll([90, 190, 300]);
                case CauldronReaction.climb:
                  g.monastery
                    ..slam = 0.35
                    ..slamAt = centre + const Offset(120, 40);
                case CauldronReaction.rot:
                  for (var i = 0; i < 3; i++) {
                    g.monastery.rot.add((
                      centre + Offset(90.0 * (i - 1), 70),
                      4.0,
                    ));
                  }
                case CauldronReaction.pure:
                  break;
              }
            },
          ),
        );
      }
      expect(
        atk.length,
        kPlaguePotions.length,
        reason: 'three plagues that attack alike are one plague',
      );
      g.monastery
        ..fighting = null
        ..lashes.clear()
        ..waves.clear()
        ..rot.clear()
        ..slam = -1;

      // EVERY GATE, MID-MECHANIC. Three plagues that all put the same thing
      // on the floor would be one fight run three times, and a bulb that
      // reads as scenery is a fight the player cannot see the shape of.
      final walk = poisonLayout.rooms['ambulatory']!;
      final gates = <int>{};
      final centre = walk.bounds.center;
      for (final p in kPlaguePotions) {
        gates.add(
          await _shot(
            g,
            'ambulatory',
            'p_gate_${p.id}',
            at: centre,
            poseAfterTick: () {
              g.monastery
                ..fighting = p.id
                ..body = _dummyBody(centre)
                ..bars = 2
                ..gated = true
                ..gateLeft = 9.0
                ..marks.clear();
              for (var i = 0; i < 3; i++) {
                g.monastery.marks.add(
                  PlagueMark(at: centre + Offset((i - 1) * 130, 60)),
                );
              }
              // Decay's is a FIELD; the other two are three.
              if (p.pot == CauldronReaction.rot) {
                g.monastery.marks.clear();
                for (var i = 0; i < 10; i++) {
                  final a = (i / 10) * 2 * pi + (i.isEven ? 0.0 : 0.31);
                  final rad = i.isEven ? 105.0 : 215.0;
                  g.monastery.marks.add(
                    PlagueMark(
                      at: centre + Offset(cos(a) * rad, sin(a) * rad * 0.62),
                    ),
                  );
                }
              }
              g.monastery.marks[0].fill = 0.5;
            },
          ),
        );
      }
      expect(
        gates.length,
        kPlaguePotions.length,
        reason: 'two gates that look alike are one gate',
      );
      g.monastery
        ..fighting = null
        ..gated = false
        ..bars = 0
        ..marks.clear();

      // THE SICK WISP, one shot per colour, plus the circle at the cross.
      // Three stages that all drew the same colour would make the errand
      // unreadable: the colour IS which hand it wants.
      final wisps = <int>{};
      final crossAt = poisonLayout.rooms['ambulatory']!.priorsSeal!.position;
      for (var stage = 0; stage < kWispOrder.length; stage++) {
        wisps.add(
          await _shot(
            g,
            'ambulatory',
            'p_wisp_${kWispOrder[stage]}',
            at: kWispStart,
            poseAfterTick: () {
              g.monastery
                ..wisp = kWispStart
                ..wispStage = stage
                ..wispCircle = -1
                ..wispNudge = 0.8;
            },
          ),
        );
      }
      expect(
        wisps.length,
        kWispOrder.length,
        reason:
            'the colour is which hand it wants, so three stages that '
            'look alike are one stage',
      );
      await _shot(
        g,
        'ambulatory',
        'p_wisp_circling',
        at: crossAt,
        poseAfterTick: () {
          g.monastery
            ..wisp = crossAt
            ..wispStage = 1
            ..wispCircle = 0.55;
        },
      );
      g.monastery
        ..wisp = null
        ..wispStage = 0
        ..wispCircle = -1;

      // SHOVED AWAY FROM THE PARTY AND STILL VISIBLE.
      //
      // The whole errand pushes the wisp away from the party, and the room's
      // gloom is centred on the party, so the obvious suspect for "I pressed
      // it twice and it disappeared" was the darkness. Measuring says no: a
      // wisp 320px out reads in 13.6k pixels under the gloom and 13.8k over
      // it. The real cause was that a press TELEPORTED it 150px, and two of
      // those carried it off the edge of the viewport with nothing to
      // follow. It glides now, and holds still afterwards.
      //
      // The check stays anyway, because it is the only thing standing
      // between this object and a future change that buries it.
      Future<Uint8List> withWisp(Offset? where) => _frame(
        g,
        'ambulatory',
        at: kWispStart,
        poseAfterTick: () {
          g.monastery
            ..wisp = where
            ..wispAnchor = where ?? kWispStart
            ..wispStage = 0
            ..wispCircle = -1;
        },
      );

      final blank = await withWisp(null);
      final near = await withWisp(kWispStart);
      final far = await withWisp(kWispStart + const Offset(320, 40));

      final nearSeen = _visibleDelta(near, blank);
      final farSeen = _visibleDelta(far, blank);
      expect(
        nearSeen,
        greaterThan(200),
        reason: 'the wisp is not visible even standing on it',
      );
      // The question is not whether the far frame DIFFERS from the blank one
      // — the gloom dims rather than blacks out, so a buried wisp still
      // shifts every byte a little and a checksum still calls it different.
      // It is whether a person could see it.
      expect(
        farSeen,
        greaterThan(nearSeen ~/ 3),
        reason:
            'shoved 320px out the wisp shows in $farSeen pixels against '
            '$nearSeen up close, so something is swallowing it away from '
            'the party',
      );
      g.monastery
        ..wisp = null
        ..wispCircle = -1;

      // THE FONT, wanting the vial and then spent — it has to state its own
      // want before the player owns the answer.
      final font = poisonLayout.rooms['ambulatory']!.lustralFont!;
      final asking = await _shot(g, 'ambulatory', 'p_font_asking', at: font);
      g.monastery.cloisterOpen = true;
      final spent = await _shot(g, 'ambulatory', 'p_font_spent', at: font);
      expect(
        spent,
        isNot(asking),
        reason: 'a spent basin must not still be asking',
      );
      g.monastery.cloisterOpen = false;

      // EVERY POT REACTION, mid-beat. Three recipes that all flashed green
      // would make the receipt worthless, so each one gets looked at.
      final reactions = <int>{};
      for (final p in kAllBrews) {
        g.monastery
          ..reaction = 0.45
          ..reactionKind = p.pot;
        reactions.add(await _shot(g, 'apothecary', 'p_react_${p.id}'));
      }
      expect(
        reactions.length,
        kAllBrews.length,
        reason: 'two brews that look identical in the pot are one brew',
      );
      g.monastery
        ..reaction = 0
        ..reactionKind = null;

      // …and every pour landing on its plague, likewise.
      final pours = <int>{};
      for (final p in kPlaguePotions) {
        g.monastery
          ..pour = 0.4
          ..pourPotion = p.id
          ..pourAt = poisonLayout.rooms[p.wardId!]!.ward!.heart;
        pours.add(await _shot(g, p.wardId!, 'p_pour_${p.id}'));
      }
      expect(pours.length, kPlaguePotions.length);
      g.monastery
        ..pour = 0
        ..pourPotion = null;

      // Stand AT the cross: the cloister is wider than the viewport, so a
      // shot from the room's centre missed the thing it was shooting.
      final cross = poisonLayout.rooms['ambulatory']!.priorsSeal!.position;
      final dark = await _shot(g, 'ambulatory', 'p_cross_empty', at: cross);
      for (final p in kPlaguePotions) {
        g.monastery.relicsPlaced.add(p.id);
      }
      g.monastery.crossLight = 0.5;
      final blazing = await _shot(g, 'ambulatory', 'p_cross_lit', at: cross);
      expect(
        blazing,
        isNot(dark),
        reason: 'three reliquaries in the stone have to CHANGE the cross',
      );
    });
  });
}
