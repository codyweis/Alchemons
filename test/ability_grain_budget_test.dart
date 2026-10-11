// THE ABILITY PARTICLE BUDGET. Every spark, ember, mote and wisp an ability
// throws is a lit grain, and a frame's grains go out in ONE drawRawAtlas
// (lib/games/cosmic/ability_grains.dart) — survival's own pool and the
// AbilityVfxPool open space and the dungeons use alike. This pins that, and
// zero blurred paints, for a representative cast: a five-family party
// casting every special on the same frame into a crowd.
//
// A budget test, not a golden. For a close look at the grains:
//   GRAIN_PREVIEW_OUT=<dir> flutter test test/ability_grain_budget_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ability_grains.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart'
    show AbilityVfxPool;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/survival_horde_arena.dart';

/// Records what a frame asks the GPU to do.
class _Census implements ui.Canvas {
  final Map<String, int> counts = {};
  int blurred = 0;
  int grainAtlasCalls = 0;
  int grainsDrawn = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is ui.Paint && (a.maskFilter != null || a.imageFilter != null)) {
        blurred++;
      }
    }
    if (key == 'drawRawAtlas' &&
        identical(i.positionalArguments.first, AbilityGrainSprite.image)) {
      grainAtlasCalls++;
      grainsDrawn += (i.positionalArguments[1] as Float32List).length ~/ 4;
    }
    switch (key) {
      case 'getSaveCount':
        return 1;
      case 'getTransform':
        return Float64List.fromList([
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]);
      case 'getLocalClipBounds':
      case 'getDestinationClipBounds':
        return ui.Rect.largest;
    }
    return null;
  }

  int count(String kind) => counts[kind] ?? 0;
}

void main() {
  setUpAll(() async {
    // Built at load, off the frame, as the games do.
    await AbilityGrainSprite.ensureLoaded();
  });

  test('the shared pool draws every particle as a grain in one call', () {
    final pool = AbilityVfxPool();
    for (var i = 0; i < 200; i++) {
      pool.add(i * 2.0, 0, 40, -20, 2.5, 0.6, const ui.Color(0xFFFF5722));
    }
    expect(pool.length, kAbilityParticleCap, reason: 'the pool is capped');
    final c = _Census();
    pool.render(c);
    expect(c.grainAtlasCalls, 1);
    expect(c.grainsDrawn, kAbilityParticleCap);
    expect(c.count('drawCircle'), 0);
    expect(c.blurred, 0);
  });

  test('reduced quality thins at spawn, never at draw', () {
    final pool = AbilityVfxPool()..thinSpawns = true;
    for (var i = 0; i < 20; i++) {
      pool.add(0, 0, 0, 0, 2, 1, const ui.Color(0xFF448AFF));
    }
    expect(pool.length, 10);
    // Every live particle is drawn every frame: nothing blinks as the list
    // compacts.
    for (var f = 0; f < 3; f++) {
      pool.update(1 / 60);
      final c = _Census();
      pool.render(c);
      expect(c.grainsDrawn, pool.length);
    }
  });

  test('drag is per second: a burst reaches as far at 60 and 120 Hz', () {
    double reach(int hz) {
      final pool = AbilityVfxPool()
        ..add(0, 0, 200, 0, 2, 2, const ui.Color(0xFF00E5FF));
      for (var f = 0; f < hz ~/ 2; f++) {
        pool.update(1 / hz);
      }
      return pool.particles.single.x;
    }

    final r60 = reach(60), r120 = reach(120);
    expect((r60 - r120).abs(), lessThan(r60 * 0.01));
    // Light enough that a release authored as speed × life gets most of the
    // way: half a second at 200 px/s covers well over half of 100 px.
    expect(r60, greaterThan(70));
  });

  test('a grain starts from the material, not the raw element colour', () {
    // Raw Material orange becomes Fire's ember; olive Poison's purple
    // element colour becomes its olive material.
    final fire = abilityGrainTone(const ui.Color(0xFFFF5722));
    expect(fire.body, isNot(0xFF5722));
    final poison = abilityGrainTone(const ui.Color(0xFF9C27B0));
    final g = (poison.body >> 8) & 0xFF, b = poison.body & 0xFF;
    expect(g, greaterThan(b), reason: 'Poison grains are olive, not purple');
    // Plain white is never a white pip.
    expect(abilityGrainTone(const ui.Color(0xFFFFFFFF)).lit, isNot(0xFFFFFF));
  });

  test(
    'a five-family party casting into a crowd: one grain draw, no blur',
    () async {
      final game = HordeArenaGame(
        party: kHordeArenaParties['Party A']!,
        population: 60,
        mixed: false,
        sustain: false,
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.forceSpecials();
      var peakParticles = 0;
      for (var f = 0; f < 90; f++) {
        game.update(1 / 60);
        if (f % 10 != 9) continue;
        final c = _Census();
        game.render(c);
        expect(c.blurred, 0, reason: 'frame $f');
        if (game.vfxParticleCount > 0) {
          expect(c.grainAtlasCalls, 1, reason: 'frame $f');
          // Every live particle but the ones fading below a hundredth.
          expect(
            c.grainsDrawn,
            inInclusiveRange(
              game.vfxParticleCount * 0.9,
              game.vfxParticleCount,
            ),
            reason: 'frame $f',
          );
        }
        if (game.vfxParticleCount > peakParticles) {
          peakParticles = game.vfxParticleCount;
        }
      }
      expect(peakParticles, greaterThan(20), reason: 'nothing was cast');

      final out = Platform.environment['GRAIN_PREVIEW_OUT'];
      if (out != null) {
        const w = 900, h = 700;
        final rec = ui.PictureRecorder();
        final canvas = ui.Canvas(rec);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, w * 1.0, h * 1.0),
          ui.Paint()..color = const ui.Color(0xFF040508),
        );
        game.render(canvas);
        final img = await rec.endRecording().toImage(w, h);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File(
          '$out/party_a_cast.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      }
      game.onRemove();
    },
  );
}
