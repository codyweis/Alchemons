// lib/widgets/alchemy_emblem.dart
//
// ALCHEMY on home (the author, 2026-10-08: a home emblem "in the middle,
// under the portal/showcase area", shown locked with progress until every
// formula is found). In the mode's own language:
//
//   · LOCKED, it is one of the mode's sand circles and nothing more ("just
//     show the ring"): ash, lit round its rim as far as the player has come
//     (formulas found of all there are).
//   · OPEN, a floating orb of grains hangs over the circle — every element
//     in it, turning — the ALCHEMY ORB ([paintAlchemyOrb]).
//   · The WAY IN (a PassageScene): the orb lifts off and flies to the head
//     of the level picker, growing as it goes, and the word ALCHEMY gathers
//     out of it underneath — the picker's own header, orb and title in the
//     same places, so the flight ends as the page ([alchemyOrbAt],
//     [alchemyTitleAt], shared with the page).
//
// Points in batches and radial gradients; no blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const Color _kBrass = Color(0xFFCDB07A);
const Color _kBrassDeep = Color(0xFF6B5A36);
const Color _kAsh = Color(0xFF8E8A82);

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

void _glow(Canvas canvas, Offset c, double r, Color color, double alpha) {
  if (alpha <= .002 || r <= 0) return;
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        c,
        r,
        [
          color.withValues(alpha: alpha.clamp(0.0, 1.0)),
          color.withValues(alpha: alpha.clamp(0.0, 1.0) * .35),
          color.withValues(alpha: 0),
        ],
        const [0, .4, 1],
      ),
  );
}

/// The element the stream shows at [time], and how far it has turned to
/// the next (each holds a few seconds, then gives way).
(Color, Color, double) _elementAt(double time) {
  const hold = 2.6;
  final n = EssenceElement.values.length;
  final i = (time / hold).floor();
  final k = _smooth(.7, 1, (time / hold) - i);
  return (
    elementOrbTint(EssenceElement.values[i % n]),
    elementOrbTint(EssenceElement.values[(i + 1) % n]),
    k,
  );
}

// ── the title, shared with the level select ────────────────────────────

HeartWord? _titleWord;
Future<HeartWord>? _titleLoading;

/// The word ALCHEMY in grains, sampled once and kept.
Future<HeartWord> alchemyTitleWord() => _titleLoading ??= heartWordOf(
  'ALCHEMY',
  size: 24,
).then((w) => _titleWord = w);

/// Where the picker's orb floats, and how big, on a screen of [width] under
/// a top inset of [top]; and its title, under it.
Offset alchemyOrbAt(double width, double top) => Offset(width / 2, top + 56);
const double kAlchemyHeaderOrb = 30;
Offset alchemyTitleAt(double width, double top) => Offset(width / 2, top + 112);

/// The title at rest (or gathering, [k] < 1, its grains coming from [from]).
void paintAlchemyTitle(
  Canvas canvas,
  RiteGrainBatch batch,
  Offset centre,
  double time, {
  double k = 1,
  Offset? from,
  double alpha = 1,
}) {
  final w = _titleWord;
  if (w == null || alpha <= .01) return;
  _glow(canvas, centre, w.width * .6 + 20, _kBrass, .08 * alpha * k);
  final n = w.letters;
  for (var i = 0; i < w.length; i++) {
    final home = centre + Offset(w.x[i], w.y[i]);
    var p = home;
    var a = alpha;
    if (k < 1 && from != null) {
      // In from the stream, letter by letter, along a slight bow.
      final leave = .4 * w.letter[i] / n + .15 * _h(i, 3);
      final u = _clamp01((k - leave) / (1 - .55));
      final e = 1 - (1 - u) * (1 - u) * (1 - u);
      final start = from + Offset((_h(i, 5) - .5) * 14, (_h(i, 6) - .5) * 14);
      p = Offset.lerp(start, home, e)! + Offset(0, -14 * math.sin(math.pi * e));
      a *= _smooth(0, .15, u);
    }
    p += Offset(0, math.sin(time * 1.4 + i * .7) * .4);
    final sh = _h(i, 9);
    batch.add(
      p.dx,
      p.dy + .8,
      p.dx,
      p.dy,
      sh > .85 ? const Color(0xFFF2E3BC) : _kBrass,
      alpha: a * (.75 + .25 * math.sin(time * 1.7 + i * 2.3)),
      width: sh > .85 ? 2.4 : 2,
    );
  }
}

// ── the alchemy orb ────────────────────────────────────────────────────

/// Grains on a sphere (golden-angle), each in one element's colour.
final List<(double, double, double, Color, double)> _orbGrains = () {
  const n = 340;
  final tints = [for (final e in EssenceElement.values) elementOrbTint(e)];
  final out = <(double, double, double, Color, double)>[];
  final golden = math.pi * (3 - math.sqrt(5));
  for (var i = 0; i < n; i++) {
    final y = 1 - (i + .5) / n * 2;
    final r = math.sqrt(1 - y * y);
    final th = golden * i;
    // Shell-weighted inward a little, so it reads as a ball of grains.
    final depth = .78 + .22 * math.pow(_h(i, 21), .5);
    out.add((
      math.cos(th) * r * depth,
      y * depth,
      math.sin(th) * r * depth,
      tints[(i * 7) % tints.length],
      _h(i, 22),
    ));
  }
  return out;
}();

/// The alchemy orb at [c], [radius] across: every element's grains on a
/// turning ball, lit from its upper left, the near side bright and the far
/// side dim through it, with a slow breath of light inside.
void paintAlchemyOrb(
  Canvas canvas,
  RiteGrainBatch batch,
  Offset c,
  double radius,
  double time, {
  double alpha = 1,
}) {
  if (alpha <= .01 || radius <= 1) return;
  final (e0, e1, ek) = _elementAt(time * .8);
  final inner = Color.lerp(e0, e1, ek)!;
  _glow(canvas, c, radius * 2.1, inner, .16 * alpha);
  _glow(canvas, c, radius * 1.05, inner, .22 * alpha);
  final spin = time * .55;
  const tilt = .38;
  final cs = math.cos(spin), sn = math.sin(spin);
  final ct = math.cos(tilt), st = math.sin(tilt);
  // Fewer, finer grains on a small orb, so it reads as a ball and not a
  // mosaic.
  final width = radius > 22 ? 2.2 : 1.7;
  final step = radius > 22 ? 1 : 2;
  for (var g = 0; g < _orbGrains.length; g += step) {
    final (x0, y0, z0, own, h) = _orbGrains[g];
    // Turn about the upright, then tip toward the viewer.
    final x1 = x0 * cs + z0 * sn, z1 = -x0 * sn + z0 * cs;
    final y2 = y0 * ct - z1 * st, z2 = y0 * st + z1 * ct;
    final near = (z2 + 1) / 2; // 0 far .. 1 near
    final lit = _clamp01(.55 + .45 * (-x1 * .5 - y2 * .6 + z2 * .6));
    final p = c + Offset(x1 * radius, y2 * radius);
    final twinkle = .8 + .2 * math.sin(time * 2.3 + h * 40);
    final a = (.18 + .82 * near) * (.55 + .45 * lit) * twinkle * alpha;
    // The whole ball drifts through one element at a time; a fifth of its
    // grains keep their own element and sparkle through it.
    final col = h > .8 ? own : Color.lerp(own, inner, .78)!;
    final colour = h > .93
        ? Color.lerp(col, const Color(0xFFFFF6E6), .65)!
        : Color.lerp(Color.lerp(col, Colors.black, .4)!, col, lit)!;
    batch.add(
      p.dx,
      p.dy,
      p.dx,
      p.dy,
      colour,
      alpha: a,
      width: near > .55 && h > .7 ? width + .4 : width,
    );
  }
  batch.paint(canvas);
}

/// The orb's grains as they stand at [time] (where, what colour, how near
/// the viewer, 0..1), for a moment that takes the orb apart.
List<(Offset, Color, double)> alchemyOrbGrainsAt(
  Offset c,
  double radius,
  double time,
) {
  final (e0, e1, ek) = _elementAt(time * .8);
  final inner = Color.lerp(e0, e1, ek)!;
  final spin = time * .55;
  const tilt = .38;
  final cs = math.cos(spin), sn = math.sin(spin);
  final ct = math.cos(tilt), st = math.sin(tilt);
  return [
    for (final (x0, y0, z0, own, h) in _orbGrains)
      () {
        final x1 = x0 * cs + z0 * sn, z1 = -x0 * sn + z0 * cs;
        final y2 = y0 * ct - z1 * st, z2 = y0 * st + z1 * ct;
        return (
          c + Offset(x1 * radius, y2 * radius),
          h > .8 ? own : Color.lerp(own, inner, .78)!,
          (z2 + 1) / 2,
        );
      }(),
  ];
}

// ── the emblem and its way in ──────────────────────────────────────────

/// Paints the emblem at [s]: the icon in its box, or the way in over the
/// screen ([EmblemStage.open]).
void paintAlchemyEmblem(
  Canvas canvas,
  EmblemStage s, {
  double progress = 1,
  bool open = true,
  bool back = true,
  bool front = true,
}) {
  final t = s.time;
  final k = s.grow;
  final box = s.box;
  final batch = _batch;
  // The circle stays where it lies on home; the passage's ground covers it.
  final c = Offset(box.center.dx, box.top + box.height * .78);
  final rx = box.width * .36, ry = rx * .3;
  // The orb: floating over the circle, then flying to the picker's head.
  final bob = math.sin(t * 1.25) * box.height * .03;
  final o0 = Offset(box.center.dx, box.top + box.height * .47 + bob);
  final o1 = alchemyOrbAt(s.screen.width, s.pad.top);
  final r0 = box.width * .2, r1 = kAlchemyHeaderOrb;
  // A gentle bow on the way up, out to the side it starts on.
  final side = (o0.dx - s.screen.width / 2).sign;
  final ctrl =
      Offset.lerp(o0, o1, .5)! +
      Offset(side * s.screen.width * .12, s.screen.height * .04);
  final u = k;
  final orbAt = Offset(
    (1 - u) * (1 - u) * o0.dx + 2 * (1 - u) * u * ctrl.dx + u * u * o1.dx,
    (1 - u) * (1 - u) * o0.dy + 2 * (1 - u) * u * ctrl.dy + u * u * o1.dy,
  );
  final orbR = ui.lerpDouble(r0, r1, k)!;

  if (back) {
    // The ground the passage brings: black, as the page is.
    if (s.ground > 0) {
      canvas.drawRect(
        Offset.zero & s.screen,
        Paint()
          ..color = Colors.black.withValues(alpha: s.ground * (1 - s.land)),
      );
    }
  }
  if (!front) return;
  final fade = 1 - s.land;
  if (fade <= .01) return;

  // The circle of sand (home's own; it goes under the ground as the orb
  // leaves): lit round as far as the player has come.
  final ringA = (1 - _smooth(0, .35, k)) * fade;
  if (ringA > .01) {
    _glow(
      canvas,
      c,
      rx * 1.15,
      open ? _kBrass : _kAsh,
      (open ? .1 : .05) * ringA,
    );
    const grains = 84;
    for (var i = 0; i < grains; i++) {
      final a = i / grains * math.pi * 2 + t * .3;
      final along = ((a - t * .3) / (math.pi * 2)) % 1.0;
      final lit = open || along <= progress;
      final r = 1 + (_h(i, 1) - .5) * .12;
      final x = c.dx + math.cos(a) * rx * r, y = c.dy + math.sin(a) * ry * r;
      final near = math.sin(a) > 0 ? 1.0 : .6;
      final col = !lit
          ? _kAsh
          : (_h(i, 2) > .86
                ? const Color(0xFFF2E3BC)
                : Color.lerp(_kBrassDeep, _kBrass, .7)!);
      batch.add(
        x,
        y,
        x,
        y,
        col,
        alpha: (lit ? 1.0 : .26) * near * ringA,
        width: lit ? (_h(i, 2) > .86 ? 2.8 : 2.4) : 2,
      );
    }
    // The orb's light on the circle under it.
    if (open) _glow(canvas, c, rx * .8, _kBrass, .12 * ringA);
    batch.paint(canvas);
  }

  if (!open) return;
  paintAlchemyOrb(canvas, batch, orbAt, orbR, t, alpha: fade);

  // Arriving, the word gathers out of it underneath.
  // Once the orb has passed it, not while it crosses.
  if (k > .87) {
    paintAlchemyTitle(
      canvas,
      batch,
      alchemyTitleAt(s.screen.width, s.pad.top),
      t,
      k: _smooth(.87, 1, k),
      from: orbAt,
      alpha: fade,
    );
    batch.paint(canvas);
  }
}

final RiteGrainBatch _batch = RiteGrainBatch();

/// The way in through the emblem.
class AlchemyPassageScene extends PassageScene {
  const AlchemyPassageScene();

  @override
  Duration get inward => const Duration(milliseconds: 1250);
  @override
  Duration get outward => const Duration(milliseconds: 950);
  @override
  Duration get landing => const Duration(milliseconds: 700);
  @override
  double get buildAt => .5;

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) => paintAlchemyEmblem(canvas, s, back: back, front: front);
}

/// The emblem on home: the icon, open or locked, with its own clock.
class AlchemyEmblem extends StatefulWidget {
  const AlchemyEmblem({
    super.key,
    required this.size,
    required this.open,
    required this.progress,
    this.animate = true,
    this.lifted,
  });

  final double size;
  final bool open;

  /// How far round the locked circle is lit (formulas found of all).
  final double progress;
  final bool animate;
  final ValueListenable<bool>? lifted;

  @override
  State<AlchemyEmblem> createState() => _AlchemyEmblemState();
}

class _AlchemyEmblemState extends State<AlchemyEmblem> with GlyphClockLease {
  bool _visible = true;
  double _stilled = 0;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    alchemyTitleWord();
    _sync();
  }

  void _sync() {
    if (!wantsClock) _stilled = GlyphClock.instance.seconds.value;
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant AlchemyEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget paint(bool away) => CustomPaint(
      size: Size.square(widget.size),
      willChange: widget.animate && !away,
      painter: away
          ? null
          : _AlchemyEmblemPainter(
              open: widget.open,
              progress: widget.progress,
              clock: glyphClock,
              time: glyphClock == null ? _stilled : null,
            ),
    );
    final lifted = widget.lifted;
    return RepaintBoundary(
      child: lifted == null
          ? paint(false)
          : ValueListenableBuilder<bool>(
              valueListenable: lifted,
              builder: (_, away, _) => paint(away),
            ),
    );
  }
}

class _AlchemyEmblemPainter extends CustomPainter {
  _AlchemyEmblemPainter({
    required this.open,
    required this.progress,
    this.clock,
    this.time,
  }) : super(repaint: clock);

  final bool open;
  final double progress;
  final ValueListenable<double>? clock;
  final double? time;

  @override
  void paint(Canvas canvas, Size size) {
    paintAlchemyEmblem(
      canvas,
      EmblemStage(
        box: Offset.zero & size,
        screen: size,
        time: time ?? clock?.value ?? 0,
      ),
      open: open,
      progress: progress,
    );
  }

  @override
  bool shouldRepaint(covariant _AlchemyEmblemPainter old) =>
      old.open != open ||
      old.progress != progress ||
      old.clock != clock ||
      old.time != time;
}
