@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// A battle against the computer on the phone, as the player sees it: the
// real screen, the floor, both sides' Alchemons and abilities, the HUD.
//
//   BATTLE_OUT=/tmp/battle flutter test test/battle_preview_test.dart \
//     --tags preview
//   [BATTLE_HOME=Horn:Fire,Wing:Air,Kin:Water,Pip:Lightning]
//   [BATTLE_AWAY=Mane:Lava,Mask:Plant,Let:Ice,Wing:Light]
//   [BATTLE_ARENA=obsidian|orrery|tidal|garden]
//   [BATTLE_FILM=15 [BATTLE_FILM_SECONDS=12]]  frames into <out>/film for
//     ffmpeg, BATTLE_FILM a second, small [BATTLE_FILM_RATIO=0.5]
void main() {
  final out = Platform.environment['BATTLE_OUT'];

  setUpAll(loadLobbyFonts);

  Future<void> shoot(
    WidgetTester tester,
    GlobalKey key,
    String name, {
    double ratio = 1.5,
  }) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('battle on the phone', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);

    final save = await LobbySave.create(tester, fresh: true);
    CosmicPartyMember member(String spec, int slot, String tag) {
      final [family, element] = spec.split(':');
      final c = save.catalog.creatures.firstWhere(
        (c) =>
            (c.mutationFamily ?? '').toLowerCase() == family.toLowerCase() &&
            c.types.isNotEmpty &&
            c.types.first == element &&
            c.spriteData != null,
        orElse: () => save.catalog.creatures.firstWhere(
          (c) =>
              (c.mutationFamily ?? '').toLowerCase() == family.toLowerCase() &&
              c.spriteData != null,
        ),
      );
      return _member(c, slot, tag);
    }

    List<CosmicPartyMember> team(String env, String fallback, String tag) {
      final specs = (Platform.environment[env] ?? fallback).split(',');
      return [
        for (var i = 0; i < specs.length; i++) member(specs[i], i, tag),
      ];
    }

    final home = team(
      'BATTLE_HOME',
      'Horn:Fire,Wing:Air,Kin:Water,Pip:Lightning',
      'h',
    );
    final away = team(
      'BATTLE_AWAY',
      'Mane:Lava,Mask:Plant,Let:Ice,Wing:Light',
      'a',
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: SilentAudio(),
        child: save.app(
          shot: key,
          home: BattleScreen(
            team: home,
            rival: away,
            arena: Platform.environment['BATTLE_ARENA'] ?? 'obsidian',
          ),
        ),
      ),
    );
    CosmicGame game() =>
        tester.widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget)).game!
            as CosmicGame;

    // Let the game load and the sprites decode on the real clock.
    for (var i = 0; i < 30; i++) {
      await settleLobby(tester, 1);
      if (game().battle != null) break;
    }
    await settleLobby(tester, 20);

    final filmFps = int.tryParse(Platform.environment['BATTLE_FILM'] ?? '');
    final filmSeconds =
        double.tryParse(Platform.environment['BATTLE_FILM_SECONDS'] ?? '') ??
        12;
    if (filmFps != null) Directory('$out/film').createSync(recursive: true);
    var filmNext = 0.0;
    var filmFrame = 0;
    var t = 0.0;
    final shots = [0.5, 3.0, 8.0, 14.0, 22.0, 32.0];
    var next = 0;
    while (t < 80) {
      await tester.pump(const Duration(milliseconds: 33));
      t += 0.033;
      if ((t * 30).round() % 30 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      if (filmFps != null && t >= filmNext && t <= filmSeconds) {
        filmNext += 1 / filmFps;
        await shoot(
          tester,
          key,
          'film/f${(filmFrame++).toString().padLeft(4, '0')}',
          ratio:
              double.tryParse(
                Platform.environment['BATTLE_FILM_RATIO'] ?? '',
              ) ??
              0.5,
        );
      }
      if (next < shots.length && t >= shots[next]) {
        tester.takeException();
        await shoot(tester, key, 'battle_${shots[next].toStringAsFixed(0).padLeft(2, '0')}s');
        next++;
      }
      if (game().battle?.over ?? false) break;
    }
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    tester.takeException();
    await shoot(tester, key, 'battle_result');
    await save.dispose(tester);
  });
}

CosmicPartyMember _member(Creature c, int slot, String tag) => CosmicPartyMember(
  instanceId: '$tag:$slot:${c.id}',
  baseId: c.id,
  displayName: c.name,
  element: c.types.first,
  family: c.mutationFamily!,
  level: 10,
  statSpeed: 4.3,
  statIntelligence: 4.3,
  statStrength: 4.3,
  statBeauty: 4.3,
  slotIndex: slot,
  staminaBars: 3,
  staminaMax: 3,
  spriteSheet: sheetFromCreature(c),
  spriteVisuals: visualsFromInstance(c, null),
);
