// lib/games/cosmic_survival/arena_wear.dart
//
// What a run does to the arena it is fought in. Four things, all of them in
// the world and none of them a message:
//
//  - The floor keeps what happened on it. Where bodies fell, where a blast
//    landed, where a front pressed through and where a creature's special
//    struck, ash and cinder stay for the rest of the run. Wave 60's floor
//    is not wave 3's.
//  - The edges go dark. The light the core holds over its disc draws in as
//    the waves climb, and keeps drawing in through the endless waves.
//  - Ash rides the air from where the wave is coming: thin and slow in a
//    quiet arena, thick and fast under a full front, from the bearing the
//    front walks in on. A boss stills it.
//  - A cleared wave lets go. The drift thins and slows, the dark at the edge
//    eases back and the core's light swells over the floor for a few
//    seconds, further after a hard wave than an easy one.
//
// Budget: the floor is baked. Marks go into tiles; a tile that has changed
// is re-recorded at most every [_bakeGap] seconds, one tile a frame: its
// char as a Picture that is turned into a small image off the frame (await
// toImage, never toImageSync; char is soft, so a small image holds it), its
// grains as a Picture of four point batches, kept as points so they stay
// sharp. A frame then draws one textured quad and one Picture per tile in
// view, eight to twelve tiles. Until a tile's image lands its char Picture
// is drawn instead. Intake is rationed, so a horde dying leaves a floor and
// not a carpet. The floor's light and the dark are one gradient fill each,
// the drift two point batches. No blur, no layers. It draws its own numbers
// and never touches the run's Random.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:flutter/painting.dart';

/// What a mark is made of.
enum WearTone {
  /// Cold ash: what a body leaves.
  ash,

  /// Cinder: what fire, a blast or a strike leaves. Warm at first.
  cinder,

  /// Ash with pale gold in it: left by a creature under a blessing.
  gilt,
}

class _Tile {
  _Tile(this.origin);

  final Offset origin;

  /// Point batches: dim ash, pale ash, cinder, gilt. Each a ring, so a tile
  /// that is full loses its oldest grains to its newest.
  final List<Float32List> pts = [
    Float32List(_caps[0] * 2),
    Float32List(_caps[1] * 2),
    Float32List(_caps[2] * 2),
    Float32List(_caps[3] * 2),
  ];
  final List<int> n = [0, 0, 0, 0];
  final List<int> head = [0, 0, 0, 0];

  /// Smudges as (x, y, radius, strength, tone index), a ring of [_smudgeCap].
  final Float32List smudges = Float32List(_smudgeCap * 5);
  int smudgeCount = 0, smudgeHead = 0;

  /// The tile as last recorded, in world units: its char, the image made
  /// of that, and its grains.
  ui.Picture? char;
  ui.Image? image;
  ui.Picture? grains;
  bool imaging = false;
  bool dirty = false, charDirty = false;
  double bakedAt = -1e9;

  static const _caps = [1500, 800, 700, 300];
  static const _smudgeCap = 240;

  void point(int b, double x, double y) {
    final cap = _caps[b];
    final i = head[b] * 2;
    pts[b][i] = x;
    pts[b][i + 1] = y;
    head[b] = (head[b] + 1) % cap;
    if (n[b] < cap) n[b]++;
  }

  void smudge(double x, double y, double r, double strength, int tone) {
    final i = smudgeHead * 5;
    smudges[i] = x;
    smudges[i + 1] = y;
    smudges[i + 2] = r;
    smudges[i + 3] = strength;
    smudges[i + 4] = tone.toDouble();
    smudgeHead = (smudgeHead + 1) % _smudgeCap;
    if (smudgeCount < _smudgeCap) smudgeCount++;
    charDirty = true;
  }
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

  static const double _tileSize = 570;
  static const int _span = 4;
  static const double _bakeGap = 0.5;

  /// A tile's image reaches this far past the tile on every side, so a
  /// smudge filed under one tile is never cut at its edge. No smudge is
  /// wider.
  static const double _margin = 96;
  static const int _imagePx = 320;

  static const _ashDim = Color(0xFF7D7466);
  static const _ashPale = Color(0xFFC4BAA4);
  static const _cinder = Color(0xFFA85C36);
  static const _gilt = Color(0xFFE2C98F);
  static const _char = Color(0xFF030208);

  bool _disposed = false;

  final List<_Tile?> _tiles = List.filled(_span * _span, null);
  final List<_Ember> _embers = [];
  Offset _centre = Offset.zero;
  bool _centred = false;
  double _clock = 0;
  int _k = 0x2F6E2B1;

  /// Marks a fall or a tread may still leave this second. Blasts and strikes
  /// are let in past it (they are rare); bodies are not.
  double _ration = 12;
  static const double _rationPerSecond = 9;
  static const double _rationMax = 16;

  /// How many marks the floor has taken this run.
  int marks = 0;

  _Tile? _tileAt(double x, double y) {
    final tx = ((x - _centre.dx) / _tileSize).floor() + _span ~/ 2;
    final ty = ((y - _centre.dy) / _tileSize).floor() + _span ~/ 2;
    if (tx < 0 || ty < 0 || tx >= _span || ty >= _span) return null;
    final i = ty * _span + tx;
    return _tiles[i] ??= _Tile(
      Offset(
        _centre.dx + (tx - _span ~/ 2) * _tileSize,
        _centre.dy + (ty - _span ~/ 2) * _tileSize,
      ),
    );
  }

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

  /// Lays [grains] grains within [radius] of [at], thickest at the middle.
  void _scatter(Offset at, double radius, int grains, WearTone tone) {
    for (var i = 0; i < grains; i++) {
      final a = _next() * 2 * pi;
      // Squared, so the middle is dense and the edge is a few strays.
      final u = _next();
      final d = radius * (0.08 + 0.92 * u * u);
      final x = at.dx + cos(a) * d, y = at.dy + sin(a) * d;
      final tile = _tileAt(x, y);
      if (tile == null) continue;
      final roll = _next();
      final b = switch (tone) {
        WearTone.ash => roll < 0.7 ? 0 : 1,
        WearTone.cinder => roll < 0.45 ? 2 : (roll < 0.85 ? 0 : 1),
        WearTone.gilt => roll < 0.4 ? 3 : (roll < 0.8 ? 1 : 0),
      };
      tile.point(b, x, y);
      tile.dirty = true;
    }
  }

  /// Char on the floor at [at]: the floor's light does not come through it.
  /// [tone] 0 is char alone, 1 has cinder warmth in it, 2 gilt.
  /// Laid as three lobes, so a mark is a stain and never a disc.
  void _charAt(Offset at, double r, double strength, [int tone = 0]) {
    final tile = _tileAt(at.dx, at.dy);
    if (tile == null) return;
    final reach = min(r, _margin);
    tile.smudge(at.dx, at.dy, reach * 0.72, strength * 0.8, tone);
    for (var i = 0; i < 2; i++) {
      final a = _next() * 2 * pi;
      final d = reach * (0.3 + 0.25 * _next());
      tile.smudge(
        at.dx + cos(a) * d,
        at.dy + sin(a) * d,
        reach * (0.4 + 0.25 * _next()),
        strength * 0.7,
        0,
      );
    }
    tile.dirty = true;
  }

  /// A body fell at [at]. Rationed: in a horde most deaths leave nothing.
  /// [heavy] bodies (brutes, colossi, elites) always leave their mark.
  void fall(Offset at, double radius, {bool heavy = false}) {
    if (!heavy) {
      if (_ration < 1) return;
      _ration -= 1;
    }
    marks++;
    final reach = radius * (heavy ? 2.6 : 1.9);
    _charAt(at, reach, heavy ? 0.6 : 0.34);
    _scatter(at, reach, heavy ? 40 : 14, WearTone.ash);
  }

  /// A crowd is standing on [at]: the ground under it is trodden. Light
  /// marks that add up to the lanes a front pressed in along.
  void tread(Offset at, double radius) {
    if (_ration < 0.5) return;
    _ration -= 0.5;
    _charAt(at, radius, 0.13);
    _scatter(at, radius, 3, WearTone.ash);
  }

  /// Something burst at [at] out to [reach]: a scorch that stays, warm for
  /// a few seconds in [light].
  void scorch(Offset at, double reach, {Color? light, bool gilt = false}) {
    marks++;
    _charAt(at, reach * 0.85, 0.62, gilt ? 2 : 1);
    _scatter(
      at,
      reach * 0.95,
      (18 + reach * 0.4).round().clamp(18, 70),
      gilt ? WearTone.gilt : WearTone.cinder,
    );
    _warm(at, reach * 0.7, 3.2, light ?? _cinder);
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
    if (p < 0.5) {
      if (_ration < 1) return;
      _ration -= 1;
    }
    marks++;
    final reach = 12 + 34 * p;
    _charAt(at, reach, 0.2 + 0.36 * p, blessed ? 2 : 1);
    _scatter(
      at,
      reach,
      (5 + 22 * p).round(),
      blessed ? WearTone.gilt : WearTone.cinder,
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
  double _dirX = 0, _dirY = 1;
  double _driftX = 0, _driftY = 0;
  double _driftAmount = 0;

  /// Eased state, for tests and the preview harness.
  double get depth => _depth;
  double get pressure => _pressure;
  double get settle => _settle;

  /// Starts the arena at wave [wave] already as worn as a run that deep
  /// would have left it (a resumed run), about [centre] out to [radius].
  void seed(int wave, Offset centre, double radius) {
    _place(centre);
    _depth = depthForWave(wave);
    final n = (wave * 14).clamp(0, 900);
    for (var i = 0; i < n; i++) {
      final a = _next() * 2 * pi;
      final d = radius * sqrt(_next()) * 0.96;
      final at = Offset(centre.dx + cos(a) * d, centre.dy + sin(a) * d);
      final roll = _next();
      if (roll < 0.14) {
        final reach = 50 + 60 * _next();
        _charAt(at, reach * 0.85, 0.62, 1);
        _scatter(at, reach, 44, WearTone.cinder);
      } else if (roll < 0.3) {
        _charAt(at, 60, 0.6);
        _scatter(at, 60, 40, WearTone.ash);
      } else {
        final reach = 24 + 26 * _next();
        _charAt(at, reach, 0.34);
        _scatter(at, reach, 14, WearTone.ash);
      }
    }
  }

  void _place(Offset centre) {
    if (_centred && centre == _centre) return;
    _centre = centre;
    _centred = true;
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
    required Offset centre,
    required int wave,
    required double fill,
    required double bearing,
    required bool bossAlive,
  }) {
    _place(centre);
    _clock += dt;
    _ration = min(_rationMax, _ration + _rationPerSecond * dt);
    for (final e in _embers) {
      e.age += dt;
    }
    _embers.removeWhere((e) => e.age >= e.life);

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

  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;

  void _bake(_Tile t) {
    if (t.charDirty || t.char == null) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < t.smudgeCount; i++) {
        final k = i * 5;
        final at = Offset(t.smudges[k], t.smudges[k + 1]);
        final r = t.smudges[k + 2];
        final tone = t.smudges[k + 4].round();
        vfxSpill(c, at, r, _char, t.smudges[k + 3]);
        // What burned is faintly warm at its heart for good.
        if (tone != 0) {
          vfxSpill(c, at, r * 0.5, tone == 1 ? _cinder : _gilt, 0.07);
        }
      }
      t.char?.dispose();
      t.char = rec.endRecording();
      t.charDirty = false;
      _image(t);
    }
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const looks = <(Color, double, double)>[
      (_ashDim, 3.2, 0.42),
      (_ashPale, 2.2, 0.5),
      (_cinder, 2.8, 0.5),
      (_gilt, 2.6, 0.7),
    ];
    for (var b = 0; b < 4; b++) {
      if (t.n[b] == 0) continue;
      final (color, size, alpha) = looks[b];
      _pointPaint
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = size;
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(t.pts[b], 0, t.n[b] * 2),
        _pointPaint,
      );
    }
    t.grains?.dispose();
    t.grains = rec.endRecording();
    t.dirty = false;
    t.bakedAt = _clock;
  }

  /// Turns the tile's char into its image, off the frame. One at a time per
  /// tile: a tile whose image is being made is not baked again until it
  /// lands.
  Future<void> _image(_Tile t) async {
    t.imaging = true;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final scale = _imagePx / (_tileSize + _margin * 2);
    c.scale(scale);
    c.translate(-(t.origin.dx - _margin), -(t.origin.dy - _margin));
    c.drawPicture(t.char!);
    final scaled = rec.endRecording();
    try {
      final image = await scaled.toImage(_imagePx, _imagePx);
      if (_disposed) {
        image.dispose();
      } else {
        t.image?.dispose();
        t.image = image;
      }
    } finally {
      scaled.dispose();
      t.imaging = false;
    }
  }

  /// Tiles drawn and tiles re-recorded by the last [paintFloor].
  int lastTilesDrawn = 0, lastTilesBaked = 0;

  /// The floor's marks inside [view], and whatever is still warm on it.
  /// Under every body.
  void paintFloor(Canvas c, Rect view) {
    lastTilesDrawn = 0;
    lastTilesBaked = 0;
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (t == null) continue;
      final box = Rect.fromLTWH(
        t.origin.dx - _margin,
        t.origin.dy - _margin,
        _tileSize + _margin * 2,
        _tileSize + _margin * 2,
      );
      if (!box.overlaps(view)) continue;
      if (t.dirty &&
          lastTilesBaked < 1 &&
          !t.imaging &&
          (t.grains == null || _clock - t.bakedAt >= _bakeGap)) {
        _bake(t);
        lastTilesBaked++;
      }
      final image = t.image;
      if (image != null) {
        c.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, _imagePx.toDouble(), _imagePx.toDouble()),
          box,
          _imagePaint,
        );
      } else if (t.char case final char?) {
        c.drawPicture(char);
      }
      if (t.grains case final grains?) {
        c.drawPicture(grains);
        lastTilesDrawn++;
      }
    }
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

  final Map<int, ui.Shader> _gloomShaders = {};
  final Paint _gloomPaint = Paint();
  static const _ink = Color(0xFF04030A);

  /// How far out, as a share of the arena's radius, the dark begins.
  double get _gloomStart => 0.78 - 0.5 * _depth;

  /// How dark the rim is, 0..1.
  double get gloom =>
      ((0.66 * _depth + 0.16 * _boss) * (1 - 0.45 * _settleEase)).clamp(
        0.0,
        0.86,
      );

  final Map<int, ui.Shader> _floorShaders = {};
  final Paint _floorPaint = Paint();
  static const _ash = Color(0xFF9A8F7C);

  /// How much of its light the floor still holds, 0..1.
  double get floorLight => (1 - 0.35 * _depth) * (1 + 0.45 * _settleEase);

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
    _disposed = true;
    for (final t in _tiles) {
      t?.char?.dispose();
      t?.char = null;
      t?.grains?.dispose();
      t?.grains = null;
      t?.image?.dispose();
      t?.image = null;
    }
  }
}

final Float32List _table = () {
  final r = Random(5417);
  return Float32List.fromList([for (var i = 0; i < 1024; i++) r.nextDouble()]);
}();
