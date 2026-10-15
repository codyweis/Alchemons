@Tags(['preview'])
library;

// The Works round home, as pictures: every berth at once round a Medium and
// a Huge home (wearing rings and a moon, so the buildings can be seen to
// stand clear of what it wears), each building close up with its worker,
// and an extractor on its planet.
//
//   WORKS_RING_OUT=/tmp/works_ring flutter test \
//     test/works_home_ring_preview_test.dart --tags preview

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

void main() {
  final out = Platform.environment['WORKS_RING_OUT'];

  testWidgets('the Works round home', (tester) async {
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
    late CosmicPlanet fire;
    final now = DateTime.now().millisecondsSinceEpoch;

    WorksState works() {
      final w = WorksState(
        extractors: {
          'Fire': ExtractorState(
            element: 'Fire',
            updatedMs: now,
            tier: 3,
            miners: ['m0', 'm1'],
            courier: 'c0',
            hopper: 380,
            cycleStartMs: now - 2000,
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
            const ScavengerFind(elements: {'Plant': 20}),
          ],
        ),
        press: SilverPressState(tier: 2, berth: 1, presser: 'p0'),
        refinery: RefineryState(
          tier: 2,
          berth: 2,
          refiner: 'r0',
          recipe: 'Air+Fire',
        ),
        armory: ArmoryState(tier: 2, berth: 3),
      );
      w.bay.slots[0].instanceId = 's0';
      w.bay.slots[1].instanceId = 's2';
      return w;
    }

    Future<void> boot(Size screen, int sizeTier) async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(screen.width, screen.height));
      for (final p in game.world_.planets) {
        p.discovered = true;
      }
      fire = game.world_.planets.firstWhere((p) => p.element == 'Fire');
      game.restoreHomePlanet(
        HomePlanet(
          position: fire.position + const Offset(4200, 1600),
          activeColor: 'Water',
          sizeTierLevel: sizeTier,
          activeSizeTier: sizeTier,
        ),
      );
      game.activeCustomizations = {'planetary_rings', 'orbiting_moon'};
      game.activeShipSkin = 'skin_solar';
      game.works = works();
      game.setWorksMembers({
        'm0': member('m0', pick('Fire', 'horn')),
        'm1': member('m1', pick('Fire', 'mane')),
        'c0': member('c0', pick('Air', 'wing')),
        's0': member('s0', pick('Earth', 'pip')),
        's2': member('s2', pick('Water', 'let')),
        'p0': member('p0', pick('Earth', 'horn')),
        'r0': member('r0', pick('Crystal', 'kin')),
      });
      game.worksPressIntake = const [Color(0xFFFF6B2B), Color(0xFF2E9BFF)];
      game.worksRefining = true;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }

    void zoom(int index) {
      while (game.currentZoomLevel != index) {
        game.cycleZoomLevel();
      }
    }

    void settle(double seconds) {
      final n = (seconds * 30).round();
      for (var i = 0; i < n; i++) {
        game.update(1 / 30);
      }
    }

    Future<void> shoot(String name, Size screen) async {
      const dpr = 2.0;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, screen.width * dpr, screen.height * dpr),
        Paint()..color = const Color(0xFF020010),
      );
      canvas.scale(dpr);
      game.render(canvas);
      final pic = rec.endRecording();
      final img = pic.toImageSync(
        (screen.width * dpr).round(),
        (screen.height * dpr).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
      pic.dispose();
    }

    void flyTo(Offset p) {
      game.teleportTo(p);
      game.enemies.clear();
      game.activeBoss = null;
    }

    await tester.runAsync(() async {
      // Every berth at once: a tall view, pulled all the way back.
      for (final (name, tier, ring) in [
        ('ring_medium', 2, const Size(1100, 760)),
        ('ring_huge', 4, const Size(1400, 1150)),
      ]) {
        await boot(ring, tier);
        zoom(2);
        final home = game.homePlanet!;
        flyTo(home.position + Offset(0, home.visualRadius + 70));
        settle(1.2);
        await shoot(name, ring);
      }

      // Each building close up, a Medium home behind it.
      const close = Size(915, 412);
      await boot(close, 2);
      zoom(0);
      for (final (name, at) in [
        ('close_bay', game.worksBayPos!),
        ('close_press', game.worksPressPos!),
        ('close_refinery', game.worksRefineryPos!),
        ('close_armory', game.worksArmoryPos!),
      ]) {
        flyTo(at + const Offset(-230, 20));
        settle(0.8);
        await shoot(name, close);
      }

      // An extractor on its planet, its courier just setting off home.
      zoom(1);
      flyTo(game.extractorRigPos('Fire')! + const Offset(260, 60));
      settle(0.8);
      await shoot('close_extractor', close);
    });
  });
}
