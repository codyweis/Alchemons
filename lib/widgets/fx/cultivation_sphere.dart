import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// A CULTIVATION IN ITS CHAMBER, as the fusion left it: the two parents'
// grains, still winding through each other in one turning sphere. It turns
// faster the nearer it is to extraction, burns gold once it is ready, and a
// long press lets a finger stir it.

/// What a cultivation is made of: its two parents, read from their
/// portraits in their own colouring — or, for one with no parents on record
/// (a vial, a wild founder), shades of its elements.
class CultivationGrains {
  CultivationGrains._();

  static final Map<String, Future<SpecimenGrains?>> _cache = {};

  /// Tones per parent. Far fewer than a merge needs: the grains are small
  /// and a chamber is one of several on screen, each a draw per tone.
  static const int tones = 12;

  static Future<List<SpecimenGrains>> forPayload(
    Map<String, dynamic> payload,
    List<String> types,
  ) async {
    final parentage = payload['parentage'];
    final read = <SpecimenGrains?>[];
    if (parentage is Map<String, dynamic>) {
      for (final key in ['parentA', 'parentB']) {
        final raw = parentage[key];
        if (raw is! Map<String, dynamic>) {
          read.add(null);
          continue;
        }
        try {
          final p = ParentSnapshot.fromJson(raw);
          read.add(await _portrait(p.image, p.genetics, p.isPrismaticSkin));
        } catch (_) {
          read.add(null);
        }
      }
    }
    Color colorOf(int i) => types.isEmpty
        ? const Color(0xFFE4C16A)
        : cultivationTypeColor(types[i.clamp(0, types.length - 1)]);
    return [
      for (var i = 0; i < 2; i++)
        (i < read.length ? read[i] : null) ??
            SpecimenGrains.disc(colorOf(i), radius: 40),
    ];
  }

  static Future<SpecimenGrains?> _portrait(
    String image,
    Genetics? genetics,
    bool prismatic,
  ) {
    final key = '$image|${genetics?.toJson()}|$prismatic';
    return _cache.putIfAbsent(key, () async {
      final path = image.startsWith('assets/') ? image : 'assets/images/$image';
      final data = await rootBundle.load(path);
      // Small: a palette and a body's proportions are all it is read for.
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 96,
      );
      final src = (await codec.getNextFrame()).image;
      final paint = Paint()..filterQuality = FilterQuality.medium;
      final filter = _colouring(genetics, prismatic);
      if (filter != null) paint.colorFilter = ColorFilter.matrix(filter);
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImage(src, Offset.zero, paint);
      final img = rec.endRecording().toImageSync(src.width, src.height);
      try {
        final bytes = await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (bytes == null) return null;
        final g = SpecimenGrains.fromRgba(
          bytes.buffer.asUint8List(),
          img.width,
          img.height,
          pixelRatio: 1,
          maxGrains: 900,
          tones: tones,
        );
        return g.length < 30 ? null : g;
      } finally {
        img.dispose();
        src.dispose();
      }
    });
  }

  /// The genetics colouring a sprite is drawn with, as one matrix.
  static List<double>? _colouring(Genetics? g, bool prismatic) {
    final bri = briFromGenes(g), sat = satFromGenes(g), hue = hueFromGenes(g);
    if (bri == 1.45 && !prismatic) return albinoMatrix(bri);
    List<double>? m;
    if (sat != 1.0 || bri != 1.0) m = brightnessSaturationMatrix(bri, sat);
    final h = ((hue % 360) + 360) % 360;
    if (h != 0) {
      final rot = hueRotationMatrix(h);
      m = m == null ? rot : _compose(rot, m);
    }
    return m;
  }

  /// [a] after [b], for 4×5 colour matrices.
  static List<double> _compose(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[r * 5 + k] * b[k * 5 + c];
        }
        out[r * 5 + c] = sum;
      }
      var t = a[r * 5 + 4];
      for (var k = 0; k < 4; k++) {
        t += a[r * 5 + k] * b[k * 5 + 4];
      }
      out[r * 5 + 4] = t;
    }
    return out;
  }
}

/// An element's colour, whichever way its name is cased ('fire', 'Fire').
Color cultivationTypeColor(String type) {
  final t = type.trim();
  if (t.isEmpty) return const Color(0xFFE4C16A);
  return BreedConstants.getTypeColor(
    t[0].toUpperCase() + t.substring(1).toLowerCase(),
  );
}

/// The grains of a cultivation, and the finger parting them.
class CultivationSphereField {
  CultivationSphereField(
    List<SpecimenGrains> parents, {
    int grains = 640,
    FusionSigil sigil = FusionSigil.octagram,
    String? element,
  }) : assert(parents.length == 2) {
    final rng = math.Random(23);
    final per = grains ~/ 2;
    length = per * 2;
    _side = Uint8List(length);
    _tone = Uint8List(length);
    _lat = Float32List(length);
    _lon0 = Float32List(length);
    _r = Float32List(length);
    _omega = Float32List(length);
    _phase = Float32List(length);
    _dx = Float32List(length);
    _dy = Float32List(length);
    _vx = Float32List(length);
    _vy = Float32List(length);
    _heat = Float32List(length);
    _x = Float32List(length);
    _y = Float32List(length);
    _z = Float32List(length);
    _palettes = [for (final p in parents) p.tones];
    var i = 0;
    for (var s = 0; s < 2; s++) {
      final g = parents[s];
      for (var j = 0; j < per; j++, i++) {
        _side[i] = s;
        // Evenly through its grains, so its colours come in the proportions
        // it has them.
        _tone[i] = g.length == 0 ? 0 : g.tone[(j * g.length) ~/ per];
        _lat[i] = math.asin(rng.nextDouble() * 2 - 1);
        _lon0[i] = rng.nextDouble() * math.pi * 2;
        // Mostly towards the shell, so it reads as a sphere, not a disc.
        _r[i] = 0.5 + 0.5 * math.pow(rng.nextDouble(), 0.45);
        // The two turn opposite ways, and each at rates of its own, so they
        // wind through each other — the merge, still going.
        _omega[i] = (s == 0 ? -1.0 : 1.0) * (0.7 + 0.6 * rng.nextDouble());
        _phase[i] = rng.nextDouble();
      }
    }
    _setSigil(sigil, element);
  }

  late final int length;
  late final Uint8List _side, _tone;
  late final Float32List _lat, _lon0, _r, _omega, _phase;
  // The finger: how far each grain has been pushed off its place, how fast
  // it is moving, and how hot it has been made.
  late final Float32List _dx, _dy, _vx, _vy, _heat;
  late final Float32List _x, _y, _z;
  late final List<List<Color>> _palettes;

  /// Where a finger is on it, from its centre, in px.
  Offset? pointer;

  bool _stirred = false;

  /// Whether anything is still off its place.
  bool get stirred => _stirred || pointer != null;

  // ── the ready sigil ───────────────────────────────────────────────────

  /// A third of the grains draw the cultivation's sigil once it is ready
  /// — the same sigil the fusion's reveal ended on. The ringed octagram has
  /// about twice the line the old star had, and at a fifth it was too sparse
  /// to read.
  static const double _sigilShare = 0.34;
  late List<(List<Offset>, double)> _lines;
  late Float32List _lineLen;
  double _sigilLen = 1;

  void _setSigil(FusionSigil sigil, String? element) {
    _lines = fusionSigilLines(sigil, element, elementRadius: 0.78);
    double len(List<Offset> pts) {
      var l = 0.0;
      for (var k = 1; k < pts.length; k++) {
        l += (pts[k] - pts[k - 1]).distance;
      }
      return l;
    }

    _lineLen = Float32List.fromList([for (final (p, _) in _lines) len(p)]);
    _sigilLen = _lineLen.fold(0.0, (a, b) => a + b);
  }

  Offset _onSigil(double along) {
    var d = along * _sigilLen;
    for (var l = 0; l < _lines.length; l++) {
      final (pts, _) = _lines[l];
      if (d > _lineLen[l] && l < _lines.length - 1) {
        d -= _lineLen[l];
        continue;
      }
      for (var k = 1; k < pts.length; k++) {
        final seg = (pts[k] - pts[k - 1]).distance;
        if (d <= seg || k == pts.length - 1) {
          return Offset.lerp(
            pts[k - 1],
            pts[k],
            seg == 0 ? 0 : (d / seg).clamp(0.0, 1.0),
          )!;
        }
        d -= seg;
      }
    }
    return Offset.zero;
  }

  // ── the motion ────────────────────────────────────────────────────────

  static const double _tip = 0.32;

  void _layout(double radius, double spin, double ready, double time) {
    final cosT = math.cos(_tip), sinT = math.sin(_tip);
    // The sigil turns slowly in the sphere's middle.
    final turn = time * 0.12;
    final ct = math.cos(turn), st = math.sin(turn);
    for (var i = 0; i < length; i++) {
      final lon = _lon0[i] + _omega[i] * spin;
      final cl = math.cos(_lat[i]);
      final r = _r[i] * radius;
      final px = r * cl * math.cos(lon);
      final py = r * math.sin(_lat[i]);
      final pz = r * cl * math.sin(lon);
      var x = px, y = py * cosT + pz * sinT;
      var z = pz * cosT - py * sinT;
      if (ready > 0 && _phase[i] < _sigilShare) {
        // Drawn in along its lines as it readies.
        final along = _phase[i] / _sigilShare;
        final e = _ease(((ready - along * 0.35) / 0.65).clamp(0.0, 1.0));
        if (e > 0) {
          final p = _onSigil(along);
          final sx = (p.dx * ct - p.dy * st) * radius * 0.82;
          final sy = (p.dx * st + p.dy * ct) * radius * 0.82;
          x += (sx - x) * e;
          y += (sy - y) * e;
          z += (1 - z) * e;
        }
      }
      _x[i] = x;
      _y[i] = y;
      _z[i] = z;
    }
  }

  static double _ease(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  static const double _k = 190, _damp = 19;

  /// One step of the finger: grains under it are pushed out to the edge of
  /// a hole round it, and flow back into place when it lifts.
  void step(double dt, double radius, double spin, double ready, double time) {
    if (!stirred) return;
    final p = pointer;
    final hole = radius * 0.34;
    final cool = math.exp(-dt * 3.0);
    var moving = false;
    _layout(radius, spin, ready, time);
    for (var i = 0; i < length; i++) {
      var tx = 0.0, ty = 0.0;
      if (p != null) {
        final ex = _x[i] - p.dx, ey = _y[i] - p.dy;
        final d2 = ex * ex + ey * ey;
        if (d2 < hole * hole) {
          // Out to the rim, crowding there, and turned a little round the
          // finger as it goes — so it reads as parting, not vanishing.
          final d = math.sqrt(d2) + 0.001;
          final ux = ex / d, uy = ey / d;
          final out = hole - d;
          final rim = out * (0.9 + 0.25 * _phase[i]);
          tx = ux * rim - uy * out * 0.25;
          ty = uy * rim + ux * out * 0.25;
          final h = (d / hole) * 0.9;
          if (h > _heat[i] && _phase[i] > 0.7) _heat[i] = h;
        }
      }
      final ax = (tx - _dx[i]) * _k - _vx[i] * _damp;
      final ay = (ty - _dy[i]) * _k - _vy[i] * _damp;
      _vx[i] += ax * dt;
      _vy[i] += ay * dt;
      _dx[i] += _vx[i] * dt;
      _dy[i] += _vy[i] * dt;
      _heat[i] *= cool;
      if (!moving &&
          (_dx[i].abs() + _dy[i].abs() > 0.05 ||
              _vx[i].abs() + _vy[i].abs() > 0.1 ||
              _heat[i] > 0.03)) {
        moving = true;
      }
    }
    _stirred = moving;
    if (!moving && p == null) {
      _dx.fillRange(0, length, 0);
      _dy.fillRange(0, length, 0);
      _vx.fillRange(0, length, 0);
      _vy.fillRange(0, length, 0);
    }
  }

  // ── the look ──────────────────────────────────────────────────────────

  static const int _tones = CultivationGrains.tones;
  static const int _farTones = 6;
  static const int _farB = 2 * _tones;
  static const int _glowB = _farB + 2 * _farTones;
  static const int _sigilB = _glowB + 2;
  static const int _glintB = _sigilB + 1;
  final GrainBatch _batch = GrainBatch(_glintB + 1);

  /// The ready heartbeat: a sharp swell every few seconds, easing off.
  static double heartbeat(double time) {
    final beat = (time % 2.6) / 2.6;
    return math.exp(-beat * 9);
  }

  /// Paints it round [c] at [radius], turned to [spin]. [ready] is 0..1 how
  /// far into its finished state it is: the sigil drawn, the gold, and the
  /// heartbeat. [time] runs its twinkle.
  void paint(
    Canvas canvas,
    Offset c,
    double radius, {
    required double spin,
    required double time,
    required List<Color> colors,
    double ready = 0,
    double twinkle = 1,
    bool darkBackdrop = true,
    double opacity = 1,
    double unwind = 0,
    List<Offset>? unwindTo,
    double scatter = 0,
    Offset Function(int side, int index)? unwindTarget,
  }) {
    if (opacity <= 0) return;
    final beat = heartbeat(time) * ready;
    final r = radius * (1 + 0.04 * beat);
    _layout(r, spin, ready, time);
    if (unwind > 0) {
      // Coming undone, each grain on its own clock. With [unwindTo], each
      // parent's grains are drawn off to their own place (a cloud [scatter]
      // wide round it), bowed as they go; without, they spiral out and away
      // from the middle, the two parents turning opposite ways.
      for (var i = 0; i < length; i++) {
        final e = _ease(((unwind - _phase[i] * 0.45) / 0.55).clamp(0.0, 1.0));
        if (e <= 0) continue;
        final x = _x[i], y = _y[i];
        final aim = unwindTarget;
        if (aim != null) {
          // Each grain to a place of its own — the root of one of its
          // parent's strands — bowed as it goes, and landing exactly there.
          final t = aim(_side[i], i);
          final dx = t.dx - x, dy = t.dy - y;
          final bow = math.sin(math.pi * e) * 0.3 * (_side[i] == 0 ? 1 : -1);
          _x[i] = x + dx * e - dy * bow;
          _y[i] = y + dy * e + dx * bow;
          continue;
        }
        final to = unwindTo;
        if (to != null) {
          final t = to[_side[i]];
          // A round cloud, thickest in the middle — the spread of the motes
          // it feeds. (Picking x and y apart made each one a square.)
          final ja = _phase[i] * 6283.19;
          final jr = math.sqrt((_phase[i] * 7919.3) % 1.0) * scatter;
          final tx = t.dx + math.cos(ja) * jr, ty = t.dy + math.sin(ja) * jr;
          final dx = tx - x, dy = ty - y;
          final bow = math.sin(math.pi * e) * 0.35 * (_side[i] == 0 ? 1 : -1);
          _x[i] = x + dx * e - dy * bow;
          _y[i] = y + dy * e + dx * bow;
          continue;
        }
        final k = 1 + 2.6 * e;
        final a = e * 1.6 * (_side[i] == 0 ? -1 : 1);
        final cs = math.cos(a), sn = math.sin(a);
        _x[i] = (x * cs - y * sn) * k;
        _y[i] = (x * sn + y * cs) * k;
      }
    }
    Color o(Color c) => opacity >= 1 ? c : c.withValues(alpha: c.a * opacity);
    final b = _batch..clear();
    // The heartbeat sends a sparse crest of glints out through it, which
    // spends itself early in the beat.
    final cycle = (time % 2.6) / 2.6;
    final crest = cycle / 0.45 * 1.1 * r;
    final band = r * 0.06;
    final crestOn = ready > 0.5 && cycle < 0.45;
    for (var i = 0; i < length; i++) {
      final x = c.dx + _x[i] + _dx[i], y = c.dy + _y[i] + _dy[i];
      final s = _side[i];
      final sigil = ready > 0.05 && _phase[i] < _sigilShare;
      if (sigil) {
        b.add(_sigilB, x, y);
        continue;
      }
      final far = _z[i] < 0;
      b.add(_glowB + s, x, y);
      var glint = (time * 0.23 + _phase[i] * 7.3) % 1.0 < 0.008 * twinkle;
      if (!glint && crestOn && _phase[i] > 0.86) {
        final d = math.sqrt(_x[i] * _x[i] + _y[i] * _y[i]);
        glint = (d - crest).abs() < band;
      }
      if (!far && (glint || _heat[i] > 0.5)) {
        b.add(_glintB, x, y);
        continue;
      }
      final n = _palettes[s].length;
      b.add(
        far
            ? _farB + s * _farTones + (_tone[i] * _farTones) ~/ math.max(1, n)
            : s * _tones + _tone[i],
        x,
        y,
      );
    }

    const gold = Color(0xFFFFD27A);
    // Its own light, and gold once it is ready, swelling on each beat.
    final pool = Color.lerp(
      Color.lerp(colors[0], colors[1], 0.5)!,
      gold,
      ready,
    )!;
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            o(
              pool.withValues(
                alpha: (darkBackdrop ? 0.16 : 0.1) + 0.12 * ready + 0.12 * beat,
              ),
            ),
            pool.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.25)),
    );

    final d = math.max(1.3, radius * 0.034);
    for (var s = 0; s < 2; s++) {
      b.draw(
        canvas,
        _glowB + s,
        d * 3.2,
        o(
          Color.lerp(
            colors[s],
            gold,
            ready * 0.5,
          )!.withValues(alpha: darkBackdrop ? 0.06 : 0.035),
        ),
      );
    }
    for (var s = 0; s < 2; s++) {
      final tones = _palettes[s];
      for (var k = 0; k < _farTones; k++) {
        final rep = tones.isEmpty
            ? colors[s]
            : tones[((k + 0.5) * tones.length / _farTones).floor().clamp(
                0,
                tones.length - 1,
              )];
        b.draw(
          canvas,
          _farB + s * _farTones + k,
          d * 0.8,
          o(Color.lerp(rep, const Color(0xFF000000), 0.45)!),
        );
      }
    }
    for (var s = 0; s < 2; s++) {
      final tones = _palettes[s];
      for (var k = 0; k < tones.length; k++) {
        b.draw(
          canvas,
          s * _tones + k,
          d,
          o(Color.lerp(tones[k], gold, ready * 0.15)!),
        );
      }
    }
    // The sigil: fine and faint, a thing seen in the grains rather than
    // drawn over them, brightening a little on each beat.
    const sigilCol = Color(0xFFFFE9B8);
    b.draw(
      canvas,
      _sigilB,
      d * 1.9,
      o(gold.withValues(alpha: 0.05 + 0.06 * beat)),
    );
    b.draw(
      canvas,
      _sigilB,
      d * (0.75 + 0.15 * beat),
      o(sigilCol.withValues(alpha: 0.55 + 0.25 * beat)),
    );
    const glint = Color(0xFFFFFBEA);
    b.draw(canvas, _glintB, d * 2.4, o(glint.withValues(alpha: 0.22)));
    b.draw(canvas, _glintB, d * 1.3, o(glint.withValues(alpha: 0.95)));
  }
}

/// A cultivation's sphere carried from the screen it was on into the next —
/// the extraction dialog's into the hatching ceremony — so what you were
/// looking at is what the hatch is made of, with no cut between.
///
/// The same grains, turned to where they were, at the place on screen they
/// were. Whoever is showing it advances it ([advance]); there is only ever
/// one in flight ([stage] / [take]).
class CultivationHandoff {
  CultivationHandoff._({
    required this.field,
    required this.centre,
    required this.radius,
    required this.colors,
    required this.spin,
    required this.time,
    required this.ready,
    this.rate = CultivationSphere.readySpin,
  });

  final CultivationSphereField field;

  /// How fast it was turning, in radians a second.
  final double rate;

  /// Where it stood, in global coordinates, and how big.
  final Offset centre;
  final double radius;
  final List<Color> colors;
  double spin, time, ready;

  /// Set once the ceremony is carrying it, so the curtain under it stops
  /// advancing it too.
  bool carried = false;

  static CultivationHandoff? _staged;

  /// Leaves [handoff] for the next screen to pick up.
  static void stage(CultivationHandoff? handoff) => _staged = handoff;

  /// The one waiting, without taking it.
  static CultivationHandoff? get staged => _staged;

  /// Picks it up: the next caller gets nothing.
  static CultivationHandoff? take() {
    final h = _staged;
    _staged = null;
    return h;
  }

  /// Moves it on by [dt] seconds, turning at [rate].
  void advance(double dt, double rate) {
    time += dt;
    spin += dt * rate;
  }

  void paint(
    Canvas canvas, {
    required Offset at,
    required double radius,
    double? ready,
    double opacity = 1,
    double unwind = 0,
    List<Offset>? unwindTo,
    double scatter = 0,
    Offset Function(int side, int index)? unwindTarget,
  }) => field.paint(
    canvas,
    at,
    radius,
    spin: spin,
    time: time,
    colors: colors,
    ready: ready ?? this.ready,
    opacity: opacity,
    unwind: unwind,
    unwindTo: unwindTo,
    scatter: scatter,
    unwindTarget: unwindTarget,
  );
}

/// A chamber's sphere carried up into the chamber's details as they open
/// over it — as an extraction carries it into the hatch. The same grains,
/// turning on from where they were, travel from the chamber to the stage,
/// rather than the stage fading in on a second sphere.
///
/// It is drawn over everything while it travels, since the dialog it is
/// going to is still fading in. Once there, the stage's own sphere (the same
/// field, on the same clock) takes over beneath it and it fades off.
class CultivationFlight {
  CultivationFlight._(this.handoff);

  /// The sphere shown by the widget under [key], ready to fly — null if it
  /// is not showing one.
  static CultivationFlight? from(GlobalKey key) {
    final h = CultivationSphere.handoffFrom(key);
    return h == null ? null : CultivationFlight._(h);
  }

  final CultivationHandoff handoff;

  /// Seconds on the way, then seconds handing over to the stage.
  static const double travel = 0.7, settle = 0.2;

  _CultivationSphereState? _to;
  OverlayEntry? _entry;

  /// The stage has it: its clock, and its own sphere showing.
  bool _landed = false;
  bool _over = false;

  /// Redraws it — to nothing, once it is over.
  VoidCallback? _repaint;

  /// Lifts it over whatever was just opened above its chamber. Call it once
  /// that is pushed, so it goes on top.
  void lift(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || _over || _entry != null) {
      _end();
      return;
    }
    overlay.insert(_entry = OverlayEntry(builder: (_) => _Flight(this)));
  }

  void _land() {
    final to = _to;
    if (to == null || _landed) return;
    _landed = true;
    to
      .._spin = handoff.spin
      .._time = handoff.time
      .._ready = handoff.ready
      .._away = false;
  }

  void _end() {
    if (_over) return;
    _over = true;
    _land();
    final e = _entry;
    _entry = null;
    e?.remove();
    // Its entry goes on the next frame; this one must not draw it.
    _repaint?.call();
  }
}

class _Flight extends StatefulWidget {
  const _Flight(this.flight);

  final CultivationFlight flight;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    widget.flight._repaint = () => _frame.value++;
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _t += dt;
    final f = widget.flight;
    if (!f._landed) f.handoff.advance(dt, f.handoff.rate);
    if (_t >= CultivationFlight.travel) f._land();
    // Done — or nothing came up to take it.
    if (_t >= CultivationFlight.travel + CultivationFlight.settle ||
        (f._to == null && _t > 0.3)) {
      f._end();
      return;
    }
    _frame.value++;
  }

  @override
  void dispose() {
    widget.flight._repaint = null;
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _FlightPainter(this, repaint: _frame),
    ),
  );
}

class _FlightPainter extends CustomPainter {
  _FlightPainter(this.state, {super.repaint});

  final _FlightState state;

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = state.widget.flight;
    if (f._over) return;
    final h = f.handoff;
    final to = f._to;
    final there = to?._globalCircle();
    final move = _smooth(state._t / CultivationFlight.travel);
    var at = h.centre, radius = h.radius;
    if (there != null) {
      at = Offset.lerp(h.centre, there.$1, move)!;
      radius = h.radius + (there.$2 - h.radius) * move;
    }
    final box = state.context.findRenderObject();
    if (box is RenderBox && box.attached) at = box.globalToLocal(at);
    // Once landed it is the stage's sphere it is drawn over, so it keeps the
    // stage's time and fades off it.
    final landed = f._landed && to != null;
    h.field.paint(
      canvas,
      at,
      radius,
      spin: landed ? to._spin : h.spin,
      time: landed ? to._time : h.time,
      ready: landed ? to._ready : h.ready,
      colors: h.colors,
      opacity:
          1 -
          _smooth(
            (state._t - CultivationFlight.travel) / CultivationFlight.settle,
          ),
    );
  }

  @override
  bool shouldRepaint(_FlightPainter old) => old.state != state;
}

/// A cultivation as a turning sphere of its parents' grains.
///
/// [progress] (0..1 to extraction) sets how fast it turns; [isReady] settles
/// it: the turning slows to a drift, its sigil draws itself in and it beats
/// gold. When [interactive], a long press and a drag part it round the finger.
class CultivationSphere extends StatefulWidget {
  const CultivationSphere({
    super.key,
    required this.payload,
    required this.types,
    this.progress,
    this.isReady = false,
    this.grains = 640,
    this.darkBackdrop = true,
    this.interactive = true,
    this.spinScale = 1,
    this.twinkle = 1,
    this.radiusFactor = 0.36,
    this.pureElement,
    this.arrival,
  });

  final Map<String, dynamic> payload;

  /// The cultivation's element types, for its light and for a cultivation
  /// with no parents on record.
  final List<String> types;
  final double? progress;
  final bool isReady;
  final int grains;
  final bool darkBackdrop;
  final bool interactive;

  /// Scales how fast it turns (a vial's rarity).
  final double spinScale;

  /// Scales how often it twinkles.
  final double twinkle;

  /// The sphere's radius, as a share of the box's shorter side.
  final double radiusFactor;

  /// An elementally pure cultivation's element: its sigil is that element's.
  final String? pureElement;

  /// The sphere it was before it came here (a chamber's, flown up into its
  /// details): it takes up those grains, and shows once they have arrived.
  final CultivationFlight? arrival;

  /// How fast it turns, in radians a second, at [progress].
  static double spinRate(double? progress) {
    final p = (progress ?? 0).clamp(0.0, 1.0);
    // Calm for most of the wait; only really going near the end, which is
    // what makes an almost-done chamber read as almost done.
    return 0.25 + 2.6 * p * p;
  }

  /// Ready, it has done its turning: a drift.
  static const double readySpin = 0.3;

  /// The sphere shown by the widget under [key], ready to carry onward —
  /// null if it is not showing one yet.
  static CultivationHandoff? handoffFrom(GlobalKey key) {
    final state = key.currentState;
    if (state is! _CultivationSphereState) return null;
    final field = state._field;
    final at = state._globalCircle();
    if (field == null || at == null) return null;
    return CultivationHandoff._(
      field: field,
      centre: at.$1,
      radius: at.$2,
      colors: state._colors,
      spin: state._spin,
      time: state._time,
      ready: state._ready,
      rate: state._rate,
    );
  }

  @override
  State<CultivationSphere> createState() => _CultivationSphereState();
}

class _CultivationSphereState extends State<CultivationSphere>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  CultivationSphereField? _field;
  Duration _last = Duration.zero;
  double _spin = 0, _time = 0, _ready = 0, _radius = 60, _rate = 0;
  List<Color> _colors = const [Color(0xFFE4C16A), Color(0xFFE4C16A)];

  /// Still on its way here (see [CultivationSphere.arrival]): not drawn.
  bool _away = false;

  @override
  void initState() {
    super.initState();
    _rate = _targetRate;
    _ticker = createTicker(_tick)..start();
    final arrival = widget.arrival;
    if (arrival != null && !arrival._over) {
      final h = arrival.handoff;
      _field = h.field;
      _spin = h.spin;
      _time = h.time;
      _ready = h.ready;
      _away = true;
      arrival._to = this;
    } else {
      _load();
    }
  }

  /// Where it stands on screen, and how big, in global coordinates.
  (Offset, double)? _globalCircle() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    final scale =
        (box.localToGlobal(Offset(box.size.width, 0)) - origin).dx /
        math.max(1.0, box.size.width);
    return (box.localToGlobal(box.size.center(Offset.zero)), _radius * scale);
  }

  double get _targetRate =>
      (widget.isReady
          ? CultivationSphere.readySpin
          : CultivationSphere.spinRate(widget.progress)) *
      widget.spinScale;

  Future<void> _load() async {
    final parents = await CultivationGrains.forPayload(
      widget.payload,
      widget.types,
    );
    if (!mounted) return;
    final pure = widget.pureElement;
    setState(
      () => _field = CultivationSphereField(
        parents,
        grains: widget.grains,
        sigil: pure == null ? FusionSigil.octagram : FusionSigil.element,
        element: pure,
      ),
    );
  }

  @override
  void didUpdateWidget(CultivationSphere old) {
    super.didUpdateWidget(old);
    if (old.grains != widget.grains ||
        old.pureElement != widget.pureElement ||
        old.payload.toString() != widget.payload.toString()) {
      _load();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _time += dt;
    // Eased onto its rate, so a cultivation finishing slows into its drift
    // rather than stopping dead.
    _rate += (_targetRate - _rate) * math.min(1.0, dt * 1.5);
    _spin += dt * _rate;
    final target = widget.isReady ? 1.0 : 0.0;
    _ready += (target - _ready) * math.min(1.0, dt * 1.2);
    if ((target - _ready).abs() < 0.001) _ready = target;
    _field?.step(dt, _radius, _spin, _ready, _time);
    _frame.value++;
  }

  /// Gone from the stage it was flying to — closed before it got there —
  /// so the flight ends with it.
  void _leave() {
    final arrival = widget.arrival;
    if (arrival != null && arrival._to == this) {
      arrival._to = null;
      arrival._end();
    }
  }

  @override
  void deactivate() {
    _leave();
    super.deactivate();
  }

  @override
  void dispose() {
    _leave();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Offset _local(Offset p, Size size) =>
      p - Offset(size.width / 2, size.height / 2);

  @override
  Widget build(BuildContext context) {
    final field = _field;
    final colors = _colors = [
      for (var i = 0; i < 2; i++)
        widget.types.isEmpty
            ? const Color(0xFFE4C16A)
            : cultivationTypeColor(
                widget.types[i.clamp(0, widget.types.length - 1)],
              ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        _radius = math.min(size.width, size.height) * widget.radiusFactor;
        final paint = CustomPaint(
          size: size,
          painter: field == null
              ? null
              : _SpherePainter(
                  field,
                  () => (_spin, _time, _ready, _radius, _away),
                  colors,
                  widget.darkBackdrop,
                  widget.twinkle,
                  repaint: _frame,
                ),
        );
        if (!widget.interactive) return paint;
        return GestureDetector(
          // A tap still does what it did; only a held finger parts it.
          onLongPressStart: (d) {
            HapticFeedback.selectionClick();
            field?.pointer = _local(d.localPosition, size);
          },
          onLongPressMoveUpdate: (d) =>
              field?.pointer = _local(d.localPosition, size),
          onLongPressEnd: (_) => field?.pointer = null,
          onLongPressCancel: () => field?.pointer = null,
          child: paint,
        );
      },
    );
  }
}

class _SpherePainter extends CustomPainter {
  _SpherePainter(
    this.field,
    this.state,
    this.colors,
    this.dark,
    this.twinkle, {
    super.repaint,
  });

  final CultivationSphereField field;
  final (double, double, double, double, bool) Function() state;
  final List<Color> colors;
  final bool dark;
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final (spin, time, ready, radius, away) = state();
    if (away) return;
    field.paint(
      canvas,
      Offset(size.width / 2, size.height / 2),
      radius,
      spin: spin,
      time: time,
      ready: ready,
      colors: colors,
      twinkle: twinkle,
      darkBackdrop: dark,
    );
  }

  @override
  bool shouldRepaint(_SpherePainter old) =>
      old.field != field || old.dark != dark || old.twinkle != twinkle;
}
