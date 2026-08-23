// The constellation screen was the jankiest surface in the game: with a filled
// tree it recorded ~1360 drawPath calls and 72 MaskFilter.blur draws a frame,
// and the starfield issued a drawCircle per visible star — so zooming out (25x
// the visible area) made it worse exactly while the player was panning.
//
// These are budget tests, not golden tests. They do not care what it looks
// like; they care that nobody reintroduces per-frame blur passes, per-particle
// Path allocation, or unbatched star drawing.

import 'package:alchemons/games/constellations/constellation_game.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get(String k) => counts[k] ?? 0;
}

Future<_CensusCanvas> _census(
  WidgetTester tester, {
  required Set<String> unlocked,
  required double zoom,
}) async {
  final game = ConstellationGame(
    selectedTree: ConstellationTree.breeder,
    unlockedSkills: unlocked,
    visibleTrees: ConstellationTree.values.toSet(),
    onSkillTapped: (_) {},
    primaryColor: const Color(0xFF4DA3FF),
    secondaryColor: const Color(0xFFE8DCC8),
  );
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: GameWidget(game: game))),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  game.camera.viewfinder.zoom = zoom;
  await tester.pump(const Duration(milliseconds: 16));

  final canvas = _CensusCanvas();
  game.renderTree(canvas as Canvas);
  return canvas;
}

void main() {
  final allSkills = {for (final s in ConstellationCatalog.allSkills) s.id};

  testWidgets('a filled tree never asks for a blur pass per connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final c = await _census(tester, unlocked: allSkills, zoom: 1.0);
    // Was 72: two MaskFilter.blur draws for every active connection line.
    // Each one is its own GPU filter pass.
    expect(
      c.blurredDraws,
      lessThanOrEqualTo(8),
      reason: 'blurred draws are the most expensive thing on this screen',
    );
  });

  testWidgets('node particles and accents are batched, not per-shape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final c = await _census(tester, unlocked: allSkills, zoom: 1.0);
    // 43 nodes once cost 43*(12 particles*2 + 6 accents) = ~1290 paths, each
    // with a freshly allocated Path AND Paint.
    expect(
      c.get('drawPath'),
      lessThan(500),
      reason: 'particles must stay bucketed and accents must stay cached',
    );
  });

  testWidgets('the starfield cost does not scale with how far you zoom out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Zooming from 1.0 to the 0.2 minimum reveals ~25x the world area. When
    // every star was its own drawCircle that took the field from ~90 draws to
    // ~1700 — right when the player is panning and least able to absorb it.
    final near = await _census(tester, unlocked: const {}, zoom: 1.0);
    final far = await _census(tester, unlocked: const {}, zoom: 0.2);

    expect(far.get('drawCircle'), lessThan(40));
    expect(
      far.get('drawRawPoints'),
      lessThanOrEqualTo(24),
      reason: 'stars are bucketed by size and brightness, at most 4*6 buckets',
    );
    // The whole point: far must not cost meaningfully more than near.
    final nearTotal = near.get('drawCircle') + near.get('drawRawPoints');
    final farTotal = far.get('drawCircle') + far.get('drawRawPoints');
    expect(farTotal, lessThan(nearTotal + 20));
  });

  testWidgets('re-applying identical skill state rebuilds nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final game = ConstellationGame(
      selectedTree: ConstellationTree.breeder,
      unlockedSkills: allSkills,
      visibleTrees: ConstellationTree.values.toSet(),
      onSkillTapped: (_) {},
      primaryColor: const Color(0xFF4DA3FF),
      secondaryColor: const Color(0xFFE8DCC8),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The screen calls this from inside two StreamBuilders, so it runs on
    // every tick. It used to re-allocate radial gradient shaders for all 43
    // nodes each time. Cheap now — and the frame after must be identical.
    final before = await () async {
      final c = _CensusCanvas();
      game.renderTree(c as Canvas);
      return c;
    }();

    for (var i = 0; i < 20; i++) {
      game.updateUnlockedSkills(allSkills);
    }
    await tester.pump(const Duration(milliseconds: 16));

    final after = _CensusCanvas();
    game.renderTree(after as Canvas);
    expect(after.get('drawPath'), closeTo(before.get('drawPath'), 60));
    expect(after.blurredDraws, before.blurredDraws);
  });
}
