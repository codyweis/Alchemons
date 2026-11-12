// lib/games/cosmic_survival/arena_wear.dart
//
// What a run does to the arena it is fought in. Four things, all of them in
// the world and none of them a message:
//
//  - The floor shows what the fight is doing to it, and lets it go. Where a
//    body fell, a blast went off, a front pressed through or a creature's
//    special struck, ash and cinder lie a few seconds (a body's ash 2.4 s, a
//    heavy one's 4 s, the rest 5 s) and fade (user, 2026-11-12: marks kept
//    for the whole run were too much on the floor).
//  - The edges go dark. The light the core holds over its disc draws in as
//    the waves climb, and keeps drawing in through the endless waves.
//  - Ash rides the air from where the wave is coming: thin and slow in a
//    quiet arena, thick and fast under a full front, from the bearing the
//    front walks in on. A boss stills it.
//  - A cleared wave lets go. The drift thins and slows, the dark at the edge
//    eases back and the core's light swells over the floor for a few
//    seconds, further after a hard wave than an easy one.
//
// Budget: a mark is a few numbers; its grains are read off its seed each
// frame. A frame draws two or three soft fills per mark in view and every
// mark's grains in at most twelve point batches. Intake is rationed and
// capped ([ArenaWear._softCap], [ArenaWear._hardCap]), so a horde dying
// leaves a floor and not a carpet. The floor's light and the dark are one
// gradient fill each,
// the drift two point batches. No blur, no layers. It draws its own numbers
// and never touches the run's Random.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:flutter/painting.dart';

/// What a mark is made of.
enum WearTone {
  /// Cold ash: what a body or a crowd's tread leaves.
  ash,

  /// Cinder: what fire, a blast or a strike leaves. Warm at first.
  cinder,

  /// Ash with pale gold in it: left by a creature under a blessing.
  gilt,
}

/// A mark on the floor: char and grains that lie [life] seconds and go. Its
/// grains are read off [seed] each frame, so nothing is stored per grain.
class _Mark {
  _Mark(
    this.x,
    this.y,
    this.r,
    this.life,
    this.strength,
    this.grains,
    this.tone,
    this.seed,
  );
  final double x, y, r, life, strength;
  final int grains, seed;
  final WearTone tone;
  double age = 0;
}

/// A mark still warm: light on the floor that cools to nothing over [life].
class _Ember {
  _Ember(this.x, this.y, this.r, this.life, this.color);
  final double x, y, r, life;
  final Color color;
  double age = 0;
}

class ArenaWear {
  ArenaWear();

  // ── floor ────────────────────────────────────────────────────────────────

  /// No mark is wider than this.
  static const double _maxReach = 96;

  static const _ashDim = Color(0xFF7D7466);
  static const _ashPale = Color(0xFFC4BAA4);
  static const _cinder = Color(0xFFA85C36);
  static const _gilt = Color(0xFFE2C98F);
  static const _char = Color(0xFF030208);

  final List<_Ember> _embers = [];
  double _clock = 0;
  int _k = 0x2F6E2B1;

  /// Marks a fall, a tread or a weak strike may still leave this second.
  /// Blasts, heavy bodies and strong strikes are let in past it (they are
  /// rare); the rest are not.
  double _ration = 12;
  static const double _rationPerSecond = 9;
  static const double _rationMax = 16;

  /// How many marks the floor has taken this run.
  int marks = 0;

  /// Its own numbers (xorshift32), so laying marks never draws from the
  /// run's Random and never repeats a spot.
  double _next() {
    var x = _k;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _k = x;
    return x / 4294967296.0;
  }

  /// A body fell at [at]: its ash lies a moment and goes. Rationed: in a
  /// horde most deaths leave nothing. [heavy] bodies (brutes, colossi,
  /// elites) always leave theirs, and it lies longer.
  void fall(Offset at, double radius, {bool heavy = false}) {
    if (!heavy) {
      if (_ration < 1) return;
      _ration -= 1;
    }
    _lay(
      at,
      radius * (heavy ? 2.6 : 1.9),
      heavy ? _heavyFallLife : _fallLife,
      heavy ? 0.6 : 0.34,
      heavy ? 40 : 14,
      WearTone.ash,
      rationed: !heavy,
    );
  }

  /// Seconds a body's ash lies on the floor.
  static const double _fallLife = 2.4, _heavyFallLife = 4.0;

  /// Seconds a blast's scorch, a strike or a crowd's tread lies.
  static const double _markLife = 5.0;

  /// Marks on the floor at once. Rationed marks are refused past [_softCap];
  /// the rest push the oldest out past [_hardCap].
  static const int _softCap = 80, _hardCap = 120;
  final List<_Mark> _marks = [];

  /// Marks on the floor now.
  int get floorMarks => _marks.length;

  void _lay(
    Offset at,
    double r,
    double life,
    double strength,
    int grains,
    WearTone tone, {
    bool rationed = false,
  }) {
    if (_marks.length >= _softCap && rationed) return;
    if (_marks.length >= _hardCap) _marks.removeAt(0);
    marks++;
    _marks.add(
      _Mark(
        at.dx,
        at.dy,
        min(r, _maxReach),
        life,
        strength,
        grains,
        tone,
        (_next() * 1024).floor(),
      ),
    );
  }

  /// A crowd is standing on [at]: the ground under it is trodden for a few
  /// seconds.
  void tread(Offset at, double radius) {
    if (_ration < 0.5) return;
    _ration -= 0.5;
    _lay(at, radius, _markLife, 0.13, 3, WearTone.ash, rationed: true);
  }

  /// Something burst at [at] out to [reach]: a scorch, warm for a few
  /// seconds in [light], that goes with the rest.
  void scorch(Offset at, double reach, {Color? light, bool gilt = false}) {
    _warm(at, reach * 0.7, 3.2, light ?? _cinder);
    _lay(
      at,
      reach * 0.9,
      _markLife,
      0.62,
      (18 + reach * 0.4).round().clamp(18, 70),
      gilt ? WearTone.gilt : WearTone.cinder,
    );
  }

  /// A creature's special struck at [at]. [power] is 0 for a newly hatched
  /// creature with no mastery and 1 for a grown one on a finished path: the
  /// stronger it is, the wider the mark, the more of it, and the longer it
  /// stays warm. [blessed] strikes leave gilt in the ash.
  void strike(
    Offset at,
    double power, {
    required Color light,
    bool blessed = false,
  }) {
    final p = power.clamp(0.0, 1.0);
    // A weak creature's strikes are rationed like bodies; a strong one's
    // are always kept.
    final rationed = p < 0.5;
    if (rationed) {
      if (_ration < 1) return;
      _ration -= 1;
    }
    final reach = 12 + 34 * p;
    _lay(
      at,
      reach,
      _markLife,
      0.2 + 0.36 * p,
      (5 + 22 * p).round(),
      blessed ? WearTone.gilt : WearTone.cinder,
      rationed: rationed,
    );
    if (p > 0.35) _warm(at, reach * 0.9, 1.2 + 3.6 * p, light);
  }

  void _warm(Offset at, double r, double life, Color color) {
    if (_embers.length >= 40) _embers.removeAt(0);
    _embers.add(_Ember(at.dx, at.dy, r, life, color));
  }
  // ── the run's weight ─────────────────────────────────────────────────────

  /// How far the run has worn the arena, 0..1, from the wave number. Climbs
  /// fastest early and never quite arrives: wave 10 0.23, 25 0.48, 50 0.73,
  /// 100 0.93.
  static double depthForWave(int wave) => 1 - exp(-max(0, wave - 1) / 38);

  double _depth = 0;
  double _pressure = 0;
  double _peak = 0;
  double _settle = 0;
  double _boss = 0;

  /// An Other Orb's dark drawing the core's light away (boss_roster_art.dart):
  /// the rim closes in and the floor dims while it lives.
  double _eclipse = 0;
  double _dirX = 0, _dirY = 1;
  double _driftX = 0, _driftY = 0;
  double _driftAmount = 0;

  /// Eased state, for tests and the preview harness.
  double get depth => _depth;
  double get pressure => _pressure;
  double get settle => _settle;

  /// Starts the arena at wave [wave] as dark at the edge as a run that
  /// deep would have left it (a resumed run). The floor's marks go in
  /// seconds, so none are laid.
  void seed(int wave) {
    _depth = depthForWave(wave);
  }

  /// A wave was cleared. [hardness] 0..1: how close it came to filling the
  /// field, or 1 for a boss.
  void waveCleared(double hardness) {
    _settle = max(_settle, 0.4 + 0.6 * hardness.clamp(0.0, 1.0));
    _peak = 0;
  }

  /// The most of the field the wave in progress has filled so far.
  double get peakPressure => _peak;

  /// Once a frame. [fill] is the share of the field's cap that is alive,
  /// [bearing] the angle from the core the wave is walking in from.
  void update(
    double dt, {
    required int wave,
    required double fill,
    required double bearing,
    required bool bossAlive,
    bool eclipse = false,
  }) {
    _eclipse += ((eclipse ? 1.0 : 0.0) - _eclipse) * min(1.0, dt * 0.5);
    _clock += dt;
    _ration = min(_rationMax, _ration + _rationPerSecond * dt);
    for (final e in _embers) {
      e.age += dt;
    }
    _embers.removeWhere((e) => e.age >= e.life);
    for (final m in _marks) {
      m.age += dt;
    }
    _marks.removeWhere((m) => m.age >= m.life);

    final f = fill.clamp(0.0, 1.0);
    if (f > _peak) _peak = f;
    // Everything eases: nothing here may step.
    _depth += (depthForWave(wave) - _depth) * min(1.0, dt * 0.25);
    _pressure += (f - _pressure) * min(1.0, dt * 0.7);
    _boss += ((bossAlive ? 1.0 : 0.0) - _boss) * min(1.0, dt * 0.6);
    _settle = max(0, _settle - dt / 6.0);

    // The air moves from the front toward the core, and turns slowly when
    // the next wave comes from somewhere else.
    final tx = -cos(bearing), ty = -sin(bearing);
    final turn = min(1.0, dt * 0.5);
    _dirX += (tx - _dirX) * turn;
    _dirY += (ty - _dirY) * turn;
    final len = sqrt(_dirX * _dirX + _dirY * _dirY);
    final still = 1 - 0.8 * _boss;
    final ease = 1 - 0.7 * _settleEase;
    final speed = (14 + 74 * _pressure) * still * ease;
    if (len > 1e-3) {
      _driftX += _dirX / len * speed * dt;
      _driftY += _dirY / len * speed * dt;
    }
    final want = (0.1 + 0.9 * _pressure) * (0.3 + 0.7 * _depth) * still * ease;
    _driftAmount += (want - _driftAmount) * min(1.0, dt * 0.9);
  }

  /// The settle, eased at both ends so it swells in and lets go.
  double get _settleEase {
    final s = _settle.clamp(0.0, 1.0);
    return s * s * (3 - 2 * s);
  }

  // ── painting ─────────────────────────────────────────────────────────────

  static final Paint _pointPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// The floor's marks inside [view], and whatever is still warm on it.
  /// Under every body.
  void paintFloor(Canvas c, Rect view) {
    _paintMarks(c, view);
    for (final e in _embers) {
      if (e.x + e.r < view.left ||
          e.x - e.r > view.right ||
          e.y + e.r < view.top ||
          e.y - e.r > view.bottom) {
        continue;
      }
      // Arrives over a tenth of its life, then cools slowly.
      final f = e.age / e.life;
      final rise = (f / 0.1).clamp(0.0, 1.0);
      final cool = 1 - f;
      vfxSpill(c, Offset(e.x, e.y), e.r, e.color, 0.2 * rise * cool * cool);
    }
  }

  /// Marks' grains by colour (dim ash, pale ash, cinder, gilt) and by how
  /// far they have faded (three steps), so they go out in at most twelve
  /// draws.
  final List<Float32List> _markPts = List.generate(12, (_) => Float32List(256));
  final List<int> _markN = List.filled(12, 0);

  /// Grain draws in the last [paintFloor].
  int lastGrainDraws = 0;

  void _markAdd(int b, double x, double y) {
    var d = _markPts[b];
    final n = _markN[b];
    if (n + 2 > d.length) {
      d = _markPts[b] = Float32List(d.length * 2)..setAll(0, d);
    }
    d[n] = x;
    d[n + 1] = y;
    _markN[b] = n + 2;
  }

  /// What is on the floor: it holds a while, then fades out. Its grains
  /// settle outward over the first quarter second, so a mark lands.
  void _paintMarks(Canvas c, Rect view) {
    lastGrainDraws = 0;
    if (_marks.isEmpty) return;
    for (final m in _marks) {
      if (m.x + m.r < view.left ||
          m.x - m.r > view.right ||
          m.y + m.r < view.top ||
          m.y - m.r > view.bottom) {
        continue;
      }
      final f = m.age / m.life;
      final g = ((f - 0.3) / 0.7).clamp(0.0, 1.0);
      final fade = 1 - g * g * (3 - 2 * g);
      if (fade <= 0.01) continue;
      final at = Offset(m.x, m.y);
      vfxSpill(c, at, m.r * 0.72, _char, m.strength * 0.8 * fade);
      // A second lobe, so a mark is a stain and never a disc. A faint
      // tread does without it.
      if (m.strength >= 0.2) {
        final la = _table[m.seed & 1023] * 2 * pi;
        vfxSpill(
          c,
          Offset(m.x + cos(la) * m.r * 0.35, m.y + sin(la) * m.r * 0.35),
          m.r * 0.5,
          _char,
          m.strength * 0.55 * fade,
        );
      }
      // What burned is faintly warm at its heart.
      if (m.tone != WearTone.ash) {
        vfxSpill(
          c,
          at,
          m.r * 0.5,
          m.tone == WearTone.cinder ? _cinder : _gilt,
          0.07 * fade,
        );
      }
      final step = (fade * 3).ceil().clamp(1, 3) - 1;
      final spread = 0.6 + 0.4 * min(1.0, m.age / 0.25);
      for (var i = 0; i < m.grains; i++) {
        final k = m.seed + i * 3;
        final a = _table[k & 1023] * 2 * pi;
        final u = _table[(k + 1) & 1023];
        final roll = _table[(k + 2) & 1023];
        // Squared, so the middle is dense and the edge is a few strays.
        final d = m.r * (0.08 + 0.92 * u * u) * spread;
        final b = switch (m.tone) {
          WearTone.ash => roll < 0.7 ? 0 : 1,
          WearTone.cinder => roll < 0.45 ? 2 : (roll < 0.85 ? 0 : 1),
          WearTone.gilt => roll < 0.4 ? 3 : (roll < 0.8 ? 1 : 0),
        };
        _markAdd(b * 3 + step, m.x + cos(a) * d, m.y + sin(a) * d);
      }
    }
    const looks = <(Color, double, double)>[
      (_ashDim, 3.2, 0.42),
      (_ashPale, 2.2, 0.5),
      (_cinder, 2.8, 0.5),
      (_gilt, 2.6, 0.7),
    ];
    for (var b = 0; b < 12; b++) {
      final n = _markN[b];
      if (n == 0) continue;
      final (color, size, alpha) = looks[b ~/ 3];
      _pointPaint
        ..color = color.withValues(alpha: alpha * ((b % 3) + 1) / 3)
        ..strokeWidth = size;
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_markPts[b], 0, n),
        _pointPaint,
      );
      _markN[b] = 0;
      lastGrainDraws++;
    }
  }

  final Map<int, ui.Shader> _gloomShaders = {};
  final Paint _gloomPaint = Paint();
  static const _ink = Color(0xFF04030A);

  /// How far out, as a share of the arena's radius, the dark begins.
  double get _gloomStart => 0.78 - 0.5 * _depth - 0.22 * _eclipse;

  /// How dark the rim is, 0..1.
  double get gloom =>
      ((0.66 * _depth + 0.16 * _boss + 0.24 * _eclipse) *
              (1 - 0.45 * _settleEase))
          .clamp(0.0, 0.86);

  final Map<int, ui.Shader> _floorShaders = {};
  final Paint _floorPaint = Paint();
  static const _ash = Color(0xFF9A8F7C);

  /// How much of its light the floor still holds, 0..1.
  double get floorLight =>
      (1 - 0.35 * _depth) * (1 + 0.45 * _settleEase) * (1 - 0.3 * _eclipse);

  /// The core's [light] lying on the floor about [centre], and the dark
  /// that has drawn in over it from the rim: over the sky and the belt,
  /// under every body, so a front walks in out of it. The floor holds less
  /// light the deeper the run; a cleared wave swells it for a while.
  void paintGloom(Canvas c, Offset centre, double radius, Color light) {
    final rgb = light.toARGB32() & 0xFFFFFF;
    _floorPaint
      ..color = Color.fromRGBO(255, 255, 255, 0.14 * floorLight)
      ..shader = _floorShaders[rgb] ??= () {
        final k = Color.lerp(Color(0xFF000000 | rgb), _ash, 0.35)!;
        return ui.Gradient.radial(
          Offset.zero,
          1,
          [
            k,
            k.withValues(alpha: 0.8),
            k.withValues(alpha: 0.5),
            k.withValues(alpha: 0.3),
            k.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 0.8, 0.95, 1.0],
        );
      }();
    c.save();
    c.translate(centre.dx, centre.dy);
    c.scale(radius * 1.05);
    c.drawCircle(Offset.zero, 1, _floorPaint);
    c.restore();

    final g = gloom;
    if (g < 0.01) return;
    // The view never reaches further than this from the core.
    const reach = 2.3;
    final step = (_gloomStart * 24).round().clamp(4, 22);
    _gloomPaint
      ..color = Color.fromRGBO(255, 255, 255, g)
      ..shader = _gloomShaders[step] ??= () {
        final start = step / 24;
        return ui.Gradient.radial(
          Offset.zero,
          1,
          [_ink.withValues(alpha: 0), _ink.withValues(alpha: 0.5), _ink, _ink],
          [start / reach, (start + 1) / 2 / reach, 1.04 / reach, 1.0],
        );
      }();
    c.save();
    c.translate(centre.dx, centre.dy);
    c.scale(radius * reach);
    c.drawCircle(Offset.zero, 1, _gloomPaint);
    c.restore();
  }

  static const int _moteCount = 230;
  static const double _driftTile = 900;
  final Float32List _dim = Float32List(_moteCount * 12);
  final Float32List _lit = Float32List(_moteCount * 12);

  /// Motes handed to the canvas by the last [paintDrift].
  int lastMotes = 0;

  /// The ash in the air over [view], above the floor and under the bodies.
  void paintDrift(Canvas c, Rect view) {
    lastMotes = 0;
    final shown = (_moteCount * _driftAmount.clamp(0.0, 1.0)).round();
    if (shown <= 0) return;
    var nd = 0, nl = 0;
    final cap = _dim.length;
    final c0 = (view.left / _driftTile).floor(),
        c1 = (view.right / _driftTile).floor();
    final r0 = (view.top / _driftTile).floor(),
        r1 = (view.bottom / _driftTile).floor();
    for (var i = 0; i < shown; i++) {
      final k = i * 4;
      // Nearer motes ride faster; each sways a little across the stream.
      final pace = 0.6 + 0.8 * _table[(k + 2) & 1023];
      final sway = sin(_clock * (0.5 + _table[(k + 3) & 1023]) + i) * 9;
      var x = _table[k & 1023] * _driftTile + _driftX * pace - _dirY * sway;
      var y =
          _table[(k + 1) & 1023] * _driftTile + _driftY * pace + _dirX * sway;
      x -= (x / _driftTile).floor() * _driftTile;
      y -= (y / _driftTile).floor() * _driftTile;
      final lit = (i & 3) == 0;
      for (var col = c0; col <= c1; col++) {
        final wx = x + col * _driftTile;
        if (wx < view.left || wx > view.right) continue;
        for (var row = r0; row <= r1; row++) {
          final wy = y + row * _driftTile;
          if (wy < view.top || wy > view.bottom) continue;
          if (lit) {
            if (nl + 2 > cap) continue;
            _lit[nl++] = wx;
            _lit[nl++] = wy;
          } else {
            if (nd + 2 > cap) continue;
            _dim[nd++] = wx;
            _dim[nd++] = wy;
          }
        }
      }
    }
    lastMotes = (nd + nl) ~/ 2;
    if (nd > 0) {
      _pointPaint
        ..color = _ashDim.withValues(alpha: 0.55)
        ..strokeWidth = 3.0;
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_dim, 0, nd),
        _pointPaint,
      );
    }
    if (nl > 0) {
      _pointPaint
        ..color = _ashPale.withValues(alpha: 0.65)
        ..strokeWidth = 2.2;
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_lit, 0, nl),
        _pointPaint,
      );
    }
  }

  void dispose() {
    _marks.clear();
    _embers.clear();
  }
}

final Float32List _table = () {
  final r = Random(5417);
  return Float32List.fromList([for (var i = 0; i < 1024; i++) r.nextDouble()]);
}();
