// lib/games/shared/enemy_facing.dart
//
// Which way an enemy's BODY points, as opposed to which way it is steering.
//
// Steering sets a heading outright every frame — straight from the velocity,
// or snapped to an aim the moment a wind-up starts — and an elongated body
// drawn at that heading turns in jumps. The body follows the heading here
// instead, easing round at a rate, and remembers how fast it is turning so
// the painter can bank it into the turn. Visual only: movement, aim and
// collision still use the real heading.

import 'dart:math';

class EnemyFacing {
  double _angle = double.nan;
  double _turn = 0;
  double _at = -1;

  /// Where the body points.
  double get angle => _angle;

  /// How fast it is turning, radians a second, smoothed; positive is
  /// clockwise on screen.
  double get turn => _turn;

  /// Eases toward [target] for the frame at [time] (seconds, the render
  /// clock). Idempotent within a frame, and snaps after a gap (first sight,
  /// a pause, a rewound clock) rather than swinging round from a stale pose.
  double follow(double target, double time, {double rate = 9}) {
    final dt = time - _at;
    if (_angle.isNaN || dt < 0 || dt > 0.5) {
      _angle = target;
      _turn = 0;
      _at = time;
      return _angle;
    }
    if (dt == 0) return _angle;
    _at = time;
    var d = target - _angle;
    while (d > pi) {
      d -= 2 * pi;
    }
    while (d < -pi) {
      d += 2 * pi;
    }
    final step = d * (1 - exp(-rate * dt));
    _angle += step;
    _turn += (step / dt - _turn) * (1 - exp(-6 * dt));
    return _angle;
  }
}
