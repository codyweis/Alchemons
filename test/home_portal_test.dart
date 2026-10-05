import 'dart:math' as math;

import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/home_portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PortalLoopTracker _tracker() => PortalLoopTracker(
  center: const Offset(200, 200),
  minRadius: 50,
  maxRadius: 240,
);

/// Points round (200, 200) at [r], from [from] through [turn] radians.
List<Offset> _arc(double r, {double from = 0, double turn = math.pi * 2}) => [
  for (var k = 0; k <= 72; k++)
    Offset(
      200 + r * math.cos(from + turn * k / 72),
      200 + r * math.sin(from + turn * k / 72),
    ),
];

void main() {
  group('PortalLoopTracker', () {
    test('a circle round the middle closes, once, either way', () {
      for (final dir in [1.0, -1.0]) {
        final t = _tracker();
        var closes = 0;
        for (final p in _arc(120, turn: dir * math.pi * 2)) {
          if (t.add(p)) closes++;
        }
        expect(closes, 1);
        expect(t.direction, dir.sign.toInt());
      }
    });

    test('a wobbly, slightly short circle still counts', () {
      final t = _tracker();
      var closed = false;
      for (var k = 0; k <= 60; k++) {
        final a = math.pi * 2 * 0.88 * k / 60;
        final r = 110 + 35 * math.sin(k * 0.9);
        closed |= t.add(Offset(200 + r * math.cos(a), 200 + r * math.sin(a)));
      }
      expect(closed, isTrue);
    });

    test('half a circle, scrubbing back and forth, does not', () {
      final t = _tracker();
      var closed = false;
      for (var i = 0; i < 4; i++) {
        for (final p in _arc(120, turn: math.pi)) {
          closed |= t.add(p);
        }
        for (final p in _arc(120, from: math.pi, turn: -math.pi)) {
          closed |= t.add(p);
        }
      }
      expect(closed, isFalse);
    });

    test('a little swirl off to one side, or on the Alchemon, does not', () {
      final small = _tracker();
      var closed = false;
      for (var k = 0; k <= 72; k++) {
        final a = math.pi * 2 * k / 72;
        // Inside the middle band: stirring on the creature itself.
        closed |= small.add(
          Offset(200 + 30 * math.cos(a), 200 + 30 * math.sin(a)),
        );
      }
      final aside = _tracker();
      for (var k = 0; k <= 72; k++) {
        final a = math.pi * 2 * k / 72;
        closed |= aside.add(
          Offset(360 + 40 * math.cos(a), 200 + 40 * math.sin(a)),
        );
      }
      expect(closed, isFalse);
    });

    test('lines straight across the middle do not add up to a circle', () {
      final t = _tracker();
      var closed = false;
      for (var i = 0; i < 6; i++) {
        closed |= t.add(const Offset(80, 200));
        closed |= t.add(const Offset(320, 200));
        closed |= t.add(const Offset(200, 80));
        closed |= t.add(const Offset(200, 320));
      }
      expect(closed, isFalse);
    });
  });

  group('HomePortalHero', () {
    Future<void> drawCircle(WidgetTester tester, Offset c, double r) async {
      final g = await tester.startGesture(c + Offset(r, 0));
      for (var k = 1; k <= 40; k++) {
        final a = math.pi * 2 * k / 40;
        await g.moveTo(c + Offset(r * math.cos(a), r * math.sin(a)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
    }

    testWidgets('circle opens, tap enters, circle closes', (tester) async {
      final toggles = <bool>[];
      var enters = 0, stirs = 0, swirls = 0, details = 0;
      var open = false, guide = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 400,
                height: 260,
                child: HomePortalHero(
                  open: open,
                  spriteKey: GlobalKey(),
                  tone: const Color(0xFFD6A35C),
                  guide: guide,
                  onToggle: (v) {
                    toggles.add(v);
                    // As home does: the first circle ends the guide.
                    setState(() {
                      open = v;
                      guide = false;
                    });
                  },
                  onEnter: () => enters++,
                  onStir: (_, _, _) => stirs++,
                  onSwirl: (_, _, _, _) => swirls++,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => details++,
                      child: const SizedBox.square(
                        key: ValueKey('hero'),
                        dimension: 120,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final c = tester.getCenter(find.byType(HomePortalHero));

      // Shut, a tap on the Alchemon is still its own.
      await tester.tap(find.byKey(const ValueKey('hero')));
      expect(details, 1);
      expect(enters, 0);

      await drawCircle(tester, c, 120);
      await tester.pump(const Duration(milliseconds: 100));
      expect(toggles, [true]);
      expect(stirs, greaterThan(20));
      // The window replaces the Alchemon.
      expect(find.byKey(const ValueKey('hero')), findsNothing);
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(swirls, greaterThan(0));

      await tester.tapAt(c);
      expect(enters, 1);

      await drawCircle(tester, c, 120);
      expect(toggles, [true, false]);
      expect(find.byKey(const ValueKey('hero')), findsOneWidget);
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Shut and still: nothing left ticking.
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('the window is built once open, and dropped once shut', (
      tester,
    ) async {
      var open = false, builds = 0;
      VoidCallback? ready;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 400,
                height: 260,
                child: HomePortalHero(
                  open: open,
                  spriteKey: GlobalKey(),
                  tone: const Color(0xFFD6A35C),
                  onToggle: (v) => setState(() => open = v),
                  onEnter: () {},
                  window: (context, onReady) {
                    builds++;
                    ready = onReady;
                    return const ColoredBox(
                      key: ValueKey('live'),
                      color: Color(0xFF335533),
                    );
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      final c = tester.getCenter(find.byType(HomePortalHero));
      await drawCircle(tester, c, 120);
      await tester.pump(const Duration(milliseconds: 100));
      // Not while the grains fall in: its first frame would stall them.
      expect(find.byKey(const ValueKey('live')), findsNothing);
      for (var i = 0; i < 110; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const ValueKey('live')), findsOneWidget);
      double opacity() => tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('live')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity(), 0);
      ready!();
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(opacity(), 1);
      await drawCircle(tester, c, 120);
      expect(find.byKey(const ValueKey('live')), findsOneWidget);
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const ValueKey('live')), findsNothing);
      expect(builds, greaterThan(0));
    });

    testWidgets('opens already open when saved that way', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 260,
            child: HomePortalHero(
              open: true,
              spriteKey: GlobalKey(),
              tone: const Color(0xFF86CF9C),
              onToggle: (_) {},
              onEnter: () {},
              child: const SizedBox(key: ValueKey('hero')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const ValueKey('hero')), findsNothing);
    });
  });

  test('the sand swirls round a point without throwing', () {
    final field = FactionRealmField()..layout(const Size(400, 800));
    field.swirl(const Offset(200, 300), 180, spin: 500);
    field.swirl(const Offset(200, 300), 180, spin: -300, pull: -0.4);
    for (var i = 0; i < 30; i++) {
      field.step(1 / 60);
    }
    field.dispose();
  });
}
