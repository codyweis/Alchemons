import 'package:alchemons/services/game_controller_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

final _svc = GameControllerService.instance;

NormalizedGamepadEvent _axis(GamepadAxis axis, double value) =>
    NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      axis: axis,
      value: value,
      rawEvent: GamepadEvent(
        gamepadId: '1',
        timestamp: 0,
        type: KeyType.analog,
        key: axis.name,
        value: value,
      ),
    );

NormalizedGamepadEvent _button(GamepadButton button, {required bool down}) =>
    NormalizedGamepadEvent(
      gamepadId: '1',
      timestamp: 0,
      button: button,
      value: down ? 1 : 0,
      rawEvent: GamepadEvent(
        gamepadId: '1',
        timestamp: 0,
        type: KeyType.button,
        key: button.name,
        value: down ? 1 : 0,
      ),
    );

void _press(GamepadButton b) => _svc.debugPadEvent(_button(b, down: true));
void _release(GamepadButton b) => _svc.debugPadEvent(_button(b, down: false));

/// A play screen that records what the controller sends it.
class _Play extends StatefulWidget {
  const _Play({required this.log});
  final List<String> log;

  @override
  State<_Play> createState() => _PlayState();
}

class _PlayState extends State<_Play> {
  PlayInputClaim? _claim;
  Offset move = Offset.zero;

  @override
  void initState() {
    super.initState();
    _claim = _svc.claim(
      context,
      onMove: (v) => move = v,
      onPressed: (b) => widget.log.add('down ${b.name}'),
      onReleased: (b) => widget.log.add('up ${b.name}'),
    );
  }

  @override
  void dispose() {
    _claim?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Future<_PlayState> _pumpPlay(WidgetTester tester, List<String> log) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [_svc.navigatorObserver],
      home: _Play(log: log),
    ),
  );
  return tester.state<_PlayState>(find.byType(_Play));
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _svc.start();
  });
  setUp(_svc.debugReset);

  testWidgets('stick: dead zone, screen-down y, full tilt is one', (
    tester,
  ) async {
    final play = await _pumpPlay(tester, []);

    _svc.debugPadEvent(_axis(GamepadAxis.leftStickX, 0.15));
    expect(play.move, Offset.zero, reason: 'inside the dead zone');
    expect(_svc.mode.value, PlayInputMode.touch);

    _svc.debugPadEvent(_axis(GamepadAxis.leftStickX, 0));
    _svc.debugPadEvent(_axis(GamepadAxis.leftStickY, 1));
    expect(play.move.dx, closeTo(0, 1e-9));
    expect(play.move.dy, closeTo(-1, 1e-9), reason: 'pad up is screen up');
    expect(_svc.mode.value, PlayInputMode.gamepad);

    _svc.debugPadEvent(_axis(GamepadAxis.leftStickY, 0));
    expect(play.move, Offset.zero);
  });

  testWidgets('d-pad diagonals are no faster than straight', (tester) async {
    final play = await _pumpPlay(tester, []);
    _press(GamepadButton.dpadRight);
    _press(GamepadButton.dpadDown);
    expect(play.move.distance, closeTo(1, 1e-9));
    expect(play.move.dx, greaterThan(0));
    expect(play.move.dy, greaterThan(0));
    _release(GamepadButton.dpadRight);
    _release(GamepadButton.dpadDown);
    expect(play.move, Offset.zero);
  });

  testWidgets('only the topmost claim hears buttons; releases go home', (
    tester,
  ) async {
    final under = <String>[];
    final over = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            _Play(log: under),
            _Play(log: over),
          ],
        ),
      ),
    );

    _press(GamepadButton.x);
    expect(over, ['down x']);
    expect(under, isEmpty);

    // The top screen goes while X is held: the screen left underneath never
    // sees a release it had no press for.
    await tester.pumpWidget(MaterialApp(home: _Play(log: under)));
    _release(GamepadButton.x);
    expect(under, isEmpty);

    _press(GamepadButton.a);
    expect(under, ['down a']);
  });

  testWidgets('a dialog over play holds the buttons; B closes it', (
    tester,
  ) async {
    final log = <String>[];
    final play = await _pumpPlay(tester, log);

    showDialog<void>(
      context: play.context,
      builder: (_) => const AlertDialog(content: Text('Leave?')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave?'), findsOneWidget);

    _press(GamepadButton.a);
    _release(GamepadButton.a);
    expect(log, isEmpty, reason: 'the game must not act under a dialog');

    _press(GamepadButton.b);
    _release(GamepadButton.b);
    await tester.pumpAndSettle();
    expect(find.text('Leave?'), findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('over a page, B goes back and Start does not', (tester) async {
    final log = <String>[];
    final play = await _pumpPlay(tester, log);
    Navigator.of(
      play.context,
    ).push(MaterialPageRoute<void>(builder: (_) => const Text('A menu page')));
    await tester.pumpAndSettle();

    _press(GamepadButton.start);
    _release(GamepadButton.start);
    await tester.pumpAndSettle();
    expect(find.text('A menu page'), findsOneWidget);

    _press(GamepadButton.b);
    _release(GamepadButton.b);
    await tester.pumpAndSettle();
    expect(find.text('A menu page'), findsNothing);
    expect(log, isEmpty, reason: 'the back press is not the game\'s');
  });

  testWidgets('in the menus, with no play screen, B is back', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [_svc.navigatorObserver],
        home: const Text('Home'),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Shop')),
    );
    await tester.pumpAndSettle();
    _press(GamepadButton.b);
    _release(GamepadButton.b);
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Start closes a dialog over play', (tester) async {
    final play = await _pumpPlay(tester, []);
    showDialog<void>(
      context: play.context,
      builder: (_) => const AlertDialog(content: Text('Save and exit?')),
    );
    await tester.pumpAndSettle();
    _press(GamepadButton.start);
    _release(GamepadButton.start);
    await tester.pumpAndSettle();
    expect(find.text('Save and exit?'), findsNothing);
  });

  testWidgets('keys: WASD moves and Space is A', (tester) async {
    final log = <String>[];
    final play = await _pumpPlay(tester, log);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    expect(_svc.mode.value, PlayInputMode.keyboard);
    expect(play.move.distance, closeTo(1, 1e-9));
    expect(play.move.dx, greaterThan(0));
    expect(play.move.dy, lessThan(0));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    expect(play.move, Offset.zero);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(log, ['down a', 'up a']);
  });

  testWidgets('keys stay with a focused text field, even over play', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            _Play(log: log),
            const Material(child: TextField()),
          ],
        ),
      ),
    );
    final play = tester.state<_PlayState>(find.byType(_Play));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    final consumed = await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(consumed, isFalse);
    expect(play.move, Offset.zero);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(log, isEmpty);
  });

  testWidgets('keys pass through with no play screen up', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final consumed = await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    expect(consumed, isFalse);
    expect(_svc.mode.value, PlayInputMode.touch);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  });

  testWidgets('a touch brings the touch controls back', (tester) async {
    await _pumpPlay(tester, []);
    _press(GamepadButton.a);
    expect(_svc.mode.value, PlayInputMode.gamepad);
    await tester.tapAt(const Offset(10, 10));
    expect(_svc.mode.value, PlayInputMode.touch);
  });

  testWidgets('unplugging lets go of everything', (tester) async {
    final log = <String>[];
    final play = await _pumpPlay(tester, log);
    _svc.debugConnection(
      GamepadConnectionEvent(
        gamepadId: '1',
        name: 'Pad',
        type: GamepadConnectionEventType.connected,
      ),
    );
    expect(_svc.gamepadConnected.value, isTrue);
    _press(GamepadButton.rightTrigger);
    _svc.debugPadEvent(_axis(GamepadAxis.leftStickX, 1));
    expect(play.move, isNot(Offset.zero));

    _svc.debugConnection(
      GamepadConnectionEvent(
        gamepadId: '1',
        name: 'Pad',
        type: GamepadConnectionEventType.disconnected,
      ),
    );
    expect(log, ['down rightTrigger', 'up rightTrigger']);
    expect(play.move, Offset.zero);
    expect(_svc.mode.value, PlayInputMode.touch);
    expect(_svc.gamepadConnected.value, isFalse);
  });

  testWidgets('an analog trigger presses past halfway', (tester) async {
    final log = <String>[];
    await _pumpPlay(tester, log);
    _svc.debugPadEvent(_axis(GamepadAxis.rightTrigger, 0.4));
    expect(log, isEmpty);
    _svc.debugPadEvent(_axis(GamepadAxis.rightTrigger, 0.7));
    _svc.debugPadEvent(_axis(GamepadAxis.rightTrigger, 0.45));
    expect(log, ['down rightTrigger'], reason: 'no chatter near the line');
    _svc.debugPadEvent(_axis(GamepadAxis.rightTrigger, 0));
    expect(log, ['down rightTrigger', 'up rightTrigger']);
  });
}
