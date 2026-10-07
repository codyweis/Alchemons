// lib/games/cosmic_survival/components/survival_lobby_stage.dart
//
// The survival lobby's stage: the core about to be defended, turning in its
// field of dust, with the player's ship orbiting it on a tilted orbit —
// behind the core for half the turn, in front of it for the other. The same
// painters the run uses (orb_art.dart, ship_art.dart), so what the lobby
// shows is what the run will be.
//
// The lobby's layout constants live here too, with [survivalLobbyOrbFor]:
// where the hub's core sits on screen, for a passage into the hub to land
// on it. The lobby lays itself out from the same constants, so the two
// cannot drift apart.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_game.dart' show ShipComponent;
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The lobby header's height: the back button, the title, the purse.
const double kSurvivalLobbyHeaderHeight = 52;

/// The stage's height, directly under the header.
const double kSurvivalLobbyStageHeight = 212;

/// The stage on a [screen] whose safe-area padding is [pad], in global
/// coordinates.
Rect survivalLobbyStageRect(Size screen, EdgeInsets pad) => Rect.fromLTWH(
  pad.left,
  pad.top + kSurvivalLobbyHeaderHeight,
  max(0.0, screen.width - pad.left - pad.right),
  kSurvivalLobbyStageHeight,
);

/// Where the hub's core is drawn on a [screen] whose safe-area padding is
/// [pad]: its centre in global coordinates (the safe-area top included) and
/// its radius in logical pixels.
({Offset centre, double radius}) survivalLobbyOrbFor(
  Size screen,
  EdgeInsets pad,
) {
  final stage = survivalLobbyStageRect(screen, pad);
  return (
    centre: stage.center,
    radius:
        SurvivalLobbyScene.coreRadius * SurvivalLobbyScene.fitScale(stage.size),
  );
}

/// The lobby's picture — backdrop, field, ship, core — drawn by the stage at
/// rest and by the run's entrance as it carries the core away
/// (survival_orb_entrance.dart). One of these is shared by both, so the
/// ship's wake runs on unbroken from one to the other.
class SurvivalLobbyScene {
  final ShipComponent ship = ShipComponent(pos: Offset.zero);

  /// The orbit seen from above at a slant: its depth squashed to this.
  static const double tilt = 0.36;
  static const double orbit = 270;
  static const double laneGap = 70;

  /// The core's radius in the stage's own units (before [fitScale]).
  static const double coreRadius = 92;
  static const double _shipSpeed = 0.42;

  /// The scale that fits the orbit's width to a stage of [size], leaving
  /// room for the ship.
  static double fitScale(Size size) =>
      min(size.width / (2 * (orbit + 70)), size.height / (2 * 150));

  /// How far a Celestial core is through its heal wait at [t].
  static double beatAt(double t) => _frac(t / 8);

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

  /// The stage at rest, filling [size].
  void paint(
    Canvas canvas,
    Size size,
    double t, {
    required OrbBaseSkin orb,
    String? shipSkin,
  }) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    paintBackdrop(canvas, rect, orb);
    final scale = fitScale(size);
    paintOrbit(
      canvas,
      t,
      orb: orb,
      shipSkin: shipSkin,
      centre: rect.center,
      fieldScale: scale,
      coreRadius: coreRadius * scale,
    );
    canvas.restore();
  }

  /// The stage's backdrop in [rect]: the core's essence washed across it and
  /// a scatter of stars, at [alpha].
  void paintBackdrop(
    Canvas canvas,
    Rect rect,
    OrbBaseSkin orb, {
    double alpha = 1,
  }) {
    if (alpha <= 0) return;
    final look = orbLook(orb);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            look.essence.withValues(alpha: 0.09 * alpha),
            look.essence.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    for (var k = 0; k < 2; k++) {
      final unit = _stars[k];
      final pts = Float32List(unit.length);
      for (var i = 0; i < unit.length; i += 2) {
        pts[i] = rect.left + unit[i] * rect.width;
        pts[i + 1] = rect.top + unit[i + 1] * rect.height;
      }
      _starPaint.color = Colors.white.withValues(
        alpha: (k == 0 ? 0.22 : 0.45) * alpha,
      );
      canvas.drawRawPoints(ui.PointMode.points, pts, _starPaint);
    }
  }

  /// The field, the ship on its orbit and the core, centred on [centre]:
  /// the field and orbit at [fieldScale], their plane squashed to
  /// [planeTilt], the lanes [lanes] apart; the core [coreRadius] across in
  /// pixels; the ship at [shipAlpha].
  void paintOrbit(
    Canvas canvas,
    double t, {
    required OrbBaseSkin orb,
    required Offset centre,
    required double fieldScale,
    required double coreRadius,
    String? shipSkin,
    double planeTilt = tilt,
    double lanes = laneGap,
    double shipAlpha = 1,
  }) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);

    // The field and the orbit lie in the tilted plane.
    canvas.save();
    canvas.scale(fieldScale, fieldScale * planeTilt);
    paintOrbField(canvas, orb, t, orbit: orbit, laneGap: lanes);
    canvas.restore();

    // The ship on its orbit, behind the core on the far half.
    final a = t * _shipSpeed + 1.2;
    final behind = sin(a) < 0;
    if (shipAlpha > 0) {
      ship
        ..pos = Offset(cos(a) * orbit, sin(a) * orbit * planeTilt)
        ..angle = atan2(cos(a) * planeTilt, -sin(a));
    }
    if (behind) _paintShip(canvas, t, fieldScale, shipSkin, shipAlpha);
    paintOrbCore(canvas, orb, t, radius: coreRadius, beat: beatAt(t));
    if (!behind) _paintShip(canvas, t, fieldScale, shipSkin, shipAlpha);
    canvas.restore();
  }

  void _paintShip(
    Canvas canvas,
    double t,
    double scale,
    String? skin,
    double alpha,
  ) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.scale(scale);
    if (alpha < 1) {
      // Only while it fades: a layer just round the ship and its wake.
      canvas.saveLayer(
        Rect.fromCircle(center: ship.pos, radius: 220),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      ship.render(canvas, t, skin: skin, glow: true);
      canvas.restore();
    } else {
      ship.render(canvas, t, skin: skin, glow: true);
    }
    canvas.restore();
  }

  static double _frac(double x) => x - x.floorToDouble();
}

class SurvivalLobbyStage extends StatefulWidget {
  const SurvivalLobbyStage({
    super.key,
    required this.orb,
    this.shipSkin,
    this.clock,
    this.scene,
    this.hidden = false,
  });

  final OrbBaseSkin orb;

  /// The cosmic hull the ship flies in ('skin_phantom', …; null standard).
  final String? shipSkin;

  /// The stage's time in seconds. Given, the stage runs on it (the lobby
  /// shares one with the run's entrance); otherwise it keeps its own.
  final ValueListenable<double>? clock;

  /// The picture to draw; one of its own when not given.
  final SurvivalLobbyScene? scene;

  /// Leaves the stage empty: the entrance is drawing it.
  final bool hidden;

  @override
  State<SurvivalLobbyStage> createState() => _SurvivalLobbyStageState();
}

class _SurvivalLobbyStageState extends State<SurvivalLobbyStage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _ownClock = ValueNotifier(0);
  Ticker? _ticker;
  late final SurvivalLobbyScene _ownScene = SurvivalLobbyScene();

  @override
  void initState() {
    super.initState();
    if (widget.clock == null) {
      _ticker = createTicker((d) => _ownClock.value = d.inMicroseconds / 1e6)
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ownClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: widget.hidden
          ? null
          : _StagePainter(
              clock: widget.clock ?? _ownClock,
              orb: widget.orb,
              shipSkin: widget.shipSkin,
              scene: widget.scene ?? _ownScene,
            ),
    ),
  );
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.clock,
    required this.orb,
    required this.shipSkin,
    required this.scene,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final OrbBaseSkin orb;
  final String? shipSkin;
  final SurvivalLobbyScene scene;

  @override
  void paint(Canvas canvas, Size size) =>
      scene.paint(canvas, size, clock.value, orb: orb, shipSkin: shipSkin);

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.orb != orb ||
      old.shipSkin != shipSkin ||
      old.clock != clock ||
      old.scene != scene;
}
