import 'dart:typed_data';

import 'package:alchemons/widgets/animations/hatching_cinematic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smallest valid PNG. The silhouette must be non-null or the reveal subtree
/// never builds and _revealScale is never evaluated — which is exactly how an
/// earlier version of this test passed while the bug was still present.
final _pixel = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
);

/// Smoke test: drives the whole ceremony frame by frame and asserts it runs to
/// completion and pops its own route without throwing.
///
/// Scope, honestly: this does NOT cover the reveal's scale animation. It was
/// written to guard a TweenSequence-driven-by-an-overshooting-curve crash, and
/// it was verified against that bug by reintroducing it — the test still
/// passed, so the reveal subtree's scale is not evaluated under `flutter test`.
/// The specific hazard is pinned in tween_sequence_hazard_test.dart instead.
void main() {
  testWidgets('ceremony plays to completion without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => playHatchingCinematicAlchemy(
              context: context,
              parentATypeId: 'T001',
              parentBTypeId: 'T002',
              paletteMain: const Color(0xFFFF8C00),
              creatureSilhouette: _pixel,
              mutationFamily: 'wing',
              hintType: HatchHintType.prismatic,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    // Step through the full ceremony in small increments. Any assertion in a
    // painter or an animation surfaces as a test failure here.
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.takeException(),
        isNull,
        reason: 'ceremony threw at roughly ${i * 50}ms',
      );
    }
    // Proof the ceremony actually RAN: it pops itself at the handover. If the
    // timeline never started, the route is still up and this fails — which is
    // how an earlier version of this test silently exercised nothing.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(
      find.text('go'),
      findsOneWidget,
      reason: 'the ceremony never completed and popped its route',
    );
  });
}
