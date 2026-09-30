import 'package:alchemons/widgets/particle_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The home title in particles, through its real gestures: it loads and
// animates, a tap and a drag are taken without error, a long press brings
// up the colours, and the choice is kept.

const _gold = 'assets/images/ui/alchemonstitle.png';

Widget _host({bool active = true}) => MaterialApp(
  home: Scaffold(
    backgroundColor: const Color(0xFF0B0A16),
    body: Center(
      child: ParticleTitle(darkBackdrop: true, active: active),
    ),
  ),
);

Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(() async {
    await TitleSamples.of(_gold);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('it reads the logo into a few thousand grains, with outlines',
      (tester) async {
    late TitleSamples s;
    await tester.runAsync(() async => s = await TitleSamples.of(_gold));
    expect(s.length, inInclusiveRange(2500, 5000));
    final edges = s.edge.where((e) => e == 1).length;
    expect(edges, greaterThan(s.length ~/ 10));
    expect(edges, lessThan(s.length * 7 ~/ 10));
    // Nine letters, left to right.
    expect(s.letter.reduce((a, b) => a > b ? a : b), 8);
  });

  testWidgets('tap, drag and long press all work, and the colour is kept',
      (tester) async {
    await tester.pumpWidget(_host());
    await _load(tester);
    // Through the intro.
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final title = find.byType(ParticleTitle);
    final centre = tester.getCenter(title);

    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.dragFrom(centre - const Offset(80, 0), const Offset(160, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Hold: the colours come up; choose Void (the last).
    await tester.longPressAt(centre);
    await tester.pump(const Duration(milliseconds: 300));
    final swatches = find.descendant(
      of: find.byType(Overlay),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 24 &&
            w.constraints?.maxHeight == 24,
      ),
    );
    expect(swatches, findsNWidgets(kTitleHues.length));
    await tester.tap(swatches.last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('title_particle_hue'), 'void');
    expect(swatches, findsNothing, reason: 'the picker closes on a pick');

    // In Void a drag is a black hole; still no errors.
    await tester.dragFrom(centre - const Offset(40, 0), const Offset(80, 0));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused before or during the intro, it is simply the title',
      (tester) async {
    await tester.pumpWidget(_host());
    await _load(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Home loses focus mid-intro: the ticker stops, the letters settle.
    await tester.pumpWidget(_host(active: false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
