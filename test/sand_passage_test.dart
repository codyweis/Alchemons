import 'dart:ui' as ui;

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/widgets/fx/sand_passage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Going between screens as sand (VoidPortal.pushThroughSand and
// leaveThroughSand): in from a circle, the ball opening onto the page once
// it is ready, and the page usable; out again into the circle it came from
// with nothing more said; and a page that cannot be pictured still leaves.
void main() {
  /// Frames, with real time now and then for pictures coming back off the
  /// raster thread.
  Future<void> drive(WidgetTester tester, double seconds) async {
    final frames = (seconds * 60).round();
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (i % 8 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
    }
  }

  testWidgets('in from a circle, and back into it', (tester) async {
    final map = GlobalKey();
    const circle = Rect.fromLTWH(40, 60, 120, 120);
    var landed = 0, leaves = 0;
    final ready = ValueNotifier<bool>(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => RepaintBoundary(
            key: map,
            child: ColoredBox(
              color: const Color(0xFF223344),
              child: Center(
                child: TextButton(
                  onPressed: () => VoidPortal.pushThroughSand<void>(
                    context,
                    page: Builder(
                      builder: (field) => ColoredBox(
                        color: const Color(0xFF3F8A47),
                        child: Center(
                          child: TextButton(
                            onPressed: () {
                              leaves++;
                              VoidPortal.leaveThroughSand<void>(field);
                            },
                            child: const Text('leave'),
                          ),
                        ),
                      ),
                    ),
                    from: SandSource(picture: map, circle: circle),
                    title: 'Field',
                    element: 'plant',
                    ready: ready,
                    back: SandLanding(
                      element: 'plant',
                      circle: () => circle,
                      onLanded: () => landed++,
                    ),
                  ),
                  child: const Text('map'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('map'));
    await drive(tester, 2.5);
    // Held behind the ball until the field says it is ready.
    expect(find.text('leave'), findsOneWidget);
    await tester.tap(find.text('leave'), warnIfMissed: false);
    expect(leaves, 0);
    ready.value = true;
    await drive(tester, 2.5);
    // Shown, and the overlay gone: the field takes taps.
    await tester.tap(find.text('leave'));
    expect(leaves, 1);
    await drive(tester, 3.5);
    expect(find.text('leave'), findsNothing);
    expect(find.text('map'), findsOneWidget);
    expect(landed, 1);
  });

  testWidgets('a page that cannot be pictured still leaves', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  transitionDuration: Duration.zero,
                  pageBuilder: (_, __, ___) => Builder(
                    builder: (ctx) => Center(
                      child: TextButton(
                        onPressed: () => VoidPortal.leaveThroughSand<void>(
                          ctx,
                          boundaryKey: GlobalKey(),
                        ),
                        child: const Text('leave'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('map'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('leave'));
    await tester.pumpAndSettle();
    expect(find.text('leave'), findsNothing);
    expect(find.text('map'), findsOneWidget);
  });

  test('pieces let go before the ball is whole, and come home in time', () {
    ui.Image blank() {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      return recorder.endRecording().toImageSync(10, 10);
    }

    final out = SandPicture(
      image: blank(),
      pixelRatio: 1,
      size: const Size(860, 400),
    );
    expect(out.goneBy, lessThan(out.doneBy));
    expect(out.doneBy, lessThan(1.4));
    expect(SandPicture.pourTime, lessThan(1.3));

    final circle = SandPicture(
      image: blank(),
      pixelRatio: 1,
      size: const Size(400, 860),
      circle: const Rect.fromLTWH(40, 60, 160, 160),
    );
    expect(circle.doneBy, lessThan(1.2));
    for (final p in [out, circle]) {
      p.dispose();
    }
  });

  test('the ball opens from shut to past the corners', () {
    const size = Size(860, 400);
    final corner = size.center(Offset.zero).distance;
    expect(SandHole.open(0), 0);
    // Shut, its soft edge too: nothing of the page shows yet.
    expect(
      SandHole.radius(size, 0) + SandHole.feather(size, 0),
      closeTo(0, 1e-9),
    );
    // Open: the whole screen clear, with time left for the sand to thin.
    expect(SandHole.open(SandHole.time), 1);
    expect(SandHole.radius(size, 1), greaterThanOrEqualTo(corner));
    expect(SandHole.time, lessThan(2.2));
    var last = -1.0;
    for (var t = 0.0; t <= SandHole.time; t += 0.05) {
      final open = SandHole.open(t);
      expect(open, greaterThanOrEqualTo(last));
      last = open;
    }
  });
}
