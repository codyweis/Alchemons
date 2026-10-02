// The star chart's behaviour as the 2026-10 redesign left it: an unlock is a
// pour of grains down the link that ignites the stone when it lands, the
// chart's verse is kept on screen and out from under the chrome, and every
// skill wears an inked glyph rather than a font icon.
//
// Behaviour, not looks — test/constellation_preview_test.dart renders it.

import 'package:alchemons/games/constellations/constellation_art.dart';
import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ConstellationGame> _boot(
  WidgetTester tester,
  Set<String> unlocked, {
  EdgeInsets insets = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = const Size(1080, 2100);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final game = ConstellationGame(
    selectedTree: ConstellationTree.breeder,
    unlockedSkills: unlocked,
    visibleTrees: ConstellationTree.values.toSet(),
    onSkillTapped: (_) {},
    primaryColor: const Color(0xFF4DA3FF),
    secondaryColor: const Color(0xFFE8DCC8),
  )..chartInsets = insets;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameWidget(game: game)),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return game;
}

void main() {
  final breeder = ConstellationCatalog.forTree(ConstellationTree.breeder);
  final root = breeder.firstWhere((s) => s.tier == 1);
  final child = breeder.firstWhere(
    (s) => s.prerequisites.length == 1 && s.prerequisites.first == root.id,
  );

  testWidgets('an unlocked stone ignites when the pour reaches it', (
    tester,
  ) async {
    final game = await _boot(tester, {root.id});
    final node = game.nodes.firstWhere((n) => n.skill.id == child.id);
    expect(node.showsOwned, isFalse);

    game.updateUnlockedSkills({root.id, child.id});
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      node.showsOwned,
      isFalse,
      reason: 'it lights when the grains arrive, not the moment it is bought',
    );

    final link = game.connections.firstWhere((c) => c.to == node);
    expect(link.isPouring, isTrue);

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(node.showsOwned, isTrue);
    expect(link.isPouring, isFalse);
  });

  testWidgets('a stone already owned when the chart opens is lit at once', (
    tester,
  ) async {
    final game = await _boot(tester, {root.id, child.id});
    final node = game.nodes.firstWhere((n) => n.skill.id == child.id);
    expect(node.showsOwned, isTrue);
  });

  group('verse is kept on the chart', () {
    testWidgets('a plate hanging off the edge is moved inside', (tester) async {
      final game = await _boot(
        tester,
        const {},
        insets: const EdgeInsets.only(top: 170, bottom: 90),
      );
      final view = game.camera.visibleWorldRect;
      final zoom = game.camera.viewfinder.zoom;
      // Half off the right edge, and under the header.
      final plate = Rect.fromCenter(
        center: Offset(view.right, view.top + 20 / zoom),
        width: 200,
        height: 60,
      );
      final kept = game.keepOnChart(plate)!;
      expect(kept.size, plate.size);
      expect(kept.right, lessThanOrEqualTo(view.right));
      expect(
        kept.top,
        greaterThanOrEqualTo(view.top + 170 / zoom),
        reason: 'never under the header',
      );
    });

    testWidgets("another tree's verse is not dragged on screen", (
      tester,
    ) async {
      final game = await _boot(tester, const {});
      final view = game.camera.visibleWorldRect;
      final far = Rect.fromCenter(
        center: view.center + Offset(view.width * 3, 0),
        width: 200,
        height: 60,
      );
      expect(game.keepOnChart(far), isNull);
    });
  });

  testWidgets('framing leaves the tree clear of the chrome', (tester) async {
    const insets = EdgeInsets.only(top: 170, bottom: 90);
    final game = await _boot(tester, const {}, insets: insets);
    final bounds = game.treeBoundsForTest(ConstellationTree.breeder)!;
    final view = game.camera.visibleWorldRect;
    final zoom = game.camera.viewfinder.zoom;
    expect(bounds.top, greaterThanOrEqualTo(view.top + insets.top / zoom - 1));
    expect(
      bounds.bottom,
      lessThanOrEqualTo(view.bottom - insets.bottom / zoom + 1),
    );
  });

  test('every skill has an inked glyph that fits its table', () {
    for (final skill in ConstellationCatalog.allSkills) {
      final b = sigilPath(sigilFor(skill)).getBounds();
      expect(b.isEmpty, isFalse, reason: skill.id);
      expect(b.left, greaterThanOrEqualTo(-1.05), reason: skill.id);
      expect(b.right, lessThanOrEqualTo(1.05), reason: skill.id);
      expect(b.top, greaterThanOrEqualTo(-1.05), reason: skill.id);
      expect(b.bottom, lessThanOrEqualTo(1.05), reason: skill.id);
    }
  });

  test('every tree has its own light', () {
    final lights = {
      for (final t in ConstellationTree.values) treeLight(t).essence,
    };
    expect(lights.length, ConstellationTree.values.length);
  });
}
