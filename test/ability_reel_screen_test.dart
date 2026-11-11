import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/debug/ability_reel_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The profile's ability reel: every family and element's special in one
/// arena, one after another. It casts each, moves on by itself, steps both
/// ways and filters to a family.
///
///   REEL_OUT=/tmp/reel flutter test test/ability_reel_screen_test.dart
/// also writes a PNG of the screen mid-cast.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['REEL_OUT'];

  testWidgets('the reel plays every ability in turn', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    expect(catalog.isLoaded, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          child: Provider<CreatureCatalog>.value(
            value: catalog,
            child: const AbilityReelScreen(),
          ),
        ),
      ),
    );
    Future<void> settle(int frames) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    String counter() {
      final t = find.textContaining(' / ');
      expect(t, findsOneWidget);
      return (tester.widget<Text>(t).data ?? '');
    }

    await settle(30);
    // The first ability is up, and its count covers many families.
    expect(find.textContaining('HORN'), findsWidgets);
    final first = counter();
    expect(RegExp(r'1 / (\d+)').firstMatch(first), isNotNull);
    final total = int.parse(RegExp(r'1 / (\d+)').firstMatch(first)!.group(1)!);
    expect(total, greaterThan(100), reason: 'most family x element pairs');

    // Mid-cast: the PNG, when asked for.
    if (outDir != null && outDir.isNotEmpty) {
      final boundary =
          tester.firstRenderObject(find.byType(RepaintBoundary)) as dynamic;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(outDir).createSync(recursive: true);
        File(
          '$outDir/ability_reel.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    // It moves on by itself after the cast and the hold (0.9 s + 4.5 s).
    await settle(110);
    expect(counter(), contains('2 / $total'));

    // Steps both ways, wrapping at the start.
    await tester.tap(find.text('BACK'));
    await settle(4);
    expect(counter(), contains('1 / $total'));
    await tester.tap(find.text('BACK'));
    await settle(4);
    expect(counter(), contains('$total / $total'));

    // A family filter shows only that family, from its first ability.
    await tester.dragUntilVisible(
      find.textContaining('MANE '),
      find.byType(ListView),
      const Offset(-120, 0),
    );
    await tester.tap(find.textContaining('MANE '));
    await settle(10);
    expect(find.textContaining('MANE  ·'), findsOneWidget);
    expect(counter(), contains('1 / '));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
