part of 'cosmic_game.dart';

// The flight from the star chart to a planet, home, or any place on it — and
// the warp anomaly's throw across space. It replaces the old instant hop
// (the ship simply was there when the chart closed) and the anomaly's white
// flash and stroked streaks.
//
//   depart  the ship swings its nose round to where it is going, the engines
//           open and it pulls away, faster and faster; the camera eases back
//           and space streams past it in grains, closing in to dark
//   cross   under the dark the ship is carried across, its companions with it
//   arrive  it comes out at speed and slows, the dark thinning off it, and
//           glides into the planet's idle orbit (or stops on the place)
//
// The ship is drawn over the dark the whole way, so it never leaves the
// screen: the world goes, and comes back, round it. Nothing here is a flash
// or a stroke — the dark is a wash, the streaming is grains in batches.

class _ShipTravel {
  _ShipTravel({
    required this.pos,
    required this.heading0,
    required this.dir,
    required this.exit,
    required this.end,
  });

  static const double departSeconds = 0.8;
  static const double crossSeconds = 0.32;
  static const double arriveSeconds = 1.1;
  static const double topSpeed = 2300;

  /// The ship, integrated through the departure.
  Offset pos;

  /// Where its nose pointed when it set off (radians, 0 = +x).
  final double heading0;

  /// Unit vector of the way it is going.
  final Offset dir;

  /// Where it comes out of the dark (it then slows from [exit] to [end]).
  final Offset exit;

  /// Where it comes to rest: in orbit beside the planet, or on the place.
  final Offset end;

  double t = 0;
  bool jumped = false;

  /// How far the stream of grains has run (screen px), for the veil.
  double stream = 0;

  double get heading => atan2(dir.dy, dir.dx);
  double get total => departSeconds + crossSeconds + arriveSeconds;

  /// 0..1 through the departure, the crossing, the arrival.
  double get departT => (t / departSeconds).clamp(0.0, 1.0);
  double get arriveT =>
      ((t - departSeconds - crossSeconds) / arriveSeconds).clamp(0.0, 1.0);

  /// How dark space is round the ship (1 while it crosses).
  double get veil {
    if (t < departSeconds) return _smooth(0.45, 1.0, departT);
    if (t < departSeconds + crossSeconds) return 1;
    return 1 - _smooth(0.0, 0.55, arriveT);
  }

  /// How open the engines are.
  double get boost {
    if (t < departSeconds) return _smooth(0.0, 0.5, departT);
    if (t < departSeconds + crossSeconds) return 1;
    return 1 - _smooth(0.2, 0.9, arriveT);
  }

  /// How far the camera has eased back.
  double get zoom {
    final out = t < departSeconds
        ? _smooth(0.1, 1.0, departT)
        : (t < departSeconds + crossSeconds
              ? 1.0
              : 1 - _smooth(0.15, 1.0, arriveT));
    return 1 - 0.08 * out;
  }

  /// How fast the ship is going, as a share of [topSpeed].
  double get pace {
    if (t < departSeconds) return 0.05 + 0.95 * departT * departT;
    if (t < departSeconds + crossSeconds) return 1;
    return 1 - _smooth(0.0, 1.0, arriveT);
  }

  static double _smooth(double e0, double e1, double x) {
    final v = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }
}

extension _ShipTravelFlight on CosmicGame {
  /// Fly the ship to [dest]. With [orbitRadius] it ends in the idle orbit
  /// round a planet at [dest] (the orbit the ship falls into on its own when
  /// it stops near one), flying along it; without, it comes to rest on
  /// [dest]. The ship cannot be steered until it has arrived.
  void _beginTravel(Offset dest, {double? orbitRadius}) {
    final delta = _toroidalDelta(dest, ship.pos);
    final dist = delta.distance;
    if (dist < 1 || _shipDead) {
      teleportTo(dest);
      return;
    }
    final dir = delta / dist;
    // Beside the planet, where the orbit's way round runs along the way the
    // ship is flying, so it slides into it without a turn.
    final end = orbitRadius == null
        ? dest
        : dest + Offset(-dir.dy, dir.dx) * orbitRadius;
    // It comes out at full speed and slows over this far, so the arrival
    // speed matches the departure's.
    const slowing = _ShipTravel.topSpeed * _ShipTravel.arriveSeconds / 2.2;
    clearSteeringInput();
    _travel = _ShipTravel(
      pos: ship.pos,
      heading0: ship.angle,
      dir: dir,
      exit: _wrap(end - dir * slowing),
      end: _wrap(end),
    );
    _revealAround(dest, 400);
  }

  /// Moves the ship along its flight; the rest of the update has already run
  /// and this overrides where the ship is.
  void _stepTravel(double dt) {
    final tr = _travel;
    if (tr == null) return;
    tr.t += dt;
    const crossEnd = _ShipTravel.departSeconds + _ShipTravel.crossSeconds;
    const crossAt = _ShipTravel.departSeconds + _ShipTravel.crossSeconds * 0.5;
    if (!tr.jumped && tr.t < crossAt) {
      // Pulling away: the nose comes round onto the way it is going and the
      // ship gathers speed along it.
      final turn = _ShipTravel._smooth(0.0, 0.45, tr.departT);
      var d = tr.heading - tr.heading0;
      while (d > pi) {
        d -= pi * 2;
      }
      while (d < -pi) {
        d += pi * 2;
      }
      final h = tr.heading0 + d * turn;
      tr.pos += Offset(cos(h), sin(h)) * (_ShipTravel.topSpeed * tr.pace * dt);
      ship.pos = _wrap(tr.pos);
      ship.angle = h;
    } else if (!tr.jumped) {
      // Under the dark: carried across, the party with it, and out the far
      // side at the same speed.
      tr.jumped = true;
      final lead = _ShipTravel.topSpeed * (crossEnd - tr.t);
      final at = _wrap(tr.exit - tr.dir * lead);
      final jump = _toroidalDelta(at, ship.pos);
      ship.pos = at;
      for (final c in activeCompanions.values) {
        c.position = _wrap(c.position + jump);
      }
      _lastShipPosForCompanions = ship.pos;
      ship.wake.clear();
      _revealAround(ship.pos, 300);
      ship.angle = tr.heading;
    } else if (tr.t < crossEnd) {
      ship.pos = _wrap(ship.pos + tr.dir * (_ShipTravel.topSpeed * dt));
      ship.angle = tr.heading;
    } else {
      // Slowing into place: fast out of the dark, easing to the orbit's own
      // pace at the end.
      final s = tr.arriveT;
      const k = 0.06;
      final f = (1 - k) * (1 - pow(1 - s, 2.2)) + k * s;
      ship.pos = _wrap(tr.exit + _toroidalDelta(tr.end, tr.exit) * f);
      ship.angle = tr.heading;
    }
    // Space streams past at the ship's pace.
    tr.stream += _ShipTravel.topSpeed * tr.pace * dt * cameraZoom * 0.9;
    _boostTrailVisual = max(_boostTrailVisual, tr.boost);
    _travelZoom = tr.zoom;
    if (tr.t >= tr.total) {
      ship.pos = tr.end;
      ship.angle = tr.heading;
      _dragTarget = ship.pos;
      _travelZoom = 1;
      _travel = null;
    }
  }

  static final GrainBatch _veilGrains = GrainBatch(8);

  /// The dark the ship crosses under, with space streaming past it in grains
  /// — drawn over the world, under the ship. World space: [view] is the
  /// screen's rect in world units.
  void _renderTravelVeil(Canvas canvas, Rect view) {
    final tr = _travel;
    if (tr == null) return;
    final veil = tr.veil;
    if (veil <= 0.004) return;
    canvas.drawRect(
      view.inflate(4),
      Paint()..color = const Color(0xFF020010).withValues(alpha: veil),
    );
    final z = cameraZoom;
    final w = view.width * z, h = view.height * z;
    final b = _veilGrains..clear();
    final back = -tr.dir;
    final pace = tr.pace;
    // Each grain of space draws out behind itself into a run of grains as
    // the ship gathers speed — the nearer, the longer — thinning to its
    // tail: buckets 0-3 head (by depth, 3 = nearest lit), 4-7 the run.
    for (var i = 0; i < 190; i++) {
      final depth = i % 3;
      final speed = const [0.35, 0.65, 1.0][depth];
      final x0 = _travelHash(i, 1) * w, y0 = _travelHash(i, 2) * h;
      final x = (x0 + back.dx * tr.stream * speed) % w;
      final y = (y0 + back.dy * tr.stream * speed) % h;
      final at = Offset(view.left + x / z, view.top + y / z);
      final lit = depth == 2 && _travelHash(i, 3) < 0.35;
      b.add(lit ? 3 : depth, at.dx, at.dy);
      final run = (pace * (2 + 7 * speed)).round();
      if (run <= 0) continue;
      final step = tr.dir * ((2.2 + 3.2 * speed) * pace / z);
      for (var k = 1; k <= run; k++) {
        final f = k / (run + 1);
        b.add(
          4 + (f * 4).floor().clamp(0, 3),
          at.dx + step.dx * k,
          at.dy + step.dy * k,
        );
      }
    }
    final a = (veil * 1.4).clamp(0.0, 1.0);
    const tone = Color.fromRGBO(205, 214, 248, 1);
    b.draw(canvas, 4, 1.5 / z, tone.withValues(alpha: 0.55 * a));
    b.draw(canvas, 5, 1.35 / z, tone.withValues(alpha: 0.36 * a));
    b.draw(canvas, 6, 1.2 / z, tone.withValues(alpha: 0.2 * a));
    b.draw(canvas, 7, 1.05 / z, tone.withValues(alpha: 0.1 * a));
    b.draw(canvas, 0, 1.2 / z, Color.fromRGBO(150, 160, 210, 0.55 * a));
    b.draw(canvas, 1, 1.6 / z, Color.fromRGBO(190, 200, 240, 0.75 * a));
    b.draw(canvas, 2, 1.9 / z, Color.fromRGBO(225, 232, 255, 0.9 * a));
    b.draw(canvas, 3, 2.3 / z, Color.fromRGBO(245, 248, 255, a));
  }

  static double _travelHash(int i, int salt) {
    final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }
}
