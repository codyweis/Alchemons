// The screen used to open at zoom 1.0 positioned on the selected tree, which
// drops the camera into the middle of a branch.
//
// It now frames the tree's own nodes, with a readability floor. The branches
// are very different sizes: breeder fits whole at 0.51, extraction at 0.40,
// but combat's arms are three times breeder's width and fitting them needs
// 0.17 — where the nodes are specks. So a very wide tree is floored and its
// arms run off the sides instead, which is fine: they are a straight line of
// nodes and panning along them is easy.

import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ConstellationGame> _boot(
  WidgetTester tester, {
  ConstellationTree selected = ConstellationTree.breeder,
  Size size = const Size(1080, 2100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final game = ConstellationGame(
    selectedTree: selected,
    unlockedSkills: {for (final s in ConstellationCatalog.allSkills) s.id},
    visibleTrees: ConstellationTree.values.toSet(),
    onSkillTapped: (_) {},
    primaryColor: const Color(0xFF4DA3FF),
    secondaryColor: const Color(0xFFE8DCC8),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameWidget(game: game)),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
  return game;
}

void main() {
  testWidgets('opens zoomed out, not at full zoom inside the tree', (
    tester,
  ) async {
    final game = await _boot(tester);
    expect(
      game.camera.viewfinder.zoom,
      lessThan(1.0),
      reason: 'it used to open at 1.0 in the middle of a branch',
    );
  });

  group('framing', () {
    for (final tree in ConstellationTree.values) {
      testWidgets('${tree.name} is centred on its own nodes', (tester) async {
        final game = await _boot(tester, selected: tree);
        final bounds = game.treeBoundsForTest(tree)!;
        final centre = game.camera.viewfinder.position;
        expect(centre.x, closeTo(bounds.center.dx, 1.0));
        expect(centre.y, closeTo(bounds.center.dy, 1.0));
      });

      testWidgets('${tree.name} is never cut off vertically', (tester) async {
        // Height is the axis that matters — a tree running off the top or
        // bottom reads as broken, where arms running off the sides read as
        // something to pan along.
        final game = await _boot(tester, selected: tree);
        final bounds = game.treeBoundsForTest(tree)!;
        final halfH = game.size.y / game.camera.viewfinder.zoom / 2;
        final centre = game.camera.viewfinder.position;
        expect(
          (bounds.top - centre.y).abs(),
          lessThan(halfH),
          reason: '${tree.name} is cut off vertically',
        );
      });
    }

    testWidgets('trees that fit are shown whole', (tester) async {
      for (final tree in [
        ConstellationTree.breeder,
        ConstellationTree.extraction,
      ]) {
        final game = await _boot(tester, selected: tree);
        final bounds = game.treeBoundsForTest(tree)!;
        final halfW = game.size.x / game.camera.viewfinder.zoom / 2;
        final centre = game.camera.viewfinder.position;
        expect(
          (bounds.left - centre.x).abs(),
          lessThan(halfW),
          reason: '${tree.name} is cut off horizontally',
        );
      }
    });

    testWidgets('a tree too wide to fit stays readable rather than fitting', (
      tester,
    ) async {
      final game = await _boot(tester, selected: ConstellationTree.combat);
      expect(
        game.camera.viewfinder.zoom,
        closeTo(ConstellationGame.minFramingZoom, 1e-6),
        reason: 'combat should sit on the readability floor, not below it',
      );
    });

    testWidgets('framing never zooms in past a full-size tree', (tester) async {
      for (final tree in ConstellationTree.values) {
        final game = await _boot(tester, selected: tree);
        expect(game.camera.viewfinder.zoom, lessThanOrEqualTo(1.0));
      }
    });
  });

  testWidgets('a wide tree frames further out than a narrow one', (
    tester,
  ) async {
    // combat's arms span roughly three times breeder's width, so a single
    // constant cannot serve both.
    final breeder = await _boot(tester, selected: ConstellationTree.breeder);
    final breederZoom = breeder.camera.viewfinder.zoom;
    final combat = await _boot(tester, selected: ConstellationTree.combat);
    expect(combat.camera.viewfinder.zoom, lessThan(breederZoom));
  });

  testWidgets('the framing zoom is reachable by pinching out', (tester) async {
    // The default must sit inside the manual zoom range, or the player can
    // never get back to the view they started on. The floor was 0.2, which
    // clipped combat.
    for (final tree in ConstellationTree.values) {
      final game = await _boot(tester, selected: tree);
      expect(
        game.camera.viewfinder.zoom,
        greaterThanOrEqualTo(ConstellationGame.minZoom),
        reason: tree.name,
      );
    }
  });

  testWidgets('re-framing is idempotent', (tester) async {
    final game = await _boot(tester);
    final zoom = game.camera.viewfinder.zoom;
    final pos = game.camera.viewfinder.position.clone();
    game.frameTree(ConstellationTree.breeder);
    expect(game.camera.viewfinder.zoom, closeTo(zoom, 1e-6));
    expect(game.camera.viewfinder.position.x, closeTo(pos.x, 1e-6));
    expect(game.camera.viewfinder.position.y, closeTo(pos.y, 1e-6));
  });
}
