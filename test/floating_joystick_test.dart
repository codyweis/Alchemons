import 'package:alchemons/screens/cosmic/widgets/virtual_joystick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The floating joystick waits faintly at its home; a thumb anywhere brings
/// it, lit, to that spot, and it glides home and dims when let go.
void main() {
  testWidgets('faint at rest, steers from where the thumb lands', (
    tester,
  ) async {
    final dirs = <Offset?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: FloatingJoystick(onDirectionChanged: dirs.add),
          ),
        ),
      ),
    );
    double shown() => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(FloatingJoystick),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    Offset lensAt() => tester.getCenter(
      find.descendant(
        of: find.byType(FloatingJoystick),
        matching: find.byType(RepaintBoundary),
      ),
    );
    expect(shown(), closeTo(0.3, 1e-9), reason: 'faint at rest');
    final home = lensAt();
    expect(home.dx, lessThan(150), reason: 'home in the bottom-left');
    expect(home.dy, greaterThan(150));

    final g = await tester.startGesture(const Offset(150, 150));
    await tester.pump();
    expect(shown(), 1.0, reason: 'lit while held');
    expect(lensAt(), const Offset(150, 150), reason: 'under the thumb');
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    final steering = dirs.whereType<Offset>().last;
    expect(steering.dx, greaterThan(0.9), reason: 'right, from the landing');
    expect(steering.dy.abs(), lessThan(0.05));

    await g.up();
    await tester.pumpAndSettle();
    expect(dirs.last, isNull);
    expect(shown(), closeTo(0.3, 1e-9), reason: 'dims when let go');
    expect(lensAt(), home, reason: 'glides home');
    expect(tester.takeException(), isNull);
  });
}
