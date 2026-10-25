@Tags(['preview'])
library;

// A raid fight as the phone shows it: the game's own onLoad, the view an
// iPhone 15 gives the game (393 wide, 852 less the control tray's 128 and
// the home bar's 34) through the game's camera, and the played Alchemon steered
// with the joystick the way a player would (it closes on the guardian,
// keeps outside the rage aura until a lull opens, then strikes). One frame a
// second, and a burst of frames round the first squad hit. Judging what a
// raid looks like and how its bodies behave, not measuring it.
//
//   RAID_FILM_OUT=/tmp/raid_film flutter test \
//     test/raid_fight_film_preview_test.dart --tags preview \
//     [--dart-define=RAIDS=Fire,Air] [--dart-define=LEVEL=2]

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

const double _w = 393, _h = 690, _dpr = 2;
const String _raids = String.fromEnvironment('RAIDS', defaultValue: 'Fire');
const int _level = int.fromEnvironment('LEVEL', defaultValue: 2);

void main() {
  final out = Platform.environment['RAID_FILM_OUT'];
  setUpAll(loadLobbyFonts);

  final catalog = [
    for (final c
        in ((jsonDecode(
                      File(
                        'assets/data/alchemons_creatures.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>)['creatures']
                as List)
            .cast<Map<String, dynamic>>())
      Creature.fromJson(c),
  ];
  Creature pick(String family, String element) {
    bool ofFamily(Creature c) =>
        c.spriteData != null &&
        (c.mutationFamily ?? '').toLowerCase() == family;
    return catalog.firstWhere(
      (c) => ofFamily(c) && c.types.first == element,
      orElse: () => catalog.firstWhere(ofFamily),
    );
  }

  for (final element in _raids.split(',')) {
    testWidgets('raid film $element L$_level', (tester) async {
      if (out == null) return;
      final dir = '$out/$element';
      Directory(dir).createSync(recursive: true);
      await tester.runAsync(() async {
        const families = ['horn', 'wing', 'kin', 'mane', 'pip'];
        final game = PlanetDungeonGame(
          element: element,
          party: [
            for (final f in families)
              debugMemberFromCreature(pick(f, element), statTier: 4),
          ],
          initialStarMask: 0,
          onStarEarned: (_) {},
          onPlayerDown: () {},
          onChanged: () {},
          raid: const RaidConfig(level: _level),
          onRaidCleared: () async {},
          layoutOverride: buildRaidArenaLayout(element),
        );
        game.onGameResize(Vector2(_w, _h));
        await game.onLoad();

        Future<void> shoot(String name) async {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec)..scale(_dpr);
          game.render(c);
          final img = rec.endRecording().toImageSync(
            (_w * _dpr).round(),
            (_h * _dpr).round(),
          );
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        }

        const dt = 1 / 60;
        var t = 0.0;
        var nextShot = 0.0;
        final burstFrom = RaidConfig(level: _level).squadHitInterval - 1.6;
        final burstTo = burstFrom + 2.2;
        var burst = 0.0;
        while (t < 40) {
          final boss = game.combatEnemies.where((e) => e.isElite).firstOrNull;
          final a = game.active;
          if (a != null && a.alive && boss != null) {
            final off = game.guardianVulnerable ? 60.0 : 130.0;
            final stand = boss.position + Offset(0, off);
            final to = stand - a.position;
            game.joystickDirection = to.distance < 12
                ? Offset.zero
                : to / to.distance;
          } else {
            game.joystickDirection = Offset.zero;
          }
          if (game.autoAttackReady) game.activateAutoAttack();
          if (game.abilityReady) game.activateCombatAbility();
          if (game.guardianVulnerable) game.activateAbility();
          game.update(dt);
          t += dt;
          if (t >= nextShot) {
            await shoot('t${t.toStringAsFixed(0).padLeft(2, '0')}');
            nextShot += 1;
          }
          if (t >= burstFrom && t <= burstTo && t >= burst) {
            await shoot('hit_${(t * 10).round().toString().padLeft(3, '0')}');
            burst = t + 0.15;
          }
          if (game.creatures.every((c) => !c.alive)) break;
        }
      });
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
