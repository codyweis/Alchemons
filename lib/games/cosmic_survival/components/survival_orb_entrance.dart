// lib/games/cosmic_survival/components/survival_orb_entrance.dart
//
// START in the survival lobby: the core carries you into the run.
//
// The lobby's chrome eases away while its core stays. The core moves and
// grows from the stage to exactly where the run will draw it — the screen's
// centre, at the run's opening zoom — while its field's tilted plane opens
// flat and the lanes widen out into the arena. Once the run is built and
// attached, the arena fades in round it; the run draws everything but the
// core meanwhile, and this overlay draws the core through the run's own
// painter (CosmicSurvivalGame.paintCorePresentation), so when it steps aside
// there is nothing to see change. Until the run is ready the core simply
// holds where it landed, turning.
//
// One unbroken motion: overlapping smoothstep phases, nothing snaps, nothing
// flashes, and every layer that leaves reaches zero on the way.

import 'dart:ui' show lerpDouble;

import 'package:alchemons/games/cosmic_survival/components/survival_lobby_stage.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The entrance's timeline, in seconds from START.
abstract final class SurvivalEntrance {
  /// The lobby's header, team, dock and labels are gone by this.
  static const double chromeOut = 0.42;

  /// The stage's own backdrop (its wash and stars) is gone by this.
  static const double backdropOut = 0.6;

  /// The lobby's ship has faded by this.
  static const double shipOut = 0.5;

  /// The core leaves the stage …
  static const double carryFrom = 0.08;

  /// … and has landed by this.
  static const double carryTo = 1.3;

  /// How long the arena takes to fade in round the landed core.
  static const double arenaSeconds = 0.7;

  static double chrome(double t) => 1 - _smooth(0, chromeOut, t);
  static double backdrop(double t) => 1 - _smooth(0, backdropOut, t);
  static double ship(double t) => 1 - _smooth(0, shipOut, t);
  static double carry(double t) => _smoother(carryFrom, carryTo, t);

  /// The arena's strength at [t], its fade having begun at [from] (null:
  /// the run is not ready yet).
  static double arena(double t, double? from) =>
      from == null ? 0 : _smooth(from, from + arenaSeconds, t);

  /// Where the run draws its core on a screen of [size] while the entrance
  /// holds its camera: the centre.
  static Offset landing(Size size) => size.center(Offset.zero);

  static double _smooth(double a, double b, double t) {
    final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static double _smoother(double a, double b, double t) {
    final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
    return x * x * x * (x * (x * 6 - 15) + 10);
  }
}

/// Where an entrance has got to. Long-lived: the lobby listens to it
/// always, and it only speaks while an entrance runs.
class SurvivalEntranceState extends ChangeNotifier {
  bool _active = false;
  double _from = 0;
  double _t = 0;
  double? _arenaFrom;
  CosmicSurvivalGame? _game;

  /// True from START until the run has the core.
  bool get active => _active;

  /// Seconds since START.
  double get t => _t;

  /// When the arena began to fade in; null until the run was ready.
  double? get arenaFrom => _arenaFrom;

  /// The run being entered, once built.
  CosmicSurvivalGame? get game => _game;

  double get chrome => _active ? SurvivalEntrance.chrome(_t) : 1;
  double get arena => _active ? SurvivalEntrance.arena(_t, _arenaFrom) : 1;

  /// Starts an entrance at [clock] seconds on the lobby's clock.
  void begin(double clock) {
    _active = true;
    _from = clock;
    _t = 0;
    _arenaFrom = null;
    _game = null;
    notifyListeners();
  }

  void attach(CosmicSurvivalGame game) => _game = game;

  /// Moves the entrance on to [clock] on the lobby's clock.
  void advance(double clock) {
    if (!_active) return;
    _t = clock - _from;
    notifyListeners();
  }

  /// The run is ready and the core has landed: the arena fades in from now.
  void beginArena() => _arenaFrom ??= _t;

  bool get landed => _t >= SurvivalEntrance.carryTo;

  bool get arenaIn =>
      _arenaFrom != null && _t >= _arenaFrom! + SurvivalEntrance.arenaSeconds;

  void finish() {
    _active = false;
    _game = null;
    _arenaFrom = null;
    notifyListeners();
  }
}

/// Draws the entrance over the whole screen: the stage's backdrop fading in
/// its own rect, and the core with its field and ship carried from [stage]
/// to the run's opening view of it; then, once the arena is coming in, the
/// core as the run itself draws it.
class SurvivalOrbEntrancePainter extends CustomPainter {
  SurvivalOrbEntrancePainter({
    required this.scene,
    required this.clock,
    required this.state,
    required this.stage,
    required this.orb,
    required this.shipSkin,
  }) : super(repaint: Listenable.merge([clock, state]));

  final SurvivalLobbyScene scene;
  final ValueListenable<double> clock;
  final SurvivalEntranceState state;

  /// The lobby stage, in this painter's (the screen's) coordinates.
  final Rect stage;
  final OrbBaseSkin orb;
  final String? shipSkin;

  @override
  void paint(Canvas canvas, Size size) {
    if (!state.active) return;
    final t = state.t;

    final backdrop = SurvivalEntrance.backdrop(t);
    if (backdrop > 0) {
      canvas.save();
      canvas.clipRect(stage);
      scene.paintBackdrop(canvas, stage, orb, alpha: backdrop);
      canvas.restore();
    }

    final landing = SurvivalEntrance.landing(size);
    const zoom = CosmicSurvivalGame.entranceZoom;
    final game = state.game;
    if (game != null && state.arenaFrom != null) {
      // The run is drawing the arena round it: draw the core as the run
      // does, where the run's held camera puts it.
      canvas.save();
      canvas.translate(landing.dx, landing.dy);
      canvas.scale(zoom);
      game.paintCorePresentation(canvas, readings: state.arena);
      canvas.restore();
      return;
    }

    final carry = SurvivalEntrance.carry(t);
    final s0 = SurvivalLobbyScene.fitScale(stage.size);
    canvas.save();
    // The stage clipped the field; the clip opens out with the carry, so
    // nothing appears at once.
    canvas.clipRect(Rect.lerp(stage, Offset.zero & size, carry)!);
    scene.paintOrbit(
      canvas,
      clock.value,
      orb: orb,
      shipSkin: shipSkin,
      centre: Offset.lerp(stage.center, landing, carry)!,
      fieldScale: lerpDouble(s0, zoom, carry)!,
      coreRadius: lerpDouble(
        SurvivalLobbyScene.coreRadius * s0,
        CosmicSurvivalGame.coreRadius * zoom,
        carry,
      )!,
      planeTilt: lerpDouble(SurvivalLobbyScene.tilt, 1, carry)!,
      lanes: lerpDouble(SurvivalLobbyScene.laneGap, kOrbFieldLaneGap, carry)!,
      shipAlpha: SurvivalEntrance.ship(t),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SurvivalOrbEntrancePainter old) =>
      old.stage != stage ||
      old.orb != orb ||
      old.shipSkin != shipSkin ||
      old.scene != scene ||
      old.clock != clock ||
      old.state != state;
}
