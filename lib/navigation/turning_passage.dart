// lib/navigation/turning_passage.dart
//
// A passage that turns the phone: something lifted off the screen being
// left is carried into the middle, goes out for a moment while the phone
// turns (a turn hitches, and must never land on anything moving), comes
// back, and settles into its place on the page reached as the page comes up
// round it. VoidPortal.pushThroughTurn / leaveThroughTurn drive it (they
// own the turn and the push); a TurningScene draws it.
//
// The home trophy's way into the stadium is one (widgets/stadium_trophy.dart
// and screens/stadium/stadium_passage.dart): the cup's grains loosen into a
// turning ring, and the ring pours back into the cup on the stadium's shelf.

import 'dart:async';

import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// What a turning passage draws.
abstract class TurningScene {
  const TurningScene();

  /// Seconds from lifting off [TurningStage.from] to being held in the
  /// middle, the screen behind sinking under the ground.
  double get rise;

  /// Seconds from held in the middle to settled on [TurningStage.to], the
  /// page coming up round it.
  double get settle;

  /// Holds still through the turn instead of going out for it: while the
  /// window turns, [TurningStage.motion] stops, so the frames either side of
  /// the turn's hitch are the same frame. Only for a scene that is centred
  /// and looks the same a quarter turn round (a ring of grains in fours).
  bool get holdsThroughTurn => false;

  /// How much of the screen the passage's ground covers at [s].
  double groundAt(TurningStage s) {
    if (s.settle > 0) return 1 - _smooth(.4, .95, s.settle);
    return _smooth(0, .75, s.rise);
  }

  void paint(Canvas canvas, TurningStage s);
}

/// One moment of a turning passage.
@immutable
class TurningStage {
  const TurningStage({
    required this.screen,
    required this.time,
    required this.from,
    required this.to,
    required this.rise,
    required this.lit,
    required this.settle,
    this.motion = 0,
    this.pad = EdgeInsets.zero,
  });

  final Size screen;

  /// Seconds, from the shared [GlyphClock], so what settles matches what
  /// the page draws in its place from then on.
  final double time;

  /// Where it lifted off, on the screen left (null: the middle).
  final Rect? from;

  /// Where it settles, on the page reached (null: not known; the middle).
  final Rect? to;

  /// 0 in its place .. 1 held in the middle.
  final double rise;

  /// 1 lit .. 0 out while the phone turns.
  final double lit;

  /// 0 held in the middle .. 1 settled on the page.
  final double settle;

  /// Seconds the passage has been moving: stopped while the window turns
  /// under a scene that [TurningScene.holdsThroughTurn].
  final double motion;

  /// The screen's safe area, for a scene that lands on a page's layout.
  final EdgeInsets pad;
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

/// The overlay a turning passage plays in. [swap] turns the phone and
/// pushes or pops the page, while the scene is out; [ready] holds the
/// settle until the page is built (or a safety timeout passes).
class TurningPassageOverlay extends StatefulWidget {
  const TurningPassageOverlay({
    super.key,
    required this.scene,
    required this.from,
    required this.to,
    required this.swap,
    required this.turns,
    required this.onComplete,
    this.ready,
    this.onSettle,
  });

  final TurningScene scene;

  /// Where it lifts off, asked once, at the start.
  final Rect? from;

  /// Where it settles, asked every frame of the settle: the page reports it
  /// once it has laid out.
  final Rect? Function() to;
  final Future<void> Function() swap;

  /// The phone turns in the swap: the scene goes out for it.
  final bool turns;
  final ValueListenable<bool>? ready;

  /// The settle has begun.
  final VoidCallback? onSettle;

  /// The last frame of it has been drawn: the page is all there is now.
  final VoidCallback onComplete;

  @override
  State<TurningPassageOverlay> createState() => _TurningPassageOverlayState();
}

class _TurningPassageOverlayState extends State<TurningPassageOverlay>
    with SingleTickerProviderStateMixin, GlyphClockLease {
  /// The scene goes out over this long before the turn ...
  static const double _dimOut = .16;

  /// ... and comes back over this long after it, a beat later.
  static const double _litIn = .26, _litDelay = .05;

  /// Held lit in the middle at least this long before settling.
  static const double _minHold = .12;

  /// Settle regardless after this long past the swap.
  static const double _timeout = 8;

  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  double _t = 0;
  bool _swapStarted = false, _swapped = false, _done = false;
  double _swappedAt = 0;
  double? _settleAt;

  /// Time the motion was stopped for, and when the current stop began.
  double _stopped = 0;
  double? _stopFrom;
  double get _motion =>
      _t - _stopped - (_stopFrom == null ? 0 : _t - _stopFrom!);

  @override
  bool get wantsClock => !_done;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    releaseGlyphClock();
    super.dispose();
  }

  double get _rise => widget.scene.rise;

  void _onTick(Duration elapsed) {
    if (_done) return;
    final t = _t = elapsed.inMicroseconds / 1e6;
    final holds = widget.scene.holdsThroughTurn;
    final swapAt = _rise + (widget.turns && !holds ? _dimOut : 0);
    if (!_swapStarted && t >= swapAt) {
      _swapStarted = true;
      final hold = widget.scene.holdsThroughTurn && widget.turns;
      if (hold) _stopFrom = t;
      unawaited(
        widget.swap().catchError((Object _) {}).whenComplete(() {
          _swapped = true;
          _swappedAt = _t;
          final from = _stopFrom;
          if (from != null) {
            _stopped += _t - from;
            _stopFrom = null;
          }
        }),
      );
    }
    if (_swapped && _settleAt == null) {
      final litBy = widget.turns && !widget.scene.holdsThroughTurn
          ? _swappedAt + _litDelay + _litIn
          : _swappedAt + (widget.turns ? _minHold : _minHold / 2);
      final ready = (widget.ready?.value ?? true) || t - _swappedAt >= _timeout;
      if (ready && t >= litBy) {
        _settleAt = t;
        widget.onSettle?.call();
      }
    }
    final at = _settleAt;
    if (at != null && t - at >= widget.scene.settle) {
      _done = true;
      _ticker.stop();
      widget.onComplete();
      return;
    }
    _frame.value++;
  }

  double get _lit {
    if (!widget.turns || _t < _rise || widget.scene.holdsThroughTurn) return 1;
    if (!_swapped) return 1 - _smooth(_rise, _rise + _dimOut, _t);
    return _smooth(_swappedAt + _litDelay, _swappedAt + _litDelay + _litIn, _t);
  }

  TurningStage _stage(Size size) {
    final at = _settleAt;
    return TurningStage(
      screen: size,
      time: GlyphClock.instance.seconds.value,
      from: widget.from,
      to: at == null ? null : widget.to(),
      rise: _clamp01(_t / _rise),
      lit: _lit,
      settle: at == null ? 0 : _clamp01((_t - at) / widget.scene.settle),
      motion: _motion,
      pad: MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing answers mid-passage: not the screen left, nor the page.
    return AbsorbPointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _TurningPainter(this)),
      ),
    );
  }
}

class _TurningPainter extends CustomPainter {
  _TurningPainter(this.state) : super(repaint: state._frame);

  final _TurningPassageOverlayState state;
  final Paint _ground = Paint();

  /// The ground: the black the glyph portal turns on.
  static const Color _void = Color(0xFF050507);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = state._stage(size);
    final scene = state.widget.scene;
    final g = scene.groundAt(s);
    if (g > .002) {
      canvas.drawRect(
        Offset.zero & size,
        _ground..color = _void.withValues(alpha: g.clamp(0.0, 1.0)),
      );
    }
    scene.paint(canvas, s);
  }

  @override
  bool shouldRepaint(_TurningPainter old) => old.state != state;
}
