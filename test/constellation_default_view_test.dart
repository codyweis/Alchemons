// The screen used to open at zoom 1.0 on whichever tree happened to be
// selected, so you landed inside one branch with no sense of the chart. It now
// opens framed on everything visible.
//
// The zoom is measured from the nodes rather than fixed: the three trees span
// ~2500 world units, and no constant frames both that and a new player's
// single tree.

import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ConstellationGame> _boot(
  WidgetTester tester, {
  Set<ConstellationTree>? visible,
  Size size = const Size(1080, 2100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final game = ConstellationGame(
    selectedTree: ConstellationTree.breeder,
    unlockedSkills: {for (final s in ConstellationCatalog.allSkills) s.id},
    visibleTrees: visible ?? ConstellationTree.values.toSet(),
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
  testWidgets('opens zoomed out, not at full zoom on one tree', (tester) async {
    final game = await _boot(tester);
    expect(
      game.camera.viewfinder.zoom,
      lessThan(0.5),
      reason: 'it used to open at 1.0 inside a single branch',
    );
  });

  testWidgets('frames every visible tree, nothing cropped', (tester) async {
    final game = await _boot(tester);
    final zoom = game.camera.viewfinder.zoom;
    final centre = game.camera.viewfinder.position;
    final viewW = game.size.x / zoom;
    final viewH = game.size.y / zoom;

    // Tree anchors, which sit inside their own node clusters.
    const anchors = {
      'breeder': Offset(0, -600),
      'combat': Offset(-700, 400),
      'extraction': Offset(700, 400),
    };
    for (final entry in anchors.entries) {
      expect(
        (entry.value.dx - centre.x).abs(),
        lessThan(viewW / 2),
        reason: '${entry.key} is off screen horizontally',
      );
      expect(
        (entry.value.dy - centre.y).abs(),
        lessThan(viewH / 2),
        reason: '${entry.key} is off screen vertically',
      );
    }
  });

  testWidgets('a single visible tree is framed closer than three', (
    tester,
  ) async {
    // A new player has only the breeder tree. Framing all three anyway would
    // open on empty space.
    final one = await _boot(tester, visible: {ConstellationTree.breeder});
    final oneZoom = one.camera.viewfinder.zoom;
    final all = await _boot(tester);
    expect(oneZoom, greaterThan(all.camera.viewfinder.zoom));
  });

  testWidgets('the framing zoom is reachable by pinching out', (tester) async {
    // The default must sit inside the manual zoom range, or the player can
    // never get back to the view they started on.
    final game = await _boot(tester);
    expect(
      game.camera.viewfinder.zoom,
      greaterThanOrEqualTo(ConstellationGame.minZoom),
    );
  });

  testWidgets('re-framing is idempotent', (tester) async {
    final game = await _boot(tester);
    final zoom = game.camera.viewfinder.zoom;
    final pos = game.camera.viewfinder.position.clone();
    game.frameVisibleTrees();
    expect(game.camera.viewfinder.zoom, closeTo(zoom, 1e-6));
    expect(game.camera.viewfinder.position.x, closeTo(pos.x, 1e-6));
    expect(game.camera.viewfinder.position.y, closeTo(pos.y, 1e-6));
  });
}
