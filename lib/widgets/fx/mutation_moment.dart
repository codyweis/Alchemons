// lib/widgets/fx/mutation_moment.dart
//
// WHEN A WILD FUSION MUTATES.
//
// Plays over the wild once the fusion's cinematic has closed. It shows THAT
// the new egg mutated and never which: the extraction reveals that.
//
//   0.0 – 0.7   the field darkens around the egg's place
//   0.3 – 2.1   the mutation meter empties: its grains rise out of the glass
//               and pour across into the egg, with more of the meter's light
//               behind them, and gather round it in a turning sphere
//   2.2 – 3.9   the sphere loosens into a lopsided cloud, then draws in tight
//   3.8 – 4.6   the egg: a glow whose colour drifts through the meter's own
//               (gold, pale, starlight, the spectrum), a few grains turning
//               round it
//   4.4 –       "MUTATION", and "revealed when extracted" under it; waits for
//               a tap
//   on the tap  the egg sinks and fades, the field lights back up
//
// Without the meter (its node not unlocked) the same light gathers from
// nothing instead of pouring from the glass.
//
// Grains draw through drawRawPoints in a few batches; no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/wilderness/mutation_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Plays the mutation's moment with the new egg at [at] (global
/// coordinates), and returns once the player has tapped past it.
Future<void> showMutationMoment(BuildContext context, {required Offset at}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => _MutationMoment(at: at),
    ),
  );
}

class _MutationMoment extends StatefulWidget {
  const _MutationMoment({required this.at});
  final Offset at;

  @override
  State<_MutationMoment> createState() => _MutationMomentState();
}

class _MutationMomentState extends State<_MutationMoment>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = Stopwatch()..start();
  final _rng = math.Random();
  final List<_Mote> _motes = [];
  bool _seeded = false;
  double? _leaveAt;
  bool _revealSounded = false;
  final _key = GlobalKey();

  static const _readyAt = 4.6;

  double get _t => _clock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted) return;
      final t = _t;
      if (!_revealSounded && t >= 3.8) {
        _revealSounded = true;
        context.sound(SoundCue.extractionRareReveal, owner: this);
        HapticFeedback.mediumImpact();
      }
      final leave = _leaveAt;
      if (leave != null && t - leave > 1.0) {
        _ticker.stop();
        Navigator.of(context).pop();
        return;
      }
      setState(() {});
    })..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// The grains: the meter's own (from where they stood), more of its light
  /// behind them, and the egg's own few.
  void _seed() {
    if (!mounted || _seeded) return;
    _seeded = true;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    Offset local(Offset g) => box == null ? g : box.globalToLocal(g);
    final at = local(widget.at);
    final bus = MutationMeterBus.instance;
    final glassG = bus.glass;
    final glass = glassG == null
        ? null
        : Rect.fromPoints(local(glassG.topLeft), local(glassG.bottomRight));
    final fill = bus.shownFill;

    Color pick() => _rng.nextDouble() < kMutagenSpectrumShare
        ? const Color(0x00000000) // spectrum, coloured as it draws
        : kMutagenColors[_rng.nextInt(kMutagenColors.length)];

    void add(Offset from, double start, {bool fromGlass = false}) {
      final u = _rng.nextDouble();
      final lop = _rng.nextDouble() * math.pi * 2;
      _motes.add(
        _Mote(
          from: from,
          start: start,
          travel: fromGlass ? 1.0 + _rng.nextDouble() * 0.35 : 0.9,
          up: fromGlass,
          colour: pick(),
          phase: _rng.nextDouble(),
          theta: _rng.nextDouble() * math.pi * 2,
          phi: math.acos(1 - 2 * u),
          dir: _rng.nextBool() ? 1 : -1,
          spread: 1 + 1.3 * math.pow(_rng.nextDouble(), 1.6),
          lopX: math.cos(lop) * 0.6 + 0.5,
          lopY: math.sin(lop) * 0.6 - 0.4,
          linger: _rng.nextDouble() < 0.14,
        ),
      );
    }

    if (glass != null) {
      // The meter's grains, from where they stood (filled from the foot).
      const across = kMeterPerRow;
      final count = (fill * (glass.height - 8) / kMeterRowStep * across).round();
      for (var i = 0; i < count; i++) {
        final row = i ~/ across;
        final y = glass.bottom - 4 - row * kMeterRowStep;
        final x =
            glass.left + 1.5 + ((i % across) + 0.5) * (glass.width - 3) / across;
        add(Offset(x, y), 0.3 + (1 - i / math.max(1, count)) * 0.5, fromGlass: true);
      }
      // More of its light behind them, so even a near-empty meter pours.
      final cap = Offset(glass.center.dx, glass.top - 5);
      for (var i = 0; i < 140; i++) {
        add(
          cap + Offset(_rng.nextDouble() * 6 - 3, _rng.nextDouble() * 10),
          0.45 + _rng.nextDouble() * 0.9,
          fromGlass: true,
        );
      }
      bus.grainsTaken();
      context.sound(SoundCue.fusionPour, owner: this);
    } else {
      // No meter: the light gathers from round the egg instead.
      for (var i = 0; i < 220; i++) {
        final a = _rng.nextDouble() * math.pi * 2;
        final d = 70 + _rng.nextDouble() * 90;
        add(at + Offset(math.cos(a) * d, math.sin(a) * d * 0.7), 0.3 + _rng.nextDouble() * 1.0);
      }
    }
    // The egg's own matter, already there.
    for (var i = 0; i < 90; i++) {
      add(at, 0.0);
    }
  }

  void _tap() {
    if (_t < _readyAt || _leaveAt != null) return;
    _leaveAt = _t;
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: CustomPaint(
        key: _key,
        size: Size.infinite,
        painter: _MomentPainter(
          t: _t,
          leaveAt: _leaveAt,
          motes: _motes,
          at: () {
            final box = _key.currentContext?.findRenderObject() as RenderBox?;
            return box == null ? widget.at : box.globalToLocal(widget.at);
          }(),
          readyAt: _readyAt,
        ),
      ),
    );
  }
}

class _Mote {
  _Mote({
    required this.from,
    required this.start,
    required this.travel,
    required this.up,
    required this.colour,
    required this.phase,
    required this.theta,
    required this.phi,
    required this.dir,
    required this.spread,
    required this.lopX,
    required this.lopY,
    required this.linger,
  });

  final Offset from;
  final double start, travel;

  /// Rises out of the glass before it crosses.
  final bool up;

  /// Fully transparent: one of the spectrum's.
  final Color colour;
  final double phase, theta, phi, spread, lopX, lopY;
  final int dir;
  final bool linger;
  final List<Offset> trail = [];
}

double _ease(double u) {
  final x = u.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

Offset _bez(Offset a, Offset c, Offset b, double u) {
  final v = 1 - u;
  return a * (v * v) + c * (2 * v * u) + b * (u * u);
}

/// The meter's colours, one after another: what the egg's light drifts
/// through, so it never settles on the mutation's own.
Color _drift(double t) {
  final ring = [
    const Color(0xFFE2C98F),
    const Color(0xFFEEEAF6),
    const Color(0xFFA9C1FF),
    mutagenSpectrum(t * 60),
  ];
  final c = (t * 0.25) % 1 * ring.length;
  final i = c.floor();
  return Color.lerp(ring[i], ring[(i + 1) % ring.length], _ease(c - i))!;
}

class _MomentPainter extends CustomPainter {
  _MomentPainter({
    required this.t,
    required this.leaveAt,
    required this.motes,
    required this.at,
    required this.readyAt,
  });

  final double t;
  final double? leaveAt;
  final List<_Mote> motes;
  final Offset at;
  final double readyAt;

  final Map<int, List<double>> _bands = {};

  void _add(Color c, double a, Offset p) {
    if (a <= 0.02) return;
    final band = (a.clamp(0.0, 1.0) * 3).round().clamp(1, 3);
    final key = (c.toARGB32() & 0x00FFFFFF) | (band << 24);
    (_bands[key] ??= []).addAll([p.dx, p.dy]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _bands.clear();
    final leave = leaveAt == null ? 0.0 : _ease((t - leaveAt!) / 0.9);

    // The field darkens around the egg's place.
    final dim = 0.64 * _ease(_span(t, 0, 0.7)) * (1 - leave);
    if (dim > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            at,
            size.longestSide * 0.8,
            [
              Color.fromRGBO(4, 4, 6, dim * 0.75),
              Color.fromRGBO(4, 4, 6, dim),
              Color.fromRGBO(4, 4, 6, math.min(1, dim * 1.2)),
            ],
            const [0, 0.45, 1],
          ),
      );
    }

    // The sphere: slows as the light arrives, loosens, draws in tight.
    const r0 = 30.0;
    final out = _ease(_span(t, 2.2, 3.1));
    final inn = _ease(_span(t, 3.1, 3.9));
    final settle = _ease(_span(t, 3.8, 4.4));
    final spin = t * 1.4 + 2.6 * math.max(0, t - 3.1) * inn;

    for (final m in motes) {
      final ang = m.theta + spin * m.dir;
      final sx = at.dx + r0 * math.sin(m.phi) * math.cos(ang);
      final sy = at.dy + r0 * 0.96 * math.cos(m.phi);
      final z = math.sin(m.phi) * math.sin(ang);

      // Getting there: up out of the glass, then across in an arc.
      final u = (t - m.start) / m.travel;
      if (u < 0) continue;
      Offset p;
      var a = 0.5 + 0.5 * (z + 1) / 2;
      if (u < 1) {
        if (m.up) {
          final rise = Offset(m.from.dx, m.from.dy - 28);
          if (u < 0.22) {
            p = Offset.lerp(m.from, rise, _ease(u / 0.22))!;
          } else {
            final ctrl = Offset(
              (rise.dx + sx) / 2 + 10,
              math.min(rise.dy, sy) - 90,
            );
            p = _bez(rise, ctrl, Offset(sx, sy), _ease((u - 0.22) / 0.78));
          }
        } else {
          p = Offset.lerp(m.from, Offset(sx, sy), _ease(u))!;
        }
        a = 0.95;
        m.trail.add(p);
        if (m.trail.length > 4) m.trail.removeAt(0);
      } else {
        m.trail.clear();
        // The breath: out into a lopsided cloud, then drawn in tight.
        final k = 1 + (m.spread - 1) * out;
        var x = at.dx + (sx - at.dx) * k + m.lopX * out * 16;
        var y = at.dy + (sy - at.dy) * k * 0.9 + m.lopY * out * 16 - out * 5;
        x += (at.dx - x) * inn * 0.88;
        y += (at.dy - y) * inn * 0.88;
        p = Offset(x, y);
        a = math.min(1.0, a + inn * 0.3);
        if (m.linger) {
          // A few keep turning round the egg.
          final sw = _ease(_span(t, 3.9, 4.6));
          final rr = 12 + m.spread * 9, an = m.theta + t * 0.5 * m.dir;
          final o = Offset(
            at.dx + math.cos(an) * rr * (1 + 0.25 * math.sin(t * 0.7 + m.phase * 6)) + 4,
            at.dy + math.sin(an) * rr * 0.8 * (1 + 0.2 * math.cos(t * 0.9 + m.phase * 4)) - 3,
          );
          p = Offset.lerp(p, o, sw)!;
          a *= 1 - 0.45 * sw;
          if (leaveAt != null) {
            p = Offset.lerp(p, at + const Offset(0, 8), leave)!;
          }
          a *= 1 - leave;
        } else {
          a *= 1 - settle;
        }
      }
      final colour = m.colour.a == 0
          ? mutagenSpectrum(((m.phase * 360 + t * 50) / 30).round() * 30.0)
          : m.colour;
      for (var i = 0; i < m.trail.length - 1; i++) {
        _add(colour, a * (0.15 + i * 0.12), m.trail[i]);
      }
      _add(colour, a, p);
    }

    for (final e in _bands.entries) {
      final band = e.key >> 24;
      final colour = Color(0xFF000000 | (e.key & 0x00FFFFFF));
      final pts = Float32List.fromList(e.value);
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = colour.withValues(alpha: 0.12 * band / 3)
          ..strokeWidth = 4.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = colour.withValues(alpha: band / 3)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // The egg: its light drifts through the meter's colours.
    final egg = _ease(_span(t, 3.7, 4.5)) * (1 - leave);
    if (egg > 0) {
      final c = _drift(t);
      final y = at.dy + 8 * leave;
      final breath = 1 + 0.06 * math.sin(t * 1.8);
      final eggAt = Offset(at.dx, y);
      canvas.drawCircle(
        eggAt,
        74 * breath,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(eggAt, 74 * breath, [
            c.withValues(alpha: 0.4 * egg),
            c.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(
        eggAt,
        17 * breath,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            eggAt - const Offset(2, 3),
            17 * breath,
            [
              Color.fromRGBO(255, 250, 240, 0.95 * egg),
              c.withValues(alpha: 0.7 * egg),
              c.withValues(alpha: 0),
            ],
            const [0, 0.5, 1],
          ),
      );
    }

    // One word, and when it will be known.
    final label = _ease(_span(t, 4.3, 5.0)) * (1 - leave);
    if (label > 0) {
      final rise = 4 * (1 - label);
      _text(
        canvas,
        'MUTATION',
        Offset(at.dx, at.dy + 52 - rise),
        size: 17,
        spacing: 5,
        colour: Color.fromRGBO(237, 230, 214, label),
      );
      _text(
        canvas,
        'REVEALED WHEN EXTRACTED',
        Offset(at.dx, at.dy + 76 - rise),
        size: 10,
        spacing: 1.6,
        colour: Color.fromRGBO(142, 140, 136, label),
      );
    }
    final hint = leaveAt == null ? _ease(_span(t, readyAt + 1.6, readyAt + 2.4)) : 0.0;
    if (hint > 0) {
      _text(
        canvas,
        'TAP TO CONTINUE',
        Offset(size.width / 2, size.height - 34),
        size: 9.5,
        spacing: 1.6,
        colour: Color.fromRGBO(142, 140, 136, 0.8 * hint),
      );
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset centre, {
    required double size,
    required double spacing,
    required Color colour,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          fontWeight: FontWeight.w600,
          letterSpacing: spacing,
          color: colour,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MomentPainter old) => true;
}
