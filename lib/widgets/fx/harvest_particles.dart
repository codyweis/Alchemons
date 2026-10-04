import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/rendering.dart';

/// A moment of a harvest, as it happens on screen (see
/// [HarvestParticleField.beats]).
enum HarvestBeat { engage, take, shatter }

/// THE HARVEST, IN PARTICLES.
///
/// The apparatus used to be stroked arcs: concentric segmented hoops closing
/// on the specimen, with line brackets and a line-drawn hexagram — UI rings,
/// next to a fusion made of the creatures' own grains. Now each of the
/// harvester's rings is a stream of motes on its own tipped orbit, so the
/// field reads as a cage you can see round, with a near side and a far one;
/// and when it holds, the specimen is turned to grains of itself and drawn
/// down into the harvester with it. When it fails, the field blows apart and
/// the specimen is still standing.
///
/// What each device is like still comes from its [HarvesterProfile] — how
/// many rings, how they close, how they give when leaned on, how fast they
/// turn, their colour, the bound sigil — so a Crusher is still two heavy
/// jaws arriving in stages and a Drown still a continuous sheet with a wave
/// running round it.
///
/// Plain Dart and driven entirely by the beat its host passes in, so both
/// harvest renderers (the Flame field in the scene and the Flutter overlay)
/// draw the same thing.
class HarvestParticleField {
  HarvestParticleField({
    required this.profile,
    required this.cage,
    required this.specimenColor,
  }) {
    _seedField();
  }

  final HarvesterProfile profile;

  /// The radius the field settles at, from the specimen's size.
  final double cage;

  /// The specimen's own colour, which lights the stage.
  final Color specimenColor;

  /// How long a take plays once the roll has held, and a break once it has
  /// not, in seconds.
  static const double takeSeconds = 1.3;
  static const double breakSeconds = 0.9;

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
  static const Color _ember = Color(0xFFD07A4A);

  // ── the field ─────────────────────────────────────────────────────────

  late final int _motes;
  late final Uint8List _ring;
  late final Float32List _angle, _jitter, _phase, _fly;
  late final List<double> _ringTip, _ringTurn;

  // The sigil, for units that write the specimen into place.
  late final Float32List _sigilX, _sigilY;

  void _seedField() {
    final rng = math.Random(41);
    final rings = profile.ringCount;
    _ringTip = [for (var i = 0; i < rings; i++) 1.02 + 0.08 * (i % 2)];
    // Planes spread round the view axis, so the rings cross like an
    // armillary instead of nesting as targets.
    _ringTurn = [for (var i = 0; i < rings; i++) 0.35 + i * math.pi / rings];
    final angle = <double>[], jitter = <double>[], phase = <double>[];
    final fly = <double>[];
    final ring = <int>[];
    for (var i = 0; i < rings; i++) {
      final segs = profile.segsBase + i * profile.segsPerRing;
      // Enough motes that a sheet of many thin segments reads as continuous
      // and a few fat jaws as solid.
      final perSeg = (180 / segs).clamp(10, 46).round() + i * 2;
      for (var s = 0; s < segs; s++) {
        for (var k = 0; k < perSeg; k++) {
          ring.add(i);
          // Within the segment's arc (62% of its sector, as the jaws were).
          final u = (k + rng.nextDouble() * 0.6) / perSeg;
          angle.add((s + u * 0.62) * math.pi * 2 / segs);
          jitter.add((rng.nextDouble() - 0.5) * 0.08);
          phase.add(rng.nextDouble());
          fly.add(0.6 + 0.4 * ((s % 3) / 2) + 0.3 * rng.nextDouble());
        }
      }
    }
    _motes = ring.length;
    _ring = Uint8List.fromList(ring);
    _angle = Float32List.fromList(angle);
    _jitter = Float32List.fromList(jitter);
    _phase = Float32List.fromList(phase);
    _fly = Float32List.fromList(fly);

    // Two triangles, sampled into points, at unit radius.
    final sx = <double>[], sy = <double>[];
    if (profile.sigil) {
      for (final rot in [-math.pi / 2, math.pi / 2]) {
        for (var e = 0; e < 3; e++) {
          final a0 = rot + e * 2 * math.pi / 3;
          final a1 = rot + (e + 1) * 2 * math.pi / 3;
          for (var k = 0; k < 26; k++) {
            final f = k / 26;
            sx.add(math.cos(a0) * (1 - f) + math.cos(a1) * f);
            sy.add(math.sin(a0) * (1 - f) + math.sin(a1) * f);
          }
        }
      }
    }
    _sigilX = Float32List.fromList(sx);
    _sigilY = Float32List.fromList(sy);
  }

  // ── the specimen ──────────────────────────────────────────────────────

  SpecimenGrains? _specimen;
  Offset _at = Offset.zero;
  double _scale = 1;
  late Float32List _order;
  double _minY = 0, _maxY = 0;

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
    final n = grains.length;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, grains.hy[i]);
      maxY = math.max(maxY, grains.hy[i]);
    }
    _minY = n == 0 ? 0 : minY;
    _maxY = n == 0 ? 0 : maxY;
    final span = math.max(1.0, _maxY - _minY);
    final rng = math.Random(13);
    // Taken from the feet up — nearest the harvester first.
    _order = Float32List.fromList([
      for (var i = 0; i < n; i++)
        ((1 - (grains.hy[i] - _minY) / span) * 0.8 + rng.nextDouble() * 0.2),
    ]);
  }

  bool get hasSpecimen => _specimen != null;

  // The take, in fractions of [takeSeconds].
  static const double _crestFrom = 0.1, _crestTo = 0.34;
  static const double _pullFrom = 0.3, _pullSpread = 0.4, _pullDur = 0.28;
  static const double _moteFrom = 0.78;

  /// Where the take's crest is on the specimen, in its own grain units from
  /// its centre: above it the specimen is grains and the sprite is cut away.
  /// −∞ before it starts, +∞ once it has passed.
  double cutY(double take) {
    final p = (take - _crestFrom) / (_crestTo - _crestFrom);
    if (p <= 0) return double.negativeInfinity;
    if (p >= 1) return double.infinity;
    return _minY + p * (_maxY - _minY);
  }

  /// Where the harvester is: under the specimen's middle, where it is drawn
  /// down to.
  Offset get _intake => Offset(_at.dx, _at.dy + cage * 0.32);

  // ── the look ──────────────────────────────────────────────────────────

  static const int _tones = SpecimenGrains.toneCount;
  // Per ring: near, far and glow. Then the sigil, the specimen's tones, its
  // glow, glints.
  late final int _sigilB = profile.ringCount * 3;
  late final int _specB = _sigilB + 1;
  late final int _specGlowB = _specB + _tones;
  late final int _glintB = _specGlowB + 1;
  late final GrainBatch _batch = GrainBatch(_glintB + 1);

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
  static double _easeInOut(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

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
    final pull = _easeInOut(_clamp01((take - 0.2) / 0.6));
    final sh = _clamp01(shatter);
    final shE = 1 - (1 - sh) * (1 - sh) * (1 - sh);
    final intake = c + _intake;
    final rings = profile.ringCount;

    // The pool of light the specimen stands in, under it.
    if (back) {
      final lit = (0.35 + 0.65 * closing) * (1 - pull) * (1 - sh);
      if (lit > 0.01) {
        final glow = Color.lerp(specimenColor, _amber, 0.5)!;
        canvas.drawCircle(
          c,
          cage * 1.8,
          Paint()
            ..shader = RadialGradient(
              colors: [
                glow.withValues(alpha: 0.16 * lit),
                glow.withValues(alpha: 0.06 * lit),
                glow.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromCircle(center: c, radius: cage * 1.8)),
        );
      }
    }

    // The field.
    for (var m = 0; m < _motes; m++) {
      final i = _ring[m];
      final rest = cage * (1.0 + i * 0.19);
      final start = rest * (3.4 - i * 0.4);
      final spin =
          time * (i.isEven ? 1.0 : -1.0) * profile.spinRate * (0.9 + i * 0.4);
      final a = _angle[m] + spin;
      var r = start + (rest - start) * shaped;
      r += profile.radialFlex(a, strain, push, cage) * (1 - pull);
      r *= 1 + _jitter[m];
      // Thrown outward when it breaks, each shard its own distance.
      r *= 1 + 1.6 * shE;
      r += shE * cage * profile.shatterSpread * _fly[m];
      // A circle in the ring's plane, tipped, then turned round the view.
      final tip = _ringTip[i], turn = _ringTurn[i];
      final x0 = r * math.cos(a), y0 = r * math.sin(a);
      final y1 = y0 * math.cos(tip);
      final z = y0 * math.sin(tip);
      final ct = math.cos(turn), st = math.sin(turn);
      var x = c.dx + x0 * ct - y1 * st;
      var y = c.dy + x0 * st + y1 * ct;
      if (pull > 0) {
        // Falls in on the harvester, turning as it goes.
        final sw = pull * 2.4 * (i.isEven ? 1 : -1);
        final dx = x - intake.dx, dy = y - intake.dy;
        final cs = math.cos(sw), sn = math.sin(sw);
        x = intake.dx + (dx * cs - dy * sn) * (1 - pull);
        y = intake.dy + (dx * sn + dy * cs) * (1 - pull);
      }
      if ((z < 0) != back) continue;
      b.add(i * 3 + 2, x, y);
      // It bites with a glint all round.
      final bite = lock > 0.15 && lock < 0.85 && _phase[m] < 0.35;
      final twinkle = (time * 0.4 + _phase[m] * 7.3) % 1.0 < 0.01;
      if (!back && (bite || twinkle)) {
        b.add(_glintB, x, y);
        continue;
      }
      b.add(i * 3 + (back ? 1 : 0), x, y);
    }

    // The bound sigil, written in grains.
    if (!back && profile.sigil && shaped > 0.2 && sh < 0.95) {
      final r = cage * 1.05 * (1 + 1.6 * shE);
      final spin = -time * profile.spinRate * 0.5;
      final cs = math.cos(spin), sn = math.sin(spin);
      for (var k = 0; k < _sigilX.length; k++) {
        var x = c.dx + (_sigilX[k] * cs - _sigilY[k] * sn) * r;
        var y = c.dy + (_sigilX[k] * sn + _sigilY[k] * cs) * r;
        if (pull > 0) {
          x = intake.dx + (x - intake.dx) * (1 - pull);
          y = intake.dy + (y - intake.dy) * (1 - pull);
        }
        b.add(_sigilB, x, y);
      }
    }

    // The specimen, taken.
    final g = _specimen;
    if (!back && g != null && take > _crestFrom) {
      final crestY = cutY(take);
      final base = c + _at;
      final glintBand = (_maxY - _minY) * 0.04;
      for (var j = 0; j < g.length; j++) {
        final hy = g.hy[j];
        if (crestY != double.infinity && hy > crestY) continue;
        final hx = g.hx[j] * _scale;
        final rx = base.dx + hx, ry = base.dy + hy * _scale;
        final f = _clamp01(
          (take - _pullFrom - _pullSpread * _order[j]) / _pullDur,
        );
        double x = rx, y = ry;
        if (f > 0) {
          final e = _easeInOut(f);
          final sw = e * 2.2;
          final dx = rx - intake.dx, dy = ry - intake.dy;
          final cs = math.cos(sw), sn = math.sin(sw);
          x = intake.dx + (dx * cs - dy * sn) * (1 - e);
          y = intake.dy + (dx * sn + dy * cs) * (1 - e);
          if (f >= 1) continue;
        }
        b.add(_specGlowB, x, y);
        if (crestY.isFinite &&
            crestY - hy < glintBand &&
            _phase[j % _motes] < 0.4) {
          b.add(_glintB, x, y);
          continue;
        }
        b.add(_specB + g.tone[j], x, y);
      }
    }

    // Draw: glows, the far rings or the near, the sigil, the specimen,
    // glints.
    final fade = (1 - sh) * (1 - 0.3 * pull);
    final moteD = 1.2 + 0.45 * profile.strokeBase + 0.9 * push;
    for (var i = 0; i < rings; i++) {
      final col = profile.ringColor(i);
      final alpha = (0.25 + 0.7 * shaped) * fade;
      if (alpha <= 0.01) continue;
      final d = moteD * (i == 0 ? 1 : 0.8);
      b.draw(canvas, i * 3 + 2, d * 3.2, col.withValues(alpha: 0.08 * alpha));
      b.draw(
        canvas,
        i * 3 + (back ? 1 : 0),
        back ? d * 0.85 : d,
        back
            ? Color.lerp(
                col,
                const Color(0xFF000000),
                0.45,
              )!.withValues(alpha: alpha)
            : Color.lerp(
                col,
                const Color(0xFFFFFFFF),
                0.15,
              )!.withValues(alpha: alpha),
      );
    }
    if (back) return;
    b.draw(
      canvas,
      _sigilB,
      1.8,
      profile.accent.withValues(alpha: 0.75 * shaped * (1 - sh)),
    );
    if (g != null) {
      final d = g.step * _scale * 1.28;
      b.draw(
        canvas,
        _specGlowB,
        d * 3.4,
        specimenColor.withValues(alpha: 0.07),
      );
      for (var k = 0; k < g.tones.length; k++) {
        b.draw(canvas, _specB + k, d, g.tones[k]);
      }
    }
    final glint = sh > 0 ? _ember : const Color(0xFFFFFBEA);
    b.draw(
      canvas,
      _glintB,
      moteD * 2.6,
      glint.withValues(alpha: 0.22 * (1 - sh)),
    );
    b.draw(
      canvas,
      _glintB,
      moteD * 1.4,
      glint.withValues(alpha: 0.95 * (1 - sh)),
    );

    // The harvester taking it all in: a bright mote that swells and goes.
    final mote = _clamp01((take - _moteFrom) / (1 - _moteFrom));
    final gather = _clamp01((take - 0.4) / 0.4);
    final heat = mote > 0 ? 1 - mote : gather;
    if (heat > 0.01) {
      final r = cage * (0.12 + 0.3 * heat);
      canvas.drawCircle(
        intake,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: 0.8 * heat),
              _amber.withValues(alpha: 0.45 * heat),
              _amber.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.35, 1.0],
          ).createShader(Rect.fromCircle(center: intake, radius: r)),
      );
    }
    // A break throws a flash of heat: wide, faint, and gone fast — a pool,
    // not a ring.
    if (sh > 0 && sh < 0.45) {
      final e = sh / 0.45;
      final r = cage * (1.2 + 1.4 * e);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _ember.withValues(alpha: 0.2 * (1 - e)),
              _ember.withValues(alpha: 0.1 * (1 - e)),
              _ember.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }
}
