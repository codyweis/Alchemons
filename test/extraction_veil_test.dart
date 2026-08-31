// The veil has to be UNDER the cinematic, not over it.
//
// It shipped once as an OverlayEntry, on the assumption that routes pushed
// afterwards would sit above it. They do not: a manually inserted entry stays
// above every later route, so the cinematic played underneath an opaque black
// rectangle and the screen simply went dark and stayed there.
//
// These pin the two things that make it a floor rather than a lid: it is a
// route, and anything pushed after it is visible.

import 'package:alchemons/widgets/animations/extraction_veil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('what is pushed after the veil is visible over it', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const Text('NURSERY');
            },
          ),
        ),
      ),
    );

    final veil = await _raise(tester, ctx);
    expect(find.text('NURSERY'), findsNothing, reason: 'the room is dark');

    // The cinematic lands on top.
    unawaited(
      Navigator.of(ctx).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) => const Text(
            'CINEMATIC',
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('CINEMATIC'),
      findsOneWidget,
      reason: 'the veil is a floor, not a lid',
    );

    Navigator.of(ctx).pop(); // cinematic done
    await tester.pumpAndSettle();
    await veil.dismiss();
    await tester.pumpAndSettle();
    expect(find.text('NURSERY'), findsOneWidget, reason: 'the room comes back');
  });

  testWidgets('dismiss is safe twice, and safe with something on top', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const Text('NURSERY');
            },
          ),
        ),
      ),
    );
    final veil = await _raise(tester, ctx);

    // Something is still stacked on the veil when the caller lets go — it has
    // to come out from underneath rather than popping the wrong route.
    unawaited(
      Navigator.of(ctx).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) =>
              const Text('LEFTOVER', textDirection: TextDirection.ltr),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await veil.dismiss();
    await veil.dismiss(); // idempotent
    await tester.pumpAndSettle();
    expect(find.text('LEFTOVER'), findsOneWidget, reason: 'not popped');
  });
}

Future<ExtractionVeil> _raise(WidgetTester tester, BuildContext ctx) async {
  ExtractionVeil? veil;
  unawaited(
    showExtractionVeil(
      ctx,
      from: const Rect.fromLTWH(100, 200, 120, 120),
      accent: const Color(0xFFE4C16A),
    ).then((v) => veil = v),
  );
  await tester.pumpAndSettle();
  expect(veil, isNotNull, reason: 'the close has to resolve');
  return veil!;
}

void unawaited(Future<void> f) {}
