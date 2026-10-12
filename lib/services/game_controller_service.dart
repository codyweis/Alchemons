// Game controllers (and the keyboard) for the action modes.
//
// One service turns whatever the player is holding into what the play
// screens already understand: a move vector shaped exactly like the
// on-screen joystick's (y down, length 0–1) and button presses. Menus stay
// touch; only a screen that claims input hears the controller, and only the
// topmost claim at that.
//
// Gamepads arrive through the `gamepads` plugin's normalized stream, in Xbox
// names (A is the bottom face button on every pad). The keyboard is folded
// into the same buttons, the face buttons as a diamond under the right hand
// the way they sit on a pad:
//
//   WASD / arrows  move           I       Y
//   Space / K      A           J     L   X  B
//   Q / E          LB / RB         K       A
//   Z / Shift      LT / RT
//   T / R          L3 / R3        Esc / P  Start     Tab / M  Select

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';

export 'package:gamepads/gamepads.dart' show GamepadButton;

/// What the player last played with. The touch joystick hides while it is
/// anything but [touch]; a touch on the screen brings it straight back.
enum PlayInputMode { touch, gamepad, keyboard }

/// A play screen's hold on controller input, made by
/// [GameControllerService.claim]. [release] it in `dispose`.
class PlayInputClaim {
  PlayInputClaim._(
    this._service,
    this._context, {
    this.onMove,
    this.onAim,
    this.onPressed,
    this.onReleased,
  });

  final GameControllerService _service;
  final BuildContext _context;

  /// The merged move vector (left stick, d-pad or keys), y down, length 0–1.
  /// Always sent to the topmost claim, even under a dialog, so the game
  /// never resumes steering a direction the player already let go of.
  final ValueChanged<Offset>? onMove;

  /// The right stick, the same shape as [onMove].
  final ValueChanged<Offset>? onAim;

  final ValueChanged<GamepadButton>? onPressed;

  /// Releases go back to the claim that heard the press, whether or not it
  /// is still on top, so nothing a screen holds can stick on.
  final ValueChanged<GamepadButton>? onReleased;

  /// Whether the screen can take buttons: mounted, and its route on top, so
  /// a dialog over the game takes nothing it shouldn't.
  bool get _active =>
      _context.mounted && ModalRoute.isCurrentOf(_context) != false;

  void release() => _service._release(this);
}

class GameControllerService {
  GameControllerService._();
  static final GameControllerService instance = GameControllerService._();

  /// What the player is using; drives the touch joystick and the marks.
  final ValueNotifier<PlayInputMode> mode = ValueNotifier(PlayInputMode.touch);

  /// Watches the app's navigator, for B as the back button in the menus.
  /// Goes in the app's `navigatorObservers`.
  final NavigatorObserver navigatorObserver = NavigatorObserver();

  /// Whether a gamepad is connected, played with or not.
  final ValueNotifier<bool> gamepadConnected = ValueNotifier(false);

  /// Stick dead zone, as a fraction of full tilt. Worn sticks rest well off
  /// centre; inside this radius they read as still.
  static const double deadZone = 0.2;

  /// Trigger travel that counts as a press.
  static const double _triggerPress = 0.5;

  final List<PlayInputClaim> _claims = [];
  final Set<GamepadButton> _padDown = {};
  final Set<GamepadButton> _keyDown = {};
  final Map<GamepadButton, PlayInputClaim> _pressOwner = {};
  final Set<String> _connected = {};

  // Sticks as the plugin reports them: y up.
  double _lx = 0, _ly = 0, _rx = 0, _ry = 0;
  final Set<LogicalKeyboardKey> _moveKeys = {};
  Offset _move = Offset.zero;
  Offset _aim = Offset.zero;

  bool _started = false;

  /// Starts listening. Called once from `main`.
  void start() {
    if (_started) return;
    _started = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    try {
      // Both live as long as the app does.
      Gamepads.normalizedEvents.listen(
        _onPad,
        onError: (Object e) => debugPrint('Gamepad events: $e'),
      );
      Gamepads.connectionEvents.listen(
        _onConnection,
        onError: (Object e) => debugPrint('Gamepad connections: $e'),
      );
      Gamepads.list()
          .then((pads) {
            for (final pad in pads) {
              _connected.add(pad.id);
              pad.dispose();
            }
            gamepadConnected.value = _connected.isNotEmpty;
          })
          .catchError((Object e) {
            debugPrint('Gamepad list: $e');
          });
    } catch (e) {
      // No plugin on this platform: the keyboard still works.
      debugPrint('Gamepads unavailable: $e');
    }
  }

  /// Claims controller input for a play screen; the newest claim is on top.
  /// [context] is the screen's own, so a dialog pushed over it holds the
  /// buttons back (B and Start close that dialog instead).
  PlayInputClaim claim(
    BuildContext context, {
    ValueChanged<Offset>? onMove,
    ValueChanged<Offset>? onAim,
    ValueChanged<GamepadButton>? onPressed,
    ValueChanged<GamepadButton>? onReleased,
  }) {
    // The screen underneath stops steering; it gets the sticks back when
    // this claim is released.
    final under = _top;
    under?.onMove?.call(Offset.zero);
    under?.onAim?.call(Offset.zero);
    final c = PlayInputClaim._(
      this,
      context,
      onMove: onMove,
      onAim: onAim,
      onPressed: onPressed,
      onReleased: onReleased,
    );
    _claims.add(c);
    if (_move != Offset.zero) onMove?.call(_move);
    if (_aim != Offset.zero) onAim?.call(_aim);
    return c;
  }

  /// Whether [button] is held on a controller or the keyboard.
  bool isDown(GamepadButton button) =>
      _padDown.contains(button) || _keyDown.contains(button);

  /// The move vector as it stands (y down, length 0–1).
  Offset get move => _move;

  PlayInputClaim? get _top => _claims.isEmpty ? null : _claims.last;

  void _release(PlayInputClaim c) {
    final wasTop = identical(_top, c);
    _claims.remove(c);
    _pressOwner.removeWhere((_, owner) => identical(owner, c));
    if (wasTop) {
      _top?.onMove?.call(_move);
      _top?.onAim?.call(_aim);
    }
  }

  /// Feeds [e] in as if the plugin had sent it.
  @visibleForTesting
  void debugPadEvent(NormalizedGamepadEvent e) => _onPad(e);

  /// Feeds [e] in as if the plugin had sent it.
  @visibleForTesting
  void debugConnection(GamepadConnectionEvent e) => _onConnection(e);

  /// Forgets every claim, held button and stick, between tests.
  @visibleForTesting
  void debugReset() {
    _claims.clear();
    _padDown.clear();
    _keyDown.clear();
    _pressOwner.clear();
    _connected.clear();
    _moveKeys.clear();
    _lx = _ly = _rx = _ry = 0;
    _move = _aim = Offset.zero;
    mode.value = PlayInputMode.touch;
    gamepadConnected.value = false;
    // The test binding clears keyboard handlers between tests.
    if (_started) {
      HardwareKeyboard.instance.removeHandler(_onKey);
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  // ── Gamepad ────────────────────────────────────────────────────────────

  void _onConnection(GamepadConnectionEvent e) {
    if (e.type == GamepadConnectionEventType.connected) {
      _connected.add(e.gamepadId);
    } else {
      _connected.remove(e.gamepadId);
    }
    gamepadConnected.value = _connected.isNotEmpty;
    if (_connected.isNotEmpty) return;
    // Unplugged mid-run: let go of everything it was holding.
    _lx = _ly = _rx = _ry = 0;
    for (final b in _padDown.toList()) {
      _buttonUp(b, fromPad: true);
    }
    _updateSticks();
    if (mode.value == PlayInputMode.gamepad) mode.value = PlayInputMode.touch;
  }

  void _onPad(NormalizedGamepadEvent e) {
    final axis = e.axis;
    if (axis != null) {
      switch (axis) {
        case GamepadAxis.leftStickX:
          _lx = e.value;
        case GamepadAxis.leftStickY:
          _ly = e.value;
        case GamepadAxis.rightStickX:
          _rx = e.value;
        case GamepadAxis.rightStickY:
          _ry = e.value;
        case GamepadAxis.leftTrigger:
          _triggerAxis(GamepadButton.leftTrigger, e.value);
          return;
        case GamepadAxis.rightTrigger:
          _triggerAxis(GamepadButton.rightTrigger, e.value);
          return;
      }
      _updateSticks();
      return;
    }
    final button = e.button;
    if (button == null) return;
    if (e.value > 0.5) {
      _buttonDown(button, fromPad: true);
    } else {
      _buttonUp(button, fromPad: true);
    }
  }

  void _triggerAxis(GamepadButton button, double value) {
    // A little hysteresis, so a trigger resting near the line can't chatter.
    if (value >= _triggerPress) {
      _buttonDown(button, fromPad: true);
    } else if (value < _triggerPress * 0.6) {
      _buttonUp(button, fromPad: true);
    }
  }

  // ── Keyboard ───────────────────────────────────────────────────────────

  static final Map<LogicalKeyboardKey, GamepadButton> _keyButtons = {
    LogicalKeyboardKey.space: GamepadButton.a,
    LogicalKeyboardKey.enter: GamepadButton.a,
    LogicalKeyboardKey.keyK: GamepadButton.a,
    LogicalKeyboardKey.keyL: GamepadButton.b,
    LogicalKeyboardKey.keyJ: GamepadButton.x,
    LogicalKeyboardKey.keyI: GamepadButton.y,
    LogicalKeyboardKey.keyQ: GamepadButton.leftBumper,
    LogicalKeyboardKey.keyE: GamepadButton.rightBumper,
    LogicalKeyboardKey.keyZ: GamepadButton.leftTrigger,
    LogicalKeyboardKey.shiftLeft: GamepadButton.rightTrigger,
    LogicalKeyboardKey.shiftRight: GamepadButton.rightTrigger,
    LogicalKeyboardKey.keyT: GamepadButton.leftStick,
    LogicalKeyboardKey.keyR: GamepadButton.rightStick,
    LogicalKeyboardKey.escape: GamepadButton.start,
    LogicalKeyboardKey.keyP: GamepadButton.start,
    LogicalKeyboardKey.tab: GamepadButton.back,
    LogicalKeyboardKey.keyM: GamepadButton.back,
  };

  static final Map<LogicalKeyboardKey, Offset> _keyDirections = {
    LogicalKeyboardKey.keyW: const Offset(0, -1),
    LogicalKeyboardKey.arrowUp: const Offset(0, -1),
    LogicalKeyboardKey.keyS: const Offset(0, 1),
    LogicalKeyboardKey.arrowDown: const Offset(0, 1),
    LogicalKeyboardKey.keyA: const Offset(-1, 0),
    LogicalKeyboardKey.arrowLeft: const Offset(-1, 0),
    LogicalKeyboardKey.keyD: const Offset(1, 0),
    LogicalKeyboardKey.arrowRight: const Offset(1, 0),
  };

  /// The keyboard name of [button], for the controls card.
  static String keyLabel(GamepadButton button) => switch (button) {
    GamepadButton.a => 'SPACE',
    GamepadButton.b => 'L',
    GamepadButton.x => 'J',
    GamepadButton.y => 'I',
    GamepadButton.leftBumper => 'Q',
    GamepadButton.rightBumper => 'E',
    GamepadButton.leftTrigger => 'Z',
    GamepadButton.rightTrigger => 'SHIFT',
    GamepadButton.leftStick => 'T',
    GamepadButton.rightStick => 'R',
    GamepadButton.start => 'ESC',
    GamepadButton.back => 'TAB',
    _ => '',
  };

  /// Whether a text field has the keyboard. Its focus node belongs to a
  /// Focus inside the EditableText, so look up from there.
  static bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    final key = event.logicalKey;
    final dir = _keyDirections[key];
    final button = _keyButtons[key];
    if (dir == null && button == null) return false;

    if (event is KeyUpEvent) {
      // Always let go, even if play has since lost the keys.
      final wasMove = _moveKeys.remove(key);
      if (wasMove) _updateSticks();
      var wasButton = false;
      if (button != null && _keyDown.contains(button)) {
        wasButton = true;
        final otherKeyHolds = _keyButtons.entries.any(
          (e) =>
              e.value == button &&
              e.key != key &&
              HardwareKeyboard.instance.isLogicalKeyPressed(e.key),
        );
        if (!otherKeyHolds) _buttonUp(button, fromPad: false);
      }
      return wasMove || wasButton;
    }

    // Keys go to play only while a play screen is on top and no text field
    // has focus (friend codes, names); arrows, Space and Esc keep their usual
    // jobs everywhere else, dialogs over play included.
    final top = _top;
    if (top == null || !top._active || _typing) return false;
    if (event is KeyRepeatEvent) return true;

    _setMode(PlayInputMode.keyboard);
    if (dir != null) {
      _moveKeys.add(key);
      _updateSticks();
    }
    if (button != null) _buttonDown(button, fromPad: false);
    return true;
  }

  // ── Touch ──────────────────────────────────────────────────────────────

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _setMode(PlayInputMode.touch);
  }

  // ── Shared ─────────────────────────────────────────────────────────────

  void _setMode(PlayInputMode m) {
    if (mode.value != m) mode.value = m;
  }

  /// A stick past the dead zone, rescaled so the edge of the zone is zero
  /// and full tilt is one. Y flips to screen down.
  static Offset _shape(double x, double y) {
    final v = Offset(x, -y);
    final len = v.distance;
    if (len <= deadZone) return Offset.zero;
    return v / len * math.min(1.0, (len - deadZone) / (1 - deadZone));
  }

  static bool _same(Offset a, Offset b) =>
      (a - b).distance < 0.01 && (a == Offset.zero) == (b == Offset.zero);

  void _updateSticks() {
    // The stick first; the d-pad and keys steer while it rests.
    var move = _shape(_lx, _ly);
    if (move != Offset.zero) {
      _setMode(PlayInputMode.gamepad);
    } else {
      for (final (b, d) in const [
        (GamepadButton.dpadUp, Offset(0, -1)),
        (GamepadButton.dpadDown, Offset(0, 1)),
        (GamepadButton.dpadLeft, Offset(-1, 0)),
        (GamepadButton.dpadRight, Offset(1, 0)),
      ]) {
        if (_padDown.contains(b)) move += d;
      }
      for (final k in _moveKeys) {
        move += _keyDirections[k]!;
      }
      if (move != Offset.zero) {
        // Opposite keys cancel; a diagonal is no faster than straight.
        move = Offset(move.dx.clamp(-1.0, 1.0), move.dy.clamp(-1.0, 1.0));
        if (move != Offset.zero) move = move / move.distance;
      }
    }
    if (!_same(move, _move)) {
      _move = move;
      _top?.onMove?.call(move);
    }

    final aim = _shape(_rx, _ry);
    if (aim != Offset.zero) _setMode(PlayInputMode.gamepad);
    if (!_same(aim, _aim)) {
      _aim = aim;
      _top?.onAim?.call(aim);
    }
  }

  static bool _isDpad(GamepadButton b) =>
      b == GamepadButton.dpadUp ||
      b == GamepadButton.dpadDown ||
      b == GamepadButton.dpadLeft ||
      b == GamepadButton.dpadRight;

  void _buttonDown(GamepadButton b, {required bool fromPad}) {
    final down = fromPad ? _padDown : _keyDown;
    if (!down.add(b)) return;
    if (fromPad) _setMode(PlayInputMode.gamepad);
    if (_isDpad(b)) {
      _updateSticks();
      return;
    }
    // Already held through the other device: no second press.
    if ((fromPad ? _keyDown : _padDown).contains(b)) return;

    final top = _top;
    if (top != null && top._active) {
      _pressOwner[b] = top;
      top.onPressed?.call(b);
      return;
    }
    // Outside play (the menus, or a dialog or page over a play screen) B is
    // the back button, which is what Android made of it before the plugin
    // took the pad's keys; Start closes a dialog over play.
    if (b == GamepadButton.b) {
      final nav = navigatorObserver.navigator;
      if (nav != null) unawaited(nav.maybePop());
    } else if (b == GamepadButton.start && top != null) {
      _closeCoveringDialog(top._context);
    }
  }

  void _buttonUp(GamepadButton b, {required bool fromPad}) {
    final down = fromPad ? _padDown : _keyDown;
    if (!down.remove(b)) return;
    if (_isDpad(b)) {
      _updateSticks();
      return;
    }
    if ((fromPad ? _keyDown : _padDown).contains(b)) return;
    _pressOwner.remove(b)?.onReleased?.call(b);
  }

  /// Start over a dialog that covers a play screen (its leave or info
  /// dialogs) closes it, as the back button would. A full page on top is
  /// left alone.
  static void _closeCoveringDialog(BuildContext context) {
    if (!context.mounted) return;
    for (final nav in {
      Navigator.maybeOf(context, rootNavigator: true),
      Navigator.maybeOf(context),
    }) {
      if (nav == null) continue;
      Route<dynamic>? top;
      nav.popUntil((route) {
        top = route;
        return true;
      });
      if (top is PopupRoute) {
        unawaited(nav.maybePop());
        return;
      }
    }
  }
}
