@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The star chart as a mid-game player sees it, on a phone: each tree at the
// framing it opens on, a close look at a few nodes, and an unlock caught
// mid-pour.
//
//   CONST_OUT=/tmp/constellation flutter test \
//     test/constellation_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['CONST_OUT'];

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

  /// Mid-game: the first three tiers of every tree, which leaves the fourth
  /// unlockable and the rest locked.
  final midGame = {
    for (final s in ConstellationCatalog.allSkills)
      if (s.tier <= 3) s.id,
  };

  Future<void> shoot(
    WidgetTester tester,
    String name,
    ConstellationTree tree, {
    double? zoom,
    String? focus,
    void Function(ConstellationGame g)? before,
    int frames = 30,
    Set<String>? unlocked,
  }) async {
    tester.view.physicalSize = const Size(1248, 1972);
    tester.view.devicePixelRatio = 1248 / 412;
    final key = GlobalKey();
    final game = ConstellationGame(
      selectedTree: tree,
      unlockedSkills: unlocked ?? midGame,
      visibleTrees: ConstellationTree.values.toSet(),
      onSkillTapped: (_) {},
      primaryColor: const Color(0xFFC9A46A),
      secondaryColor: const Color(0xFF8FB8A8),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: GameWidget(game: game),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (focus != null) game.focusOnSkill(focus, zoom: zoom);
    if (zoom != null && focus == null) game.camera.viewfinder.zoom = zoom;
    before?.call(game);
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1248 / 412 / 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('constellation preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    for (final tree in ConstellationTree.values) {
      await shoot(tester, 'tree_${tree.name}', tree);
    }
    // The entrance from home's UPGRADE emblem: the sky alone, then the
    // trees lit from the root out (1.5 s, so ~11 frames a quarter).
    for (final (i, frames) in [1, 11, 22, 33, 46].indexed) {
      await shoot(
        tester,
        'entrance_$i',
        ConstellationTree.breeder,
        before: (g) => g
          ..holdEntrance()
          ..playEntrance(),
        frames: frames,
      );
    }
    await shoot(
      tester,
      'full_extraction',
      ConstellationTree.extraction,
      unlocked: {for (final s in ConstellationCatalog.allSkills) s.id},
    );
    await shoot(
      tester,
      'fresh_breeder',
      ConstellationTree.breeder,
      unlocked: const {},
    );
    // Close on the edge of what is owned: an owned node, the unlockable ones
    // above it, and the locked ones above those.
    final frontier = ConstellationCatalog.forTree(
      ConstellationTree.breeder,
    ).firstWhere((s) => s.tier == 3);
    await shoot(
      tester,
      'close_breeder',
      ConstellationTree.breeder,
      focus: frontier.id,
      zoom: 1.0,
    );
    // An unlock caught mid-pour.
    final next = ConstellationCatalog.forTree(
      ConstellationTree.breeder,
    ).firstWhere((s) => s.tier == 4);
    await shoot(
      tester,
      'unlock_breeder',
      ConstellationTree.breeder,
      focus: frontier.id,
      zoom: 0.9,
      frames: 14,
      before: (g) => g.updateUnlockedSkills({...midGame, next.id}),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
  });
}
