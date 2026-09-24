// THE CINDER CATHEDRAL, IN GLASS — every room whole, and every change of
// state the glass is meant to show (docs/dungeons.md §7.11).
//
// `dungeon_room_render_test.dart` frames each room at a fixed 900x600 from its
// centre, which crops most of the cathedral and shows every room in its
// opening state. The glass-inlay direction is ABOUT state — a pane that lights
// when you do something — so this sizes the viewport to each room, loads the
// glow sprites (a headless game has none, and the cathedral's light is mostly
// glow), steps the clock into the middle of each animation, and asserts that
// the states are different pictures.
//
// `mkdir -p build/room_audit` and run this to get the PNGs (FireGlass_*.png).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String roomId, {int stars = 0}) async {
  const els = ['Fire', 'Air', 'Plant'];
  const fams = ['mask', 'wing', 'mane'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i],
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: 'Fire',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  // Banked stars are applied in onLoad, which a headless game never runs.
  g.starMask = stars;
  final b = kPlanetDungeonLayouts['Fire']!.rooms[roomId]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.currentRoomId = roomId;
  // The party stands out of the way, at the room's south edge.
  final stand = Offset(b.left + 60, b.bottom - 40);
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = stand
        ..lastSafe = stand,
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every room of the cathedral, in every state it shows', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // The test engine draws every glyph as a block, and the epitaph IS
      // words. Where this Mac has an italic serif, register it as the
      // 'serif' family the epitaph asks for, so the PNGs show letters (the
      // hashes compare either way).
      final serif = File(
        '/System/Library/Fonts/Supplemental/Georgia Italic.ttf',
      );
      if (serif.existsSync()) {
        final bytes = serif.readAsBytesSync();
        for (final family in const ['serif']) {
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
      }
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        String roomId, {
        int stars = 0,
        void Function(PlanetDungeonGame g)? setup,
        double seconds = 0.4,
        void Function(PlanetDungeonGame g)? after,
      }) async {
        final g = await _game(roomId, stars: stars);
        setup?.call(g);
        final frames = (seconds * 60).round();
        for (var i = 0; i < frames; i++) {
          g.update(1 / 60);
        }
        after?.call(g);
        final w = g.size.x.round(), h = g.size.y.round();
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(w, h);
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/FireGlass_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = raw!.buffer.asUint8List();
        var hash = 17;
        for (var i = 0; i < bytes.length; i += 97) {
          hash = (hash * 31 + bytes[i]) & 0x3FFFFFFF;
        }
        shots[name] = hash;
      }

      // Narthex: cold, catching, roaring.
      await shoot('narthex_cold', 'narthex');
      await shoot(
        'narthex_catching',
        'narthex',
        setup: (g) => g.entryDoorRevealed = true,
        seconds: 0.7,
      );
      await shoot(
        'narthex_lit',
        'narthex',
        setup: (g) => g.entryDoorRevealed = true,
        seconds: 2.0,
      );

      // Nave: the rose counts the stars, and the chancel gate opens on two.
      void walked(PlanetDungeonGame g) {
        for (var i = 0; i < 8; i++) {
          g.naveCandles[i] = 1.0;
        }
      }

      await shoot(
        'nave_none',
        'nave',
        setup: (g) => g.entryDoorRevealed = true,
      );
      await shoot(
        'nave_two',
        'nave',
        stars: 0x3,
        setup: (g) {
          g.entryDoorRevealed = true;
          walked(g);
        },
      );
      await shoot(
        'nave_all',
        'nave',
        stars: 0x7,
        setup: (g) {
          g.entryDoorRevealed = true;
          walked(g);
        },
      );

      // Scriptorium: dark, two corners, the light front mid-run, settled.
      await shoot('scriptorium_dark', 'scriptorium');
      await shoot(
        'scriptorium_two_corners',
        'scriptorium',
        setup: (g) => g.litMuralTorches.addAll([0, 1]),
        seconds: 0.5,
      );
      await shoot(
        'scriptorium_lighting',
        'scriptorium',
        setup: (g) {
          g.litMuralTorches.addAll([0, 1, 2, 3]);
          g.choirRevealTier = 1;
        },
        seconds: 1.2,
      );
      await shoot(
        'scriptorium_lit',
        'scriptorium',
        setup: (g) {
          g.litMuralTorches.addAll([0, 1, 2, 3]);
          g.choirRevealTier = 1;
        },
        seconds: 3.5,
      );

      // The Ember Epitaph (the scriptorium's Lost Maxim): the quill writes
      // the cipher into the window, the planter's flame is fed, and a
      // burn-front sweeps the words into fire.
      void readMural(PlanetDungeonGame g) {
        g.litMuralTorches.addAll([0, 1, 2, 3]);
        g.choirRevealTier = 1;
      }

      await shoot(
        'epitaph_writing',
        'scriptorium',
        setup: (g) {
          readMural(g);
          g.epitaphStage = 1;
        },
        seconds: 2.2,
      );
      await shoot(
        'epitaph_fed',
        'scriptorium',
        setup: (g) {
          readMural(g);
          g.epitaphStage = 3;
          g.epitaphFans = 2;
          g.epitaphWriteT = 10;
        },
        seconds: 3.0,
      );
      await shoot(
        'epitaph_burning',
        'scriptorium',
        setup: (g) {
          readMural(g);
          g.discoveredClouds.add('egg:fire_epitaph');
        },
        seconds: 2.0,
      );
      await shoot(
        'epitaph_won',
        'scriptorium',
        setup: (g) {
          readMural(g);
          g.discoveredClouds.add('egg:fire_epitaph');
        },
        seconds: 7.0,
      );

      // Choir: the evidence, two fires taken (one mid-run up its spoke), a
      // wrong flame's smoke, and the rite won.
      await shoot('choir_fresh', 'choir');
      await shoot(
        'choir_two_lit',
        'choir',
        setup: (g) => g.ritualProgress = 2,
        seconds: 2.0,
      );
      await shoot(
        'choir_catching',
        'choir',
        setup: (g) => g.ritualProgress = 1,
        seconds: 0.35,
      );
      await shoot(
        'choir_snuffed',
        'choir',
        setup: (g) => g.ritualProgress = 3,
        seconds: 1.5,
        after: (g) {
          g.ritualProgress = 0;
          for (var i = 0; i < 18; i++) {
            g.update(1 / 60);
          }
        },
      );
      await shoot('choir_won', 'choir', stars: 0x1, seconds: 3.0);

      // Cloister: the garth, then a fire running through planted vine.
      await shoot('cloister_bare', 'cloister');
      await shoot(
        'cloister_burning',
        'cloister',
        setup: (g) {
          final room = g.layout.rooms['cloister']!;
          final f = g.burnFieldFor(room)!;
          for (var i = 0; i < 12; i++) {
            f.plant(i);
          }
          f.light(0);
          f.step();
          f.step();
        },
      );

      await shoot('reliquary', 'reliquary');
      await shoot('vestry', 'vestry', stars: 0x3, seconds: 1.0);

      // Bell gallery: silent, one bell rung (its oculus flooding), declared.
      await shoot('gallery_silent', 'bell_gallery', stars: 0x3);
      await shoot(
        'gallery_one_rung',
        'bell_gallery',
        stars: 0x3,
        setup: (g) {
          g.vesperRouteId = 'route_nave';
          g.bellsRung.add('chain_low');
        },
        seconds: 2.0,
      );

      // High altar: the tally in the dais, and the black flame.
      await shoot('altar_dormant', 'high_altar', stars: 0x3);
      await shoot(
        'altar_two_bells',
        'high_altar',
        stars: 0x3,
        setup: (g) => g.bellsRung.addAll(['chain_low', 'chain_mid']),
      );
      await shoot(
        'altar_awake',
        'high_altar',
        stars: 0x3,
        setup: (g) {
          g.bellsRung.addAll(['chain_low', 'chain_mid', 'chain_high']);
          g.guardianAwake = true;
        },
        seconds: 2.0,
      );

      // Sanctum: the empty roost, and the roost burning.
      await shoot('sanctum_empty', 'sanctum', stars: 0x3);
      await shoot(
        'sanctum_awake',
        'sanctum',
        stars: 0x3,
        setup: (g) => g.guardianAwake = true,
        seconds: 2.0,
      );

      // Every state the glass claims to show must be a different picture.
      for (final (a, b) in const [
        ('narthex_cold', 'narthex_catching'),
        ('narthex_catching', 'narthex_lit'),
        ('nave_none', 'nave_two'),
        ('nave_two', 'nave_all'),
        ('scriptorium_dark', 'scriptorium_two_corners'),
        ('scriptorium_two_corners', 'scriptorium_lighting'),
        ('scriptorium_lighting', 'scriptorium_lit'),
        ('scriptorium_lit', 'epitaph_writing'),
        ('epitaph_writing', 'epitaph_fed'),
        ('epitaph_fed', 'epitaph_burning'),
        ('epitaph_burning', 'epitaph_won'),
        ('choir_fresh', 'choir_two_lit'),
        ('choir_fresh', 'choir_snuffed'),
        ('choir_two_lit', 'choir_won'),
        ('cloister_bare', 'cloister_burning'),
        ('gallery_silent', 'gallery_one_rung'),
        ('altar_dormant', 'altar_two_bells'),
        ('altar_two_bells', 'altar_awake'),
        ('sanctum_empty', 'sanctum_awake'),
      ]) {
        expect(
          shots[a] != shots[b],
          isTrue,
          reason: '$a and $b draw the same picture',
        );
      }
    });
  });
}
