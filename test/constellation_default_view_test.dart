// The screen used to open at zoom 1.0 positioned on the selected tree, which
// drops the camera into the middle of a branch. It now frames that tree so all
// of it is on screen.
//
// The zoom is measured from the tree's own nodes rather than fixed: the
// branches are very different sizes — breeder fits at 0.51, combat needs 0.17
// — and any constant that shows all of one shows only part of another.

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
    MaterialApp(home: Scaffold(body: GameWidget(game: game))),
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

  group('every tree is framed whole', () {
    for (final tree in ConstellationTree.values) {
      testWidgets('${tree.name} fits on screen', (tester) async {
        final game = await _boot(tester, selected: tree);
        final zoom = game.camera.viewfinder.zoom;
        final centre = game.camera.viewfinder.position;
        final halfW = game.size.x / zoom / 2;
        final halfH = game.size.y / zoom / 2;

        final bounds = game.treeBoundsForTest(tree);
        expect(bounds, isNotNull, reason: '${tree.name} has no nodes');
        expect(
          (bounds!.left - centre.x).abs() < halfW &&
              (bounds.right - centre.x).abs() < halfW,
          isTrue,
          reason: '${tree.name} is cut off horizontally',
        );
        expect(
          (bounds.top - centre.y).abs() < halfH &&
              (bounds.bottom - centre.y).abs() < halfH,
          isTrue,
          reason: '${tree.name} is cut off vertically',
        );
      });
    }
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
