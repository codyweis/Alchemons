@Tags(['preview'])
library;

// The pull of a planet in grains, the home's orbit wake, and the space
// tutorial's coach mark and build warning, rendered to PNGs:
//
//   COSMIC_FIX_OUT=/tmp/cosmic_fix flutter test \
//     test/cosmic_space_fixes_preview_test.dart --tags preview
//
// Without COSMIC_FIX_OUT the tests return at once and pass.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/coach_mark.dart';
import 'package:alchemons/screens/cosmic/widgets/ship_menu_overlay.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:drift/native.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _w = 475.0, _h = 751.0;

void main() {
  final out = Platform.environment['COSMIC_FIX_OUT'];

  testWidgets('gravity rings preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    late CosmicGame game;

    Future<void> shoot(String name) async {
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

    void settle(double s) {
      for (var i = 0; i < (s * 30).round(); i++) {
        game.update(1 / 30);
      }
    }

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
      final planet = game.world_.planets.firstWhere(
        (p) => p.element == 'Water',
      );
      Offset at(double f, double a) =>
          planet.position +
          Offset(cos(a), sin(a)) * planet.particleFieldRadius * f;

      void fly(Offset p) {
        game.teleportTo(p);
        game.enemies.clear();
        game.activeBoss = null;
      }

      // On the edge of the pull, before there is a home: the band shows.
      fly(at(1.0, 0.6));
      settle(1.5);
      await shoot('ring_edge_mid');
      fly(at(1.2, 0.6));
      settle(0.5);
      await shoot('ring_capture_mid');
      game.cycleZoomLevel();
      settle(1);
      await shoot('ring_capture_far');
      fly(at(1.5, 0.6));
      settle(0.5);
      await shoot('ring_capture_edge_far');
      game.cycleZoomLevel();
      game.cycleZoomLevel();
      settle(1);

      // A warmer planet, on its edge.
      final fire = game.world_.planets.firstWhere((p) => p.element == 'Fire');
      fly(
        fire.position +
            Offset(cos(2.2), sin(2.2)) * fire.particleFieldRadius * 1.05,
      );
      settle(0.5);
      await shoot('ring_fire_mid');

      // A home built at 1.2×: it orbits, and leaves its wake.
      fly(at(1.2, 0.6));
      game.buildHomePlanet();
      settle(3);
      fly(game.homePlanet!.position + const Offset(-150, 60));
      settle(6);
      await shoot('home_orbit_wake');
    });
  });

  testWidgets('coach marks and the build warning preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
    }

    late CosmicGame game;
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      await loadFont(
        'monospace',
        '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      );
      await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
      // The HUD's glyphs (AppIcons are Phosphor).
      final phosphor =
          '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
          'phosphoricons_flutter-1.0.0/lib/fonts';
      for (final (family, file) in [
        ('PhosphorBold', 'Phosphor-Bold.ttf'),
        ('PhosphorFill', 'Phosphor-Fill.ttf'),
        ('Phosphor', 'Phosphor.ttf'),
      ]) {
        await loadFont(
          'packages/phosphoricons_flutter/$family',
          '$phosphor/$file',
        );
      }
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(_w, _h));
      final water = game.world_.planets.firstWhere((p) => p.element == 'Water');
      game.teleportTo(
        water.position +
            Offset(cos(0.6), sin(0.6)) * water.particleFieldRadius * 1.1,
      );
      game.enemies.clear();
      for (var i = 0; i < 40; i++) {
        game.update(1 / 30);
      }
    });

    tester.view.physicalSize = const Size(_w * 3, _h * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    Future<void> shoot(String name) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 130));
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final ship = GlobalKey(), map = GlobalKey(), gun = GlobalKey();
    final slot = GlobalKey(), tether = GlobalKey();

    Widget hudButton(Key k, IconData icon, Color accent, {double size = 44}) =>
        CustomPaint(
          key: k,
          painter: BracketFramePainter(
            color: BracketPalette.dark.line.withValues(alpha: 0.52),
            bracketSize: size >= 50 ? 8 : 6,
            strokeWidth: 1.05,
          ),
          child: Container(
            width: size,
            height: size,
            color: BracketPalette.dark.bg0.withValues(alpha: 0.76),
            child: Icon(icon, color: BracketPalette.dark.muted, size: 20),
          ),
        );

    Widget hud(Widget? coach) => Provider.value(
      value: db,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        builder: (context, child) => RepaintBoundary(key: key, child: child!),
        home: Scaffold(
          backgroundColor: const Color(0xFF020010),
          body: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GamePainter(game))),
              Positioned(
                top: 120,
                left: 12,
                child: SafeArea(
                  child: hudButton(
                    map,
                    AppIcons.map_rounded,
                    const Color(0xFFB794F6),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 260,
                child: hudButton(
                  ship,
                  AppIcons.rocket_launch_rounded,
                  const Color(0xFF00E5FF),
                ),
              ),
              Positioned(
                right: 12,
                top: 88,
                child: Column(
                  children: [
                    hudButton(tether, AppIcons.link, const Color(0xFF42A5F5)),
                    const SizedBox(height: 10),
                    hudButton(
                      slot,
                      AppIcons.catching_pokemon,
                      const Color(0xFF00E676),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 20,
                child: hudButton(
                  gun,
                  AppIcons.flash_on_rounded,
                  const Color(0xFF00E5FF),
                  size: 50,
                ),
              ),
              ?coach,
            ],
          ),
        ),
      ),
    );

    for (final (name, coach) in <(String, Widget)>[
      (
        'coach_gun',
        CosmicCoachMark(
          text:
              'Tap the lightning button to switch on auto-fire. Tap it '
              'again to stop.',
          target: gun,
        ),
      ),
      (
        'coach_ship',
        CosmicCoachMark(
          text: 'Tap the ship to open its console and build your home.',
          target: ship,
        ),
      ),
      (
        'coach_map',
        CosmicCoachMark(
          text: 'Open the map to find the signal.',
          target: map,
          accent: const Color(0xFFB794F6),
        ),
      ),
      (
        'coach_slot',
        CosmicCoachMark(
          text:
              "Specials need time to recharge. The number in a slot's "
              'corner is the seconds left.',
          target: slot,
          accent: const Color(0xFF00E676),
        ),
      ),
      (
        'coach_no_target',
        const CosmicCoachMark(
          text:
              'Fly a little way. Your Alchemon follows while the tether is '
              'linked.',
          accent: Color(0xFF9FA8DA),
        ),
      ),
    ]) {
      await tester.pumpWidget(hud(Positioned.fill(child: coach)));
      await shoot(name);
    }

    // The console, docked: inside Water's pull, about to build.
    final water = game.world_.planets.firstWhere((p) => p.element == 'Water');
    for (final (name, hasHome) in [
      ('console_build_in_pull', false),
      ('console_move_in_pull', true),
    ]) {
      await tester.pumpWidget(
        hud(
          Positioned.fill(
            child: ShipMenuOverlay(
              hasHomePlanet: hasHome,
              pullPlanet: water,
              onFlyElsewhere: () {},
              tutorialBuildHomeMode: !hasHome,
              meterFill: 0.4,
              walletShards: 80,
              shipHealth: 90,
              shipMaxHealth: 100,
              fuelFraction: 0.6,
              activeWeaponName: 'STANDARD GUN',
              orbitalStockpile: 0,
              orbitalActive: 0,
              hasBooster: false,
              hasOrbitals: false,
              hasMissiles: false,
              missileAmmo: 0,
              cargoLevel: 0,
              isNearHome: false,
              onClose: () {},
              onBuildHome: () {},
              onRelocateHome: () {},
              onJettisonCargo: () {},
              onDumpWallet: () {},
              onRefuel: () {},
              onCraftMissiles: () {},
              onCraftSentinels: () {},
              onUpgradeCargo: () {},
            ),
          ),
        ),
      );
      await shoot(name);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.game);
  final CosmicGame game;
  @override
  void paint(Canvas canvas, Size size) => game.render(canvas);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
