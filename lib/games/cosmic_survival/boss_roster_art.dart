// lib/games/cosmic_survival/boss_roster_art.dart
//
// SURVIVAL'S BOSSES, IN GRAINS.
//
// The five bosses designed with the horde (docs/survival_roster/bosses.png),
// drawn in the horde's grains and stream tubes (roster_art.dart). A boss
// still fights the way its discipline fights (cosmic_survival_game.dart);
// its kind, read off that discipline with no dice, is how it looks and what
// its wave does to the arena. Open space keeps its own bosses
// (boss_forms.dart), and so does any discipline whose boss is not built yet.
//
// Built: all five. The disciplines with no boss of their own (artillery,
// siegebreaker) keep their archetype's old form (boss_forms.dart), redrawn
// here in grains ([SurvivalBossKind.form]), so every boss in survival stands
// in the same field.
//
// Blur-free: every grain is a point in one of a few tone batches.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/games/cosmic/enemy_body_art.dart'
    show BossForm, bossFormFor;
import 'package:alchemons/games/cosmic/vfx_shapes.dart' show vfxSpill;
import 'package:flutter/painting.dart' show HSVColor;
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';

/// The five bosses.
enum SurvivalBossKind {
  /// An egg of strands with one band broken; it hatches Strands out of the
  /// break.
  unhatched,

  /// A great shell of bands, open, a specimen hung inside, grains pouring in.
  harvester,

  /// A head of bright sand leading a stream that curls in toward the core
  /// behind it. Its wave fills the arena with dust it flows through
  /// (dust_sea.dart).
  drift,

  /// Two shells, ember and blue, bound by tubes.
  pair,

  /// A dark orb lit at the rim by yours, your party's shadows round it.
  otherOrb,

  /// No boss of its own: its archetype's old form (the Comet, the
  /// Singularity, the Ouroboros, the Spire, the Hive, the Armillary), in
  /// grains.
  form,
}

/// The boss [boss] is drawn as. Read off the discipline, so a seeded run
/// meets the same bosses.
SurvivalBossKind survivalBossKindOf(SurvivalBoss boss) =>
    switch (boss.discipline) {
      SurvivalBossDiscipline.riftcaller => SurvivalBossKind.drift,
      SurvivalBossDiscipline.conductor => SurvivalBossKind.harvester,
      SurvivalBossDiscipline.standard => SurvivalBossKind.unhatched,
      SurvivalBossDiscipline.duelist => SurvivalBossKind.pair,
      SurvivalBossDiscipline.trickster => SurvivalBossKind.otherOrb,
      SurvivalBossDiscipline.artillery ||
      SurvivalBossDiscipline.siegebreaker => SurvivalBossKind.form,
    };

/// How far above its centre, in radii, a boss of [kind] reaches (its bar
/// and name sit over that).
double survivalBossReach(SurvivalBossKind kind) => switch (kind) {
  SurvivalBossKind.drift => 0.8,
  SurvivalBossKind.harvester => 1.06,
  SurvivalBossKind.unhatched => 1.32,
  SurvivalBossKind.pair => 1.1,
  SurvivalBossKind.otherOrb => 1.08,
  SurvivalBossKind.form => 1.5,
};

const _ink = Color(0xFF07060B);
const _white = Color(0xFFFFF6E4);
const _tau = pi * 2;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// Tones of one colour: 0 the far/faint, 1 deep, 2 dark, 3 itself, 4 lit,
/// 5 glint.
List<Color> _tones(Color c) => [
  Color.lerp(c, _ink, 0.6)!.withValues(alpha: 0.5),
  Color.lerp(c, _ink, 0.55)!,
  Color.lerp(c, _ink, 0.3)!,
  c,
  Color.lerp(c, _white, 0.38)!,
  Color.lerp(c, _white, 0.78)!,
];

class _Pts {
  Float32List d = Float32List(1024);
  int n = 0;

  void add(double x, double y) {
    if (n + 2 > d.length) d = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x;
    d[n + 1] = y;
    n += 2;
  }
}

final List<_Pts> _fine = List.generate(6, (_) => _Pts());
final List<_Pts> _coarse = List.generate(6, (_) => _Pts());
final _Pts _heads = _Pts();
final Paint _pt = Paint()
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

void _flush(Canvas c, List<Color> tone) {
  void out(_Pts b, double w, Color col) {
    if (b.n == 0) return;
    c.drawRawPoints(
      PointMode.points,
      Float32List.sublistView(b.d, 0, b.n),
      _pt
        ..strokeWidth = w
        ..color = col,
    );
    b.n = 0;
  }

  for (var t = 0; t < 6; t++) {
    out(_fine[t], t == 0 ? 1.2 : 1.6, tone[t]);
  }
  for (var t = 1; t < 6; t++) {
    out(_coarse[t], 2.6, tone[t]);
  }
  out(_heads, 5.0, tone[5]);
}

// ───────────────────────────── The Drift ─────────────────────────────

/// Where a Drift's head has been: its stream is laid along this.
class _Trail {
  static const int n = 192;
  static const double gap = 0.1;
  final Float32List x = Float32List(n), y = Float32List(n);
  final Float32List born = Float32List(n);
  int head = 0, count = 0;
  double last = -1e9;

  void sample(Offset at, double time) {
    if (time < last || time - last > 2) count = 0;
    if (count > 0 && time - last < gap) return;
    x[head] = at.dx;
    y[head] = at.dy;
    born[head] = time;
    head = (head + 1) % n;
    if (count < n) count++;
    last = time;
  }

  /// Sample [k] back from the newest (0 is the newest).
  int at(int k) => (head - 1 - k) % n;
}

final Expando<_Trail> _trails = Expando('drift trail');

/// The stream in [sections] + 1 cross-sections from head (0) to tail: centre
/// and the unit normal across it. Filled by [_layStream].
const int _sections = 40;
final Float32List _sx = Float32List(_sections + 1);
final Float32List _sy = Float32List(_sections + 1);
final Float32List _nx = Float32List(_sections + 1);
final Float32List _ny = Float32List(_sections + 1);

/// The stream behind [boss]: its path, each sample settled toward [core]
/// by how long ago the head was there, so the stream curls in behind it.
/// Returns false while there is no stream yet.
bool _layStream(SurvivalBoss boss, double time, Offset core) {
  final t = _trails[boss];
  if (t == null || t.count < 3) return false;
  final last = t.count - 1;
  for (var s = 0; s <= _sections; s++) {
    final k = s / _sections * last;
    final k0 = k.floor(), k1 = min(last, k0 + 1), u = k - k0;
    final a = t.at(k0), b = t.at(k1);
    var x = t.x[a] + (t.x[b] - t.x[a]) * u;
    var y = t.y[a] + (t.y[b] - t.y[a]) * u;
    final age = time - (t.born[a] + (t.born[b] - t.born[a]) * u);
    final settle = 1 - exp(-max(0.0, age) * 0.085);
    x += (core.dx - x) * settle;
    y += (core.dy - y) * settle;
    _sx[s] = x;
    _sy[s] = y;
  }
  for (var s = 0; s <= _sections; s++) {
    final a = max(0, s - 1), b = min(_sections, s + 1);
    final dx = _sx[b] - _sx[a], dy = _sy[b] - _sy[a];
    final l = sqrt(dx * dx + dy * dy);
    if (l < 1e-3) {
      _nx[s] = s > 0 ? _nx[s - 1] : 0;
      _ny[s] = s > 0 ? _ny[s - 1] : 1;
    } else {
      _nx[s] = -dy / l;
      _ny[s] = dx / l;
    }
  }
  return true;
}

/// Once a frame from the game's update, for every living boss: what a
/// boss's look remembers between frames (a Drift's path) is kept here, so
/// it does not depend on how often it is drawn.
void tickSurvivalBossArt(SurvivalBoss boss, double time) {
  switch (survivalBossKindOf(boss)) {
    case SurvivalBossKind.drift:
      (_trails[boss] ??= _Trail()).sample(boss.position, time);
    case SurvivalBossKind.otherOrb:
      final b = _blinks[boss] ??= _Blink(boss.position);
      // A jump no walk could make in a frame is a blink.
      if ((boss.position - b.last).distance > 90) {
        b.from = b.last;
        b.at = time;
      }
      b.last = boss.position;
    default:
      break;
  }
}

/// The stream's half-width at [f] (0 head, 1 tail).
double _streamWidth(double r, double f) => r * (0.3 + 0.62 * f);

/// The Drift's stream as places the dust is pushed out of: [add] receives
/// a centre and a reach for each. For the dust sea.
void driftStreamSources(
  SurvivalBoss boss,
  double time,
  Offset core,
  void Function(double x, double y, double reach) add,
) {
  add(boss.position.dx, boss.position.dy, boss.radius * 1.5);
  if (!_layStream(boss, time, core)) return;
  for (var s = 2; s <= _sections; s += 3) {
    add(_sx[s], _sy[s], _streamWidth(boss.radius, s / _sections) * 1.15);
  }
}

/// A Drift: its stream, then its head.
void paintDrift(
  Canvas c,
  SurvivalBoss boss, {
  required double time,
  required Offset core,
}) {
  final r = boss.radius;
  // Struck, the head flares; the stream does not (a boss under fire would
  // be white end to end).
  final tone = _tones(boss.color);
  final headTone = _tones(
    Color.lerp(boss.color, _white, 0.55 * boss.hitFlash.clamp(0.0, 1.0))!,
  );
  final arrive = boss.isSpawning && boss.spawnIntroDuration > 0
      ? (1 - boss.spawnIntroTimer / boss.spawnIntroDuration).clamp(0.0, 1.0)
      : 1.0;
  final seed = boss.template.name.length * 7;

  // The stream: fine sand flowing back along it, a quarter of it running
  // the other way, brightest along its crest and fading to the tail.
  if (_layStream(boss, time, core)) {
    const grains = 3000;
    for (var i = 0; i < grains; i++) {
      final counter = i % 4 == 0;
      final f = (pow(_h(i, 141), 0.8) + time * (counter ? -0.05 : 0.1)) % 1.0;
      final ac = _h(i, 142) + _h(i, 143) - 1;
      final k = f * _sections, s0 = k.floor(), u = k - s0;
      final s1 = min(_sections, s0 + 1);
      final w = _streamWidth(r, f);
      final cx = _sx[s0] + (_sx[s1] - _sx[s0]) * u;
      final cy = _sy[s0] + (_sy[s1] - _sy[s0]) * u;
      final x = cx + _nx[s0] * ac * w, y = cy + _ny[s0] * ac * w;
      final crest = 1 - min(1.0, ac.abs() * 1.5);
      final lit = (counter ? 0.15 : 0.3) + 0.6 * crest * (1 - 0.75 * f);
      final t = f > 0.9
          ? 0
          : (lit < 0.3 ? 1 : (lit < 0.5 ? 2 : (lit < 0.7 ? 3 : 4)));
      _fine[t].add(x, y);
    }
    // Clumps riding the stream.
    for (var k = 0; k < 10; k++) {
      final f = (0.08 + 0.085 * k + time * 0.07) % 1.0;
      if (f > 0.85) continue;
      final kk = f * _sections, s0 = kk.floor(), u = kk - s0;
      final s1 = min(_sections, s0 + 1);
      final across = (_h(k, 144) - 0.5) * 0.8 * _streamWidth(r, f);
      final cx = _sx[s0] + (_sx[s1] - _sx[s0]) * u + _nx[s0] * across;
      final cy = _sy[s0] + (_sy[s1] - _sy[s0]) * u + _ny[s0] * across;
      for (var j = 0; j < 7; j++) {
        final a = _h(j + k * 7, 145) * _tau + time * 2;
        final d = r * 0.07 * sqrt(_h(j + k * 7, 146));
        _coarse[j < 2 ? 5 : 4].add(cx + d * cos(a), cy + d * sin(a));
      }
    }
  }

  _flush(c, tone);

  // The head: a churning ball of bright sand in its own light.
  final hx = boss.position.dx, hy = boss.position.dy;
  final rh = r * 0.62;
  vfxSpill(c, boss.position, rh * 2.4, headTone[3], 0.32);
  vfxSpill(c, boss.position, rh * 1.3, _white, 0.18);
  final spread = 1 + 3.5 * (1 - arrive) * (1 - arrive);
  final keep = 0.15 + 0.85 * arrive;
  for (var i = 0; i < 260; i++) {
    if (_h(i, 147) > keep) continue;
    final rho = sqrt(_h(i, 148)), a0 = _h(i, 149) * _tau;
    final ring = min(2, (rho * 3).floor());
    final a = a0 + time * (1.6 - 0.5 * ring) + seed;
    final x = rho * cos(a), y = rho * sin(a);
    final z = sqrt(max(0.0, 1 - rho * rho));
    final light = 0.45 + 0.55 * (-0.5 * x - 0.62 * y + 0.6 * z);
    final t = light < 0.3 ? 2 : (light < 0.6 ? 3 : (light < 0.86 ? 4 : 5));
    final d = rh * spread;
    _coarse[t].add(hx + d * x, hy + d * y);
  }
  _heads.add(hx - rh * 0.22, hy - rh * 0.22);
  _flush(c, headTone);
}

// ──────────────────────────── The Unhatched ────────────────────────────

/// Strand segments by tone (0 the far side).
final List<_Pts> _strands = List.generate(6, (_) => _Pts());

/// When each Unhatched last hatched.
final Expando<double> _hatchedAt = Expando('unhatched hatch');

/// Where an Unhatched's break is: on the side it faces. What it hatches
/// comes out here.
Offset unhatchedCrack(SurvivalBoss boss) {
  final heading = boss.charging ? boss.chargeAngle : boss.angle;
  final r = boss.radius;
  return Offset(
    boss.position.dx + cos(heading) * r * 0.42,
    boss.position.dy + sin(heading) * r * 0.42 * 1.28 + r * 0.08,
  );
}

/// [boss] has just hatched: its break flares and spills.
void noteUnhatchedHatch(SurvivalBoss boss, double time) {
  _hatchedAt[boss] = time;
}

final Paint _line = Paint()
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;
final Paint _eggDark = Paint();
const _bone = Color(0xFFE9DDC4);

void _lines(Canvas c, _Pts b, double w, Color col) {
  if (b.n < 4) {
    b.n = 0;
    return;
  }
  c.drawRawPoints(
    PointMode.lines,
    Float32List.sublistView(b.d, 0, b.n),
    _line
      ..strokeWidth = w
      ..color = col,
  );
  b.n = 0;
}

/// The Unhatched: an egg wound from strands, one band of it broken open on
/// the side it faces, what is inside glowing through. It hatches Strands
/// out of the break (the game spawns them at [unhatchedCrack]); each time,
/// the break flares and spills grains. The break widens as it is worn down;
/// a raised shield knits it shut; venting, the inside glows hot; enraged,
/// the shell goes red. Laid from the foot up as it arrives.
void paintUnhatched(Canvas c, SurvivalBoss boss, {required double time}) {
  final r = boss.radius;
  final cx = boss.position.dx, cy = boss.position.dy;
  final hit = boss.hitFlash.clamp(0.0, 1.0);
  // The shell is bone with the wave's colour in it; what is inside, and
  // what reaches out, is the colour itself.
  var shell = Color.lerp(boss.color, _bone, 0.64)!;
  if (boss.enraged) shell = Color.lerp(shell, const Color(0xFFE0533A), 0.35)!;
  final tone = _tones(Color.lerp(shell, _white, 0.35 * hit)!);
  final hotTone = _tones(Color.lerp(boss.color, _white, 0.12)!);
  final arrive = boss.isSpawning && boss.spawnIntroDuration > 0
      ? (1 - boss.spawnIntroTimer / boss.spawnIntroDuration).clamp(0.0, 1.0)
      : 1.0;
  // How far it has hatched; a shield seals it.
  final grow = boss.shieldUp ? -1.0 : (1 - boss.hpFraction).clamp(0.0, 1.0);
  final vent = boss.isVenting
      ? (boss.overheatTimer / 1.9).clamp(0.0, 1.0)
      : 0.0;
  final heading = boss.charging ? boss.chargeAngle : boss.angle;
  final hc = cos(heading), hs = sin(heading);
  const strands = 60, samples = 30, ry = 1.28, tip = 0.3;
  final ct = cos(tip), st = sin(tip);
  final spin = time * 0.3;
  final laid = arrive * 1.08 + 0.02;

  for (var j = 0; j < strands; j++) {
    final lon0 = j / strands * _tau;
    final shade = 0.75 + 0.25 * _h(j, 121);
    final s0 = 0.36 + 0.1 * _h(j, 122) - 0.14 * grow;
    final s1 = 0.56 + 0.14 * _h(j, 123) + 0.14 * grow;
    final a0 = 0.05 + 0.3 * _h(j, 124) - 0.45 * grow;
    final a1 = 0.75 + 0.3 * _h(j, 125) + 0.3 * grow;
    var open = false;
    var px = 0.0, py = 0.0;
    for (var i = 0; i <= samples; i++) {
      final s = i / samples;
      if (s > laid) break;
      final lat = -1.38 + 2.76 * s;
      final lon = lon0 + s * 2.9 + spin;
      final cl = cos(lat), y = sin(lat);
      final x = cl * cos(lon), z = cl * sin(lon);
      final yy = y * ct - z * st, zz = y * st + z * ct;
      final qx = cx + r * x, qy = cy - r * ry * yy;
      final along = x * hc - ry * yy * hs;
      final broken =
          zz > 0 && grow > -0.5 && s > s0 && s < s1 && along > a0 && along < a1;
      if (i > 0 && !open && !broken) {
        final int t;
        if (zz > 0) {
          final l = (0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz)) * shade;
          t = l < 0.3 ? 2 : (l < 0.6 ? 3 : (l < 0.86 ? 4 : 5));
        } else {
          t = 0;
        }
        _strands[t]
          ..add(px, py)
          ..add(qx, qy);
      }
      open = broken;
      px = qx;
      py = qy;
    }
  }

  // The far side, then the dark inside the shell, then what is inside
  // glowing through the break, then the near side over all of it.
  _lines(c, _strands[0], max(1.0, r * 0.018), tone[1]);
  _eggDark.color = _ink.withValues(alpha: 0.55);
  c.drawOval(
    Rect.fromCenter(
      center: boss.position,
      width: r * 1.9,
      height: r * ry * 1.9 * min(1.0, laid),
    ),
    _eggDark,
  );
  final crack = unhatchedCrack(boss);
  final since = time - (_hatchedAt[boss] ?? -1e9);
  final flare = since < 1.5 ? exp(-since * 2.4) : 0.0;
  if (grow > -0.5) {
    vfxSpill(
      c,
      crack,
      r * (0.4 + 0.25 * grow + 0.3 * flare),
      boss.color,
      0.2 + 0.15 * grow + 0.45 * vent + 0.4 * flare,
    );
    for (var i = 0; i < 26; i++) {
      final a = _h(i, 126) * _tau + time * (1.2 + _h(i, 127));
      final d = r * 0.16 * sqrt(_h(i, 128)) * (1 + grow + flare);
      _coarse[i < 6 ? 5 : 4].add(crack.dx + d * cos(a), crack.dy + d * sin(a));
    }
    // A hatch spills out of the break, toward the side it faces.
    if (since < 0.9) {
      final f = since / 0.9;
      for (var i = 0; i < 60; i++) {
        final a = heading + (_h(i, 129) - 0.5) * 1.6;
        final d = r * (0.1 + 0.9 * f * (0.4 + 0.6 * _h(i, 130)));
        _fine[f < 0.4 ? 5 : (f < 0.7 ? 4 : 3)].add(
          crack.dx + d * cos(a),
          crack.dy + d * sin(a),
        );
      }
    }
    _flush(c, hotTone);
  }
  final wNear = max(1.6, r * 0.03);
  for (var t = 2; t < 6; t++) {
    _lines(c, _strands[t], wNear, tone[t]);
  }
}

// ───────────────────────────── The Pair ─────────────────────────────

/// A banded shell of unit grains, for the Pair's two bodies.
class _PairShell {
  _PairShell(
    int n, {
    required int bands,
    required int segs,
    required double fill,
    required double twist,
    required int salt,
  }) {
    final xs = <double>[], ys = <double>[], zs = <double>[];
    final bs = <int>[];
    for (var i = 0; xs.length < n && i < n * 4; i++) {
      final u = _h(i, 181 + salt), y = 2 * u - 1;
      final lon = _h(i, 182 + salt) * _tau;
      final b = min(bands - 1, (u * bands).floor());
      if ((u * bands) % 1.0 < 0.12) continue;
      if (((lon + twist * y) * segs / _tau) % 1.0 > fill) continue;
      final cl = sqrt(1 - y * y);
      xs.add(cl * cos(lon));
      ys.add(y);
      zs.add(cl * sin(lon));
      bs.add(b);
    }
    x = Float32List.fromList(xs);
    y = Float32List.fromList(ys);
    z = Float32List.fromList(zs);
    band = Uint8List.fromList(bs);
    this.bands = bands;
  }

  late final Float32List x, y, z;
  late final Uint8List band;
  late final int bands;
}

final _pairA = _PairShell(
  1300,
  bands: 4,
  segs: 3,
  fill: 0.72,
  twist: 0.5,
  salt: 0,
);
final _pairB = _PairShell(
  1300,
  bands: 8,
  segs: 9,
  fill: 0.55,
  twist: 0.9,
  salt: 4,
);
final Float64List _pc = Float64List(8), _ps = Float64List(8);
final List<_Pts> _tubeA = [_Pts(), _Pts()], _tubeB = [_Pts(), _Pts()];

/// One of the Pair's bodies at ([cx], [cy]), radius [r], into the grain
/// buckets.
void _pairBody(_PairShell sh, double cx, double cy, double r, double spin) {
  for (var k = 0; k < sh.bands; k++) {
    final a = k.isEven ? spin : -spin * 1.3;
    _pc[k] = cos(a);
    _ps[k] = sin(a);
  }
  for (var i = 0; i < sh.x.length; i++) {
    final k = sh.band[i];
    final x = sh.x[i] * _pc[k] - sh.z[i] * _ps[k];
    final z = sh.x[i] * _ps[k] + sh.z[i] * _pc[k];
    final yy = sh.y[i] * _tc - z * _ts, zz = sh.y[i] * _ts + z * _tc;
    if (zz <= 0) {
      _fine[0].add(cx + r * x, cy - r * yy);
      continue;
    }
    final light = 0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz);
    final t = light < 0.3 ? 2 : (light < 0.64 ? 3 : (light < 0.9 ? 4 : 5));
    _fine[t].add(cx + r * x, cy - r * yy);
  }
}

/// The colour opposite [c].
Color _opposite(Color c) {
  final h = HSVColor.fromColor(c);
  return h.withHue((h.hue + 180) % 360).toColor();
}

/// The Pair: two shells in opposite colours, bound by tubes, turning round
/// each other. Worn below half, they close in and turn faster, the tubes
/// short and thrashing; arriving, they come in from apart.
void paintPair(Canvas c, SurvivalBoss boss, {required double time}) {
  final r = boss.radius;
  final cx = boss.position.dx, cy = boss.position.dy;
  final hit = boss.hitFlash.clamp(0.0, 1.0);
  final colA = Color.lerp(boss.color, _white, 0.35 * hit)!;
  final colB = Color.lerp(_opposite(boss.color), _white, 0.35 * hit)!;
  final toneA = _tones(colA), toneB = _tones(colB);
  final arrive = boss.isSpawning && boss.spawnIntroDuration > 0
      ? (1 - boss.spawnIntroTimer / boss.spawnIntroDuration).clamp(0.0, 1.0)
      : 1.0;
  final tight = boss.hpFraction < 0.45 ? 1.0 : 0.0;
  final seed = boss.template.name.length;
  final axis = time * (0.6 + 0.9 * tight) + seed;
  final apart = 1 + 2.5 * pow(1 - arrive, 2);
  final sep =
      r * (0.72 - 0.14 * tight + 0.05 * sin(boss.phaseTimer * 4)) * apart;
  final ux = cos(axis), uy = sin(axis);
  final ax = cx - ux * sep, ay = cy - uy * sep;
  final bx = cx + ux * sep, by = cy + uy * sep;
  final rl = r * 0.5;

  // Each in its own light, then its shell.
  vfxSpill(c, Offset(ax, ay), rl * 1.5, colA, 0.38);
  vfxSpill(c, Offset(bx, by), rl * 1.5, colB, 0.38);
  _pairBody(_pairA, ax, ay, rl, 0.2 + time * 0.5);
  _flush(c, toneA);
  _pairBody(_pairB, bx, by, rl, 0.2 + time * 0.5 + 1.7);
  _flush(c, toneB);

  // The tubes that bind them: from the face of one to the face of the
  // other, each half the colour of the body it leaves, sagging and swaying.
  final nx = -uy, ny = ux;
  const tubes = 14;
  for (var j = 0; j < tubes; j++) {
    final across = (j - (tubes - 1) / 2) / ((tubes - 1) / 2);
    final off = across * rl * 0.75;
    final rim = sqrt(max(0.0, 1 - across * across * 0.56)) * rl * 0.92;
    final p0x = ax + ux * rim + nx * off, p0y = ay + uy * rim + ny * off;
    final p1x = bx - ux * rim - nx * off, p1y = by - uy * rim - ny * off;
    var px = p0x, py = p0y;
    const steps = 18;
    for (var i = 1; i <= steps; i++) {
      final f = i / steps;
      final bow =
          sin(f * pi) *
          (rl * (0.18 + 0.1 * j / tubes) +
              rl *
                  (0.16 + 0.2 * tight) *
                  sin(f * _tau * 1.5 + j * 0.9 - time * (1.6 + 3 * tight)));
      final x = p0x + (p1x - p0x) * f + nx * bow;
      final y = p0y + (p1y - p0y) * f + ny * bow;
      final half = f <= 0.5 ? _tubeA : _tubeB;
      half[0]
        ..add(px, py)
        ..add(x, y);
      if (i > 1 && i < steps) {
        half[1]
          ..add(px, py)
          ..add(x, y);
      }
      px = x;
      py = y;
    }
    _heads
      ..add(p0x, p0y)
      ..add(p1x, p1y);
  }
  final w = max(1.6, r * 0.028);
  _lines(c, _tubeA[0], w, toneA[3]);
  _lines(c, _tubeB[0], w, toneB[3]);
  _lines(c, _tubeA[1], w * 0.4, toneA[5]);
  _lines(c, _tubeB[1], w * 0.4, toneB[5]);
  _flush(c, _tones(Color.lerp(colA, colB, 0.5)!));
}

// ──────────────────────────── The Harvester ────────────────────────────

/// The Harvester's shell: grains on a sphere in six bands that turn against
/// each other, cut into five segments a band. The top band and the bottom
/// two are closed; the three round its middle are open, a few grains left
/// in them, so what it holds is seen through them.
class _HarvestShell {
  _HarvestShell() {
    const n = 10000, bands = 6, segs = 5;
    final xs = <double>[], ys = <double>[], zs = <double>[];
    final bs = <int>[];
    for (var i = 0; i < n; i++) {
      final u = _h(i, 161), y = 2 * u - 1, lon = _h(i, 162) * _tau;
      final b = min(bands - 1, (u * bands).floor());
      if ((u * bands) % 1.0 < 0.1) continue;
      if ((lon * segs / _tau) % 1.0 > 0.93) continue;
      final closed = b == 0 || b == 1 || b == 5;
      if (!closed && _h(i, 163) > 0.05) continue;
      final cl = sqrt(1 - y * y);
      xs.add(cl * cos(lon));
      ys.add(y);
      zs.add(cl * sin(lon));
      bs.add(b);
    }
    x = Float32List.fromList(xs);
    y = Float32List.fromList(ys);
    z = Float32List.fromList(zs);
    band = Uint8List.fromList(bs);
  }

  late final Float32List x, y, z;
  late final Uint8List band;
}

final _harvestShell = _HarvestShell();
final Float64List _bc = Float64List(6), _bs = Float64List(6);
final Float64List _rc = Float64List(3), _rsn = Float64List(3);
final Int32List _near = Int32List(_harvestShell.x.length);
final double _tc = cos(0.42), _ts = sin(0.42);
final Paint _hollowOf = Paint();

const _brass = Color(0xFFE2C98F);

/// A Harvester. Its open bands draw the arena's grains in, from all round
/// it and from far out across the field; a specimen hangs inside, an
/// octagram written behind it. As its next ring of shots nears, the bands
/// draw harder and the specimen's light swells, so the ring is read off the
/// body before it is thrown.
void paintHarvester(Canvas c, SurvivalBoss boss, {required double time}) {
  final r = boss.radius;
  final cx = boss.position.dx, cy = boss.position.dy;
  final hit = boss.hitFlash.clamp(0.0, 1.0);
  final tone = _tones(Color.lerp(boss.color, _white, 0.3 * hit)!);
  final spec = Color.lerp(boss.color, _brass, 0.6)!;
  final specTone = _tones(Color.lerp(spec, _white, 0.45 * hit)!);
  final arrive = boss.isSpawning && boss.spawnIntroDuration > 0
      ? (1 - boss.spawnIntroTimer / boss.spawnIntroDuration).clamp(0.0, 1.0)
      : 1.0;
  final grow = 1 - pow(1 - arrive, 3).toDouble();
  final rr = r * (0.35 + 0.65 * grow);
  // The last moment before its ring: 0 → 1.
  final charge = (1 - boss.spreadTimer / 0.9).clamp(0.0, 1.0);
  final dir = boss.template.name.length.isEven ? 1.0 : -1.0;

  // The harvest: rivers of grains drawn in from far across the field,
  // spiralling to its open middle, brightening as they arrive.
  const rivers = 9;
  for (var i = 0; i < 1300; i++) {
    final s = (_h(i, 171) + time * 0.09) % 1.0;
    final far = pow(1 - s, 1.3).toDouble();
    final d = rr * (1.05 + 4.2 * far);
    final arm = i % rivers;
    final a =
        arm * _tau / rivers +
        (_h(i, 172) - 0.5) * (0.05 + 0.16 * far) +
        dir * s * 2.4;
    final t = s < 0.2 ? 2 : (s < 0.55 ? 3 : (s < 0.85 ? 4 : 5));
    _fine[t].add(cx + d * cos(a), cy + d * sin(a) * 0.92);
  }
  // Grains pouring in to the open bands, faster as the ring nears.
  final pour = time * (0.3 + 0.5 * charge);
  for (var i = 0; i < 700; i++) {
    final s = (_h(i, 132) + pour) % 1.0;
    final a = _h(i, 133) * _tau + s * 1.1 * dir;
    final y = sin(a) * 0.5;
    if (y.abs() > 0.34) continue;
    final d = rr * (1.36 - 0.34 * s);
    _fine[s < 0.4 ? 2 : (s < 0.8 ? 3 : 4)].add(cx + d * cos(a), cy + d * y);
  }

  // The shell's far side.
  final sh = _harvestShell;
  final spin = 0.25 + time * 0.35;
  for (var k = 0; k < 6; k++) {
    final a = k.isEven ? spin : -spin;
    _bc[k] = cos(a);
    _bs[k] = sin(a);
  }
  var nNear = 0;
  for (var i = 0; i < sh.x.length; i++) {
    final k = sh.band[i];
    final x = sh.x[i] * _bc[k] - sh.z[i] * _bs[k];
    final z = sh.x[i] * _bs[k] + sh.z[i] * _bc[k];
    final yy = sh.y[i] * _tc - z * _ts, zz = sh.y[i] * _ts + z * _tc;
    if (zz > 0) {
      _near[nNear++] = i;
      continue;
    }
    _fine[k == 2 || k == 3 || k == 4 ? 1 : 0].add(cx + rr * x, cy - rr * yy);
  }
  _flush(c, tone);

  // Its hollow: dark inside the shell, so the far side lies behind it.
  _hollowOf.color = _ink.withValues(alpha: 0.45);
  c.drawCircle(boss.position, rr * 0.98, _hollowOf);

  // The octagram, behind the specimen, turning slowly.
  final turn = time * 0.08 * dir;
  for (var k = 0; k < 8; k++) {
    final a0 = turn + k * _tau / 8 - pi / 2;
    final a1 = turn + (k + 3) * _tau / 8 - pi / 2;
    final x0 = cos(a0) * rr * 0.6, y0 = sin(a0) * rr * 0.54;
    final x1 = cos(a1) * rr * 0.6, y1 = sin(a1) * rr * 0.54;
    for (var i = 0; i < 46; i++) {
      final f = (i + 0.5) / 46;
      _fine[2].add(cx + x0 + (x1 - x0) * f, cy + y0 + (y1 - y0) * f);
    }
  }
  _flush(c, tone);

  // The specimen, in its own light, which swells as the ring nears.
  final rs = rr * 0.27;
  vfxSpill(c, boss.position, rr * 0.75, spec, 0.28 + 0.32 * charge);
  vfxSpill(c, boss.position, rs * 1.2, _white, 0.12 + 0.2 * charge);
  for (var k = 0; k < 3; k++) {
    final a = time * (1.1 - 0.3 * k) + k;
    _rc[k] = cos(a);
    _rsn[k] = sin(a);
  }
  for (var i = 0; i < 700; i++) {
    final rho = sqrt(_h(i, 164)), a0 = _h(i, 165) * _tau;
    final k = min(2, (rho * 3).floor());
    final ux = rho * cos(a0), uy = rho * sin(a0);
    final x = ux * _rc[k] - uy * _rsn[k], y = ux * _rsn[k] + uy * _rc[k];
    final z = sqrt(max(0.0, 1 - rho * rho));
    final light = 0.45 + 0.55 * (-0.5 * x - 0.62 * y + 0.6 * z);
    final t = light < 0.3 ? 2 : (light < 0.62 ? 3 : (light < 0.88 ? 4 : 5));
    _coarse[t].add(cx + rs * x, cy + rs * y);
  }
  _flush(c, specTone);

  // The shell's near side, over all of it.
  for (var j = 0; j < nNear; j++) {
    final i = _near[j];
    final k = sh.band[i];
    final x = sh.x[i] * _bc[k] - sh.z[i] * _bs[k];
    final z = sh.x[i] * _bs[k] + sh.z[i] * _bc[k];
    final yy = sh.y[i] * _tc - z * _ts, zz = sh.y[i] * _ts + z * _tc;
    final light = 0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz);
    final t = light < 0.3 ? 2 : (light < 0.66 ? 3 : (light < 0.9 ? 4 : 5));
    _fine[t].add(cx + rr * x, cy - rr * yy);
  }
  _flush(c, tone);
}

// ─────────────────────────── The Other Orb ───────────────────────────

/// One of your Alchemons read as grains, for the Other Orb's guard: unit
/// positions (1 across, centred), how light each was, and whether it is on
/// the creature's edge.
class BossShadow {
  BossShadow(this.x, this.y, this.lum, this.edge);
  final Float32List x, y, lum;
  final Uint8List edge;
  int get length => x.length;
}

/// Reads the first frame ([frameW] x [frameH] at the top left) of a
/// creature's [sheet] as a [BossShadow] about [across] grains wide. Null
/// when the frame is empty.
Future<BossShadow?> bossShadowFromSheet(
  Image sheet,
  double frameW,
  double frameH, {
  int across = 46,
}) async {
  final w = across, h = max(1, (across * frameH / frameW).round());
  final rec = PictureRecorder();
  Canvas(rec).drawImageRect(
    sheet,
    Rect.fromLTWH(0, 0, frameW, frameH),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final pic = rec.endRecording();
  final small = await pic.toImage(w, h);
  pic.dispose();
  final data = await small.toByteData(format: ImageByteFormat.rawStraightRgba);
  small.dispose();
  if (data == null) return null;
  final px = data.buffer.asUint8List();
  bool solid(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && px[(y * w + x) * 4 + 3] > 110;
  final xs = <double>[], ys = <double>[], lum = <double>[];
  final edge = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!solid(x, y)) continue;
      final i = (y * w + x) * 4;
      xs.add(x / w - 0.5);
      ys.add((y - h / 2) / w);
      lum.add((px[i] * 0.3 + px[i + 1] * 0.59 + px[i + 2] * 0.11) / 255);
      edge.add(
        !solid(x - 1, y) ||
                !solid(x + 1, y) ||
                !solid(x, y - 1) ||
                !solid(x, y + 1)
            ? 1
            : 0,
      );
    }
  }
  if (xs.isEmpty) return null;
  return BossShadow(
    Float32List.fromList(xs),
    Float32List.fromList(ys),
    Float32List.fromList(lum),
    Uint8List.fromList(edge),
  );
}

/// Where an Other Orb last blinked from, and when.
class _Blink {
  _Blink(this.last);
  Offset last;
  Offset? from;
  double at = -1e9;
}

final Expando<_Blink> _blinks = Expando('other orb blink');

const _violet = Color(0xFFB08CFF);
const _deep = Color(0xFF2A1E48);
const _coreBrass = Color(0xFFD9B36A);

/// The Other Orb: a dark orb, lit at the rim by yours, drinking your core's
/// light across the field, your own party standing round it as shadows.
/// When it blinks it folds shut where it was and opens where it lands.
void paintOtherOrb(
  Canvas c,
  SurvivalBoss boss, {
  required double time,
  required Offset core,
  List<BossShadow> shadows = const [],
}) {
  final r = boss.radius;
  final cx = boss.position.dx, cy = boss.position.dy;
  final hit = boss.hitFlash.clamp(0.0, 1.0);
  final rimCol = Color.lerp(
    Color.lerp(_violet, boss.color, 0.3)!,
    _white,
    0.4 * hit,
  )!;
  final rimTone = _tones(rimCol);
  final deepTone = _tones(Color.lerp(_deep, boss.color, 0.12)!);
  final arrive = boss.isSpawning && boss.spawnIntroDuration > 0
      ? (1 - boss.spawnIntroTimer / boss.spawnIntroDuration).clamp(0.0, 1.0)
      : 1.0;
  final blink = _blinks[boss];
  final since = blink == null ? 1e9 : time - blink.at;
  final opened = min(arrive, min(1.0, since / 0.45));
  final rr = r * (0.15 + 0.85 * (1 - pow(1 - opened, 3)));

  // Folding shut where it blinked from.
  if (blink?.from case final from? when since < 0.6) {
    final f = since / 0.6;
    for (var i = 0; i < 220; i++) {
      final a = _h(i, 191) * _tau + f * 3;
      final d = r * (1 - f) * sqrt(_h(i, 192));
      _fine[i % 5 == 0 ? 4 : 1].add(from.dx + d * cos(a), from.dy + d * sin(a));
    }
    _flush(c, rimTone);
  }

  final toCore = core - boss.position;
  final dist = toCore.distance;
  final face = atan2(toCore.dy, toCore.dx);

  // Its pale light, its dark body.
  vfxSpill(c, boss.position, rr * 1.75, rimCol, 0.2);
  c.drawCircle(boss.position, rr, _eggDark..color = _ink);
  for (var i = 0; i < 1500; i++) {
    final rho = sqrt(_h(i, 151)), a = _h(i, 152) * _tau + time * 0.15;
    _fine[1 + (_h(i, 153) * 2.2).floor()].add(
      cx + rr * rho * cos(a),
      cy + rr * rho * sin(a),
    );
  }
  _flush(c, deepTone);

  // Your core's light, drawn across to it.
  if (dist > rr * 1.2 && dist < 1500) {
    final ux = toCore.dx / dist, uy = toCore.dy / dist;
    final fromX = core.dx - ux * 62, fromY = core.dy - uy * 62;
    final toX = cx + ux * rr, toY = cy + uy * rr;
    final width = (dist / 400).clamp(0.6, 2.0);
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < 700; i++) {
        final s = (_h(i, 157) + time * 0.3) % 1.0;
        if ((s < 0.5) != (pass == 0)) continue;
        final arc = sin(s * pi);
        final w = (22 * arc + 4) * width;
        final x =
            fromX +
            (toX - fromX) * s -
            uy * (-0.18 * dist * arc) +
            (_h(i, 158) - 0.5) * w;
        final y =
            fromY +
            (toY - fromY) * s +
            ux * (-0.18 * dist * arc) +
            (_h(i, 159) - 0.5) * w;
        _fine[s < 0.15 || s > 0.85 ? 4 : 3].add(x, y);
      }
      _flush(c, pass == 0 ? _tones(_coreBrass) : rimTone);
    }
  }

  // The rim your orb lights.
  for (var i = 0; i < 1100; i++) {
    final d = (_h(i, 154) + _h(i, 155) - 1) * 1.5;
    final rho = 1 - pow(_h(i, 156), 2) * 0.09 * (1 - d.abs() / 1.5);
    final lit = 1 - d.abs() / 1.5;
    final t = lit > 0.75 ? 5 : (lit > 0.45 ? 4 : (lit > 0.2 ? 3 : 2));
    _fine[t].add(cx + rr * rho * cos(face + d), cy + rr * rho * sin(face + d));
  }
  _flush(c, rimTone);

  // Its guard: your party, as shadows, standing on its far side.
  if (shadows.isNotEmpty && opened > 0.6) {
    final n = min(4, shadows.length);
    final size = rr * 0.95;
    for (var k = 0; k < n; k++) {
      final sh = shadows[k];
      final a = face + pi + (k - (n - 1) / 2) * 0.95;
      final ox = cx + cos(a) * rr * 1.6;
      final oy = cy + sin(a) * rr * 1.6 + sin(time * 1.6 + k) * rr * 0.04;
      for (var i = 0; i < sh.length; i++) {
        final onEdge = sh.edge[i] == 1;
        if (!onEdge && _h(i, 181) < 0.35) continue;
        final x = ox + sh.x[i] * size + (_h(i, 182) - 0.5) * 1.2;
        final y = oy + sh.y[i] * size + (_h(i, 183) - 0.5) * 1.2;
        if (onEdge) {
          _fine[4].add(x, y);
        } else {
          _fine[1 + (sh.lum[i] * 2.4).floor().clamp(0, 2)].add(x, y);
        }
      }
    }
    _flush(c, rimTone);
  }
}

// ─────────────────────── The old forms, in grains ───────────────────────

/// Rocks tumbling round a boss: [n] clumps of grains on tilted orbits.
void _debris(double cx, double cy, double r, double time, int n, int salt) {
  for (var k = 0; k < n; k++) {
    final a = time * (0.5 + 0.3 * _h(k, salt)) + k * _tau / n;
    final d = r * (0.85 + 0.3 * _h(k, salt + 1));
    final ox = cx + d * cos(a), oy = cy + d * sin(a) * 0.55;
    final size = r * (0.1 + 0.07 * _h(k, salt + 2));
    for (var i = 0; i < 26; i++) {
      final b = _h(i + k * 26, salt + 3) * _tau;
      final q = size * sqrt(_h(i + k * 26, salt + 4));
      final lit = cos(b + 2.3);
      _coarse[lit > 0.4 ? 4 : (lit > -0.3 ? 2 : 1)].add(
        ox + q * cos(b),
        oy + q * sin(b),
      );
    }
  }
}

/// A churning lit ball of [n] grains, radius [rb], into the coarse buckets.
void _sun(double cx, double cy, double rb, double time, int n, int salt) {
  for (var k = 0; k < 3; k++) {
    final a = time * (1.3 - 0.35 * k) + k;
    _rc[k] = cos(a);
    _rsn[k] = sin(a);
  }
  for (var i = 0; i < n; i++) {
    final rho = sqrt(_h(i, salt)), a0 = _h(i, salt + 1) * _tau;
    final k = min(2, (rho * 3).floor());
    final ux = rho * cos(a0), uy = rho * sin(a0);
    final x = ux * _rc[k] - uy * _rsn[k], y = ux * _rsn[k] + uy * _rc[k];
    final z = sqrt(max(0.0, 1 - rho * rho));
    final light = 0.45 + 0.55 * (-0.5 * x - 0.62 * y + 0.6 * z);
    final t = light < 0.3 ? 2 : (light < 0.62 ? 3 : (light < 0.88 ? 4 : 5));
    _coarse[t].add(cx + rb * x, cy + rb * y);
  }
}

/// A boss's archetype form ([bossFormFor]) in grains.
void paintGrainForm(Canvas c, SurvivalBoss boss, {required double time}) =>
    paintGrainFormOf(
      c,
      form: bossFormFor(boss.type),
      position: boss.position,
      radius: boss.radius,
      color: boss.color,
      time: time,
      hitFlash: boss.hitFlash,
      enraged: boss.enraged,
      arrive: boss.isSpawning && boss.spawnIntroDuration > 0
          ? (1 - boss.spawnIntroTimer / boss.spawnIntroDuration).clamp(0.0, 1.0)
          : 1.0,
      charging: boss.charging,
      heading: boss.charging ? boss.chargeAngle : boss.angle,
      shieldUp: boss.shieldUp,
      venting: boss.isVenting,
    );

/// How far above its centre, in radii, a [form] in grains reaches.
double grainFormReach(BossForm form) => switch (form) {
  BossForm.comet => 1.1,
  BossForm.singularity => 1.2,
  BossForm.ouroboros => 1.1,
  BossForm.spire => 1.55,
  BossForm.hive => 1.15,
  BossForm.armillary => 1.5,
};

/// A [form] in grains from plain values, for open space's bosses too.
/// [arrive] 0..1 grows it in; [heading] is where it faces (a comet's tail
/// streams behind it).
void paintGrainFormOf(
  Canvas c, {
  required BossForm form,
  required Offset position,
  required double radius,
  required Color color,
  required double time,
  double hitFlash = 0,
  bool enraged = false,
  double arrive = 1,
  bool charging = false,
  double heading = 0,
  bool shieldUp = false,
  bool venting = false,
}) {
  final r = radius;
  final cx = position.dx, cy = position.dy;
  final hit = hitFlash.clamp(0.0, 1.0);
  var col = color;
  if (enraged) col = Color.lerp(col, const Color(0xFFE0533A), 0.35)!;
  col = Color.lerp(col, _white, 0.35 * hit)!;
  final tone = _tones(col);
  final rr = r * (0.3 + 0.7 * (1 - pow(1 - arrive, 3)));
  final hc = cos(heading), hs = sin(heading);
  final spinUp = enraged ? 1.8 : 1.0;
  switch (form) {
    case BossForm.comet:
      // A blazing nucleus trailing a river of embers, rocks tumbling round.
      final tail = charging ? 1.7 : 1.0;
      for (var i = 0; i < 1700; i++) {
        final s = (_h(i, 201) + time * 0.6) % 1.0;
        final back = rr * (0.4 + 3.2 * s * tail);
        final ac = _h(i, 202) + _h(i, 203) - 1;
        final side =
            rr * (0.18 + 0.5 * s) * ac + rr * 0.12 * s * sin(s * 9 - time * 4);
        _fine[s < 0.2 ? 5 : (s < 0.45 ? 4 : (s < 0.75 ? 3 : 2))].add(
          cx - hc * back - hs * side,
          cy - hs * back + hc * side,
        );
      }
      _flush(c, tone);
      vfxSpill(c, position, rr * 1.5, col, 0.42);
      vfxSpill(c, position, rr * 0.7, _white, 0.24);
      _sun(cx, cy, rr * 0.56, time, 760, 204);
      _debris(cx, cy, rr * 1.1, time * spinUp, 4, 206);
      _flush(c, tone);
    case BossForm.singularity:
      // A black hole in a disk of grains, quickest near the hole, brighter
      // on its approaching side; the far side drawn first, behind.
      final flare = venting ? 0.25 : 0.0;
      for (var pass = 0; pass < 2; pass++) {
        for (var i = 0; i < 2300; i++) {
          final rad = 0.62 + 0.88 * pow(_h(i, 211), 0.8);
          final a = _h(i, 212) * _tau + time * 1.4 * spinUp / pow(rad, 1.5);
          final far = sin(a) < 0;
          if (far != (pass == 0)) continue;
          final lit = 0.5 + 0.5 * cos(a) * (1.2 - rad * 0.6) + flare;
          final t = lit < 0.3
              ? 1
              : (lit < 0.55 ? 2 : (lit < 0.8 ? 3 : (lit < 0.95 ? 4 : 5)));
          _fine[far ? max(1, t - 1) : t].add(
            cx + rr * rad * cos(a),
            cy + rr * rad * sin(a) * 0.36,
          );
        }
        if (pass == 0) {
          // The far side lensed up over the top of the hole.
          for (var i = 0; i < 260; i++) {
            final a = pi + _h(i, 213) * pi;
            final d = rr * (0.56 + 0.06 * _h(i, 214));
            _fine[_h(i, 215) < 0.5 ? 4 : 3].add(
              cx + d * cos(a),
              cy + d * sin(a),
            );
          }
          _flush(c, tone);
          vfxSpill(c, position, rr * 1.6, col, 0.26 + flare);
          c.drawCircle(position, rr * 0.52, _eggDark..color = _ink);
        }
      }
      // Streams falling in.
      for (var k = 0; k < 6; k++) {
        for (var i = 0; i < 40; i++) {
          final f = (i / 40 + time * 0.4 + k * 0.17) % 1.0;
          final a = k * _tau / 6 + f * 2.2 + time * 0.3;
          final d = rr * (1.6 - 1.0 * f);
          _fine[f > 0.6 ? 4 : 2].add(cx + d * cos(a), cy + d * sin(a) * 0.4);
        }
      }
      _flush(c, tone);
    case BossForm.armillary:
      // Rings of grains turning on three axes round a sun, runes lit in
      // them; the far half of each ring behind the sun.
      for (var pass = 0; pass < 2; pass++) {
        for (var k = 0; k < 3; k++) {
          final ringR = rr * (0.95 + 0.24 * k);
          final spin = time * (0.5 + 0.25 * k) * (k.isEven ? 1 : -1) * spinUp;
          final leanZ = 0.4 + 1.1 * k, leanX = 1.1 + 0.35 * k;
          final cz = cos(leanZ), sz = sin(leanZ);
          final cxl = cos(leanX), sxl = sin(leanX);
          for (var i = 0; i < 700; i++) {
            final a = _h(i + k * 700, 221) * _tau + spin;
            final w = (_h(i + k * 700, 222) - 0.5) * 0.11;
            var x = cos(a) * (1 + w), y = sin(a) * (1 + w), z = 0.0;
            final y2 = y * cxl - z * sxl, z2 = y * sxl + z * cxl;
            y = y2;
            z = z2;
            final x3 = x * cz - y * sz, y3 = x * sz + y * cz;
            x = x3;
            y = y3;
            if ((z < 0) != (pass == 0)) continue;
            final rune = (a * 8 / _tau) % 1.0 < 0.06;
            final light = 0.5 + 0.5 * (-0.5 * x - 0.62 * y + 0.6 * z);
            final t = rune
                ? 5
                : (z < 0 ? 1 : (light < 0.45 ? 2 : (light < 0.75 ? 3 : 4)));
            (z < 0 ? _fine : _coarse)[t].add(cx + ringR * x, cy + ringR * y);
          }
        }
        _flush(c, tone);
        if (pass == 0) {
          vfxSpill(c, position, rr * 1.1, col, 0.4);
          _sun(cx, cy, rr * 0.42, time, 760, 224);
          _flush(c, tone);
        }
      }
    case BossForm.spire:
      vfxSpill(c, position, rr * 1.2, col, 0.22);
      _grainSpire(c, cx, cy, rr, time * spinUp, shieldUp, col);
      _flush(c, _tones(Color.lerp(col, _white, 0.18)!));
      _debris(cx, cy + rr * 0.1, rr * 1.15, time * spinUp, 5, 231);
      _flush(c, tone);
    case BossForm.ouroboros:
      // A serpent of grain vertebrae swimming a circle round an egg of light.
      vfxSpill(c, position, rr * 0.7, col, 0.3);
      _sun(cx, cy, rr * 0.3, time, 360, 241);
      final swim = time * 1.2 * spinUp;
      for (var v = 0; v < 26; v++) {
        final a = swim + v * _tau / 28;
        final ox = cx + rr * 0.9 * cos(a), oy = cy + rr * 0.9 * sin(a) * 0.6;
        final size = rr * (v == 0 ? 0.16 : 0.11 * (1 - v / 40));
        for (var i = 0; i < 12; i++) {
          final b = _h(i + v * 12, 242) * _tau;
          final q = size * sqrt(_h(i + v * 12, 243));
          _coarse[v == 0 ? 5 : (cos(b + 2.3) > 0 ? 4 : 2)].add(
            ox + q * cos(b),
            oy + q * sin(b),
          );
        }
      }
      _flush(c, tone);
    case BossForm.hive:
      // A murmuration on shifting orbits round a dark core.
      c.drawCircle(position, rr * 0.3, _eggDark..color = _ink);
      for (var f = 0; f < 9; f++) {
        final inc = 0.3 + 0.08 * f, node = f * 0.7;
        final orbit = rr * (0.55 + 0.07 * f);
        for (var i = 0; i < 100; i++) {
          final a = time * (0.9 + 0.1 * f) * spinUp + i * 0.045 + f;
          final x = cos(a), y = sin(a) * inc;
          final px = x * cos(node) - y * sin(node);
          final py = x * sin(node) + y * cos(node);
          final jitter = (_h(i + f * 100, 251) - 0.5) * 0.08;
          _fine[i % 7 == 0 ? 5 : (sin(a) > 0 ? 4 : 2)].add(
            cx + orbit * (px + jitter),
            cy + orbit * (py + jitter),
          );
        }
      }
      _flush(c, tone);
  }
}

/// The Spire's crystal: a tall six-sided bipyramid turning on its axis,
/// grains laid on each face and lit as that face is, so it reads as a
/// faceted stone of sand; fire in its veins. Shielded, its faces brighten.
final Float64List _vx = Float64List(8),
    _vy = Float64List(8),
    _vz = Float64List(8);

final Path _spireBody = Path();
final Paint _spireMass = Paint();

void _grainSpire(
  Canvas c,
  double cx,
  double cy,
  double r,
  double time,
  bool shield,
  Color col,
) {
  _spireBody.reset();
  // Apex 6, foot 7, the girdle 0-5.
  final turn = time * 0.4;
  for (var k = 0; k < 6; k++) {
    final a = turn + k * _tau / 6;
    _vx[k] = cos(a) * 0.5;
    _vz[k] = sin(a) * 0.5;
    _vy[k] = -0.12;
  }
  _vx[6] = 0;
  _vy[6] = -1.5;
  _vz[6] = 0;
  _vx[7] = 0;
  _vy[7] = 1.15;
  _vz[7] = 0;
  final lift = shield ? 0.15 : 0.0;
  for (var k = 0; k < 6; k++) {
    final k1 = (k + 1) % 6;
    for (final tip in const [6, 7]) {
      // The face's normal, toward the viewer or away.
      final ax = _vx[k] - _vx[tip],
          ay = _vy[k] - _vy[tip],
          az = _vz[k] - _vz[tip];
      final bx = _vx[k1] - _vx[tip],
          by = _vy[k1] - _vy[tip],
          bz = _vz[k1] - _vz[tip];
      var nx = ay * bz - az * by,
          ny = az * bx - ax * bz,
          nz = ax * by - ay * bx;
      final nl = sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nl;
      ny /= nl;
      nz /= nl;
      if (tip == 7) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      // Outward normals of a convex solid: faces turned away are not seen.
      final cxm = (_vx[k] + _vx[k1] + _vx[tip]) / 3;
      final czm = (_vz[k] + _vz[k1] + _vz[tip]) / 3;
      if (nx * cxm + nz * czm < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      final seen = nz > 0;
      if (!seen) continue;
      _spireBody
        ..moveTo(cx + r * _vx[tip], cy + r * _vy[tip])
        ..lineTo(cx + r * _vx[k], cy + r * _vy[k])
        ..lineTo(cx + r * _vx[k1], cy + r * _vy[k1])
        ..close();
      final light = (0.5 + 0.5 * (-0.5 * nx - 0.62 * ny + 0.6 * nz)) + lift;
      final t = light < 0.35 ? 2 : (light < 0.55 ? 3 : (light < 0.78 ? 4 : 5));
      for (var i = 0; i < 380; i++) {
        var u = _h(i + k * 260 + tip * 7, 232),
            v = _h(i + k * 260 + tip * 7, 233);
        if (u + v > 1) {
          u = 1 - u;
          v = 1 - v;
        }
        final x = _vx[tip] + ax * u + bx * v;
        final y = _vy[tip] + ay * u + by * v;
        // Fire in its veins: a seam of light down the middle of the seen
        // faces.
        final vein = (u - v).abs() < 0.03;
        _fine[vein ? 5 : t].add(cx + r * x, cy + r * y);
      }
    }
  }
  // Its dark body under the grains, so the faces read as stone.
  c.drawPath(_spireBody, _spireMass..color = Color.lerp(col, _ink, 0.78)!);
}

/// Paints [boss]'s body as [kind] in world space.
void paintSurvivalBossKind(
  Canvas c,
  SurvivalBoss boss,
  SurvivalBossKind kind, {
  required double time,
  required Offset core,
  List<BossShadow> shadows = const [],
}) {
  switch (kind) {
    case SurvivalBossKind.drift:
      paintDrift(c, boss, time: time, core: core);
    case SurvivalBossKind.harvester:
      paintHarvester(c, boss, time: time);
    case SurvivalBossKind.unhatched:
      paintUnhatched(c, boss, time: time);
    case SurvivalBossKind.pair:
      paintPair(c, boss, time: time);
    case SurvivalBossKind.otherOrb:
      paintOtherOrb(c, boss, time: time, core: core, shadows: shadows);
    case SurvivalBossKind.form:
      paintGrainForm(c, boss, time: time);
  }
}
