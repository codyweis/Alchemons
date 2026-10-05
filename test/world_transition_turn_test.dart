// Entering the wild turns the phone to landscape under the glyph portal's
// black. The page is pushed the moment the turn is asked for, and a wild
// field bakes all its art on its first frame — so if that frame were laid
// out tall, the field would bake twice on black, once for nothing. These pin
// that the page is laid out wide from its first frame, keeps its state when
// the turn lands, and that the black never waits out its timeout for a turn
// that is not coming.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_portal.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _tall = Size(412, 915);
const _dpr = 2.625;

/// Records every size it is laid out at and how often it was created.
class _Probe extends StatefulWidget {
  const _Probe(this.sizes, this.inits);

  final List<Size> sizes;
  final List<int> inits;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.inits.add(1);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      widget.sizes.add(c.biggest);
      return const ColoredBox(color: Color(0xFF203040));
    },
  );
}

void main() {
  late List<MethodCall> platformCalls;

  Future<(List<Size>, List<int>)> enter(
    WidgetTester tester, {
    required Size window,
  }) async {
    tester.view.physicalSize = window * _dpr;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    platformCalls = [];
    final messenger = tester.binding.defaultBinaryMessenger;
    // The system, and Android's seamless-rotation hook.
    for (final channel in const [
      SystemChannels.platform,
      MethodChannel('alchemons/rotation'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        platformCalls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final sizes = <Size>[];
    final inits = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => VoidPortal.pushThroughGlyphs<void>(
                context,
                page: _Probe(sizes, inits),
                title: 'Valley',
                orientation: const [
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ],
                returnOrientation: const [
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ],
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    return (sizes, inits);
  }

  final portal = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is PortalPainter,
  );

  /// Pumps 16 ms frames until the portal itself is up; returns how long.
  Future<double> untilPortal(WidgetTester tester, {double limit = 3}) async {
    var t = 0.0;
    while (portal.evaluate().isEmpty && t < limit) {
      await tester.pump(const Duration(milliseconds: 16));
      t += 0.016;
    }
    return t;
  }

  Future<void> playOut(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('the page is laid out wide from its first frame, and keeps '
      'its state when the turn lands', (tester) async {
    final (sizes, inits) = await enter(tester, window: _tall);
    // The dip to black, the turn asked for, the push.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      platformCalls.map((c) => c.method),
      contains('SystemChrome.setPreferredOrientations'),
    );
    expect(sizes, isNotEmpty, reason: 'pushed while the system turns');
    expect(tester.view.physicalSize, _tall * _dpr, reason: 'not turned yet');
    expect(sizes.toSet(), {_tall.flipped});
    expect(portal, findsNothing, reason: 'still black while turning');

    // The system lands the turn a few hundred ms later.
    await tester.pump(const Duration(milliseconds: 200));
    tester.view.physicalSize = _tall.flipped * _dpr;
    final t = await untilPortal(tester);
    expect(t, lessThan(0.3));

    expect(sizes.toSet(), {_tall.flipped}, reason: 'never laid out tall');
    expect(inits, [1], reason: 'the same page, not a rebuilt one');

    // Let the portal play out and leave.
    await playOut(tester);
    expect(portal, findsNothing);
    expect(sizes.toSet(), {_tall.flipped});
  });

  testWidgets('a turn the system ignores: the page falls back to the real '
      'window after the timeout', (tester) async {
    final (sizes, inits) = await enter(tester, window: _tall);
    final t = await untilPortal(tester);
    // 0.25 s to black + the 1 s wait for a turn that never came.
    expect(t, greaterThan(1.2));
    expect(sizes.last, _tall);
    expect(inits, [1]);
    await playOut(tester);
  });

  testWidgets('already wide: no wait for a turn that is not coming', (
    tester,
  ) async {
    final (sizes, inits) = await enter(tester, window: _tall.flipped);
    final t = await untilPortal(tester);
    expect(t, lessThan(0.4), reason: 'was the full 1 s timeout on black');
    expect(sizes.toSet(), {_tall.flipped});
    expect(inits, [1]);
    await playOut(tester);
  });
}
