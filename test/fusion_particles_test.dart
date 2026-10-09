import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [w]×[h] straight-alpha image: a red disc on the left half, a blue
/// square on the right, transparent elsewhere.
Uint8List _redAndBlue(int w, int h) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      final dx = x - w * 0.3, dy = y - h * 0.5;
      if (dx * dx + dy * dy < (w * 0.18) * (w * 0.18)) {
        px[o] = 220;
        px[o + 1] = 40;
        px[o + 2] = 30;
        px[o + 3] = 255;
      } else if (x > w * 0.6 && x < w * 0.85 && y > h * 0.35 && y < h * 0.65) {
        px[o] = 30;
        px[o + 1] = 80;
        px[o + 2] = 230;
        px[o + 3] = 255;
      }
    }
  }
  return px;
}

void main() {
  group('SpecimenGrains', () {
    test('grains sit where the pixels were and keep their color', () {
      // 120 logical px read at 2x.
      final g = SpecimenGrains.fromRgba(
        _redAndBlue(240, 240),
        240,
        240,
        pixelRatio: 2,
      );
      expect(g.length, greaterThan(500));
      var reds = 0, blues = 0;
      for (var i = 0; i < g.length; i++) {
        final c = g.tones[g.tone[i]];
        // Centred on the box: the disc is left of centre, the square right.
        if (g.hx[i] < 0) {
          expect(c.r, greaterThan(c.b), reason: 'grain $i on the disc');
          reds++;
        } else {
          expect(c.b, greaterThan(c.r), reason: 'grain $i on the square');
          blues++;
        }
        expect(g.hx[i].abs(), lessThan(60));
        expect(g.hy[i].abs(), lessThan(60));
      }
      expect(reds, greaterThan(100));
      expect(blues, greaterThan(100));
    });

    test('a big sprite is read coarser, not into more grains', () {
      const w = 600;
      final solid = Uint8List(w * w * 4)..fillRange(0, w * w * 4, 200);
      final g = SpecimenGrains.fromRgba(solid, w, w, pixelRatio: 1);
      expect(g.length, lessThan(SpecimenGrains.maxGrains * 1.15));
      expect(g.step, greaterThan(1.15));
    });

    testWidgets('reads a live boundary as it is showing', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(
              dimension: 140,
              child: Center(
                child: Container(
                  width: 60,
                  height: 40,
                  color: const Color(0xFF20C060),
                ),
              ),
            ),
          ),
        ),
      );
      final box =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final g = (await tester.runAsync(
        () => SpecimenGrains.capture(box, pixelRatio: 2),
      ))!;
      expect(g.length, greaterThan(1200));
      for (var i = 0; i < g.length; i++) {
        expect(g.hx[i].abs(), lessThan(31));
        expect(g.hy[i].abs(), lessThan(21));
        final c = g.tones[g.tone[i]];
        expect(c.g, greaterThan(c.r));
      }
    });

    test('an empty box reads as nothing', () {
      final g = SpecimenGrains.fromRgba(
        Uint8List(64 * 64 * 4),
        64,
        64,
        pixelRatio: 1,
      );
      expect(g.length, 0);
    });
  });

  group('FusionParticleField', () {
    const centres = [Offset(67, 80), Offset(233, 80)];
    const core = Offset(150, 110);
    const radius = 44.0;

    FusionParticleField field() {
      final a = SpecimenGrains.fromRgba(
        _redAndBlue(240, 240),
        240,
        240,
        pixelRatio: 2,
      );
      final b = SpecimenGrains.disc(const Color(0xFF3080E0));
      return FusionParticleField(
        specimens: [a, b],
        centres: centres,
        scales: const [1.03, 1.03],
        core: core,
        coreRadius: radius,
        colors: const [Color(0xFFE05030), Color(0xFF3080E0)],
      );
    }

    test('the sprite is cut away as its grains appear, top down', () {
      final f = field();
      expect(f.cutY(0, 0), double.negativeInfinity);
      for (var i = 0; i < f.length; i++) {
        expect(f.debugGrain(i, 0), isNull);
      }
      final mid = f.cutY(0, 0.25);
      expect(mid.isFinite, isTrue);
      expect(f.cutY(0, 0.35), greaterThan(mid));
      expect(f.cutY(0, 0.6), double.infinity);
      expect(f.cutY(1, 0.6), double.infinity);
    });

    test('standing, the grains are the specimen, where it stood', () {
      final f = field();
      for (var i = 0; i < f.length; i++) {
        final p = f.debugGrain(i, 0.62);
        expect(
          p,
          isNotNull,
          reason: 'grain $i is a grain once the crest passed',
        );
        // In one of the chambers, near its centre: not yet poured.
        final near =
            (p! - centres[0]).distance < 75 || (p - centres[1]).distance < 75;
        expect(near, isTrue, reason: 'grain $i at $p');
      }
    });

    test('the side nearest the orb gives way first', () {
      final f = field();
      // Specimen A's grains are the first block; find its nearest and
      // farthest from the orb while standing.
      var nearI = -1, farI = -1;
      var nearD = double.infinity, farD = -1.0;
      for (var i = 0; i < f.length; i++) {
        final p = f.debugGrain(i, 0.62)!;
        if ((p - centres[0]).distance > 75) continue;
        final d = (p - core).distance;
        if (d < nearD) {
          nearD = d;
          nearI = i;
        }
        if (d > farD) {
          farD = d;
          farI = i;
        }
      }
      final farHome = f.debugGrain(farI, 0.62)!;
      final nearHome = f.debugGrain(nearI, 0.62)!;
      // Part way through the pour the nearest has left; the farthest has not.
      expect((f.debugGrain(nearI, 1.3)! - nearHome).distance, greaterThan(20));
      expect((f.debugGrain(farI, 1.3)! - farHome).distance, lessThan(8));
    });

    test('by the end every grain is in the cloud, and then in the orb', () {
      final f = field();
      for (var i = 0; i < f.length; i++) {
        expect((f.debugGrain(i, 2.1)! - core).distance, lessThan(radius * 1.2));
        expect(
          (f.debugGrain(i, 2.49)! - core).distance,
          lessThan(radius * 0.3),
        );
      }
      expect(f.chamberEmpty(0, 0.5), 0);
      expect(f.chamberEmpty(0, 2.0), 1);
    });

    test('paints nothing before it starts or once it is over', () {
      final f = field();
      for (final t in [0.0, FusionParticleField.duration]) {
        final rec = PictureRecorder();
        final canvas = _CountingCanvas(Canvas(rec));
        f.paint(canvas, t, back: false);
        f.paint(canvas, t, back: true);
        expect(canvas.draws, 0, reason: 't=$t');
        rec.endRecording().dispose();
      }
    });

    test('no blur anywhere in it', () {
      final f = field();
      for (var t = 0.05; t < FusionParticleField.duration; t += 0.1) {
        final rec = PictureRecorder();
        final canvas = _CountingCanvas(Canvas(rec));
        f.paint(canvas, t, back: true);
        f.paint(canvas, t, back: false);
        expect(canvas.blurred, 0, reason: 't=$t');
        rec.endRecording().dispose();
      }
    });
  });

  group('FusionBurstField', () {
    FusionBurstField burst() => FusionBurstField(
      grains: [
        SpecimenGrains.disc(const Color(0xFFE05030)),
        SpecimenGrains.disc(const Color(0xFF3080E0)),
      ],
      radius: 78,
    );

    _CountingCanvas paintAt(FusionBurstField b, double u) {
      final rec = PictureRecorder();
      final canvas = _CountingCanvas(Canvas(rec));
      b.paint(
        canvas,
        const Offset(200, 300),
        u,
        colors: const [Color(0xFFE05030), Color(0xFF3080E0)],
        accent: const Color(0xFFFF6B3D),
        sigil: FusionSigil.octagramAndElement,
        element: 'earth',
        pure: true,
        clock: u,
      );
      rec.endRecording().dispose();
      return canvas;
    }

    test('nothing before the hand-over; grains from it on', () {
      final b = burst();
      expect(paintAt(b, -0.1).draws, 0);
      expect(paintAt(b, 0.1).draws, greaterThan(0));
    });

    test('no blur anywhere in it', () {
      final b = burst();
      for (var u = 0.0; u < 2.6; u += 0.1) {
        expect(paintAt(b, u).blurred, 0, reason: 'u=$u');
      }
    });

    test('a draw per color, not per grain', () {
      final b = burst();
      for (var u = 0.0; u < 2.6; u += 0.25) {
        // Two specimens' tones near and far, the sigil, embers, glow and
        // glints: well under a hundred, for thousands of grains.
        expect(paintAt(b, u).draws, lessThan(100), reason: 'u=$u');
      }
      expect(b.length, greaterThan(500));
    });
  });
}

/// Counts what is drawn, and how much of it is blurred.
class _CountingCanvas implements Canvas {
  _CountingCanvas(this._inner);
  final Canvas _inner;
  int draws = 0, blurred = 0;

  void _count(Paint p) {
    draws++;
    if (p.maskFilter != null) blurred++;
  }

  @override
  void drawRawPoints(PointMode mode, Float32List points, Paint paint) {
    _count(paint);
    _inner.drawRawPoints(mode, points, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _count(paint);
    _inner.drawCircle(c, radius, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
