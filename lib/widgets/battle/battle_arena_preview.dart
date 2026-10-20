import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/battle_arena_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Element lights for the preview's demo specials.
const List<Color> _kDemoLight = [
  Color(0xFFE8743A),
  Color(0xFF5BC8E8),
  Color(0xFF8FD26A),
  Color(0xFFB98CF0),
];

/// A battle arena's floor, as a picture of it: its middle, filling the box,
/// moving while [live] (the hub, the card in view) and still otherwise.
class BattleArenaPreview extends StatefulWidget {
  const BattleArenaPreview({super.key, required this.arena, this.live = true});

  final String arena;
  final bool live;

  @override
  State<BattleArenaPreview> createState() => _BattleArenaPreviewState();
}

class _BattleArenaPreviewState extends State<BattleArenaPreview>
    with SingleTickerProviderStateMixin {
  late BattleFloor _floor = _make();
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker = createTicker((elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    _time.value = t;
    // With nobody on it, the floor is shown what a fight does to it now
    // and then: a ripple, a lit shard.
    if (t >= _nextDemo) {
      _nextDemo = t + 0.9;
      final a = _demo.nextDouble() * pi * 2;
      final r = 0.2 + _demo.nextDouble() * 0.5;
      final at = Offset(
        cos(a) * kBattleFloorHalfWidth * r,
        sin(a) * kBattleFloorHalfHeight * r,
      );
      if (_demo.nextBool()) {
        _floor.step(at, t);
      } else {
        _floor.special(at, _kDemoLight[_demo.nextInt(_kDemoLight.length)], t);
      }
    }
  });
  final Random _demo = Random(5);
  double _nextDemo = 0.4;

  BattleFloor _make() => battleFloorFor(
    widget.arena,
    rx: kBattleFloorHalfWidth,
    ry: kBattleFloorHalfHeight,
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) _ticker.start();
  }

  @override
  void didUpdateWidget(BattleArenaPreview old) {
    super.didUpdateWidget(old);
    if (old.arena != widget.arena) {
      _floor.dispose();
      _floor = _make();
    }
    if (widget.live && !_ticker.isActive) _ticker.start();
    if (!widget.live && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _floor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _FloorPainter(_floor, _time),
      child: const SizedBox.expand(),
    ),
  );
}

/// Whether a preview box shows the floor on its side (a box wider than
/// tall), and the zoom it draws it at: what the battle's opening flight
/// starts from, so the hub's stage and the flight's first frame agree.
bool battleArenaPreviewSideways(Size size) => size.width > size.height;

double battleArenaPreviewZoom(Size size) {
  final long = kBattleFloorHalfHeight * 2 * 1.08;
  final short = kBattleFloorHalfWidth * 2 * 1.08;
  return battleArenaPreviewSideways(size)
      ? min(size.width / long, size.height / short * 1.25)
      : min(size.height / long, size.width / short * 1.25);
}

class _FloorPainter extends CustomPainter {
  _FloorPainter(this.floor, this.time) : super(repaint: time);

  final BattleFloor floor;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    // A box wider than tall shows the floor on its side, its length across,
    // so its whole shape is seen; a tall one shows it upright.
    final wide = battleArenaPreviewSideways(size);
    final zoom = battleArenaPreviewZoom(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    if (wide) canvas.rotate(-pi / 2);
    final w = (wide ? size.height : size.width) / zoom;
    final h = (wide ? size.width : size.height) / zoom;
    final view = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    floor.paint(canvas, Offset.zero, time.value, view);
    canvas.restore();
    // A little dark at the edges, so it sits in its frame.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          size.longestSide * 0.7,
          [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          const [0.6, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_FloorPainter old) => !identical(old.floor, floor);
}
