@Tags(['preview'])
library;

// The Works in open space, as pictures to judge, with what each frame
// costs to record.
//
//   WORKS_SPACE_OUT=/tmp/works_space flutter test \
//     test/works_space_preview_test.dart --tags preview
//
// Writes home_<zoom>.png (the bay and the press beside home, scavengers
// resting and out), rig_<zoom>.png (an extractor on its planet with its
// miner, the courier on its run), courier.png (a courier halfway home) and
// flows.png (a hopper sent home), and prints the recording time of each
// frame with and without the Works.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/works.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 915.0, _h = 412.0;

void main() {
  final out = Platform.environment['WORKS_SPACE_OUT'];

  testWidgets('the Works in space', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final species = [
      for (final c in json['creatures'] as List)
        Creature.fromJson(c as Map<String, dynamic>),
    ];
    Creature pick(String element, String family) => species.firstWhere(
      (c) =>
          c.types.isNotEmpty &&
          c.types.first == element &&
          (c.mutationFamily ?? '').toLowerCase() == family &&
          c.spriteData != null,
      orElse: () => species.firstWhere(
        (c) => c.types.isNotEmpty && c.types.first == element,
      ),
    );
    CosmicPartyMember member(String id, Creature c) => CosmicPartyMember(
      instanceId: id,
      baseId: c.id,
      displayName: c.name,
      family: c.mutationFamily ?? 'kin',
      element: c.types.first,
      level: 10,
      slotIndex: 0,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 3,
      staminaMax: 3,
      spriteSheet: c.spriteData == null ? null : sheetFromCreature(c),
    );

    late CosmicGame game;
    late CosmicPlanet planet;
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(() async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(_w, _h));
      for (final p in game.world_.planets) {
        p.discovered = true;
      }
      planet = game.world_.planets.firstWhere((p) => p.element == 'Fire');
      // Home a fair way off, so a courier's run crosses open space.
      game.restoreHomePlanet(
        HomePlanet(
          position: planet.position + const Offset(1900, 700),
          activeColor: 'Water',
          sizeTierLevel: 2,
          activeSizeTier: 2,
        ),
      );
      final works = WorksState(
        extractors: {
          'Fire': ExtractorState(
            element: 'Fire',
            updatedMs: now,
            tier: 3,
            miners: ['m0', 'm1'],
            courier: 'c0',
            hopper: 260,
            cycleStartMs: now - 3000,
            cycleMs: 120000,
            cargo: 25,
            delivered: false,
          ),
        },
        bay: ScavengerBayState(
          tier: 3,
          berth: 0,
          crates: [
            const ScavengerFind(elements: {'Fire': 12, 'Ice': 8}),
            const ScavengerFind(elements: {'Water': 20}),
            const ScavengerFind(elements: {'Crystal': 20}, shards: 2),
          ],
        ),
        press: SilverPressState(tier: 2, berth: 1, presser: 'p0', reserve: 100),
        refinery: RefineryState(
          tier: 2,
          berth: 2,
          refiner: 'r0',
          recipe: 'Fire+Water',
        ),
      );
      works.bay.slots[0].instanceId = 's0';
      works.bay.slots[1]
        ..instanceId = 's1'
        ..tripStartMs = now - 20000
        ..tripMs = 240000;
      works.bay.slots[2].instanceId = 's2';
      game.works = works;
      game.setWorksMembers({
        'm0': member('m0', pick('Fire', 'horn')),
        'm1': member('m1', pick('Fire', 'mane')),
        'c0': member('c0', pick('Air', 'wing')),
        's0': member('s0', pick('Earth', 'pip')),
        's1': member('s1', pick('Lightning', 'wing')),
        's2': member('s2', pick('Water', 'let')),
        'p0': member('p0', pick('Earth', 'horn')),
        'r0': member('r0', pick('Crystal', 'kin')),
      });
      game.worksRefining = true;
      game.worksPressIntake = const [Color(0xFFFF6B2B), Color(0xFF2E9BFF)];
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });

    void settle(double seconds) {
      final n = (seconds * 30).round();
      for (var i = 0; i < n; i++) {
        game.update(1 / 30);
      }
    }

    /// Median microseconds to record a frame, after a warm-up.
    int timeFrames() {
      for (var i = 0; i < 6; i++) {
        final rec = ui.PictureRecorder();
        game.render(Canvas(rec));
        rec.endRecording().dispose();
      }
      final times = <int>[];
      for (var i = 0; i < 41; i++) {
        final rec = ui.PictureRecorder();
        final sw = Stopwatch()..start();
        game.render(Canvas(rec));
        rec.endRecording().dispose();
        times.add(sw.elapsedMicroseconds);
      }
      times.sort();
      return times[20];
    }

    Future<void> shoot(String name) async {
      final with_ = timeFrames();
      // Nobody at work: what the buildings alone cost.
      final crew = game.worksMembers;
      game.worksMembers = const {};
      final empty = timeFrames();
      game.worksMembers = crew;
      final saved = game.works;
      game.works = null;
      final none = timeFrames();
      game.works = saved;
      // ignore: avoid_print
      print(
        '$name: ${with_}us with the Works, ${empty}us without its '
        'workers, ${none}us without the Works',
      );

      const dpr = 1.5;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w * dpr, _h * dpr),
        Paint()..color = const Color(0xFF020010),
      );
      canvas.scale(dpr);
      game.render(canvas);
      final pic = rec.endRecording();
      final img = pic.toImageSync((_w * dpr).round(), (_h * dpr).round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
      pic.dispose();
    }

    await tester.runAsync(() async {
      final home = game.homePlanet!.position;
      for (final (zoom, label) in [(0, 'mid'), (1, 'far'), (2, 'close')]) {
        while (game.currentZoomLevel != zoom) {
          game.cycleZoomLevel();
        }
        game.teleportTo(home + const Offset(-60, 200));
        game.enemies.clear();
        settle(0.6);
        await shoot('home_$label');
        game.teleportTo(game.extractorRigPos('Fire')! + const Offset(140, 40));
        game.enemies.clear();
        settle(0.6);
        await shoot('rig_$label');
      }
      while (game.currentZoomLevel != 0) {
        game.cycleZoomLevel();
      }
      // A courier halfway home.
      final x = game.works!.extractors['Fire']!;
      x.cycleStartMs = now - 30000;
      final mid = Offset.lerp(game.extractorRigPos('Fire'), home, 0.45)!;
      game.teleportTo(mid + const Offset(0, 120));
      game.enemies.clear();
      settle(0.5);
      await shoot('courier');
      // A hopper sent home.
      game.teleportTo(game.extractorRigPos('Fire')! + const Offset(500, 300));
      game.enemies.clear();
      game.playHopperSentHome('Fire');
      settle(1.3);
      await shoot('flows');
    });
  });
}
