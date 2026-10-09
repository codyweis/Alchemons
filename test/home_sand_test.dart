import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/field/home_sand_field.dart';
import 'package:alchemons/games/wilderness/field/sand_floor.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_sand.dart';
import 'package:alchemons/models/shop_scenes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Living Sands: a home realm the shop sells that is only ever a home, a
// rippled floor of sand in colors and a lie the player picks.
void main() {
  const rose = HomeSandStyle(
    colors: [
      Color(0xFFE88AA0),
      Color(0xFF6FD3C8),
      Color(0xFF223344),
      Color(0xFF445566),
      Color(0xFF667788),
    ],
    count: 3,
    shimmer: Color(0xFFFFFFFF),
    pattern: SandPattern.layered,
    density: 0.2,
    grain: 0.9,
    sparkle: 0.8,
    motion: SandMotion.mixes,
  );

  group('its style', () {
    test('is saved with the home, and kept by another realm', () {
      final layout = const HomeBiomeLayout(
        realm: HomeRealm.sand,
      ).copyWith(sandStyle: rose);
      final back = HomeBiomeLayout.fromJson(
        jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
      );
      expect(back.realm, HomeRealm.sand);
      expect(back.sandStyle, rose);
      // Moved to the Valley and back, the sands are as they were.
      expect(back.copyWith(realm: HomeRealm.valley).sandStyle, rose);
    });

    test('a save from before it, or a broken one, reads as the default', () {
      expect(HomeSandStyle.fromJson(null), const HomeSandStyle());
      expect(HomeSandStyle.fromJson('x'), const HomeSandStyle());
      expect(
        HomeSandStyle.fromJson({
          'first': 'red',
          'second': -4,
          'count': 'many',
          'density': double.nan,
          'pattern': 'plaid',
        }),
        const HomeSandStyle(),
      );
      // A color saved without its alpha is opaque.
      expect(
        HomeSandStyle.fromJson({
          'colors': [0x00E88AA0],
        }).colors.first,
        const Color(0xFFE88AA0),
      );
      // Out of range, kept in range.
      final wild = HomeSandStyle.fromJson({'count': 9, 'sparkle': 4});
      expect(wild.count, kSandMaxCount);
      expect(wild.sparkle, 1);
    });

    test('a save from when there were two sands keeps them', () {
      final old = HomeSandStyle.fromJson({
        'first': 0xFFE88AA0,
        'second': 0xFF6FD3C8,
        'shimmer': 0xFFFFFFFF,
      });
      expect(old.count, 2);
      expect(old.sands, const [Color(0xFFE88AA0), Color(0xFF6FD3C8)]);
      expect(old.shimmer, const Color(0xFFFFFFFF));
      expect(old.colors.sublist(2), kSandDefaultColors.sublist(2));
    });

    test('a save from when sand could only spring back or stay keeps it', () {
      expect(
        HomeSandStyle.fromJson({'stays': true}).motion,
        SandMotion.staysPut,
      );
      expect(
        HomeSandStyle.fromJson({'stays': false}).motion,
        SandMotion.springsBack,
      );
      expect(HomeSandStyle.fromJson({'motion': 'mixes'}).stays, isTrue);
    });

    test('fewer sands keeps the colors of the ones put away', () {
      final three = rose.withColor(2, const Color(0xFF00FF00));
      final one = three.copyWith(count: 1);
      expect(one.sands, [rose.colors.first]);
      expect(one.copyWith(count: 3).sands[2], const Color(0xFF00FF00));
    });
  });

  test('sold for a home only, opening only once bought', () {
    final scene = shopSceneOf('sand')!;
    expect(scene.homeOnly, isTrue);
    expect(scene.species, isEmpty);
    expect(HomeRealm.open(arcane: true), isNot(contains(HomeRealm.sand)));
    expect(
      HomeRealm.open(arcane: true, bought: {'sand'}),
      contains(HomeRealm.sand),
    );
  });

  test('the floor is laid round the loop and lies under both rows', () {
    final scene = homeSandScene(rose);
    expect(scene.loop, isTrue);
    // A flat floor: both rows move with it.
    expect(scene.layers.map((l) => l.parallaxFactor).toSet(), {1.0});
    final field = HomeSandField(rose);
    const screen = Size(915, 412);
    final period = scene.worldWidth * 2.0;
    final back = field.build(
      HomeRealm.sand.far.layer,
      Size(period, screen.height),
      screen,
    );
    expect(back, hasLength(1));
    expect(back.single.live, isNotNull);
    expect(
      field.build(HomeRealm.sand.near.layer, Size(period, 412), screen),
      isEmpty,
    );
    field.dispose();
  });

  group('a floor of sand', () {
    const tile = Size(933, 412);
    SandFloor floor([HomeSandStyle style = const HomeSandStyle()]) =>
        SandFloor(style)
          ..layout(tile)
          ..step(1 / 60);

    void paint(SandFloor f) {
      final rec = ui.PictureRecorder();
      f.paint(Canvas(rec));
      rec.endRecording().dispose();
    }

    void settle(SandFloor f, [double seconds = 5]) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        f.step(1 / 60);
      }
    }

    // A finger drawn straight across the middle, sampled twice a frame.
    void drag(SandFloor f) {
      for (var i = 1; i <= 60; i++) {
        f.stir(Offset(200 + 6.0 * i, 206), const Offset(6, 0), 1 / 120);
        if (i.isEven) f.step(1 / 60);
      }
    }

    // Grains within 8 px of [at].
    int near(SandFloor f, Offset at) {
      var n = 0;
      for (var i = 0; i < f.grainCount; i++) {
        if ((f.debugGrainAt(i) - at).distance < 8) n++;
      }
      return n;
    }

    // Grains in the middle of the finger's path.
    int inPath(SandFloor f) {
      var n = 0;
      for (var i = 0; i < f.grainCount; i++) {
        final p = f.debugGrainAt(i);
        if (p.dx > 260 && p.dx < 500 && (p.dy - 206).abs() < 8) n++;
      }
      return n;
    }

    test('covers it all, evenly, and rests as one picture', () {
      final f = floor();
      expect(f.grainCount, greaterThan(40000));
      // Every 20 px square of it has sand in it: no clumps and holes.
      final filled = <int>{};
      for (var i = 0; i < f.grainCount; i++) {
        final p = f.debugGrainAt(i);
        filled.add((p.dx ~/ 20) * 1000 + p.dy ~/ 20);
      }
      expect(
        filled.length,
        (tile.width / 20).ceil() * (tile.height / 20).ceil(),
      );
      paint(f);
      expect(f.debugPictures, 1, reason: 'lies in place from the first frame');
      // Only what can glint is drawn grain by grain.
      expect(f.debugSprites, lessThan(f.grainCount * 0.02));
      f.dispose();
    });

    test('is seamless from its right edge round to its left', () {
      final f = floor();
      for (final y in [40.0, 150.0, 260.0, 390.0]) {
        for (final p in SandPattern.values) {
          expect(
            f.debugPatternAt(p, tile.width - 0.01, y),
            closeTo(f.debugPatternAt(p, 0, y), 0.01),
            reason: '$p at $y',
          );
        }
      }
      f.dispose();
    });

    test('lays exactly as many sands as it is given, in every pattern', () {
      for (final p in SandPattern.values) {
        for (var count = 1; count <= kSandMaxCount; count++) {
          final f = floor(HomeSandStyle(count: count, pattern: p));
          final seen = {
            for (var i = 0; i < f.grainCount; i++) f.debugSandOf(i),
          };
          expect(seen, {for (var s = 0; s < count; s++) s}, reason: '$p');
          f.dispose();
        }
      }
    });

    test('restyled, every grain keeps its place', () {
      final f = floor();
      final at = [for (var i = 0; i < f.grainCount; i++) f.debugGrainAt(i)];
      final was = [for (var i = 0; i < f.grainCount; i++) f.debugColorOf(i)];
      f
        ..style = rose.copyWith(motion: SandMotion.springsBack)
        ..step(1 / 60);
      var changed = 0;
      for (var i = 0; i < f.grainCount; i++) {
        expect(f.debugGrainAt(i), at[i]);
        if (f.debugColorOf(i) != was[i]) changed++;
      }
      expect(changed, greaterThan(f.grainCount * 0.9));
      // The same as a floor laid that way from the start.
      final fresh = floor(rose.copyWith(motion: SandMotion.springsBack));
      for (var i = 0; i < f.grainCount; i += 97) {
        expect(f.debugColorOf(i), fresh.debugColorOf(i));
      }
      f.dispose();
      fresh.dispose();
    });

    test('density draws fewer grains, without moving any', () {
      final f = floor(const HomeSandStyle(density: 1));
      final thick = f.drawnCount;
      expect(thick, f.grainCount);
      f.style = const HomeSandStyle(density: 0);
      expect(f.drawnCount, closeTo(thick * 0.3, thick * 0.02));
      f.dispose();
    });

    test('springing back, a stir leaves nothing behind', () {
      final f = floor();
      final before = inPath(f);
      drag(f);
      expect(f.debugAtRest, isFalse);
      settle(f);
      expect(f.debugAtRest, isTrue);
      expect(inPath(f), before);
      for (var i = 0; i < f.grainCount; i += 37) {
        expect(
          (f.debugGrainAt(i) - f.debugFirstLieOf(i)).distance,
          lessThan(0.1),
        );
      }
      f.dispose();
    });

    test('staying put, a finger leaves a furrow until it is smoothed', () {
      final f = floor(const HomeSandStyle(motion: SandMotion.staysPut));
      final before = inPath(f);
      drag(f);
      settle(f);
      expect(f.debugAtRest, isTrue);
      // A few lie too deep to be moved; the rest are heaped either side.
      expect(inPath(f), lessThan(before * 0.12));
      paint(f);
      expect(f.debugPictures, 1, reason: 'a furrow is drawn as still sand');
      f.smooth();
      settle(f);
      expect(inPath(f), before);
      f.dispose();
    });

    test('springing back, the dark shows in the finger\'s wake', () {
      final f = floor();
      final rest = near(f, const Offset(300, 206));
      var least = rest;
      for (var i = 1; i <= 60; i++) {
        f.stir(Offset(200 + 6.0 * i, 206), const Offset(6, 0), 1 / 120);
        if (i.isEven) f.step(1 / 60);
        least = math.min(least, near(f, const Offset(300, 206)));
      }
      expect(least, lessThan(rest * 0.3));
      settle(f);
      expect(near(f, const Offset(300, 206)), rest);
      f.dispose();
    });

    test('told to spring back, sand that stayed goes back to its lie', () {
      final f = floor(const HomeSandStyle(motion: SandMotion.staysPut));
      final before = inPath(f);
      drag(f);
      settle(f);
      f.style = const HomeSandStyle();
      settle(f);
      expect(inPath(f), before);
      f.dispose();
    });

    test('a furrow stays open while a finger is busy elsewhere', () async {
      // How light the furrow's middle is, drawn.
      Future<double> light(SandFloor f) async {
        final rec = ui.PictureRecorder();
        f.paint(Canvas(rec));
        final img = await rec.endRecording().toImage(
          tile.width.toInt(),
          tile.height.toInt(),
        );
        final px = (await img.toByteData())!;
        var sum = 0;
        for (var y = 203; y < 210; y++) {
          for (var x = 240; x < 300; x++) {
            final o = (y * img.width + x) * 4;
            sum += px.getUint8(o) + px.getUint8(o + 1) + px.getUint8(o + 2);
          }
        }
        img.dispose();
        return sum / (7 * 60 * 3);
      }

      final f = floor(const HomeSandStyle(motion: SandMotion.staysPut));
      paint(f);
      for (var i = 1; i <= 30; i++) {
        f.stir(Offset(200 + 6.0 * i, 206), const Offset(6, 0), 1 / 120);
        if (i.isEven) {
          f.step(1 / 60);
          paint(f);
        }
      }
      // The furrow's sand comes to lie still while the finger ploughs on
      // far off (fresh sand all the way, so something is always moving).
      for (var i = 1; i <= 300; i++) {
        f.stir(Offset(420 + 1.6 * i, 90), const Offset(1.6, 0), 1 / 120);
        if (i.isEven) {
          f.step(1 / 60);
          paint(f);
        }
      }
      final busy = await light(f);
      settle(f);
      final still = await light(f);
      expect(busy, closeTo(still, 6), reason: 'no sand drawn where it was');
      f.dispose();
    });

    test('mixing, a finger draws the sands through each other', () {
      final f = floor(const HomeSandStyle(motion: SandMotion.mixes));
      // Grains in 4 px bands across the finger's way, as they lie.
      List<int> bands() {
        final n = List.filled(20, 0);
        for (var i = 0; i < f.grainCount; i++) {
          final p = f.debugGrainAt(i);
          final b = ((p.dy - 166) / 4).floor();
          if (p.dx >= 300 && p.dx < 600 && b >= 0 && b < 20) n[b]++;
        }
        return n;
      }

      final before = bands();
      drag(f);
      settle(f);
      expect(f.debugAtRest, isTrue);
      // Nothing dug or heaped: as many grains across the way as before.
      final after = bands();
      for (var b = 0; b < 20; b++) {
        expect(after[b], closeTo(before[b], before[b] * 0.12), reason: '$b');
      }
      // Carried along the finger's way, the middle of it far; the sands
      // drawn through each other.
      var far = 0, among = 0;
      for (var i = 0; i < f.grainCount; i++) {
        final d = f.debugGrainAt(i) - f.debugFirstLieOf(i);
        if (d.dx > 50 && d.dy.abs() < 10) far++;
        if (d.distance > 4) among++;
      }
      expect(far, greaterThan(100));
      expect(among, greaterThan(1000));
      // Far from it, as it lay.
      for (var i = 0; i < f.grainCount; i++) {
        final q = f.debugFirstLieOf(i);
        if ((q.dy - 206).abs() > 60) {
          expect(f.debugGrainAt(i), q);
        }
      }

      // Smoothed: all of it back as it first lay.
      f.smooth();
      settle(f);
      for (var i = 0; i < f.grainCount; i += 37) {
        expect(
          (f.debugGrainAt(i) - f.debugFirstLieOf(i)).distance,
          lessThan(0.1),
        );
      }
      f.dispose();
    });

    test('mixing, a tap twists the sand round it', () {
      final f = floor(const HomeSandStyle(motion: SandMotion.mixes));
      const at = Offset(330, 200);
      // How far the grains that first lay [r] from the tap have gone.
      double moved(double r) {
        var sum = 0.0, n = 0;
        for (var i = 0; i < f.grainCount; i++) {
          final q = f.debugFirstLieOf(i);
          if (((q - at).distance - r).abs() < 2) {
            sum += (f.debugGrainAt(i) - q).distance;
            n++;
          }
        }
        return sum / n;
      }

      f.ripple(at);
      settle(f, 2);
      expect(f.debugAtRest, isTrue);
      // Turned most halfway out, hardly at its middle, not past its edge.
      expect(moved(20), greaterThan(15));
      expect(moved(2), lessThan(moved(20) * 0.4));
      expect(moved(50), 0);
      // Told to stay put instead, it stays mixed; to spring back, it goes
      // back.
      f
        ..style = const HomeSandStyle(motion: SandMotion.staysPut)
        ..step(1 / 60);
      settle(f, 1);
      expect(moved(20), greaterThan(15));
      f
        ..style = const HomeSandStyle()
        ..step(1 / 60);
      settle(f);
      expect(moved(20), lessThan(0.1));
      f.dispose();
    });

    test('a furrow runs on round the seam', () {
      final f = floor(const HomeSandStyle(motion: SandMotion.staysPut));
      int near(double x) {
        var n = 0;
        for (var i = 0; i < f.grainCount; i++) {
          final p = f.debugGrainAt(i);
          if ((p.dx - x).abs() < 6 && (p.dy - 206).abs() < 6) n++;
        }
        return n;
      }

      final before = near(3);
      for (var i = 1; i <= 20; i++) {
        final x = tile.width - 60 + 6.0 * i;
        f.stir(Offset(x % tile.width, 206), const Offset(6, 0), 1 / 120);
      }
      settle(f);
      expect(near(3), lessThan(before * 0.3));
      f.dispose();
    });
  });
}
