@Tags(['preview'])
library;

// THE LOOK LINEUP. Every point of interest and contest arena in open space at
// the closest zoom, each contest mid-cinematic with its overlay on top, and a
// few of the rebuilt pieces (rift, Nexus, home black hole) as the yardstick —
// for judging what has fallen behind the rest of the art.
//
//   LINEUP_OUT=/tmp/lineup flutter test \
//     test/cosmic_look_lineup_preview_test.dart --tags preview

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/contest_arena_overlays.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:provider/provider.dart';

// Space is played in portrait; LINEUP_LANDSCAPE=1 turns the phone.
final bool _landscape = Platform.environment['LINEUP_LANDSCAPE'] != null;
final double _w = _landscape ? 915.0 : 412.0;
final double _h = _landscape ? 412.0 : 915.0;
const double _dpr = 2.0;
final String? _only = Platform.environment['LINEUP_ONLY'];

CosmicPartyMember _member(
  String family,
  String element,
  int slot, {
  Creature? species,
}) => CosmicPartyMember(
      instanceId: '$family-$element-$slot',
      baseId: '${family.substring(0, 3).toUpperCase()}01',
      displayName: slot < 0 ? 'Cinderwick' : (species?.name ?? '$element $family'),
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 5,
      staminaMax: 5,
      spriteSheet: species == null ? null : sheetFromCreature(species),
    );

void main() {
  final out = Platform.environment['LINEUP_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    final home = Platform.environment['HOME'];
    const ph = 'hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/.pub-cache/$ph/Phosphor-Bold.ttf',
    );
  });

  testWidgets('cosmic look lineup', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = Size(_w * _dpr, _h * _dpr);
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);

    late CosmicGame game;
    await tester.runAsync(() async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(_w, _h));
      // mid → far → close
      game.cycleZoomLevel();
      game.cycleZoomLevel();
      for (var i = 0; i < 20; i++) {
        game.update(1 / 30);
      }
    });

    void settle(double s) {
      for (var i = 0; i < (s * 30).round(); i++) {
        game.update(1 / 30);
        game.shipHealth = CosmicBalance.shipMaxHealth;
      }
    }

    void flyTo(Offset p, {Offset off = const Offset(-150, 30)}) {
      game.teleportTo(p + off);
      game.enemies.clear();
      game.activeBoss = null;
    }

    ui.Image frame() {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, _w * _dpr, _h * _dpr),
        Paint()..color = const Color(0xFF020010),
      );
      c.scale(_dpr);
      game.render(c);
      final pic = rec.endRecording();
      final img = pic.toImageSync((_w * _dpr).round(), (_h * _dpr).round());
      pic.dispose();
      return img;
    }

    Future<void> save(ui.Image img, String name) async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Future<void> shoot(String name) async {
      if (_only != null && !name.contains(_only!)) return;
      await tester.runAsync(() async {
        final img = frame();
        await save(img, name);
        img.dispose();
      });
    }

    /// The game frame with a widget overlay pumped on top of it.
    Future<void> shootWithOverlay(String name, Widget overlay) async {
      if (_only != null && !name.contains(_only!)) return;
      late ui.Image bg;
      await tester.runAsync(() async => bg = frame());
      final key = GlobalKey();
      await tester.pumpWidget(
        Provider<FactionTheme>.value(
          value: FactionTheme.scorchForge(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: RepaintBoundary(
              key: key,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RawImage(image: bg, fit: BoxFit.fill),
                  ),
                  Positioned.fill(child: overlay),
                ],
              ),
            ),
          ),
        ),
      );
      Future<void> grab(String suffix) => tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: _dpr);
        await save(img, '$name$suffix');
        img.dispose();
      });
      // Mid-judging, then the result.
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await grab('_judging');
      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await grab('_result');
      await tester.pumpWidget(const SizedBox());
      // Let the overlay's own timers run out before the next one.
      await tester.pump(const Duration(seconds: 30));
    }

    final world = game.world_;

    // ── points of interest, one of each ──
    final seen = <POIType>{};
    for (final poi in game.spacePOIs) {
      if (!seen.add(poi.type)) continue;
      poi.discovered = true;
      flyTo(poi.position);
      settle(0.8);
      flyTo(poi.position);
      game.update(1 / 30);
      await shoot('poi_${poi.type.name}');
    }

    // ── landmarks ──
    flyTo(world.bloodRing.position, off: const Offset(0, 470));
    settle(1);
    await shoot('landmark_blood_ring');
    flyTo(world.elementalNexus.position, off: const Offset(0, 520));
    settle(1);
    await shoot('ref_elemental_nexus');
    flyTo(world.prismaticField.position, off: const Offset(-60, 40));
    settle(1);
    await shoot('landmark_prismatic');
    flyTo(world.riftPortals.first.position);
    settle(1);
    await shoot('ref_rift_portal');
    flyTo(game.galaxyWhirls.first.position, off: const Offset(0, 300));
    settle(0.5);
    await shoot('landmark_galaxy_whirl');
    flyTo(game.elementalCacheField.caches.first.position);
    settle(1);
    await shoot('landmark_elemental_cache');
    if (game.bossLairs.isNotEmpty) {
      flyTo(game.bossLairs.first.position, off: const Offset(0, -340));
      settle(0.3);
      await shoot('landmark_boss_lair');
    }

    // ── contest arenas at rest ──
    final arenas = <CosmicContestTrait, CosmicContestArena>{};
    for (final a in world.contestArenas) {
      arenas.putIfAbsent(a.trait, () => a);
    }
    for (final e in arenas.entries) {
      flyTo(e.value.position, off: const Offset(-200, 30));
      settle(1);
      await shoot('contest_${e.key.name}_arena');
    }

    // ── each contest, mid-cinematic, with its overlay ──
    final catalog = await tester.runAsync(() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      return CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
    });
    ContestJudging judgingFor(CosmicContestTrait trait) {
      final rival = kCosmicContestLevels[trait]![1].opponent;
      final v = judgeEntrant(
        trait,
        2,
        const ContestEntrant(
          name: 'Airwing',
          element: 'Air',
          family: 'wing',
          statRating: 3.6,
        ),
        rivalElement: rival.element,
      );
      return ContestJudging(
        condition: contestCondition(trait, 2),
        player: v,
        rival: judgeRival(trait, 2, rival),
        playerStat: '${trait.label.toUpperCase()} 312',
        rivalStat: 'LEVEL 2 RIVAL',
      );
    }

    final player = _member(
      'Wing',
      'Air',
      0,
      species: catalog!.getCreatureById('WNG04'),
    );
    final rival = _member(
      'Horn',
      'Fire',
      -1,
      species: catalog.getCreatureById('HOR01'),
    );
    for (final e in arenas.entries) {
      flyTo(e.value.position, off: const Offset(-40, 0));
      game.summonCompanion(player, slotIndex: 0);
      // Let the sprite sheets load.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      settle(0.5);
      final at = e.value.position;
      switch (e.key) {
        case CosmicContestTrait.beauty:
          game.beginBeautyContestCinematic(
            opponentMember: rival,
            arenaCenter: at,
            playerWon: true,
          );
        case CosmicContestTrait.speed:
          game.beginSpeedContestCinematic(
            opponentMember: rival,
            arenaCenter: at,
            playerWon: true,
            playerScore: 4.31,
            opponentScore: 3.87,
          );
        case CosmicContestTrait.strength:
          game.beginStrengthContestCinematic(
            opponentMember: rival,
            arenaCenter: at,
            playerWon: true,
            playerScore: 4.31,
            opponentScore: 3.87,
          );
        case CosmicContestTrait.intelligence:
          game.beginIntelligenceContestCinematic(
            opponentMember: rival,
            arenaCenter: at,
            playerWon: true,
            playerScore: 4.31,
            opponentScore: 3.87,
          );
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      settle(1.6);
      await shoot('contest_${e.key.name}_cinematic_1');
      settle(1.8);
      await shoot('contest_${e.key.name}_cinematic_2');
      settle(3.0);
      await shoot('contest_${e.key.name}_cinematic_3');
      final overlay = switch (e.key) {
        CosmicContestTrait.beauty => CosmicBeautyContestArenaOverlay(
          player: player,
          opponentMember: rival,
          playerScore: 4.31,
          opponentScore: 3.87,
          stakes: const ContestStakes(level: 2, levels: 5, shards: 35, gold: 2),
          judging: judgingFor(e.key),
        ),
        CosmicContestTrait.speed => CosmicSpeedContestArenaOverlay(
          player: player,
          opponentMember: rival,
          playerScore: 4.31,
          opponentScore: 3.87,
          stakes: const ContestStakes(level: 2, levels: 5, shards: 35, gold: 2),
          judging: judgingFor(e.key),
        ),
        CosmicContestTrait.strength => CosmicStrengthContestArenaOverlay(
          player: player,
          opponentMember: rival,
          playerScore: 4.31,
          opponentScore: 3.87,
          stakes: const ContestStakes(level: 2, levels: 5, shards: 35, gold: 2),
          judging: judgingFor(e.key),
        ),
        CosmicContestTrait.intelligence =>
          CosmicIntelligenceContestArenaOverlay(
            player: player,
            opponentMember: rival,
            playerScore: 4.31,
            opponentScore: 3.87,
            stakes: const ContestStakes(
              level: 2,
              levels: 5,
              shards: 35,
              gold: 2,
            ),
            judging: judgingFor(e.key),
          ),
      };
      await shootWithOverlay('contest_${e.key.name}_overlay', overlay);
      game.endBeautyContestCinematic();
      game.returnCompanion();
      settle(0.3);
    }

    // ── yardstick: the home black hole ──
    flyTo(
      Offset(world.worldSize.width * 0.31, world.worldSize.height * 0.69),
      off: Offset.zero,
    );
    game.restoreHomePlanet(
      HomePlanet(
        position: game.ship.pos + const Offset(230, 10),
        activeColor: 'Water',
        sizeTierLevel: 3,
        activeSizeTier: 3,
      ),
    );
    game.activeCustomizations = {'black_hole'};
    settle(0.5);
    game.homePlanet!.position = game.ship.pos + const Offset(230, 10);
    game.update(1 / 60);
    await shoot('ref_home_black_hole');
  });
}
