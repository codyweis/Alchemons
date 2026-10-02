// lib/games/cosmic_survival/components/survival_lobby_stage.dart
//
// The survival lobby's stage: the core about to be defended, turning in its
// field of dust, with the player's ship orbiting it on a tilted orbit —
// behind the core for half the turn, in front of it for the other. The same
// painters the run uses (orb_art.dart, ship_art.dart), so what the lobby
// shows is what the run will be.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_game.dart' show ShipComponent;
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SurvivalLobbyStage extends StatefulWidget {
  const SurvivalLobbyStage({super.key, required this.orb, this.shipSkin});

  final OrbBaseSkin orb;

  /// The cosmic hull the ship flies in ('skin_phantom', …; null standard).
  final String? shipSkin;

  @override
  State<SurvivalLobbyStage> createState() => _SurvivalLobbyStageState();
}

class _SurvivalLobbyStageState extends State<SurvivalLobbyStage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (d) => _clock.value = d.inMicroseconds / 1e6,
  );
  final ShipComponent _ship = ShipComponent(pos: Offset.zero);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _StagePainter(
        clock: _clock,
        orb: widget.orb,
        shipSkin: widget.shipSkin,
        ship: _ship,
      ),
    ),
  );
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.clock,
    required this.orb,
    required this.shipSkin,
    required this.ship,
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final OrbBaseSkin orb;
  final String? shipSkin;
  final ShipComponent ship;

  /// The orbit seen from above at a slant: its depth squashed to this.
  static const double _tilt = 0.36;
  static const double _orbit = 270;
  static const double _shipSpeed = 0.42;

  /// Stars in two brightnesses, each drawn as one batch of points.
  static final List<Float32List> _stars = () {
    final r = Random(19);
    return [
      for (var k = 0; k < 2; k++)
        Float32List.fromList([for (var i = 0; i < 70; i++) r.nextDouble()]),
    ];
  }();
  static final Paint _starPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final look = orbLook(orb);
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            look.essence.withValues(alpha: 0.09),
            look.essence.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    for (var k = 0; k < 2; k++) {
      final unit = _stars[k];
      final pts = Float32List(unit.length);
      for (var i = 0; i < unit.length; i += 2) {
        pts[i] = unit[i] * size.width;
        pts[i + 1] = unit[i + 1] * size.height;
      }
      _starPaint.color = Colors.white.withValues(alpha: k == 0 ? 0.22 : 0.45);
      canvas.drawRawPoints(ui.PointMode.points, pts, _starPaint);
    }

    // Fit the orbit's width to the stage, leaving room for the ship.
    final scale = min(
      size.width / (2 * (_orbit + 70)),
      size.height / (2 * 150),
    );
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    // The field and the orbit lie in the tilted plane.
    canvas.save();
    canvas.scale(1, _tilt);
    paintOrbField(canvas, orb, t, orbit: _orbit, laneGap: 70);
    canvas.restore();

    // The ship on its orbit, behind the core on the far half.
    final a = t * _shipSpeed + 1.2;
    final pos = Offset(cos(a) * _orbit, sin(a) * _orbit * _tilt);
    final vel = Offset(-sin(a), cos(a) * _tilt);
    ship
      ..pos = pos
      ..angle = atan2(vel.dy, vel.dx);
    final behind = sin(a) < 0;
    if (behind) ship.render(canvas, t, skin: shipSkin, glow: true);
    paintOrbCore(canvas, orb, t, radius: 92, beat: _frac(t / 8));
    if (!behind) ship.render(canvas, t, skin: shipSkin, glow: true);
    canvas.restore();
  }

  static double _frac(double x) => x - x.floorToDouble();

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.orb != orb || old.shipSkin != shipSkin;
}
