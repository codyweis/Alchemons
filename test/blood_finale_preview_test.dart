@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show CosmicWorld;
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/story/blood_finale.dart';
import 'package:alchemons/screens/story/work_memory.dart'
    show readSpecimenGrains;
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// THE FINALE, end to end: a real Alchemon offered (its sprite's first
// frame stands in for the live sprite), a census of real species read the
// way the page reads them, and each line tapped after a moment's reading.
//
//   FINALE_OUT=/tmp/finale flutter test \
//     test/blood_finale_preview_test.dart --tags preview
//
// FINALE_SIZE=880x412 (landscape; try 412x880), FINALE_CENSUS=60 species,
// FINALE_EVERY=2 (shoot every other 20 fps frame), FINALE_OFFER=HOR03,
// FINALE_FROM_SPACE=1 to open in space at the Blood Ring: the real game
// flying beside it, then its ritual (the screen's overlay mirrored here),
// and the finale out of the red.
// Writes frame PNGs and finale.mp4 when ffmpeg is on the path. Crimson Text
// stands in as Georgia Italic, so the run may end "failed" once
// google_fonts notices; the frames are written.
void main() {
  testWidgets(
    'blood finale preview',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      final out = Platform.environment['FINALE_OUT'];
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      final env = Platform.environment;
      final dims = (env['FINALE_SIZE'] ?? '880x412')
          .split('x')
          .map(double.parse)
          .toList();
      final screen = Size(dims[0], dims[1]);
      final censusCount = int.tryParse(env['FINALE_CENSUS'] ?? '') ?? 60;
      final every = int.tryParse(env['FINALE_EVERY'] ?? '') ?? 2;
      final offerId = env['FINALE_OFFER'] ?? 'HOR03';
      const fps = 20;
      tester.view.physicalSize = screen * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;

      Future<void> loadFont(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(
              Future.value(ByteData.view(file.readAsBytesSync().buffer)),
            ))
            .load();
      }

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
      final offerSpecies = all.firstWhere((c) => c.id == offerId);
      final offering = debugMemberFromCreature(offerSpecies);

      final census = <CensusEntry>[];
      late ui.Image portraitImage;
      SpecimenGrains? offeringGrains;
      final standSize = screen.height * 0.46;
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
        // The census: species with art, a spread across the catalog.
        final withArt = [
          for (final c in all)
            if (c.image.isNotEmpty && c.spriteData != null) c,
        ];
        final step = (withArt.length / censusCount).clamp(1, 1000).toInt();
        for (
          var i = 0;
          i < withArt.length && census.length < censusCount;
          i += step
        ) {
          final c = withArt[i];
          final entry = await readCensusImage(
            'assets/images/${c.image}',
            c.types.isEmpty ? '' : c.types.first,
          );
          if (entry != null) census.add(entry);
        }
        // The offering: its sheet's first frame, as it stands.
        final data = await rootBundle.load(
          'assets/images/${offerSpecies.spriteData!.spriteSheetPath}',
        );
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final sheet = (await codec.getNextFrame()).image;
        final fw = offerSpecies.spriteData!.frameWidth.toDouble();
        final fh = offerSpecies.spriteData!.frameHeight.toDouble();
        final r = ui.PictureRecorder();
        Canvas(r).drawImageRect(
          sheet,
          Rect.fromLTWH(0, 0, fw, fh),
          Rect.fromLTWH(0, 0, fw, fh),
          Paint(),
        );
        portraitImage = await r.endRecording().toImage(fw.round(), fh.round());
        offeringGrains = await readSpecimenGrains(
          Size(standSize, standSize),
          (c) {
            final k = standSize / fw;
            c.drawImageRect(
              portraitImage,
              Rect.fromLTWH(0, 0, fw, fh),
              Rect.fromCenter(
                center: Offset.zero,
                width: fw * k,
                height: fh * k,
              ),
              Paint()..filterQuality = FilterQuality.medium,
            );
          },
          pixelRatio: 1.5,
          maxGrains: 2400,
        );
      });

      Widget portrait(double size) =>
          RawImage(image: portraitImage, fit: BoxFit.contain);

      var shot = 0;
      Future<void> writeFrame(ui.Image image) async {
        final name = 'frame_${shot.toString().padLeft(4, '0')}.png';
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        shot++;
      }

      if (env['FINALE_FROM_SPACE'] == '1') {
        // The real game, beside the Blood Ring.
        late CosmicGame game;
        await tester.runAsync(() async {
          game = CosmicGame(
            world_: CosmicWorld.generate(seed: 1),
            onMeterChanged: () {},
          );
          await game.onLoad();
          game.onGameResize(Vector2(screen.width, screen.height));
          game.teleportTo(
            game.world_.bloodRing.position + const Offset(-300, 60),
          );
          game.enemies.clear();
          game.activeBoss = null;
          for (var i = 0; i < 30; i++) {
            game.update(1 / 30);
          }
        });
        Future<void> shootSpace({double ritual = 0, double black = 0}) =>
            tester.runAsync(() async {
              const k = 1.5;
              final rec = ui.PictureRecorder();
              final canvas = Canvas(rec);
              canvas.drawRect(
                Offset.zero & (screen * k),
                Paint()..color = const Color(0xFF020010),
              );
              canvas.scale(k);
              game.render(canvas);
              if (ritual > 0) _ritualOverlay(canvas, screen, game, ritual);
              if (black > 0) {
                canvas.drawRect(
                  Offset.zero & screen,
                  Paint()..color = Colors.black.withValues(alpha: black),
                );
              }
              final image = await rec.endRecording().toImage(
                (screen.width * k).round(),
                (screen.height * k).round(),
              );
              await writeFrame(image);
            });
        var f = 0;
        // A moment of flight beside it, as the player comes up to it.
        for (var i = 0; i < 2.5 * fps; i++) {
          game.update(1 / fps);
          if (f++ % every == 0) await shootSpace();
        }
        // The ritual: eight seconds, as the screen drives it.
        const ritualFrames = 8 * fps;
        for (var i = 0; i <= ritualFrames; i++) {
          final p = i / ritualFrames;
          game.bloodRitualProgress = p;
          game.update(1 / fps);
          if (f++ % every == 0) await shootSpace(ritual: p);
        }
        // The finale page fades in over the red (its route's 360 ms).
        for (var i = 0; i < 0.4 * fps; i++) {
          if (f++ % every == 0) {
            await shootSpace(ritual: 1, black: (i + 1) / (0.4 * fps));
          }
        }
      }

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: BloodFinalePage(
            offering: offering,
            census: census,
            offeringGrains: offeringGrains,
            portrait: portrait,
          ),
        ),
      );

      Future<void> shoot() async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await writeFrame(await boundary.toImage(pixelRatio: 1.5));
        });
      }

      double? hintSince;
      var clock = 0.0;
      var frame = 0;
      var gone = 0.0;
      while (clock < 200) {
        await tester.pump(const Duration(milliseconds: 1000 ~/ fps));
        clock += 1 / fps;
        if (frame++ % every == 0) await shoot();
        final hint =
            find.text('CONTINUE').evaluate().isNotEmpty ||
            find.text('RETURN').evaluate().isNotEmpty;
        if (hint) {
          hintSince ??= clock;
          if (clock - hintSince > 3.2) {
            await tester.tapAt(screen.center(Offset.zero));
            hintSince = null;
          }
        } else {
          hintSince = null;
          // Now and then, a tap on whoever is passing in the front lane:
          // it comes apart into its grains and gathers back.
          if (frame % 90 == 45) {
            await tester.tapAt(Offset(screen.width * 0.5, screen.height * 0.8));
          }
        }
        if (find.byType(BloodFinalePage).evaluate().isEmpty) {
          gone += 1 / fps;
          if (gone > 0.5) break;
        }
      }
      expect(
        find.byType(BloodFinalePage),
        findsNothing,
        reason: 'the finale reached its end',
      );

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
            '$out/finale.mp4',
          ]);
        } catch (_) {}
      });
    },
  );
}

/// The screen's overlay on the ritual (cosmic_screen.dart's
/// _BloodRitualSpaceOverlayPainter), mirrored: the dark closing in round
/// the edges as it builds, the red out of the ring's heart at the end.
void _ritualOverlay(Canvas canvas, Size size, CosmicGame game, double t) {
  final z = game.cameraZoom;
  final ring = Offset(
    (game.bloodRing.position.dx - game.camX) * z,
    (game.bloodRing.position.dy - game.camY) * z,
  );
  final rect = Offset.zero & size;
  final far = size.longestSide * 0.75;
  final dark = Curves.easeInOut.transform((t / 0.6).clamp(0.0, 1.0));
  canvas.drawRect(
    rect,
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.25 * dark),
              Colors.black.withValues(alpha: 0.85 * dark),
            ],
            stops: const [0.0, 0.62, 1.0],
          ).createShader(
            Rect.fromCircle(center: size.center(Offset.zero), radius: far),
          ),
  );
  final engulf = Curves.easeInCubic.transform(
    ((t - 0.74) / 0.22).clamp(0.0, 1.0),
  );
  if (engulf > 0) {
    var reach = 0.0;
    for (final c in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      reach = math.max(reach, (c - ring).distance);
    }
    final r = 40 + (reach + 260) * engulf;
    canvas.drawCircle(
      ring,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFCDD2).withValues(alpha: 0.5 * engulf),
            const Color(0xFFD32F2F).withValues(alpha: 0.7 * engulf),
            const Color(0xFF8B0000).withValues(alpha: 0.95 * engulf),
            const Color(0xFF8B0000).withValues(alpha: 0),
          ],
          stops: const [0.0, 0.35, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: ring, radius: r)),
    );
  }
  final full = Curves.easeInOutCubic.transform(
    ((t - 0.88) / 0.12).clamp(0.0, 1.0),
  );
  canvas.drawRect(
    rect,
    Paint()..color = const Color(0xFF7F0000).withValues(alpha: 0.96 * full),
  );
}
