// lib/games/wilderness/ship_landing.dart
//
// The cosmic ship coming down in the Valley, waiting in the grass to be
// claimed, and leaving with its new pilot.
//
// It is the ship the player flies in space (ship_art.dart): the same
// obsidian hull with its light trapped inside, the same wake of grains.
// It comes in high from the left on a shallow glide, nose first, leaving a
// long trail that cools from white-hot to ash as it hangs in the sky; near
// the ground it pitches up and burns its engines to brake, the wash parting
// the grass under it, and settles on its tail, leaning a little, sunk into
// the meadow. The grass is the field's own — the ship strokes it the way a
// finger does — and the grains it throws up fall back and settle.
//
// At rest the engines are down to embers and the light inside breathes
// slowly; a grain or two of it drifts up off the hull. Claimed, the engines
// spool up and it climbs away the way it came, wake and all.
//
// Nothing here blurs or strokes a line: the hull is ship_art's plates, the
// rest is grains drawn in a few point batches.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

/// The ground under the ship, relative to the spawn anchor it stands on:
/// the top of the grass and where a creature's feet would rest in it.
typedef ShipGround = ({double top, double rest})? Function();

/// Strokes the field's grass at a world point, moving [dx] (screen px) —
/// a finger's touch, which parts the grass and kicks grains off it.
typedef ShipStir = void Function(Vector2 world, double dx);

enum _Phase { waiting, descending, landed, lifting, gone }

class ShipLandingComponent extends PositionComponent with TapCallbacks {
  ShipLandingComponent({
    required this.onTap,
    this.ground,
    this.stir,
    this.flyIn = false,
    this.onBurn,
    this.onCrashLanded,
    this.skin,
  }) : super(size: Vector2.all(2), anchor: Anchor.center);

  final VoidCallback onTap;
  final ShipGround? ground;
  final ShipStir? stir;

  /// When true the ship comes down out of the sky before it can be tapped;
  /// when false it is simply there, at rest (a restored save).
  final bool flyIn;

  /// Fired once, as the engines open up to brake near the ground.
  final VoidCallback? onBurn;

  /// Fired once, the moment the ship touches down.
  final VoidCallback? onCrashLanded;

  /// The hull to draw (null for the standard one).
  final String? skin;

  /// Hull units to layer units: the space hull is about 45 tall.
  static const double scaleK = 3.0;

  /// How long the camera has to find the landing before the ship shows.
  static const double leadIn = 0.8;

  /// The glide, flare and touchdown.
  static const double descentTime = 2.9;

  /// From the claim to the hull gone off the top of the screen.
  static const double liftTime = 2.0;

  /// The lean it rests at, nose up (radians, clockwise).
  static const double _restRot = 0.08;

  /// Where the tail sits between the top of the grass and a creature's feet.
  static const double _sink = 0.55;

  _Phase _phase = _Phase.waiting;
  double _clock = 0; // seconds in the current phase
  double _elapsed = 0;
  double _hullTime = 0; // the hull's own clock: slows when it rests
  double _washCarry = 0;
  double _driftCarry = 0;
  bool _burnFired = false;
  VoidCallback? _onGone;

  // Where the ship is drawn this frame (local, origin at the anchor).
  Offset _pos = Offset.zero;
  double _rot = _restRot;
  double _engine = 0, _boost = 0;
  bool _hullShown = false;
  bool _glow = false;

  final ShipWake _wake = ShipWake();
  final _Grains _grains = _Grains();

  /// Whether it is on the ground, waiting to be claimed.
  bool get landed => _phase == _Phase.landed;

  /// Whether it has left (and can be removed).
  bool get gone => _phase == _Phase.gone;

  // ── ground ──────────────────────────────────────────────────────────────

  double _groundTop = 30, _groundRest = 40;
  double _groundCheckedAt = -1;

  void _readGround() {
    final g = ground?.call();
    if (g != null) {
      _groundTop = g.top;
      _groundRest = g.rest;
    }
    _groundCheckedAt = _elapsed;
  }

  /// The tail's tip, where it rests in the grass.
  double get _tailY => _groundTop + (_groundRest - _groundTop) * _sink;

  /// The hull's centre at rest, so its tail tip stands at [_tailY].
  Offset get _restCentre =>
      Offset(18 * scaleK * sin(_restRot), _tailY - 18 * scaleK * cos(_restRot));

  // ── lifecycle ───────────────────────────────────────────────────────────

  @override
  void onMount() {
    super.onMount();
    _readGround();
    if (!flyIn) {
      _phase = _Phase.landed;
      _clock = 10; // long settled
    }
  }

  /// The player has claimed it: it takes off and leaves, and [onGone] is
  /// called once its wake has died away.
  void launch({VoidCallback? onGone}) {
    _onGone = onGone;
    if (_phase == _Phase.gone) {
      onGone?.call();
      return;
    }
    _phase = _Phase.lifting;
    _clock = 0;
    _washCarry = 0;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_phase != _Phase.landed) return;
    onTap();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (_phase != _Phase.landed) return false;
    final c = _restCentre;
    final dx = (point.x - size.x / 2 - c.dx) / (24 * scaleK);
    final dy = (point.y - size.y / 2 - c.dy) / (26 * scaleK);
    return dx * dx + dy * dy <= 1;
  }

  // ── motion ──────────────────────────────────────────────────────────────

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The glide's path, relative to the resting centre, at [u] in 0..1.
  static Offset _glide(double u) {
    const p0 = Offset(-1150, -720);
    const p1 = Offset(-600, -360);
    const p2 = Offset(-110, -170);
    final v = 1 - u;
    return p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u);
  }

  /// How far along the glide the ship is at [tau] (0..1 of the descent):
  /// fast at first, slowing toward the ground, still moving when it
  /// touches.
  static double _glideU(double tau) =>
      0.85 * (1 - pow(1 - tau, 2.2)) + 0.15 * tau;

  @override
  void update(double dt) {
    super.update(dt);
    if (dt <= 0) return;
    _elapsed += dt;
    _clock += dt;
    if (_elapsed - _groundCheckedAt > 0.5) _readGround();
    final rest = _restCentre;
    var hullRate = 1.0;
    var emit = 0.0;

    switch (_phase) {
      case _Phase.waiting:
        _hullShown = false;
        if (_clock >= leadIn) {
          _phase = _Phase.descending;
          _clock = 0;
        }
      case _Phase.descending:
        final tau = (_clock / descentTime).clamp(0.0, 1.0);
        final u = _glideU(tau);
        _pos = rest + _glide(u);
        final ahead = _glide(min(1.0, u + 0.004)) - _glide(max(0.0, u - 0.004));
        final velRot = atan2(ahead.dy, ahead.dx) + pi / 2;
        final w = _smooth(0.5, 0.97, tau);
        _rot = velRot + (_restRot - velRot) * w;
        _engine = 1;
        _boost = 0.2 + 0.8 * _smooth(0.55, 0.85, tau);
        _hullShown = true;
        _glow = true;
        emit = 1;
        if (!_burnFired && tau >= 0.6) {
          _burnFired = true;
          onBurn?.call();
        }
        // The engine wash reaches the grass in the last of the flare.
        if (tau > 0.72) {
          _wash(dt, rest.dx, _smooth(0.72, 1, tau), lift: false);
        }
        if (tau >= 1) {
          _touchDown(rest);
          _phase = _Phase.landed;
          _clock = 0;
        }
      case _Phase.landed:
        final t = _clock;
        // It settles into the turf: a lean that rocks once and stills.
        final settle = t > 4 ? 0.0 : exp(-3.2 * t) * sin(8 * t);
        _rot = _restRot + 0.045 * settle;
        _pos = rest + Offset(0, 3.5 * (1 - exp(-7 * t)));
        final e = t >= 0.8 ? 0.0 : pow(1 - t / 0.8, 2).toDouble();
        _engine = e;
        _boost = 0.9 * e;
        emit = e;
        _hullShown = true;
        _glow = false;
        // The engines' last breath keeps the grass bent for a moment.
        if (t < 0.45) _wash(dt, rest.dx, 1 - t / 0.45, lift: false);
        hullRate = 0.22 + 0.78 * exp(-1.5 * t);
        if (t > 1.2) _drift(dt);
      case _Phase.lifting:
        final t = _clock;
        final spool = _smooth(0, 0.6, t);
        final settled = rest + const Offset(0, 3.5);
        final u = max(0.0, t - 0.6);
        _pos =
            settled +
            Offset(
              90 * u * u + sin(t * 53) * 0.7 * spool * (u > 0 ? 0 : 1),
              -(40 * u + 420 * u * u),
            );
        _rot = _restRot + 0.35 * _smooth(0, 1.2, u);
        _engine = spool;
        _boost = 0.3 + 0.7 * spool;
        _glow = true;
        hullRate = 0.22 + 0.78 * spool;
        _hullShown = t < liftTime;
        emit = _hullShown ? spool : 0;
        if (t < 1.0) {
          _wash(dt, settled.dx, spool * (1 - _smooth(0.6, 1.0, t)), lift: true);
        }
        if (!_hullShown &&
            (_wake.bounds == null || t > liftTime + 2) &&
            _grains.empty) {
          _phase = _Phase.gone;
          final g = _onGone;
          _onGone = null;
          g?.call();
        }
      case _Phase.gone:
        _hullShown = false;
    }

    _hullTime += dt * hullRate;
    if (_phase != _Phase.waiting) {
      _wake.update(
        _elapsed,
        _pos / scaleK,
        _rot - pi / 2,
        skin,
        boost: _boost,
        emit: emit,
        life: 3.0,
      );
      if (_hullShown) _shed(dt);
    }
    _lastPos = _pos;
    _grains.step(dt, _groundTop + 2);
  }

  Offset? _lastPos;
  double _shedCarry = 0;

  /// The trail: grains torn off the hull by its speed, left hanging in the
  /// air, white-hot where they leave it and cooling to ash behind.
  void _shed(double dt) {
    final last = _lastPos;
    if (last == null) return;
    final vel = (_pos - last) / dt;
    final speed = vel.distance;
    if (speed < 30 || speed > 6000) return;
    _shedCarry += dt * 720 * min(1.0, speed / 650);
    final r = _grains.rand;
    final c = cos(_rot), s = sin(_rot);
    while (_shedCarry >= 1) {
      _shedCarry -= 1;
      // Anywhere across the hull, more from its back than its nose.
      final hx = (r() - 0.5) * 26 * (0.4 + 0.6 * r());
      final hy = -8 + 26 * sqrt(r());
      final q = Offset(hx * c - hy * s, hx * s + hy * c) * scaleK;
      final f = r() * dt; // spread over the frame, a line not a clump
      _grains.add(
        _pos.dx + q.dx - vel.dx * f,
        _pos.dy + q.dy - vel.dy * f,
        vel.dx * 0.1 + (r() - 0.5) * 110,
        vel.dy * 0.1 + (r() - 0.5) * 110,
        // Shorter behind a ship climbing away, so the sky clears soon.
        (1.5 + r() * 1.6) * (_phase == _Phase.lifting ? 0.58 : 1),
        _Grains.trail,
      );
    }
  }

  /// The engines' wash on the grass under the ship: it parts outward and,
  /// strong enough, throws dust off the ground. [k] is its strength, 0..1.
  void _wash(double dt, double x, double k, {required bool lift}) {
    if (k <= 0.02) return;
    _washCarry += dt;
    if (_washCarry < 0.07) return;
    _washCarry = 0;
    final r = _grains.rand;
    final spread = (8 + 14 * k) * scaleK;
    for (final side in const [-1.0, 1.0]) {
      _stir(
        Offset(x + side * spread * (0.4 + 0.6 * r()), _groundTop),
        side * (4 + 10 * k),
      );
    }
    final n = (3 + 5 * k).round();
    for (var i = 0; i < n; i++) {
      final side = r() < 0.5 ? -1.0 : 1.0;
      _grains.add(
        x + side * (4 + r() * 14) * scaleK,
        _groundTop - r() * 4,
        side * (60 + r() * 160) * k,
        -(20 + r() * 70) * k,
        0.6 + r() * 0.8,
        r() < 0.25 ? _Grains.ember : _Grains.dust,
      );
    }
    if (lift && r() < 0.5) {
      // A few of the ship's own grains shaken loose by the spool.
      final c = _pos + Offset((r() - 0.5) * 20, 30);
      _grains.add(
        c.dx,
        c.dy,
        (r() - 0.5) * 40,
        -(10 + r() * 30),
        1.0,
        _Grains.ember,
      );
    }
  }

  void _stir(Offset local, double dx) {
    final s = stir;
    if (s == null) return;
    s(
      absolutePositionOf(Vector2(size.x / 2 + local.dx, size.y / 2 + local.dy)),
      dx,
    );
  }

  void _touchDown(Offset rest) {
    onCrashLanded?.call();
    final r = _grains.rand;
    // The grass: a blow at the tail and either side of it — each a tap's
    // ripple and puff of grains — and the blades round it thrown outward.
    for (final x in const [0.0, -12.0, 12.0]) {
      _stir(Offset(rest.dx + x * scaleK, _groundTop), 0);
    }
    for (final side in const [-1.0, 1.0]) {
      _stir(Offset(rest.dx + side * 8 * scaleK, _groundTop), side * 20);
      _stir(Offset(rest.dx + side * 18 * scaleK, _groundTop), side * 16);
      _stir(Offset(rest.dx + side * 30 * scaleK, _groundTop), side * 10);
    }
    // Dust rolling out low either way along the ground.
    for (var i = 0; i < 90; i++) {
      final side = r() < 0.5 ? -1.0 : 1.0;
      _grains.add(
        rest.dx + side * (2 + r() * 10) * scaleK,
        _groundTop - r() * 10,
        side * (90 + 260 * r()),
        -(10 + 40 * r()),
        0.9 + r() * 1.0,
        _Grains.skirt,
      );
    }
    // Ground thrown up round it: dust, and the hull's own embers.
    for (var i = 0; i < 70; i++) {
      final side = r() < 0.5 ? -1.0 : 1.0;
      final reach = 0.15 + 0.85 * r();
      _grains.add(
        rest.dx + side * (2 + 26 * reach) * scaleK,
        _groundTop - r() * 6,
        side * (40 + 220 * r()) * (1.1 - reach * 0.5),
        -(60 + 200 * r()) * (1.1 - reach * 0.6),
        0.9 + r() * 0.9,
        _Grains.dust,
      );
    }
    for (var i = 0; i < 36; i++) {
      final side = r() < 0.5 ? -1.0 : 1.0;
      _grains.add(
        rest.dx + side * r() * 8 * scaleK,
        _tailY - r() * 10,
        side * (50 + 190 * r()),
        -(50 + 150 * r()),
        0.7 + r() * 0.9,
        _Grains.ember,
      );
    }
  }

  /// Grains of its light rising off the hull at rest.
  void _drift(double dt) {
    _driftCarry += dt * 2.6;
    final r = _grains.rand;
    while (_driftCarry >= 1) {
      _driftCarry -= 1;
      final p =
          _driftFrom[(r() * _driftFrom.length).floor() % _driftFrom.length];
      final c = cos(_rot), s = sin(_rot);
      final q = Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c) * scaleK;
      _grains.add(
        _pos.dx + q.dx + (r() - 0.5) * 4,
        _pos.dy + q.dy,
        (r() - 0.5) * 8,
        -(9 + r() * 9),
        2.8 + r() * 1.8,
        _Grains.drift,
      );
    }
  }

  /// Where light leaks out of the standard hull (hull units).
  static const _driftFrom = [
    Offset(0, -6),
    Offset(0, -9),
    Offset(-10, 3),
    Offset(10, 3),
    Offset(0, 8),
    Offset(-15.5, 6.5),
    Offset(15.5, 6.5),
  ];

  // ── drawing ─────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (_phase == _Phase.waiting || _phase == _Phase.gone) return;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // The engines' wake, in the ship's units. It stops at the ground: what
    // blasts into the grass comes back up as the wash's dust.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4000, -4000, 4000, _groundTop + 6));
    canvas.scale(scaleK);
    _wake.paint(canvas, grain: 0.55);
    canvas.restore();

    if (_hullShown) {
      canvas.save();
      canvas.translate(_pos.dx, _pos.dy);
      canvas.rotate(_rot);
      canvas.scale(scaleK);
      paintShipHull(
        canvas,
        skin,
        _hullTime,
        glow: _glow,
        boost: _boost,
        engines: _engine,
      );
      canvas.restore();
    }

    _grains.paint(canvas, shipLight(skin));
    canvas.restore();
  }
}

/// The loose grains round the ship: embers of its light that cool as they
/// fall, dust off the ground, and motes rising off the hull at rest.
class _Grains {
  static const int ember = 0, dust = 1, drift = 2, trail = 3, skirt = 4;
  static const int _cap = 2200;

  final Float32List _x = Float32List(_cap);
  final Float32List _y = Float32List(_cap);
  final Float32List _vx = Float32List(_cap);
  final Float32List _vy = Float32List(_cap);
  final Float32List _age = Float32List(_cap);
  final Float32List _life = Float32List(_cap);
  final Uint8List _kind = Uint8List(_cap);
  final Uint8List _down = Uint8List(_cap); // lying on the ground
  int _n = 0;
  int _seed = 0x51ED27;
  double _t = 0;

  bool get empty => _n == 0;

  double rand() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }

  void add(double x, double y, double vx, double vy, double life, int kind) {
    if (_n >= _cap) return;
    final i = _n++;
    _x[i] = x;
    _y[i] = y;
    _vx[i] = vx;
    _vy[i] = vy;
    _age[i] = 0;
    _life[i] = life;
    _kind[i] = kind;
    _down[i] = 0;
  }

  /// Moves every grain on by [dt]; anything heavy falling past [floor]
  /// comes to rest on it.
  void step(double dt, double floor) {
    _t += dt;
    var i = 0;
    while (i < _n) {
      _age[i] += dt;
      if (_age[i] >= _life[i]) {
        _n--;
        _x[i] = _x[_n];
        _y[i] = _y[_n];
        _vx[i] = _vx[_n];
        _vy[i] = _vy[_n];
        _age[i] = _age[_n];
        _life[i] = _life[_n];
        _kind[i] = _kind[_n];
        _down[i] = _down[_n];
        continue;
      }
      if (_down[i] == 0) {
        final k = _kind[i];
        if (k == drift) {
          // Light: it rises, sways and slows.
          final d = exp(-0.6 * dt);
          _vx[i] = _vx[i] * d + sin(_t * 1.3 + i * 0.7) * 6 * dt;
          _vy[i] *= d;
        } else if (k == trail) {
          // Hangs in the air, spreading as it goes, sinking a little.
          final d = exp(-0.9 * dt);
          _vx[i] = _vx[i] * d + (rand() - 0.5) * 420 * dt;
          _vy[i] = _vy[i] * d + (rand() - 0.5) * 420 * dt + 18 * dt;
        } else if (k == skirt) {
          // Dust rolling out low along the ground, slowing.
          final d = exp(-2.6 * dt);
          _vx[i] *= d;
          _vy[i] = _vy[i] * d + 40 * dt;
        } else {
          final d = exp(-(k == dust ? 2.2 : 1.4) * dt);
          _vx[i] *= d;
          _vy[i] = _vy[i] * d + (k == dust ? 300 : 210) * dt;
        }
        _x[i] += _vx[i] * dt;
        _y[i] += _vy[i] * dt;
        if ((k == ember || k == dust || k == skirt) &&
            _vy[i] > 0 &&
            _y[i] > floor) {
          _y[i] = floor;
          _down[i] = 1;
          // A grain that lands fades out where it lies, soon.
          _life[i] = min(_life[i], _age[i] + 0.35);
        }
      }
      i++;
    }
  }

  static final List<Float32List> _buckets = List.generate(
    10,
    (_) => Float32List(_cap * 2),
  );
  static final List<int> _bucketN = List.filled(10, 0);
  static const Color _ash = Color(0xFFC4CDD6);
  static final Paint _dots = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void paint(Canvas c, ShipLight l) {
    if (_n == 0) return;
    _bucketN.fillRange(0, 10, 0);
    for (var i = 0; i < _n; i++) {
      final f = _age[i] / _life[i];
      final int b = switch (_kind[i]) {
        ember => f < 0.3 ? 0 : (f < 0.65 ? 1 : 2),
        dust || skirt => i.isEven ? 3 : 4,
        drift => f < 0.25 || f > 0.8 ? 6 : 5,
        _ => f < 0.14 ? 7 : (f < 0.45 ? 8 : 9),
      };
      final k = _bucketN[b]++ * 2;
      _buckets[b][k] = _x[i];
      _buckets[b][k + 1] = _y[i];
    }
    void pass(int b, double d, Color col) {
      final n = _bucketN[b];
      if (n == 0) return;
      _dots
        ..strokeWidth = d
        ..color = col;
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_buckets[b], 0, n * 2),
        _dots,
      );
    }

    // The trail, cooling: ash, the light, the white-hot.
    pass(9, 1.5, Color.lerp(l.grainDim, _ash, 0.7)!.withValues(alpha: 0.42));
    pass(8, 1.7, l.essence.withValues(alpha: 0.7));
    pass(7, 2.2, l.grainHot.withValues(alpha: 0.95));
    // Dust, under the light.
    pass(3, 2.2, const Color(0x8C544A34));
    pass(4, 1.9, const Color(0x8CBDB280));
    pass(2, 1.6, l.grainDim.withValues(alpha: 0.4));
    pass(1, 2.0, l.essence.withValues(alpha: 0.7));
    pass(0, 2.5, l.grainHot.withValues(alpha: 0.95));
    pass(6, 1.6, l.essence.withValues(alpha: 0.32));
    pass(5, 2.0, l.grainHot.withValues(alpha: 0.7));
  }
}
