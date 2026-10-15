import 'package:alchemons/screens/cosmic/widgets/space_trigger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Space's combat buttons take presses from raw pointers: a held boost or
// trigger stays on however far the thumb drifts, and a toggle is taken as
// the finger lands (user 2026-10-14: "it always stops going when I pressing
// it down").

const _plate = Key('plate');

Widget _host(Widget trigger) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: trigger),
);

Widget _hold(List<bool> log, {double reach = 8}) => SpaceTrigger.hold(
  reach: reach,
  onHeld: log.add,
  child: const SizedBox(key: _plate, width: 62, height: 62),
);

void main() {
  testWidgets('a hold stays on while the thumb drifts, off when it lifts', (
    tester,
  ) async {
    final log = <bool>[];
    await tester.pumpWidget(_host(_hold(log)));
    final g = await tester.startGesture(tester.getCenter(find.byKey(_plate)));
    expect(log, [true]);
    // Well past any tap's slop, and off the button altogether.
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(14, -9));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(log, [true]);
    await g.up();
    expect(log, [true, false]);
  });

  testWidgets('two fingers: it lets go with the last of them', (tester) async {
    final log = <bool>[];
    await tester.pumpWidget(_host(_hold(log)));
    final at = tester.getCenter(find.byKey(_plate));
    final a = await tester.startGesture(at, pointer: 1);
    final b = await tester.startGesture(at + const Offset(10, 0), pointer: 2);
    await a.up();
    expect(log, [true]);
    await b.up();
    expect(log, [true, false]);
  });

  testWidgets('a toggle is taken as the finger lands, drift or not', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      _host(
        SpaceTrigger.toggle(
          reach: 8,
          onPressed: () => presses++,
          child: const SizedBox(key: _plate, width: 62, height: 62),
        ),
      ),
    );
    final g = await tester.startGesture(tester.getCenter(find.byKey(_plate)));
    expect(presses, 1);
    await g.moveBy(const Offset(60, 40));
    await g.up();
    expect(presses, 1);
  });

  testWidgets('a thumb just off the plate still presses it', (tester) async {
    final log = <bool>[];
    await tester.pumpWidget(_host(_hold(log)));
    final edge = tester.getTopRight(find.byKey(_plate));
    final g = await tester.startGesture(edge + const Offset(6, -6));
    expect(log, [true]);
    await g.up();
    // Past the reach, nothing.
    final far = await tester.startGesture(edge + const Offset(14, -14));
    await far.up();
    expect(log, [true, false]);
  });

  testWidgets('taken away mid-hold, it lets go', (tester) async {
    final log = <bool>[];
    await tester.pumpWidget(_host(_hold(log)));
    final g = await tester.startGesture(tester.getCenter(find.byKey(_plate)));
    expect(log, [true]);
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pump();
    expect(log, [true, false]);
    await g.up();
    expect(log, [true, false]);
  });

  testWidgets('turned into a toggle mid-hold, the hold ends', (tester) async {
    final log = <bool>[];
    var presses = 0;
    await tester.pumpWidget(_host(_hold(log)));
    final g = await tester.startGesture(tester.getCenter(find.byKey(_plate)));
    await tester.pumpWidget(
      _host(
        SpaceTrigger.toggle(
          reach: 8,
          onPressed: () => presses++,
          child: const SizedBox(key: _plate, width: 62, height: 62),
        ),
      ),
    );
    await tester.pump();
    expect(log, [true, false]);
    await g.up();
    expect(presses, 0);
  });
}
