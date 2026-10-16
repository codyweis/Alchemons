import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/bloodborn_extraction.dart';
import 'package:alchemons/widgets/fx/bloodborn_vial.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small body of grains in one colour, standing on its feet.
SpecimenGrains _body() {
  final xs = <double>[], ys = <double>[];
  for (var y = -40.0; y < 40; y += 2) {
    for (var x = -20.0; x < 20; x += 2) {
      xs.add(x);
      ys.add(y);
    }
  }
  return SpecimenGrains.points(
    Float32List.fromList(xs),
    Float32List.fromList(ys),
    Uint8List(xs.length),
    const [Color(0xFF887766)],
    2,
  );
}

void main() {
  test('the vial paints at every stage, in a vessel and on a floor', () {
    final field = BloodbornVialField(_body(), pool: 120);
    for (final (p, ready) in [(0.0, 0.0), (0.4, 0.0), (1.0, 1.0)]) {
      for (var t = 0.0; t < 3; t += 0.37) {
        final rec = _record((canvas) {
          field.paintVessel(
            canvas,
            const Offset(80, 80),
            70,
            progress: p,
            ready: ready,
            time: t,
            pointer: const Offset(80, 120),
            stir: 1,
          );
          field.paintOpen(
            canvas,
            const Offset(200, 300),
            180,
            progress: p,
            ready: ready,
            time: t,
            beat: ready == 0 ? 0.8 : null,
          );
        });
        expect(rec, isNotNull);
      }
    }
  });

  test('the heartbeat swells and eases, never above one', () {
    var peak = 0.0;
    for (var t = 0.0; t < 2.4; t += 0.01) {
      final b = bloodHeartbeat(t, period: 1.2);
      expect(b, inInclusiveRange(0, 1));
      peak = b > peak ? b : peak;
    }
    expect(peak, greaterThan(0.95));
    // Quiet between beats.
    expect(bloodHeartbeat(0.9, period: 1.2), lessThan(0.05));
  });

  testWidgets('a chamber holding a Bloodborn Vial shows the vial', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: CultivationSphere(
              payload: {'baseId': 'NOPE', 'source': 'bloodborn'},
              types: ['blood', 'dark'],
              progress: 0.4,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(BloodbornVial), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Bloodborn extraction runs through to its handover', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BloodbornExtractionView(
          payload: const {'baseId': 'NOPE', 'source': 'bloodborn'},
          mutationFamily: 'horn',
          body: _body(),
          showSkip: false,
          onComplete: () => done = true,
        ),
      ),
    );
    for (var i = 0; i < 20 * 15 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done, isTrue);
    expect(tester.takeException(), isNull);
  });
}

/// Records [draw] into a picture, so a painter runs without a frame.
ui.Picture _record(void Function(Canvas canvas) draw) {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  return recorder.endRecording();
}
