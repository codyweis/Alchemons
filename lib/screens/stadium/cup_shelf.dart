// lib/screens/stadium/cup_shelf.dart
//
// The stadium's three cups on a ledge of stone grains: Copper, Silver, Gold,
// each in its own metal once it is open (ash until then), with light in its
// bowl as its races are won. The chosen one stands taller, in a spotlight;
// tap another to look at it. Under each, its name and a bead per race.
//
// Choosing another: the spotlight swings across to it, a stream of light
// pours out of the old cup's bowl and over into the new one's, and the new
// cup rises into the light, a glint running over it as it settles.
//
// Home's trophy is the cup racing for now; the way in (stadium_passage.dart)
// pours into it here, so the shelf leaves that cup to the passage until it
// has landed, and says where each cup stands.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/screens/stadium/stadium_passage.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);

/// Where the cups stand in a shelf [size], with [focus] how chosen each is
/// (0..1; the chosen one 1).
class CupShelfGeo {
  factory CupShelfGeo(Size size, List<double> focus) {
    final floor = size.height - kCupShelfLabels;
    final weights = [for (final f in focus) 1 + .6 * f];
    final total = weights.fold(0.0, (s, w) => s + w);
    final inner = size.width - 8;
    // The chosen cup as tall as the shelf and its slot allow, its light
    // and all; the others a little over half of it.
    final bigSlot = inner * (1.6 / (total == 0 ? 1 : total));
    final big = math.max(
      8.0,
      math.min(math.min((floor - 4) / 1.3, bigSlot / 1.12), 168.0),
    );
    final small = big * .6;
    final boxes = <Rect>[];
    final heights = <double>[];
    var x = 4.0;
    for (var i = 0; i < focus.length; i++) {
      final slot = inner * weights[i] / total;
      final h = ui.lerpDouble(small, big, focus[i])!;
      final cx = x + slot / 2, cy = floor - h * .5;
      heights.add(h);
      boxes.add(Rect.fromLTWH(cx - .525 * h, cy - .78 * h, 1.05 * h, 1.3 * h));
      x += slot;
    }
    return CupShelfGeo._(floor, boxes, heights);
  }

  CupShelfGeo._(this.floor, this.boxes, this.heights);

  /// The ledge's top.
  final double floor;

  /// Each cup's box ([trophyBoxFor] its height) and height.
  final List<Rect> boxes;
  final List<double> heights;

  /// Which cup a tap at [x] is nearest.
  int cupAt(double x) {
    var best = 0;
    for (var i = 1; i < boxes.length; i++) {
      if ((boxes[i].center.dx - x).abs() < (boxes[best].center.dx - x).abs()) {
        best = i;
      }
    }
    return best;
  }
}

/// Under the ledge: the cup's name and its beads.
const double kCupShelfLabels = 34;

/// Grains in the light passing between cups.
const int _kPour = 150;

/// One cup as the shelf shows it: its look, its name, how many races (or
/// bouts) it has and how many are won, and whether it is open.
@immutable
class ShelfCup {
  const ShelfCup({
    required this.look,
    required this.name,
    required this.of,
    required this.won,
    required this.open,
  });

  final TrophyLook look;
  final String name;
  final int of, won;
  final bool open;

  /// The race cups, Copper to Gold.
  static List<ShelfCup> races(RaceProgress p) => [
    for (var i = 0; i < kRaceCups.length; i++)
      ShelfCup(
        look: TrophyLook.ofCup(i, p),
        name: kRaceCups[i].name,
        of: kRaceCups[i].courses.length,
        won: p.wonIn(kRaceCups[i]),
        open: p.cupOpen(i),
      ),
  ];

  /// The gem cups, Ruby to Emerald.
  static List<ShelfCup> gems(RaceProgress p) => [
    for (var i = 0; i < kGemCups.length; i++)
      ShelfCup(
        look: TrophyLook.ofGem(i, p),
        name: kGemCups[i].name,
        of: kGemCups[i].bouts.length,
        won: p.wonInGem(kGemCups[i]),
        open: p.gemOpen(i),
      ),
  ];

  @override
  bool operator ==(Object other) =>
      other is ShelfCup &&
      other.look == look &&
      other.name == name &&
      other.of == of &&
      other.won == won &&
      other.open == open;

  @override
  int get hashCode => Object.hash(look, name, of, won, open);
}

class CupShelf extends StatefulWidget {
  const CupShelf({
    super.key,
    required this.cups,
    required this.selected,
    required this.onSelect,
    this.passage,
  });

  final List<ShelfCup> cups;
  final int selected;
  final ValueChanged<int> onSelect;

  /// The way in from home, when it came that way.
  final StadiumPassage? passage;

  @override
  State<CupShelf> createState() => _CupShelfState();
}

/// How far through a choice each part of it is, given how far the whole
/// is (0..1): the cups growing and shrinking, the spotlight's foot (a
/// little ahead) and its lamp (a little behind).
double _cupsAt(double v) => Curves.easeOutCubic.transform(_clamp01(v / .5));
double _footAt(double v) => Curves.easeOutCubic.transform(_clamp01(v / .45));
double _lampAt(double v) =>
    Curves.easeInOutCubic.transform(_clamp01((v - .05) / .55));

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

/// The shelf partway through a choice.
class _Moment {
  const _Moment({
    required this.cups,
    required this.foot,
    required this.lamp,
    required this.v,
    required this.from,
    required this.to,
  });

  /// How chosen each cup is: for its size, for where the spotlight falls,
  /// and for where its lamp hangs.
  final List<double> cups, foot, lamp;

  /// How far through the choice (1 at rest).
  final double v;

  /// The cup the light left, and the one it went to.
  final int from, to;

  bool get moving => v < 1 && from != to;
}

class _CupShelfState extends State<CupShelf>
    with SingleTickerProviderStateMixin, GlyphClockLease {
  late final AnimationController _pick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );

  /// How chosen each cup was as the last choice began, and which had the
  /// light.
  late List<double> _from = _focusOf(widget.selected);
  late int _fromCup = widget.selected;
  bool _visible = true;

  List<double> _focusOf(int selected) => [
    for (var i = 0; i < widget.cups.length; i++) i == selected ? 1.0 : 0.0,
  ];

  /// How chosen each cup is [k] of the way from [_from] to [target].
  List<double> _blend(int target, double k) {
    final to = _focusOf(target);
    return [
      for (var i = 0; i < to.length; i++) ui.lerpDouble(_from[i], to[i], k)!,
    ];
  }

  List<double> get _focus => _blend(widget.selected, _cupsAt(_pick.value));

  _Moment _moment() {
    final v = _pick.value;
    return _Moment(
      cups: _blend(widget.selected, _cupsAt(v)),
      foot: _blend(widget.selected, _footAt(v)),
      lamp: _blend(widget.selected, _lampAt(v)),
      v: v,
      from: _fromCup,
      to: widget.selected,
    );
  }

  @override
  bool get wantsClock => _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    widget.passage?.cupAt = _cupAt;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant CupShelf old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // From where the cups stand now — mid-choice, if it was.
      _from = _blend(old.selected, _cupsAt(_pick.value));
      _fromCup = old.selected;
      _pick.forward(from: 0);
    }
    if (old.passage != widget.passage) {
      if (old.passage?.cupAt == _cupAt) old.passage?.cupAt = null;
      widget.passage?.cupAt = _cupAt;
    }
  }

  @override
  void dispose() {
    if (widget.passage?.cupAt == _cupAt) widget.passage?.cupAt = null;
    _pick.dispose();
    releaseGlyphClock();
    super.dispose();
  }

  /// Cup [i]'s box on the screen, at rest.
  Rect? _cupAt(int i) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final geo = CupShelfGeo(box.size, _focusOf(widget.selected));
    if (i < 0 || i >= geo.boxes.length) return null;
    return geo.boxes[i].shift(box.localToGlobal(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    final held = widget.passage?.held;
    final type = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final i = CupShelfGeo(box.biggest, _focus).cupAt(d.localPosition.dx);
          if (i == widget.selected) return;
          HapticFeedback.selectionClick();
          widget.onSelect(i);
        },
        child: RepaintBoundary(
          child: CustomPaint(
            size: box.biggest,
            painter: _ShelfPainter(
              cups: widget.cups,
              selected: widget.selected,
              moment: _moment,
              heldCup: () =>
                  held != null && held.value ? widget.passage!.carried : null,
              textStyle: type,
              repaint: Listenable.merge([
                _pick,
                ?held,
                if (glyphClock != null) glyphClock!,
              ]),
              time: () => GlyphClock.instance.seconds.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  _ShelfPainter({
    required this.cups,
    required this.selected,
    required this.moment,
    required this.heldCup,
    required this.textStyle,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<ShelfCup> cups;
  final int selected;
  final _Moment Function() moment;
  final int? Function() heldCup;
  final TextStyle textStyle;
  final double Function() time;

  static final GrainBatch _batch = GrainBatch(6);
  static final Map<String, TextPainter> _labels = {};

  TextPainter _label(String text, Color color, double size) {
    final key = '$text|${color.toARGB32()}|$size';
    return _labels[key] ??= TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time();
    final m = moment();
    final f = m.cups;
    final geo = CupShelfGeo(size, f);
    final floor = geo.floor;
    final held = heldCup();

    double mix(List<double> w, double Function(int i) of) {
      var sum = 0.0, n = 0.0;
      for (var i = 0; i < w.length; i++) {
        sum += w[i] * of(i);
        n += w[i];
      }
      return n == 0 ? 0 : sum / n;
    }

    // The spotlight, from a lamp above the shelf: as the choice changes
    // its foot swings over to the new cup, the lamp following, dimming a
    // little on the way.
    final footX = mix(m.foot, (i) => geo.boxes[i].center.dx);
    final lampX = mix(m.lamp, (i) => geo.boxes[i].center.dx);
    final beamW = mix(m.foot, (i) => geo.boxes[i].width);
    final beam = .62 + .38 * m.foot.reduce(math.max);
    {
      final top = Offset(lampX, -size.height * .1);
      final spread = beamW * .9;
      final path = Path()
        ..moveTo(top.dx - beamW * .12, top.dy)
        ..lineTo(top.dx + beamW * .12, top.dy)
        ..lineTo(footX + spread, floor + 4)
        ..lineTo(footX - spread, floor + 4)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            top,
            Offset(footX, floor),
            [
              _brassHot.withValues(alpha: 0),
              _brassHot.withValues(alpha: .07 * beam),
              _brassHot.withValues(alpha: .13 * beam),
            ],
            const [0, .55, 1],
          ),
      );
      final pool = Offset(footX, floor + 2);
      canvas.drawOval(
        Rect.fromCenter(center: pool, width: spread * 2.4, height: 22),
        Paint()
          ..shader = ui.Gradient.radial(pool, spread * 1.2, [
            _brassHot.withValues(alpha: .22 * beam),
            _brassHot.withValues(alpha: 0),
          ]),
      );
    }

    // The ledge: a band of dark stone grains, its edge lit, thinning away
    // at both ends.
    final b = _batch..clear();
    final left = 6.0, right = size.width - 6;
    double thin(double x) => math.min(1, math.min(x - left, right - x) / 44);
    for (var x = left; x < right; x += 3.1) {
      final xi = (x * 3).round();
      final h = _hash(xi, 1);
      final keep = thin(x);
      if (_hash(xi, 5) > keep) continue;
      b.add(h < .7 ? 0 : 1, x + (h - .5) * 1.2, floor + 1 + (h - .5) * .8);
      for (var y = 4.0; y < 10; y += 2.8) {
        final hy = _hash(xi * 7 + y.round(), 2);
        if (hy < .35 || hy > .35 + .65 * keep) continue;
        b.add(hy < .8 ? 2 : 3, x + (hy - .5) * 1.4, floor + y);
      }
    }
    // The edge brightens where the spotlight falls.
    {
      final reach = beamW * .7;
      for (var x = footX - reach; x < footX + reach; x += 2.4) {
        final k = 1 - ((x - footX) / reach).abs();
        if (_hash((x * 5).round(), 4) > k * beam) continue;
        b.add(4, x, floor + .5);
      }
    }
    b.draw(canvas, 0, 1.6, _brass.withValues(alpha: .45));
    b.draw(canvas, 1, 1.9, _brassHot.withValues(alpha: .7));
    b.draw(canvas, 2, 1.7, const Color(0xFF2E2C29));
    b.draw(canvas, 3, 1.7, const Color(0xFF45413B));
    b.draw(canvas, 4, 2.1, _brassHot.withValues(alpha: .9));

    // The cups. The newly chosen one rises into the light and settles,
    // a glint running over it as it does.
    final rise = m.moving ? math.sin(math.pi * _cupsAt(m.v)) : 0.0;
    Offset cupCentre(int i) =>
        trophyCentreIn(geo.boxes[i]) +
        Offset(0, i == m.to ? -rise * geo.heights[i] * .07 : 0);
    for (var i = 0; i < geo.boxes.length; i++) {
      if (held == i) continue;
      final look = cups[i].look;
      final open = look.metal != TrophyMetal.ash;
      final arriving = m.moving && i == m.to;
      if (arriving) {
        // Its bowl brightens as the light pours in.
        final pulse = math.sin(math.pi * _clamp01((m.v - .26) / .45));
        if (pulse > 0) {
          final mouth = cupCentre(i) + Offset(0, -geo.heights[i] * .5);
          final r = geo.heights[i] * .55;
          canvas.drawCircle(
            mouth,
            r,
            Paint()
              ..shader = ui.Gradient.radial(mouth, r, [
                trophyLight(look.metal).withValues(alpha: .2 * pulse),
                trophyLight(look.metal).withValues(alpha: 0),
              ]),
          );
        }
      }
      paintStadiumTrophy(
        canvas,
        cupCentre(i),
        geo.heights[i],
        look,
        t,
        alpha: (open ? .72 : .6) + .28 * f[i],
        // The glint runs over the chosen one and any cup won outright;
        // the rest stand still.
        still: f[i] < .5 && look.fill < 1,
        glint: arriving ? (m.v - .4) / .44 : null,
      );
    }

    if (m.moving && held == null) {
      _pour(
        canvas,
        size,
        from: cupCentre(m.from) + Offset(0, -geo.heights[m.from] * .46),
        to: cupCentre(m.to) + Offset(0, -geo.heights[m.to] * .46),
        v: m.v,
        fromLook: cups[m.from].look,
        toLook: cups[m.to].look,
        width: trophyGrainWidth(geo.heights[m.to]),
      );
    }

    // Names and beads.
    for (var i = 0; i < geo.boxes.length; i++) {
      final cup = cups[i];
      final open = cup.open;
      final cx = geo.boxes[i].center.dx;
      final name = cup.name.split(' ').first.toUpperCase();
      final colour = !open
          ? _muted.withValues(alpha: .55)
          : Color.lerp(_ink.withValues(alpha: .7), _brassHot, f[i])!;
      final tp = _label(name, colour, 10);
      tp.paint(canvas, Offset(cx - tp.width / 2, floor + 13));
      final won = cup.won;
      for (var r = 0; r < cup.of; r++) {
        final x = cx + (r - 1) * 9.0;
        final at = Offset(x, floor + 29);
        final lit = r < won;
        canvas.drawCircle(
          at,
          lit ? 2.4 : 1.8,
          Paint()
            ..color = lit
                ? _brassHot
                : (open
                      ? _muted.withValues(alpha: .5)
                      : _muted.withValues(alpha: .25)),
        );
      }
    }
  }

  static final List<Float32List> _pourPts = [
    for (var i = 0; i < 6; i++) Float32List(_kPour * 6),
  ];
  static final Paint _pourPaint = Paint()..strokeCap = StrokeCap.round;

  /// The light passing from one cup to the next: a pour of grains out of
  /// the bowl at [from], up over the shelf and down into the bowl at [to],
  /// each trailing two fainter grains, in [fromLook]'s light as it leaves
  /// and [toLook]'s as it lands.
  static void _pour(
    Canvas canvas,
    Size size, {
    required Offset from,
    required Offset to,
    required double v,
    required TrophyLook fromLook,
    required TrophyLook toLook,
    required double width,
  }) {
    final d = (to - from).distance;
    final ctrl = Offset(
      (from.dx + to.dx) / 2,
      math.min(from.dy, to.dy) - size.height * .07 - d * .1,
    );
    final along = to - from;
    final normal = d == 0 ? Offset.zero : Offset(-along.dy, along.dx) / d;
    Offset at(double e, double h) {
      final u = 1 - e;
      final p = from * (u * u) + ctrl * (2 * u * e) + to * (e * e);
      // A rope of sand: narrow where it leaves and lands, loose and a
      // little twisted between.
      final off =
          ((h - .5) * 11 + math.sin(e * math.pi * 2 + h * 6) * 2.5) *
          math.sin(math.pi * e);
      return p + normal * off;
    }

    // Buckets: [the cup it is nearer] × [faint trail, lit, brightest].
    final n = List.filled(6, 0);
    void add(int bucket, Offset p) {
      final buf = _pourPts[bucket];
      buf[n[bucket]++] = p.dx;
      buf[n[bucket]++] = p.dy;
    }

    for (var i = 0; i < _kPour; i++) {
      final h1 = _hash(i, 21), h2 = _hash(i, 22), h3 = _hash(i, 23);
      final u = (v - .22 * h1) / (.28 + .08 * h2);
      if (u <= 0 || u >= 1) continue;
      // Lit as soon as it leaves; out only as it reaches the bowl.
      final lit = math.min(1.0, u / .12) * math.min(1.0, (1 - u) / .08);
      if (lit < .2) continue;
      final e = Curves.easeInOutSine.transform(u);
      final group = e < .5 ? 0 : 3;
      add(group + (lit > .7 ? (h2 < .28 ? 2 : 1) : 0), at(e, h3));
      for (final back in const [.022, .044]) {
        final eb = Curves.easeInOutSine.transform(math.max(0, u - back));
        add(group, at(eb, h3));
      }
    }
    for (var g = 0; g < 2; g++) {
      final look = g == 0 ? fromLook : toLook;
      final fade = look.metal == TrophyMetal.ash ? .45 : 1.0;
      final light = trophyLight(look.metal);
      const alphas = [.32, .78, .95];
      for (var l = 0; l < 3; l++) {
        final k = g * 3 + l;
        if (n[k] == 0) continue;
        _pourPaint
          ..strokeWidth = width * (l == 2 ? 1.05 : .85)
          ..color = (l == 2 ? Color.lerp(light, Colors.white, .45)! : light)
              .withValues(alpha: alphas[l] * fade);
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(_pourPts[k], 0, n[k]),
          _pourPaint,
        );
      }
    }
  }

  static double _hash(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(_ShelfPainter old) =>
      !listEquals(old.cups, cups) ||
      old.selected != selected ||
      old.textStyle != textStyle;
}
