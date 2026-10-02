@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/customization_menu_overlay.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The customization lab as a mid-game player sees it, on a phone, with the
// real home planet painter behind its stage and pictures: both tabs, each
// drawn full length too, and the dock open on a few things.
//
//   LAB_OUT=/tmp/lab flutter test \
//     test/customization_lab_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['LAB_OUT'];

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
    await loadFont(
      'MaterialIcons',
      '/Users/codyweisenberger/Documents/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  });

  HomeCustomizationState state() => HomeCustomizationState(
    unlockedIds: {
      'equip_machinegun',
      'equip_orbitals',
      'storm_bolts',
      'skin_phantom',
      'skin_solar',
      'refuel_station',
      'sentinel_station',
      'dust_storm',
      'planetary_rings',
      'spirit_wisps',
      'flame_ring',
    },
    activeIds: {
      'equip_machinegun',
      'equip_orbitals',
      'storm_bolts',
      'skin_phantom',
      'refuel_station',
      'planetary_rings',
    },
    ammoUpgradeLevel: 2,
    missileUpgradeLevel: 1,
    fuelUpgradeLevel: 1,
  );

  final storage = ElementStorage(
    stored: const {
      'Fire': 640,
      'Water': 310,
      'Lightning': 220,
      'Earth': 140,
      'Air': 95,
      'Ice': 60,
      'Dark': 30,
      'Plant': 120,
    },
  );

  HomePlanet planet() => HomePlanet(
    position: Offset.zero,
    astralBank: 820,
    sizeTierLevel: 2,
    activeSizeTier: 2,
    activeColor: 'Water',
    unlockedColors: {'Water', 'Fire'},
  );

  for (final (name, tab, height, tapKey) in [
    ('ship_phone', 0, 844.0, null),
    ('home_phone', 1, 844.0, null),
    ('ship_full', 0, 1500.0, null),
    ('home_full', 1, 1900.0, null),
    ('ship_dock_hull', 0, 844.0, 'lab.hull.skin_solar'),
    ('ship_dock_ammo', 0, 844.0, 'lab.recipe.storm_bolts'),
    ('home_dock_effect', 1, 844.0, 'lab.recipe.planetary_rings'),
    ('home_dock_locked', 1, 844.0, 'lab.recipe.black_hole'),
    ('home_dock_color', 1, 844.0, 'lab.color.Void'),
  ]) {
    testWidgets('lab preview $name', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      tester.view.physicalSize = Size(390 * 3, height * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final home = planet();
      final game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await tester.runAsync(game.onLoad);
      game.onGameResize(Vector2(390, 844));
      game.restoreHomePlanet(home);

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFF05060A),
            body: CustomizationMenuOverlay(
              customizationState: state(),
              elementStorage: storage,
              homePlanet: home,
              onTryRecipe: (_) {},
              onToggleRecipe: (_) {},
              onOptionChanged: (_, _, _) {},
              onUpgradeSize: () {},
              onSelectSize: (_) {},
              onUnlockColor: (_) {},
              onSelectColor: (_) {},
              onClose: () {},
              cargoLevel: 1,
              isNearHome: true,
              onUpgradeCargo: () {},
              onChambers: () {},
              onUpgradePowerUp: (_) {},
              onGarrison: () {},
              garrisonStationed: 1,
              garrisonSlots: 3,
              initialTab: tab,
              canPreview: true,
              onPreview: () {},
              paintHome: game.paintHomeShowcase,
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (tapKey != null) {
        final target = find.byKey(ValueKey(tapKey));
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
