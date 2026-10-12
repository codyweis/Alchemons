// What a controller (or the keyboard) shows on screen: a pointer at the
// party slot it has chosen, and the controls card in a mode's pause or
// settings panel. Neither shows for a player on touch alone.

import 'package:alchemons/services/game_controller_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The brass a controller's choice is lit in.
const Color kPadChosenColor = Color(0xFFE2C98F);

/// Points at [child] from its left while it is [chosen] and the player is
/// on a controller or keyboard. A small solid brass pointer rather than a
/// lit frame, because the slots it marks already light their frames to say
/// a companion is out.
class PadChosen extends StatelessWidget {
  const PadChosen({super.key, required this.chosen, required this.child});

  final bool chosen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayInputMode>(
      valueListenable: GameControllerService.instance.mode,
      child: child,
      builder: (context, mode, child) => CustomPaint(
        foregroundPainter: chosen && mode != PlayInputMode.touch
            ? const _PadPointerPainter()
            : null,
        child: child,
      ),
    );
  }
}

/// One line of a controls card: the buttons, and what they do in this mode.
typedef PadBinding = (List<GamepadButton> buttons, String does);

/// The name of [button] on a pad (Xbox letters) or the keyboard.
String padButtonLabel(GamepadButton button, {required bool keyboard}) {
  if (keyboard) return GameControllerService.keyLabel(button);
  return switch (button) {
    GamepadButton.a => 'A',
    GamepadButton.b => 'B',
    GamepadButton.x => 'X',
    GamepadButton.y => 'Y',
    GamepadButton.leftBumper => 'LB',
    GamepadButton.rightBumper => 'RB',
    GamepadButton.leftTrigger => 'LT',
    GamepadButton.rightTrigger => 'RT',
    GamepadButton.leftStick => 'L3',
    GamepadButton.rightStick => 'R3',
    GamepadButton.start => 'START',
    GamepadButton.back => 'SELECT',
    GamepadButton.home => 'HOME',
    GamepadButton.touchpad => 'PAD',
    GamepadButton.dpadUp => 'UP',
    GamepadButton.dpadDown => 'DOWN',
    GamepadButton.dpadLeft => 'LEFT',
    GamepadButton.dpadRight => 'RIGHT',
  };
}

/// The browser on a computer, where the keyboard is always to hand.
bool get _desktopWeb =>
    kIsWeb &&
    defaultTargetPlatform != TargetPlatform.iOS &&
    defaultTargetPlatform != TargetPlatform.android;

/// The controls for a mode, in a plain two-column list. Shown while a
/// gamepad is connected or being played, the keys once one is pressed, and
/// always in a computer's browser; on a phone with no pad it takes no space.
class ControllerLegend extends StatelessWidget {
  const ControllerLegend({
    super.key,
    required this.bindings,
    this.move = 'MOVE',
    this.aim,
    this.padding = EdgeInsets.zero,
    this.muted = const Color(0xFF9A93A6),
  });

  final List<PadBinding> bindings;

  /// What the left stick (WASD) does.
  final String move;

  /// What the right stick does, if anything.
  final String? aim;

  /// Space around the card when it shows; none when it doesn't.
  final EdgeInsets padding;

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final svc = GameControllerService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([svc.mode, svc.gamepadConnected]),
      builder: (context, _) {
        final mode = svc.mode.value;
        final pad =
            mode == PlayInputMode.gamepad ||
            (svc.gamepadConnected.value && mode != PlayInputMode.keyboard);
        if (!pad && mode != PlayInputMode.keyboard && !_desktopWeb) {
          return const SizedBox.shrink();
        }
        final keyboard = !pad;
        final rows = <(String, String)>[
          (keyboard ? 'WASD' : 'L STICK', move),
          if (aim != null && !keyboard) ('R STICK', aim!),
          for (final (buttons, does) in bindings)
            (
              buttons
                  .map((b) => padButtonLabel(b, keyboard: keyboard))
                  .where((l) => l.isNotEmpty)
                  .join(' / '),
              does,
            ),
        ];
        return Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final (key, does) in rows)
                    SizedBox(
                      width: cell,
                      child: Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 44),
                            child: Text(
                              key,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: kPadChosenColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              does,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// A brass pointer just outside [PadChosen]'s left edge, at its middle.
class _PadPointerPainter extends CustomPainter {
  const _PadPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final tip = Path()
      ..moveTo(-10, cy - 5.5)
      ..lineTo(-3, cy)
      ..lineTo(-10, cy + 5.5)
      ..close();
    canvas.drawPath(
      tip,
      Paint()..color = const Color(0xFF0B0B10).withValues(alpha: 0.7),
    );
    canvas.drawPath(
      tip.shift(const Offset(0.6, 0)),
      Paint()..color = kPadChosenColor,
    );
  }

  @override
  bool shouldRepaint(_PadPointerPainter oldDelegate) => false;
}
