// The fusion styles (the Athanor's): each replaces the merge's sphere and
// the cinematic's sigil with its own way of fusing, inside the shared
// fields, so every fusion spot plays it. Up to the stand a styled merge IS
// the plain one (the hold and the run back depend on it); it still ends in
// the orb; it is grains only (no blur), a draw per color; and a styled
// cinematic draws no sigil.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts draws and blurs, and keeps the colors grains are drawn in.
class _Spy implements Canvas {
  int draws = 0, blurred = 0;
  final Set<int> colors = {};

  void _count(Paint p) {
    draws++;
    if (p.maskFilter != null) blurred++;
  }

  @override
  void drawRawPoints(PointMode mode, Float32List points, Paint paint) {
    _count(paint);
    colors.add(paint.color.toARGB32());
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) => _count(paint);

  @override
  void drawPath(Path path, Paint paint) => _count(paint);

  @override
  void drawRect(Rect rect, Paint paint) => _count(paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _centres = [Offset(67, 80), Offset(233, 80)];
const _core = Offset(150, 110);
const _radius = 44.0;
const _a = Color(0xFFE05030), _b = Color(0xFF3080E0);

FusionParticleField _merge(FusionStyle? style) => FusionParticleField(
  specimens: [SpecimenGrains.disc(_a), SpecimenGrains.disc(_b)],
  centres: _centres,
  scales: const [1.03, 1.03],
  core: _core,
  coreRadius: _radius,
  colors: const [_a, _b],
  style: style,
  useWornStyle: false,
);

FusionBurstField _burst(FusionStyle? style) => FusionBurstField(
  grains: [SpecimenGrains.disc(_a), SpecimenGrains.disc(_b)],
  radius: 78,
  style: style,
  useWornStyle: false,
);

_Spy _paintBurst(FusionBurstField b, double u) {
  final spy = _Spy();
  b.paint(spy, const Offset(200, 300), u, colors: const [_a, _b], clock: u);
  return spy;
}

void main() {
  tearDown(() => FusionStyle.worn.value = null);

  test('a field takes the worn style unless told otherwise', () {
    FusionStyle.worn.value = FusionStyle.gilt;
    expect(
      FusionParticleField(
        specimens: [SpecimenGrains.disc(_a), SpecimenGrains.disc(_b)],
        centres: _centres,
        scales: const [1, 1],
        core: _core,
        coreRadius: _radius,
        colors: const [_a, _b],
      ).style,
      FusionStyle.gilt,
    );
    expect(
      FusionBurstField(
        grains: [SpecimenGrains.disc(_a), SpecimenGrains.disc(_b)],
        radius: 60,
      ).style,
      FusionStyle.gilt,
    );
    expect(_merge(null).style, isNull);
    expect(_burst(FusionStyle.ember).style, FusionStyle.ember);
    expect(_burst(null).styleLight, isNull);
    expect(_burst(FusionStyle.frost).styleLight, isNotNull);
  });

  for (final style in FusionStyle.values) {
    group(style.title, () {
      test('up to the stand it is the plain merge', () {
        final plain = _merge(null), styled = _merge(style);
        for (final t in [0.0, 0.2, 0.4, FusionParticleField.standTime]) {
          expect(styled.cutY(0, t), plain.cutY(0, t));
          for (var i = 0; i < plain.length; i += 7) {
            expect(styled.debugGrain(i, t), plain.debugGrain(i, t));
          }
        }
      });

      test('it leaves the pair and ends in the orb', () {
        final f = _merge(style);
        var moved = 0;
        for (var i = 0; i < f.length; i++) {
          final home = f.debugGrain(i, FusionParticleField.standTime)!;
          if ((f.debugGrain(i, 1.9)! - home).distance > 20) moved++;
          expect(
            (f.debugGrain(i, 2.49)! - _core).distance,
            lessThan(_radius * 0.35),
            reason: 'grain $i',
          );
        }
        expect(moved, greaterThan(f.length * 0.8));
      });

      test('the merge: nothing before or after, no blur, a draw per color', () {
        final f = _merge(style);
        for (final t in [0.0, FusionParticleField.duration]) {
          final spy = _Spy();
          f.paint(spy, t, back: true);
          f.paint(spy, t, back: false);
          expect(spy.draws, 0);
        }
        for (var t = 0.05; t < FusionParticleField.duration; t += 0.1) {
          final spy = _Spy();
          f.paint(spy, t, back: true, clock: t);
          f.paint(spy, t, back: false, clock: t);
          expect(spy.blurred, 0, reason: 't=$t');
          expect(spy.draws, lessThan(110), reason: 't=$t');
        }
      });

      test('the cinematic: no blur, a draw per color, no sigil', () {
        final b = _burst(style);
        expect(_paintBurst(b, -0.1).draws, 0);
        // The plain cinematic's sigil, as it draws it with no accent.
        final sigil = Color.lerp(
          const Color(0xFFFFFFFF),
          const Color(0xFFFFE7B0),
          0.3,
        )!;
        for (var u = 0.0; u < 3.0; u += 0.1) {
          final spy = _paintBurst(b, u);
          expect(spy.draws, greaterThan(0), reason: 'u=$u');
          expect(spy.blurred, 0, reason: 'u=$u');
          expect(spy.draws, lessThan(100), reason: 'u=$u');
          for (final c in spy.colors) {
            expect(c & 0xFFFFFF, isNot(sigil.toARGB32() & 0xFFFFFF));
          }
        }
      });
    });
  }

  // Smooth, not jittery: a grain's second difference shrinks with the
  // square of the step (motion that is a smooth function of time); a jump
  // or a flicker would not shrink at all. Checked across the merge.
  for (final style in [null, ...FusionStyle.values]) {
    test(
      '${style?.title ?? 'the plain fusion'}: every grain moves smoothly',
      () {
        final f = _merge(style);
        double worst(double h) {
          var m = 0.0;
          for (var t = 0.66; t < 2.45; t += 0.053) {
            for (var i = 0; i < f.length; i += 9) {
              final a = f.debugGrain(i, t - h), b = f.debugGrain(i, t);
              final c = f.debugGrain(i, t + h);
              if (a == null || b == null || c == null) continue;
              m = math.max(m, (a - b * 2 + c).distance);
            }
          }
          return m;
        }

        final coarse = worst(1 / 30), fine = worst(1 / 240);
        // Eight times finer a step: 64 times less for smooth motion, 8 times
        // less where the flow's lattice bends a path; a jump or a flicker
        // would not shrink at all.
        expect(
          fine,
          lessThan(coarse / 5 + 0.25),
          reason: 'coarse $coarse, fine $fine',
        );
      },
    );
  }

  test('the plain cinematic still draws its sigil', () {
    final sigil = Color.lerp(
      const Color(0xFFFFFFFF),
      const Color(0xFFFFE7B0),
      0.3,
    )!;
    final spy = _paintBurst(_burst(null), 2.4);
    expect(
      spy.colors.map((c) => c & 0xFFFFFF),
      contains(sigil.toARGB32() & 0xFFFFFF),
    );
  });
}
