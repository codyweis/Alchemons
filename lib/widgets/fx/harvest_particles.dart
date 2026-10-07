import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart' show GrainGlass;
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/rendering.dart';

/// The moments of a harvest a host announces as it plays them.
enum HarvestBeat { engage, take, shatter }

/// THE HARVEST, IN PARTICLES.
///
/// The harvester is a shell of its element's grains. They pour in from round
/// the specimen along a swirl and settle into a sphere about it: bands of
/// latitude turning against each other, each band broken into the device's
/// own segments — the Volcanic clamp's few fat plates, the Oceanic drown's
/// sheet of fine slits, the Earthen crusher's two heavy jaws, the Verdant
/// snare's tendrils winding pole to pole, the Arcane bind's even plates with
/// an octagram written behind the specimen, the Stabilized lock a band per
/// element. A sphere seen from a little above, with a far side behind the
/// specimen and a near side in front, rather than rings tipped about it
/// like an atom.
///
/// While it holds, the specimen leans on it and it gives the device's way,
/// shedding a few of its grains (embers rise, droplets fall, spores drift).
///
/// A take is a fusion's first half done to one: the specimen turns to grains
/// of itself behind a crest, and they pour into a sphere of their own,
/// turning, the shell closing round them as its skin. It seals warm, then
/// drifts up and thins away — sent on to the Cultivations, the way the
/// encounter says. A break tears the shell where the specimen pushes
/// through: the grains there go first, the rest loosens after them, and all
/// of it drifts out and dissolves.
///
/// Plain Dart, driven entirely by the beat its host passes in, so both
/// harvest renderers (the Flame field in the scene and the Flutter overlay)
/// draw the same thing. Blur-free: grains in batches, light as gradients.
class HarvestParticleField {
  HarvestParticleField({
    required this.profile,
    required this.cage,
    required this.specimenColor,
    this.shellCount = 2000,
    this.grain,
    this.rise = 1.25,
    this.sigilStrength = 1,
  }) {
    _seedShell();
  }

  /// Grains in the shell. The stage wants thousands; an icon a few hundred.
  final int shellCount;

  /// The shell's grain size, when it should not follow [cage]: an icon's
  /// cage is too small for grains in proportion to show at all.
  final double? grain;

  /// How far, in cages, a taken specimen's sphere lifts as it goes. An icon
  /// keeps it in its box.
  final double rise;

  /// How strongly the Arcane bind's octagram shows. Behind a specimen it is
  /// a seal; on an icon, with nothing in front of it, full strength reads
  /// as a star badge.
  final double sigilStrength;

  final HarvesterProfile profile;

  /// The radius the shell settles at, from the specimen's size.
  final double cage;

  /// The specimen's own colour, which lights the stage.
  final Color specimenColor;

  /// How long a take plays once the roll has held, and a break once it has
  /// not, in seconds.
  static const double takeSeconds = 2.3;
  static const double breakSeconds = 1.2;

  static final StreamController<HarvestBeat> _beats =
      StreamController<HarvestBeat>.broadcast(sync: true);

  /// A harvest's moments, announced by whichever host is playing it (the
  /// scene's HarvestFieldEffect or the overlay) on the frame they happen --
  /// so a sound lands on the picture, not on a guess at how long the picture
  /// takes. The take is announced when its crest starts, after the specimen
  /// has been read, not when the roll comes back.
  static Stream<HarvestBeat> get beats => _beats.stream;
  static void announce(HarvestBeat beat) => _beats.add(beat);

  static const Color _amber = Color(0xFFE4C16A);

  /// The shell is seen from a little above and turned a little, so it is
  /// lopsided rather than a badge.
  static const double _tip = 0.42, _turn = -0.2;
  static final double _cosTip = math.cos(_tip), _sinTip = math.sin(_tip);
  static final double _cosTurn = math.cos(_turn), _sinTurn = math.sin(_turn);

  /// Where the specimen tears through on a break: the near side, up and to
  /// the right, in view space (x right, y down, z towards the viewer).
  static const double _tearX = 0.52, _tearY = -0.46, _tearZ = 0.72;

  // ── the shell ─────────────────────────────────────────────────────────

  late final int _n;
  late final Uint8List _band;
  late final Float32List _lat, _lon, _rad, _ph, _arrive, _fly;

  /// The Arcane bind's octagram, at unit radius.
  late final Float32List _sigilX, _sigilZ;

  void _seedShell() {
    final rng = math.Random(41);
    final rings = profile.ringCount;
    final perBand = shellCount ~/ rings;
    final thick = 0.022 + 0.011 * profile.strokeBase;
    final band = <int>[];
    final lat = <double>[], lon = <double>[], rad = <double>[];
    final ph = <double>[], arrive = <double>[], fly = <double>[];
    for (var i = 0; i < rings; i++) {
      // Equal-area bands top to bottom, with a seam between them.
      final z0 = -1 + 2 * i / rings, z1 = -1 + 2 * (i + 1) / rings;
      final zMid = (z0 + z1) / 2, zHalf = (z1 - z0) / 2 * 0.84;
      final segs = profile.segsBase + i * profile.segsPerRing;
      for (var k = 0; k < perBand; k++) {
        final s = rng.nextInt(segs);
        // Along the segment, thinning to its ends: each is a lens, not a
        // block.
        final u = rng.nextDouble();
        final w = math.sin(math.pi * u);
        final z = zMid + (rng.nextDouble() * 2 - 1) * zHalf * (0.3 + 0.7 * w);
        final la = math.asin(z.clamp(-0.995, 0.995));
        band.add(i);
        lat.add(la);
        lon.add((s + u * 0.62) * math.pi * 2 / segs + profile.twist * la);
        rad.add(1 + (rng.nextDouble() - 0.5) * 2 * thick * (0.4 + 0.6 * w));
        ph.add(rng.nextDouble());
        // The bands come in one after another, top first.
        arrive.add(0.3 * i / rings + 0.7 * rng.nextDouble());
        fly.add(0.55 + 0.9 * rng.nextDouble());
      }
    }
    _n = band.length;
    _band = Uint8List.fromList(band);
    _lat = Float32List.fromList(lat);
    _lon = Float32List.fromList(lon);
    _rad = Float32List.fromList(rad);
    _ph = Float32List.fromList(ph);
    _arrive = Float32List.fromList(arrive);
    _fly = Float32List.fromList(fly);

    final sx = <double>[], sz = <double>[];
    if (profile.sigil) {
      final pts = octagramLine(1);
      for (var k = 1; k < pts.length; k++) {
        final a = pts[k - 1], b = pts[k];
        final n = math.max(1, ((b - a).distance / 0.022).round());
        for (var j = 0; j < n; j++) {
          final p = Offset.lerp(a, b, j / n)!;
          sx.add(p.dx);
          sz.add(p.dy);
        }
      }
    }
    _sigilX = Float32List.fromList(sx);
    _sigilZ = Float32List.fromList(sz);
  }

  // ── the specimen ──────────────────────────────────────────────────────

  SpecimenGrains? _specimen;
  Offset _at = Offset.zero;
  double _scale = 1;
  double _minY = 0, _maxY = 0;
  late Float32List _crestAt, _release, _sLat, _sLon, _sOrbit, _sOmega;
  late Float32List _sBulge, _sPh;

  /// The specimen as it is showing, for a take: read into grains, standing
  /// at [at] from the field's centre, drawn [scale] times its grain units.
  void setSpecimen(
    SpecimenGrains grains, {
    required Offset at,
    double scale = 1,
  }) {
    _specimen = grains;
    _at = at;
    _scale = scale;
    _seedSpecimen(grains);
  }

  bool get hasSpecimen => _specimen != null;

  /// A ball in the specimen's colour, for a take with nothing read: the
  /// shell still closes on something you can see go.
  SpecimenGrains? _stand;

  void _seedSpecimen(SpecimenGrains g) {
    final n = g.length;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, g.hy[i]);
      maxY = math.max(maxY, g.hy[i]);
    }
    if (n == 0) minY = maxY = 0;
    _minY = minY;
    _maxY = maxY;
    final span = math.max(1.0, maxY - minY);
    final midY = (minY + maxY) / 2, halfY = math.max(1.0, span / 2);
    var halfW = 1.0;
    for (var i = 0; i < n; i++) {
      halfW = math.max(halfW, g.hx[i].abs());
    }
    final rng = math.Random(13);
    _crestAt = Float32List(n);
    _release = Float32List(n);
    _sLat = Float32List(n);
    _sLon = Float32List(n);
    _sOrbit = Float32List(n);
    _sOmega = Float32List(n);
    _sBulge = Float32List(n);
    _sPh = Float32List(n);
    for (var i = 0; i < n; i++) {
      final down = (g.hy[i] - minY) / span;
      _crestAt[i] = _crestFrom + down * (_crestTo - _crestFrom);
      // The top goes first, the way the crest came down it.
      _release[i] = math.max(
        _crestAt[i] + 0.06,
        _pourFrom + _pourSpread * (down * 0.75 + rng.nextDouble() * 0.25),
      );
      // A thick sphere. Each grain keeps its height: the top of the specimen
      // goes round the top.
      _sOrbit[i] = 0.62 + 0.42 * rng.nextDouble();
      _sLat[i] = math.asin(
        ((g.hy[i] - midY) / halfY * 0.88 + (rng.nextDouble() - 0.5) * 0.24)
            .clamp(-0.97, 0.97),
      );
      // One way round, at rates of its own so it shears into bands.
      final w = 1.6 + 2.6 * rng.nextDouble();
      _sOmega[i] = w;
      // Folding in where it stood: a grain from the specimen's left lands
      // on the sphere's left, most of them round its near side.
      final across = (g.hx[i] / halfW * 0.92 + (rng.nextDouble() - 0.5) * 0.16)
          .clamp(-0.98, 0.98);
      final lonAt = math.acos(across) * (rng.nextDouble() < 0.62 ? 1 : -1);
      _sLon[i] = lonAt - w * (_release[i] + _flight) * takeSeconds;
      _sBulge[i] =
          (rng.nextDouble() < 0.7 ? 1.0 : -0.4) *
          (0.1 + 0.25 * rng.nextDouble());
      _sPh[i] = rng.nextDouble();
    }
  }

  // The take, in fractions of [takeSeconds].
  static const double _crestFrom = 0.03, _crestTo = 0.27;
  static const double _pourFrom = 0.14, _pourSpread = 0.3, _flight = 0.17;

  /// Where the take's crest is on the specimen, in its own grain units from
  /// its centre: above it the specimen is grains and the sprite is cut away.
  /// −∞ before it starts, +∞ once it has passed.
  double cutY(double take) {
    final p = (take - _crestFrom) / (_crestTo - _crestFrom);
    if (p <= 0) return double.negativeInfinity;
    if (p >= 1) return double.infinity;
    return _minY + p * (_maxY - _minY);
  }

  // ── the look ──────────────────────────────────────────────────────────

  static const int _tones = SpecimenGrains.toneCount;
  static const int _backTones = 8;
  // Per band: far, near in shadow, lit, catching the light, glow. Then the
  // sigil, what the shell sheds, the specimen's tones (near, far), its glow,
  // glints.
  static const int _perBand = 5;
  static const int _sigilB = 4 * _perBand;
  static const int _shedB = _sigilB + 1;
  static const int _specB = _shedB + 1;
  static const int _specBackB = _specB + _tones;
  static const int _specGlowB = _specBackB + _backTones;
  static const int _glintB = _specGlowB + 1;
  final GrainBatch _batch = GrainBatch(_glintB + 1);
  final Paint _p = Paint();

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
  static double _smooth(double x) {
    final v = _clamp01(x);
    return v * v * (3 - 2 * v);
  }

  static double _easeInOut(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  /// A point on the shell's sphere (y its pole) into view space: seen from a
  /// little above, turned a little. Returns depth (above zero is the near
  /// side) and writes the screen offset from the centre to [_vx], [_vy].
  double _view(double px, double py, double pz) {
    final y = py * _cosTip + pz * _sinTip;
    final z = pz * _cosTip - py * _sinTip;
    _vx = px * _cosTurn - y * _sinTurn;
    _vy = px * _sinTurn + y * _cosTurn;
    return z;
  }

  double _vx = 0, _vy = 0;

  /// Paints the field round [c] (and, on a take, the specimen) at this beat.
  ///
  /// [closing] is the raw 0..1 sweep in (the profile shapes it), [lock] the
  /// 0..1 moment it bites, [push] how hard the specimen is leaning, [strain]
  /// the looping strain phase in turns, [time] seconds since it engaged.
  /// [take] runs 0..1 over [takeSeconds] once the roll holds, [shatter] 0..1
  /// over [breakSeconds] once it does not. [back] picks the far side of the
  /// field (drawn behind the specimen) or everything else.
  void paint(
    Canvas canvas,
    Offset c, {
    required double closing,
    required double lock,
    required double push,
    required double strain,
    required double time,
    double take = 0,
    double shatter = 0,
    required bool back,
  }) {
    final b = _batch..clear();
    final shaped = profile.closingCurve(closing);
    final sh = _clamp01(shatter);
    final tk = _clamp01(take);
    final rings = profile.ringCount;

    // ── the take's stages ──
    // The shell closes in to be the new sphere's skin; the sphere seals,
    // then drifts up and thins away.
    final shellIn = _smooth((tk - 0.16) / 0.4);
    final seal = _smooth((tk - 0.48) / 0.2);
    final depart = _easeInOut(_clamp01((tk - 0.72) / 0.28));
    final gone = _smooth((tk - 0.8) / 0.2);
    final up = cage * rise * depart;
    final shrink = 1 - 0.5 * depart;
    final sphereC = c.translate(0, -up);
    final sphereR = cage * (0.5 - 0.1 * seal) * shrink;

    // ── the shell ──
    final bite = math.sin(math.pi * _clamp01(lock));
    final restR = cage * (1 - 0.05 * bite);
    final d0 = grain ?? cage * (0.0088 + 0.0024 * profile.strokeBase);
    final flexOn = 1 - shellIn;
    final shellAlpha = (1 - 0.15 * shellIn) * (1 - gone);

    // ── the stage light and the shell's own edge, under it all ──
    if (back) {
      final lit = (0.35 + 0.65 * closing) * (1 - shellIn) * (1 - sh);
      if (lit > 0.01) {
        final glow = Color.lerp(specimenColor, _amber, 0.5)!;
        _pool(canvas, c, cage * 1.8, glow, 0.16 * lit);
      }
      // A lens, not a disc: the shell's edge catches a little light.
      final edge =
          _smooth((shaped - 0.5) / 0.5) * (1 - _smooth(sh / 0.22)) * shellAlpha;
      if (edge > 0.01) {
        final r = restR + (sphereR * 1.14 - restR) * shellIn;
        _rim(canvas, sphereC, r * 1.04, profile.accent, edge);
      }
    }

    final spinUp = 3.2 * shellIn * shellIn;
    final tearing = sh > 0;
    for (var m = 0; m < _n; m++) {
      final i = _band[m];
      final dir = i.isEven ? 1.0 : -1.0;
      final omega = dir * profile.spinRate * (0.55 + 0.25 * i);
      var lon = _lon[m] + omega * time + dir * spinUp;
      var r = restR * _rad[m];
      var alpha = 1.0;
      // Pouring in: each grain still on its way is further out and further
      // back round the swirl, the late ones latest.
      if (shaped < 1) {
        final g = _smooth(shaped * 1.7 - _arrive[m] * 0.7);
        if (g <= 0.001) continue;
        r *= 1 + (1 - g) * 1.7;
        lon -= (1 - g) * 2.3;
        alpha = 0.2 + 0.8 * g;
      }
      // Closing to be the sphere's skin.
      if (shellIn > 0) r = r + (sphereR * 1.14 * _rad[m] - r) * shellIn;
      final cl = math.cos(_lat[m]);
      var z = _view(
        r * cl * math.cos(lon),
        r * math.sin(_lat[m]),
        r * cl * math.sin(lon),
      );
      var x = _vx, y = _vy;
      // It gives the device's way where the specimen leans.
      if (push > 0 && flexOn > 0) {
        final a = math.atan2(y, x);
        final f = profile.radialFlex(a, strain, push, cage) * flexOn;
        final len = math.sqrt(x * x + y * y);
        if (len > 0) {
          x += x / len * f;
          y += y / len * f;
        }
      }
      final len = math.max(1e-6, math.sqrt(x * x + y * y + z * z));
      final nx = x / len, ny = y / len, nz = z / len;
      if (tearing) {
        // Torn where it is pushed through: the grains there go first and
        // fast, the rest loosen after them, and all of it drifts out and
        // thins.
        final k = nx * _tearX + ny * _tearY + nz * _tearZ;
        final rel = (1 - k) * 0.5;
        final go = _clamp01((sh - rel * 0.62) / 0.38);
        final e = 1 - (1 - go) * (1 - go) * (1 - go);
        // Before it goes, the near side bulges out where it is pushed.
        final swell =
            1 + 0.14 * _smooth(sh / 0.14) * _clamp01(k * 1.4) * (1 - go);
        final out =
            cage * profile.shatterSpread * _fly[m] * e * (1 - 0.55 * rel);
        final toTear = cage * 0.35 * e * _clamp01(k + 0.3);
        x = x * swell + nx * out + _tearX * toTear;
        y = y * swell + ny * out + _tearY * toTear + cage * 0.18 * e * e;
        z = z + nz * out;
        alpha *= 1 - _smooth((go - 0.25) / 0.75);
        if (alpha <= 0.01) continue;
      }
      // Thinning in or out: a grain shows once the alpha passes its own
      // threshold, so they arrive and leave one by one instead of dimming.
      if (alpha < 1 && _ph[m] > alpha) continue;
      final px = sphereC.dx + x;
      final py = sphereC.dy + y;
      if ((z < 0) != back) continue;
      final base = i * _perBand;
      if (back) {
        b.add(base, px, py);
        continue;
      }
      b.add(base + 4, px, py);
      final bit = lock > 0.15 && lock < 0.85 && _ph[m] < 0.22;
      final twinkle = (time * 0.4 + _ph[m] * 7.3) % 1.0 < 0.008;
      if (bit || twinkle) {
        b.add(_glintB, px, py);
        continue;
      }
      // Lit from the upper left, like every glass and grain body here.
      final light = 0.5 + 0.5 * (-0.45 * nx - 0.55 * ny + 0.7 * nz);
      b.add(
        base + (light < 0.42 ? 1 : (light < 0.72 && _ph[m] > 0.1 ? 2 : 3)),
        px,
        py,
      );
    }

    // ── the bound sigil, behind the specimen, facing out ──
    // Laid round the equator it foreshortened into a zigzag through the
    // specimen; this way it is a seal written behind it, inside the shell.
    if (back && profile.sigil && shaped > 0.15) {
      final r = (shellIn > 0 ? sphereR * 1.05 : restR * 0.9) * (1 + 0.3 * sh);
      final spin = -time * profile.spinRate * 0.12;
      final cs = math.cos(spin), sn = math.sin(spin);
      for (var k = 0; k < _sigilX.length; k++) {
        b.add(
          _sigilB,
          sphereC.dx + (_sigilX[k] * cs - _sigilZ[k] * sn) * r,
          sphereC.dy + (_sigilX[k] * sn + _sigilZ[k] * cs) * r,
        );
      }
    }

    // ── what it sheds while it holds ──
    final hold =
        _smooth((shaped - 0.85) / 0.15) * (1 - _smooth(tk / 0.15)) * (1 - sh);
    if (!back && hold > 0.01) _shed(b, c, restR, time);

    // ── the specimen, taken ──
    final g = _specimen ?? (tk > 0 ? (_stand ??= _standIn()) : null);
    final hasReal = _specimen != null;
    if (g != null && tk > 0) {
      final base = c + _at;
      final tau = tk * takeSeconds;
      final glintBand = (_maxY - _minY) * 0.04;
      final crestY = hasReal ? cutY(tk) : double.infinity;
      final loose = _smooth((tk - _crestFrom) / 0.2);
      for (var j = 0; j < g.length; j++) {
        if (tk < _crestAt[j]) continue;
        final ph = _sPh[j];
        // Standing as grains, loosened: each drifts on a small loop.
        final wob = g.step * _scale * 0.45 * loose;
        final rx =
            base.dx +
            g.hx[j] * _scale * (1 + 0.03 * loose) +
            wob * math.cos(ph * 18.85 + time * (4.6 + ph * 3));
        final ry =
            base.dy +
            g.hy[j] * _scale * (1 + 0.03 * loose) +
            wob * math.sin(ph * 25.13 + time * (3.9 + ph * 3));
        // Its place on the turning sphere.
        final lon = _sLon[j] + _sOmega[j] * tau;
        final r = sphereR * _sOrbit[j];
        final cl = math.cos(_sLat[j]);
        final z = _view(
          r * cl * math.cos(lon),
          r * math.sin(_sLat[j]),
          r * cl * math.sin(lon),
        );
        final tx = sphereC.dx + _vx, ty = sphereC.dy + _vy;
        final f = (tk - _release[j]) / _flight;
        double x, y;
        var far = false;
        if (f <= 0) {
          x = rx;
          y = ry;
        } else if (f >= 1) {
          x = tx;
          y = ty;
          far = z < 0;
        } else {
          final e = _easeInOut(f);
          final arc = _sBulge[j] * cage * math.sin(math.pi * f);
          x = rx + (tx - rx) * e;
          y = ry + (ty - ry) * e - arc;
          far = e > 0.6 && z < 0;
        }
        if (far != back) continue;
        if (gone > 0 && ph < gone) continue;
        if (back) {
          b.add(_specBackB + (g.tone[j] * _backTones) ~/ g.tones.length, x, y);
          continue;
        }
        b.add(_specGlowB, x, y);
        final crest =
            crestY.isFinite && crestY - g.hy[j] < glintBand && ph < 0.22;
        final twinkle =
            (time * 0.23 + ph * 7.3) % 1.0 < (f > 0 && f < 1 ? 0.025 : 0.008);
        if (crest || twinkle) {
          b.add(_glintB, x, y);
          continue;
        }
        b.add(_specB + g.tone[j], x, y);
      }
    }

    // ── draw ──
    final fade = 1 - sh * 0.15;
    final pushD = 1 + 0.15 * push * flexOn;
    Color ring(int i) => profile.ringColor(i);
    for (var i = 0; i < rings; i++) {
      final d = d0 * (i == 0 ? 1.0 : 0.88) * pushD * (1 - 0.2 * shellIn);
      final col = ring(i);
      final a = (0.3 + 0.7 * shaped) * fade * shellAlpha;
      if (a <= 0.01) continue;
      final base = i * _perBand;
      const black = Color(0xFF000000), white = Color(0xFFFFFFFF);
      if (back) {
        b.draw(
          canvas,
          base,
          d * 0.82,
          Color.lerp(col, black, 0.5)!.withValues(alpha: 0.7 * a),
        );
        continue;
      }
      b.draw(canvas, base + 4, d * 3.4, col.withValues(alpha: 0.05 * a));
      b.draw(
        canvas,
        base + 1,
        d * 0.92,
        Color.lerp(col, black, 0.28)!.withValues(alpha: 0.75 * a),
      );
      b.draw(
        canvas,
        base + 2,
        d,
        Color.lerp(col, white, 0.1)!.withValues(alpha: 0.9 * a),
      );
      b.draw(
        canvas,
        base + 3,
        d,
        Color.lerp(col, white, 0.5)!.withValues(alpha: 0.95 * a),
      );
    }
    if (profile.sigil) {
      // It lets go first: on a break, and as the take closes the shell.
      final a =
          _smooth((shaped - 0.15) / 0.5) *
          (1 - _smooth(sh / 0.3)) *
          (1 - shellIn) *
          shellAlpha *
          sigilStrength;
      if (back) {
        b.draw(
          canvas,
          _sigilB,
          d0 * 3.0,
          profile.accent.withValues(alpha: 0.07 * a),
        );
        b.draw(
          canvas,
          _sigilB,
          d0 * 0.95,
          Color.lerp(
            profile.accent,
            const Color(0xFFFFFFFF),
            0.25,
          )!.withValues(alpha: 0.6 * a),
        );
      }
    }

    if (g != null && tk > 0) {
      final d = g.step * _scale * 1.28 * (1 - 0.25 * seal) * shrink;
      final warm = Color.lerp(specimenColor, _amber, 0.45)!;
      final tones = g.tones;
      if (back) {
        for (var k = 0; k < _backTones; k++) {
          final rep =
              tones[((k + 0.5) * tones.length / _backTones).floor().clamp(
                0,
                tones.length - 1,
              )];
          b.draw(
            canvas,
            _specBackB + k,
            d * 0.82,
            Color.lerp(
              rep,
              const Color(0xFF000000),
              0.42,
            )!.withValues(alpha: 1 - gone),
          );
        }
      } else {
        // Sealed, it glows from inside, warm, then lifts away.
        final light = seal * (1 - gone);
        if (light > 0.01) {
          final breathe = 0.85 + 0.15 * math.sin(time * 3.1);
          _pool(canvas, sphereC, sphereR * 2.2, warm, 0.3 * light * breathe);
        }
        b.draw(
          canvas,
          _specGlowB,
          d * 3.4,
          specimenColor.withValues(alpha: 0.07 * (1 - gone)),
        );
        for (var k = 0; k < tones.length; k++) {
          b.draw(
            canvas,
            _specB + k,
            d,
            Color.lerp(
              tones[k],
              warm,
              0.18 * seal,
            )!.withValues(alpha: 1 - gone),
          );
        }
      }
    }

    if (back) return;
    b.draw(
      canvas,
      _shedB,
      d0 * 0.95,
      Color.lerp(
        profile.accent,
        const Color(0xFFFFFFFF),
        0.4,
      )!.withValues(alpha: 0.85 * hold),
    );
    const glint = Color(0xFFFFF6E2);
    b.draw(canvas, _glintB, d0 * 2.4, glint.withValues(alpha: 0.18));
    b.draw(canvas, _glintB, d0 * 1.2, glint.withValues(alpha: 0.9));

    // A break lets out what it held: a faint wash of the device's light
    // where it tore, wide and gone fast — a pool, not a ring.
    if (sh > 0 && sh < 0.5) {
      final e = sh / 0.5;
      final at = c + Offset(_tearX, _tearY) * cage;
      _pool(
        canvas,
        at,
        cage * (0.8 + 1.2 * e),
        profile.accent,
        0.16 * math.sin(math.pi * e),
      );
    }
  }

  /// A few grains leaving the shell while it holds, the way its element
  /// moves: embers climb, droplets and shards fall, spores drift, sparks
  /// flick off, the prismatic lock's motes rise slow.
  void _shed(GrainBatch b, Offset c, double r, double time) {
    final count = profile.moteCount;
    for (var k = 0; k < count; k++) {
      final h1 = GrainGlass.h(k, 61), h2 = GrainGlass.h(k, 62);
      final period = 1.1 + 0.6 * h2;
      final q = (time / period + h1) % 1.0;
      final cycle = (time / period + h1).floor();
      // Born somewhere on the near side's rim, a new place each time round.
      final a = (GrainGlass.h(k + cycle * 31, 63)) * math.pi * 2;
      final sx = c.dx + math.cos(a) * r * 0.96;
      final sy = c.dy + math.sin(a) * r * 0.96 * 0.9;
      double dx = 0, dy = 0;
      switch (profile.mote) {
        case HarvesterMote.ember:
          dx = math.sin(q * 6 + k) * r * 0.06;
          dy = -r * 0.5 * q;
        case HarvesterMote.droplet:
          dy = r * 0.5 * q * q;
        case HarvesterMote.shard:
          dx = math.cos(a) * r * 0.08 * q;
          dy = r * 0.42 * q * q;
        case HarvesterMote.spore:
          dx = math.cos(a) * r * 0.3 * q + math.sin(q * 5 + k) * r * 0.06;
          dy = math.sin(a) * r * 0.2 * q - r * 0.08 * q;
        case HarvesterMote.spark:
          dx = math.cos(a) * r * 0.32 * q;
          dy = math.sin(a) * r * 0.32 * q;
        case HarvesterMote.prism:
          dy = -r * 0.35 * q;
      }
      // Visible through the middle of its life only.
      if (math.sin(math.pi * q) < 0.3) continue;
      b.add(_shedB, sx + dx, sy + dy);
    }
  }

  SpecimenGrains _standIn() {
    final g = SpecimenGrains.disc(specimenColor, radius: cage * 0.42);
    _seedSpecimen(g);
    return g;
  }

  final Map<(int, int), Shader> _shaders = {};

  /// A soft pool of [color] light, [alpha] at its middle.
  void _pool(Canvas canvas, Offset at, double r, Color color, double alpha) {
    if (r <= 0 || alpha <= 0.003) return;
    final shader = _shaders.putIfAbsent(
      (r.round(), color.toARGB32()),
      () => ui.Gradient.radial(
        Offset.zero,
        r.roundToDouble(),
        [color, color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
        const [0.0, 0.42, 1.0],
      ),
    );
    _p
      ..shader = shader
      // The shader carries the colour; the paint's alpha scales it.
      ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.drawCircle(Offset.zero, r, _p);
    canvas.restore();
    _p.shader = null;
  }

  /// The faint light a sphere's edge catches, brighter lower right: what
  /// makes a shell of grains read as a body rather than a scatter.
  void _rim(Canvas canvas, Offset at, double r, Color color, double alpha) {
    if (r <= 0 || alpha <= 0.003) return;
    final rr = r.roundToDouble();
    final shader = _shaders.putIfAbsent(
      (-rr.toInt() - 1, color.toARGB32()),
      () => ui.Gradient.radial(
        Offset(rr * 0.1, rr * 0.12),
        rr * 1.04,
        [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.05),
          Color.lerp(
            color,
            const Color(0xFFFFFFFF),
            0.3,
          )!.withValues(alpha: 0.16),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.72, 0.93, 1.0],
      ),
    );
    _p
      ..shader = shader
      ..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.drawCircle(Offset.zero, r * 1.05, _p);
    canvas.restore();
    _p.shader = null;
  }
}
