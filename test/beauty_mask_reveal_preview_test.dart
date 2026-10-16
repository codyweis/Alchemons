@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/story/beauty_mask_reveal.dart';
import 'package:alchemons/screens/story/work_memory.dart';
import 'package:alchemons/widgets/fx/realm_sift.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// THE FIRST DESCENT'S CINEMATIC, end to end: every realm pictured by its own
// field as the cinematic pictures it, the real dungeon's entrance frozen
// under it and a real party standing in it, each line tapped through after
// a moment's reading.
//
//   REVEAL_OUT=/tmp/reveal flutter test \
//     test/beauty_mask_reveal_preview_test.dart --tags preview
//
// One PNG per frame at REVEAL_FPS (default 20), and reveal.mp4 when ffmpeg
// is on the path. REVEAL_SIZE=880x412 picks the screen (logical px),
// REVEAL_ELEMENT the planet (Fire), REVEAL_SCALE the frames' scale (1.5),
// REVEAL_SHOOT_FROM the second the frames start (0), REVEAL_EVERY every how
// many frames one is shot (1).
// Crimson Text stands in as Georgia Italic, so the run may end "failed"
// once google_fonts notices the real one is missing; the frames are written.
void main() {
  testWidgets(
    'first descent cinematic preview',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      final out = Platform.environment['REVEAL_OUT'];
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      final dims = (Platform.environment['REVEAL_SIZE'] ?? '880x412')
          .split('x')
          .map(double.parse)
          .toList();
      final screen = Size(dims[0], dims[1]);
      // The cinematic steps at most 1/20 s a frame (a hitch pauses it rather
      // than jumping it), so it is pumped at 20 and shot every frame.
      final fps = int.tryParse(Platform.environment['REVEAL_FPS'] ?? '') ?? 20;
      final scale =
          double.tryParse(Platform.environment['REVEAL_SCALE'] ?? '') ?? 1.5;
      final element = Platform.environment['REVEAL_ELEMENT'] ?? 'Fire';
      final shootFrom =
          double.tryParse(Platform.environment['REVEAL_SHOOT_FROM'] ?? '') ?? 0;
      // Every how many frames one is shot (the clip's rate is fps / every).
      final every =
          int.tryParse(Platform.environment['REVEAL_EVERY'] ?? '') ?? 1;
      const dpr = 2.0;
      tester.view.physicalSize = screen * dpr;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      GoogleFonts.config.allowRuntimeFetching = false;

      Future<void> loadFont(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(
              Future.value(ByteData.view(file.readAsBytesSync().buffer)),
            ))
            .load();
      }

      await tester.runAsync(() async {
        await loadFont(
          'monospace',
          '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
        );
        await loadFont(
          'Roboto',
          '/System/Library/Fonts/Supplemental/Arial.ttf',
        );
        for (final f in ['CrimsonText_italic', 'CrimsonText_regular']) {
          await loadFont(
            f,
            '/System/Library/Fonts/Supplemental/Georgia Italic.ttf',
          );
        }
      });

      // Every realm, pictured.
      final pictures = <RealmPicture>[];
      for (final (id, scene) in maskedRealms()) {
        final game = SceneGame(scene: scene)..fieldHourOverride = 18.4;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: screen.width,
                height: screen.height,
                child: GameWidget(game: game),
              ),
            ),
          ),
        );
        for (var i = 0; i < 80 && !game.isLoaded; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        for (var i = 0; i < 8; i++) {
          game.update(1 / 30);
        }
        final picture = await tester.runAsync(
          () => RealmPicture.record(id, screen, 1.5, game.render),
        );
        pictures.add(picture!);
      }
      await tester.pumpWidget(const SizedBox());

      // The planet: its entrance, frozen, with a party of three standing in
      // it (drawn by the cinematic, not the room).
      late PlanetDungeonGame dungeon;
      late ui.Image planet;
      WorkMemoryCast? cast;
      await tester.runAsync(() async {
        final all = [
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
        final party = <CosmicPartyMember>[
          for (final id in ['HOR03', 'LET01', 'WNG04'])
            debugMemberFromCreature(all.firstWhere((c) => c.id == id)),
        ];
        dungeon = PlanetDungeonGame(
          element: element,
          party: party,
          initialStarMask: 0,
          onStarEarned: (_) {},
          onPlayerDown: () {},
          onChanged: () {},
        );
        dungeon.currentRoomId = dungeon.layout.entranceRoomId;
        dungeon.onGameResize(Vector2(screen.width, screen.height));
        final at = dungeon.layout.entranceSpawn;
        for (var i = 0; i < party.length; i++) {
          final pos = at + Offset((i - 1) * 56.0, (i % 2) * 18.0);
          final c = DungeonCreature(member: party[i])
            ..position = pos
            ..lastSafe = pos;
          dungeon.creatures.add(c);
          await dungeon.debugLoadSprite(c);
        }
        dungeon.update(1 / 60);
        dungeon.partyLooksHidden = true;
        final rec = ui.PictureRecorder();
        dungeon.render(Canvas(rec));
        planet = await rec.endRecording().toImage(
          screen.width.round(),
          screen.height.round(),
        );
        // The memory's cast, as the dungeon screen makes it: the lead, and
        // the two kinds it is made from as wild ones look.
        Future<ui.Image?> firstFrame(String family, String element) async {
          Creature? pick;
          for (final c in all) {
            if (c.spriteData == null) continue;
            if ((c.mutationFamily ?? '').toLowerCase() != family) continue;
            if (c.types.isNotEmpty && c.types.first == element) {
              pick = c;
              break;
            }
            pick ??= c;
          }
          if (pick == null) return null;
          final data = await rootBundle.load(
            'assets/images/${pick.spriteData!.spriteSheetPath}',
          );
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final sheet = (await codec.getNextFrame()).image;
          final fw = pick.spriteData!.frameWidth.toDouble();
          final fh = pick.spriteData!.frameHeight.toDouble();
          final r = ui.PictureRecorder();
          Canvas(r).drawImageRect(
            sheet,
            Rect.fromLTWH(0, 0, fw, fh),
            Rect.fromLTWH(0, 0, fw, fh),
            Paint(),
          );
          return r.endRecording().toImage(fw.round(), fh.round());
        }

        final lead = dungeon.creatures.first.member;
        cast = await workMemoryCast(
          family: lead.family,
          element: lead.element,
          side: screen.height * 0.26,
          leadHalfHeight: dungeon.partyLookHalfHeight(0),
          paintLead: (c) => dungeon.paintPartyLook(
            c,
            0,
            faceRight: dungeon.partyLookFacesRight(0),
            time: 0,
          ),
          firstFrameOf: firstFrame,
        );
      });
      expect(cast, isNotNull, reason: 'the memory has its cast');

      final key = GlobalKey();
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(image: planet, fit: BoxFit.fill),
                BeautyMaskReveal(
                  pictures: pictures,
                  party: _Party(dungeon),
                  memoryCast: () async => cast,
                  onComplete: () async => done = true,
                ),
              ],
            ),
          ),
        ),
      );

      final frames = <String>[];
      Future<void> shoot() async {
        final name = 'frame_${frames.length.toString().padLeft(4, '0')}.png';
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: scale);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        frames.add(name);
      }

      // Each line is read for a few seconds, then tapped.
      final step = Duration(microseconds: 1000000 ~/ fps);
      double? hintSince;
      var clock = 0.0;
      var after = 0.0;
      var frame = 0;
      while (clock < 180) {
        await tester.pump(step);
        clock += 1 / fps;
        if (clock >= shootFrom && frame++ % every == 0) await shoot();
        final hint =
            find.text('LOOK CLOSER').evaluate().isNotEmpty ||
            find.text('CONTINUE').evaluate().isNotEmpty;
        if (hint) {
          hintSince ??= clock;
          if (clock - hintSince > 3.2) {
            await tester.tap(
              find.byType(BeautyMaskReveal),
              warnIfMissed: false,
            );
            hintSince = null;
          }
        } else {
          hintSince = null;
        }
        if (done) {
          after += 1 / fps;
          if (after > 1) break;
        }
      }
      expect(done, isTrue, reason: 'the cinematic reached its end');

      await tester.runAsync(() async {
        try {
          await Process.run('ffmpeg', [
            '-y',
            '-framerate',
            '${fps / every}',
            '-i',
            '$out/frame_%04d.png',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-vf',
            'scale=trunc(iw/2)*2:trunc(ih/2)*2',
            '$out/reveal.mp4',
          ]);
        } catch (_) {}
      });
    },
  );
}

class _Party implements RevealParty {
  _Party(this.game);

  final PlanetDungeonGame game;

  @override
  int get count => game.partyLookCount;

  @override
  Offset restAt(int i) => game.partyLookAt(i);

  @override
  double get zoom => game.partyLookZoom;

  @override
  bool facesRight(int i) => game.partyLookFacesRight(i);

  @override
  double halfHeight(int i) => game.partyLookHalfHeight(i);

  @override
  void paint(
    Canvas canvas,
    int i, {
    required bool faceRight,
    required double time,
  }) => game.paintPartyLook(canvas, i, faceRight: faceRight, time: time);

  @override
  void step(double dt) => game.stepPartyLooks(dt);
}
