// lib/screens/cosmic/widgets/space_action_glyphs.dart
//
// The marks on space's action buttons — the home rail (DEPOSIT, DESCEND,
// HOME BASE, SHIP) and a planet's DESCEND / RAID / SUMMON RAID — drawn in
// the star chart's material (glass lit from inside, light pooled round it,
// grains) instead of stock arrows and icons:
//
//   deposit  the cargo, grains in its own elements' colors, falling into
//            the home planet's bead — which is what a deposit does: the
//            hold's elements go into home's color
//   descend  the curve of a planet's face below, a grain diving down into
//            it and lighting where it goes in
//   home     the home planet, a lit bead in its own color
//   ship     the hull the player flies, in its grains
//   raid     a planet with the storm of an overrun on it (the chart's own)
//   summon   the raid beacon (the item's own glyph)
//
// And the combat buttons:
//
//   gun      bolts of light streaming out of a muzzle spark
//   boost    an engine's nozzle throwing its plume of grains — longer,
//            hotter and flickering while it burns
//   missile  a dart curving in on a target, its trail of grains behind it
//   tether   a magnet of dark glass: linked, its poles lit and the party's
//            grains drawn in toward them; unlinked, the poles dark and the
//            grains drifting loose
//
// Small and cheap: a few discs and a batch of points. Deposit and descend
// move while they are lit, the combat marks while they fire or burn, all
// on the shared glyph clock.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/widgets/cosmic_ship_emblem.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/raid_beacon_glyph.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'star_chart_art.dart' show paintRaidGlyph;

enum SpaceAction {
  deposit,
  descend,
  home,
  ship,
  raid,
  summon,
  gun,
  boost,
  missile,
  tether,
}

class SpaceActionGlyph extends StatefulWidget {
  const SpaceActionGlyph(
    this.kind, {
    super.key,
    this.size = 36,
    this.color = const Color(0xFFE4C16A),
    this.cargo = const [],
    this.lit = true,
    this.skin,
  });

  final SpaceAction kind;
  final double size;

  /// The light it is drawn in: home's color (deposit, home), the planet's
  /// (descend, raid).
  final Color color;

  /// The hold's elements, for deposit's falling grains.
  final List<Color> cargo;

  /// Off for an action with nothing to do (nothing to deposit), or a
  /// weapon standing down: it stands still and dim. On, a weapon fires.
  final bool lit;

  /// The hull, for ship (null: the standard hull).
  final String? skin;

  @override
  State<SpaceActionGlyph> createState() => _SpaceActionGlyphState();
}

class _SpaceActionGlyphState extends State<SpaceActionGlyph>
    with GlyphClockLease {
  bool _visible = true;
  ShipGrains? _ship;

  @override
  bool get wantsClock =>
      _visible &&
      widget.lit &&
      widget.kind != SpaceAction.home &&
      widget.kind != SpaceAction.ship &&
      widget.kind != SpaceAction.raid &&
      widget.kind != SpaceAction.summon;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    _readShip();
  }

  void _readShip() {
    if (widget.kind != SpaceAction.ship) return;
    final skin = widget.skin;
    _ship = ShipGrains.now(skin);
    if (_ship != null) return;
    ShipGrains.of(skin).then((g) {
      if (mounted && widget.skin == skin) setState(() => _ship = g);
    }, onError: (_) {});
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
  void didUpdateWidget(covariant SpaceActionGlyph old) {
    super.didUpdateWidget(old);
    syncGlyphClock();
    if (old.skin != widget.skin || old.kind != widget.kind) _readShip();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == SpaceAction.summon) {
      return RaidBeaconGlyph(size: widget.size * 1.15);
    }
    return CustomPaint(
      size: Size.square(widget.size),
      painter: SpaceActionPainter(
        widget.kind,
        color: widget.color,
        cargo: widget.cargo,
        lit: widget.lit,
        skin: widget.skin,
        ship: _ship,
        clock: glyphClock,
      ),
    );
  }
}

class SpaceActionPainter extends CustomPainter {
  SpaceActionPainter(
    this.kind, {
    required this.color,
    this.cargo = const [],
    this.lit = true,
    this.skin,
    this.ship,
    this.clock,
    this.time,
  }) : super(repaint: clock);

  final SpaceAction kind;
  final Color color;
  final List<Color> cargo;
  final bool lit;
  final String? skin;
  final ShipGrains? ship;
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  static final GrainBatch _b = GrainBatch(8);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final t = time ?? clock?.value ?? 0;
    switch (kind) {
      case SpaceAction.deposit:
        _deposit(canvas, c, s, t);
      case SpaceAction.descend:
        _descend(canvas, c, s, t);
      case SpaceAction.home:
        _bead(canvas, c, s * 0.36, 1);
      case SpaceAction.ship:
        _ship(canvas, c, s, t);
      case SpaceAction.raid:
        paintRaidGlyph(canvas, c, s, color);
      case SpaceAction.summon:
        break; // its own widget
      case SpaceAction.gun:
        _gun(canvas, c, s, t);
      case SpaceAction.boost:
        _boost(canvas, c, s, t);
      case SpaceAction.missile:
        _missile(canvas, c, s, t);
      case SpaceAction.tether:
        _tether(canvas, c, s, t);
    }
  }

  /// A magnet of dark glass, its poles lit while it holds the party, their
  /// grains drawn in toward it (or drifting loose).
  void _tether(Canvas canvas, Offset c, double s, double t) {
    final m = stoneLightFor(color);
    final cx = c.dx;
    final outer = s * 0.36, inner = s * 0.15;
    final base = c.dy + s * 0.08, top = c.dy - s * 0.1;
    final magnet = Path()
      ..moveTo(cx - outer, top)
      ..lineTo(cx - outer, base)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, base), radius: outer),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(cx + outer, top)
      ..lineTo(cx + inner, top)
      ..lineTo(cx + inner, base)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, base), radius: inner),
        0,
        math.pi,
        false,
      )
      ..lineTo(cx - inner, top)
      ..close();
    final held = lit ? 1.0 : 0.0;
    // Its light pooled in the gap while it holds.
    if (lit) {
      paintDisc(canvas, m.leak, Offset(cx, top - s * 0.04), s * 0.36, 0.6);
    }
    _paint
      ..shader = ui.Gradient.linear(
        Offset(cx - outer, top),
        Offset(cx + outer, base + outer),
        [Color.lerp(m.face, m.rim, 0.25 + 0.2 * held)!, m.face, m.ink],
        const [0.0, 0.45, 1.0],
      )
      ..color = const Color(0xFF000000);
    canvas.drawPath(magnet, _paint);
    _paint.shader = null;
    // The poles: the legs' ends, lit with what it is holding.
    final legW = outer - inner;
    for (final side in const [-1.0, 1.0]) {
      final pole = Rect.fromLTWH(
        cx + side * (inner + legW / 2) - legW / 2,
        top,
        legW,
        s * 0.08,
      );
      _paint
        ..shader = ui.Gradient.linear(pole.topCenter, pole.bottomCenter, [
          Color.lerp(m.essence, Colors.white, 0.35 * held)!,
          Color.lerp(m.essence, m.ink, 0.5 + 0.3 * (1 - held))!,
        ])
        ..color = Color.fromRGBO(0, 0, 0, 0.45 + 0.55 * held);
      canvas.drawRect(pole, _paint);
      _paint.shader = null;
      if (lit) paintDisc(canvas, m.spark, pole.topCenter, s * 0.09, 0.8);
    }
    // The party: grains drawn down over the gap, or loose above it.
    final b = _b..clear();
    for (var i = 0; i < 5; i++) {
      final a = hash01(i, 21) * math.pi - math.pi;
      final far = s * (0.36 + 0.1 * hash01(i, 22));
      final ph = lit ? (t * 0.45 + i / 5) % 1.0 : 0.0;
      final pull = lit ? 1 - math.pow(1 - ph, 2).toDouble() : 0.0;
      final home = Offset(
        cx + (hash01(i, 23) - 0.5) * inner * 1.6,
        top - s * 0.1,
      );
      final loose = Offset(
        cx + math.cos(a) * far,
        top - s * 0.08 + math.sin(a) * far * 0.7,
      );
      final p = Offset.lerp(loose, home, pull * 0.85)!;
      b.add(lit && ph > 0.85 ? 1 : 0, p.dx, p.dy);
    }
    final dim = lit ? 1.0 : 0.5;
    b.draw(canvas, 0, s * 0.16, m.essence.withValues(alpha: 0.16 * dim));
    b.draw(canvas, 0, s * 0.09, m.grainHot.withValues(alpha: dim));
    b.draw(canvas, 1, s * 0.11, m.hot);
  }

  /// Bolts of light streaming up and out of a muzzle spark.
  void _gun(Canvas canvas, Offset c, double s, double t) {
    final m = stoneLightFor(color);
    final dim = lit ? 1.0 : 0.55;
    final muzzle = c + Offset(-s * 0.34, s * 0.36);
    const dir = Offset(0.62, -0.78);
    paintDisc(canvas, m.leak, muzzle, s * 0.32, 0.6 * dim);
    final b = _b..clear();
    // Three bolts a beat apart, each a short run of grains, hot at its head.
    for (var k = 0; k < 3; k++) {
      final ph = lit ? (t * 1.6 + k / 3) % 1.0 : 0.22 + k * 0.28;
      final head = muzzle + dir * (s * (0.14 + 0.8 * ph));
      final side = Offset(-dir.dy, dir.dx) * (s * (k - 1) * 0.09);
      for (var j = 0; j < 8; j++) {
        final p = head - dir * (j * s * 0.026) + side;
        b.add(j == 0 ? 0 : (j < 4 ? 1 : 2), p.dx, p.dy);
      }
    }
    b.draw(canvas, 0, s * 0.18, m.essence.withValues(alpha: 0.2 * dim));
    b.draw(canvas, 2, s * 0.05, m.grainDim.withValues(alpha: 0.5 * dim));
    b.draw(canvas, 1, s * 0.065, m.grainHot.withValues(alpha: 0.85 * dim));
    b.draw(canvas, 0, s * 0.085, m.hot.withValues(alpha: dim));
    paintDisc(
      canvas,
      m.spark,
      muzzle,
      s * (lit ? 0.17 + 0.04 * math.sin(t * 40) : 0.13),
      dim,
    );
  }

  /// An engine's nozzle and its plume of grains pouring down and out.
  void _boost(Canvas canvas, Offset c, double s, double t) {
    final m = stoneLightFor(color);
    final burn = lit ? 1.0 : 0.0;
    final nozzle = c + Offset(0, -s * 0.36);
    final b = _b..clear();
    final n = lit ? 48 : 22;
    final reach = s * (0.56 + 0.22 * burn);
    for (var i = 0; i < n; i++) {
      final ph = lit ? (t * 2.2 + hash01(i, 11)) % 1.0 : hash01(i, 11) * 0.75;
      final spread = (hash01(i, 12) - 0.5) * s * (0.08 + 0.44 * ph);
      final p = nozzle + Offset(spread, s * 0.06 + reach * ph);
      b.add(ph < 0.3 ? 0 : (ph < 0.65 ? 1 : 2), p.dx, p.dy);
    }
    final dim = lit ? 1.0 : 0.6;
    paintDisc(
      canvas,
      m.leak,
      nozzle + Offset(0, reach * 0.4),
      reach * 0.75,
      0.45 * dim,
    );
    b.draw(canvas, 0, s * 0.16, m.essence.withValues(alpha: 0.14 * dim));
    b.draw(canvas, 2, s * 0.045, m.grainDim.withValues(alpha: 0.5 * dim));
    b.draw(canvas, 1, s * 0.055, m.essence.withValues(alpha: 0.85 * dim));
    b.draw(canvas, 0, s * 0.065, m.grainHot.withValues(alpha: dim));
    // The nozzle: a bead of the engine's light, flickering as it burns.
    final flick = lit ? 0.85 + 0.15 * math.sin(t * 31) * math.sin(t * 7) : 0.7;
    paintDisc(canvas, m.spark, nozzle, s * 0.2 * flick, dim);
  }

  /// A dart curving in on its target, a trail of grains behind it.
  void _missile(Canvas canvas, Offset c, double s, double t) {
    final m = stoneLightFor(color);
    final dim = lit ? 1.0 : 0.6;
    final target = c + Offset(s * 0.34, -s * 0.34);
    final from = c + Offset(-s * 0.4, s * 0.38);
    final bend = c + Offset(-s * 0.36, -s * 0.24);
    Offset at(double u) {
      final v = 1 - u;
      return from * (v * v) + bend * (2 * v * u) + target * (u * u);
    }

    // The target: a small light it is homing on.
    paintDisc(canvas, m.leak, target, s * 0.24, 0.55 * dim);
    paintDisc(canvas, m.spark, target, s * 0.1, 0.8 * dim);
    final u = lit ? (t * 0.9) % 1.0 * 0.82 : 0.62;
    final b = _b..clear();
    for (var k = 1; k <= 14; k++) {
      final q = u - k * 0.04;
      if (q < 0) break;
      final p =
          at(q) +
          Offset(hash01(k, 2) - 0.5, hash01(k, 3) - 0.5) * (s * 0.04 * k / 9);
      b.add(k < 4 ? 1 : 2, p.dx, p.dy);
    }
    b.draw(canvas, 2, s * 0.05, m.grainDim.withValues(alpha: 0.55 * dim));
    b.draw(canvas, 1, s * 0.065, m.grainHot.withValues(alpha: 0.85 * dim));
    // The dart, nose along its way.
    final head = at(u);
    final ahead = at(math.min(1.0, u + 0.02)) - head;
    final ang = math.atan2(ahead.dy, ahead.dx);
    final r = s * 0.17;
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(ang);
    final dart = Path()
      ..moveTo(r * 1.4, 0)
      ..lineTo(-r * 0.9, -r * 0.62)
      ..lineTo(-r * 0.45, 0)
      ..lineTo(-r * 0.9, r * 0.62)
      ..close();
    _paint
      ..shader = ui.Gradient.linear(
        Offset(-r, -r),
        Offset(r, r),
        [m.hot, m.essence, Color.lerp(m.essence, Colors.black, 0.5)!],
        const [0.0, 0.45, 1.0],
      )
      ..color = Color.fromRGBO(0, 0, 0, dim);
    canvas.drawPath(dart, _paint);
    _paint.shader = null;
    canvas.restore();
    paintDisc(
      canvas,
      m.spark,
      head - Offset(math.cos(ang), math.sin(ang)) * r * 0.6,
      s * 0.08,
      dim,
    );
  }

  /// Home's bead: a sphere in its color lit from the upper left, bright
  /// enough to read at a button's size, its light round it.
  void _bead(Canvas canvas, Offset at, double r, double alpha) {
    final m = stoneLightFor(color);
    paintDisc(canvas, m.leak, at, r * 2.2, 0.8 * alpha);
    _paint
      ..shader = ui.Gradient.radial(
        at + Offset(-r * 0.38, -r * 0.42),
        r * 1.5,
        [
          Color.lerp(color, Colors.white, 0.7)!,
          Color.lerp(color, Colors.white, 0.15)!,
          color,
          Color.lerp(color, Colors.black, 0.55)!,
        ],
        const [0.0, 0.25, 0.55, 1.0],
      )
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    canvas.drawCircle(at, r, _paint);
    _paint.shader = null;
    paintDisc(
      canvas,
      kGlint,
      at + Offset(-r * 0.36, -r * 0.42),
      r * 0.28,
      0.8 * alpha,
    );
  }

  static final Paint _paint = Paint();

  /// The cargo falling into home.
  void _deposit(Canvas canvas, Offset c, double s, double t) {
    final bead = c + Offset(0, s * 0.17);
    final r = s * 0.3;
    _bead(canvas, bead, r, lit ? 1 : 0.55);
    if (!lit) return;
    final colors = cargo.isEmpty ? const [Color(0xFFE4C16A)] : cargo;
    final b = _b..clear();
    const n = 6;
    final top = c.dy - s * 0.46;
    for (var i = 0; i < n; i++) {
      final ph = (t * 0.7 + i / n) % 1.0;
      final from = (hash01(i, 3) - 0.5) * s * 0.5;
      final fall = ph * ph;
      final y = top + (bead.dy - r * 0.6 - top) * fall;
      final x = c.dx + from * (1 - fall);
      // Bucket by color (up to 6), and the last moments in the fade one.
      b.add(ph > 0.88 ? 7 : i % math.min(colors.length, 6), x, y);
    }
    for (var k = 0; k < math.min(colors.length, 6); k++) {
      final col = Color.lerp(colors[k], Colors.white, 0.25)!;
      b.draw(canvas, k, s * 0.2, col.withValues(alpha: 0.2));
      b.draw(canvas, k, s * 0.11, col);
    }
    b.draw(canvas, 7, s * 0.07, Colors.white.withValues(alpha: 0.5));
  }

  /// A grain diving into a planet's face.
  void _descend(Canvas canvas, Offset c, double s, double t) {
    final m = stoneLightFor(color);
    // The planet's face below: the top of a big sphere, lit along its
    // limb and falling away into the dark beneath — a horizon, not a dome.
    final pr = s * 0.9;
    final pc = c + Offset(0, s * 0.3 + pr);
    final surface = pc.dy - pr;
    final box = Rect.fromLTRB(
      c.dx - s * 0.8,
      c.dy - s * 0.8,
      c.dx + s * 0.8,
      c.dy + s * 0.8,
    );
    canvas.saveLayer(box, Paint());
    paintDisc(canvas, m.leak, Offset(c.dx, surface), s * 0.5, 0.7);
    _paint.shader = ui.Gradient.radial(
      Offset(c.dx - pr * 0.25, surface + pr * 0.15),
      pr * 1.1,
      [
        Color.lerp(color, Colors.white, 0.45)!,
        color,
        Color.lerp(color, Colors.black, 0.6)!,
      ],
      const [0.0, 0.35, 1.0],
    );
    _paint.color = const Color(0xFF000000);
    canvas.drawCircle(pc, pr, _paint);
    // Falling away into the dark below and to either side, so it stays
    // inside its tile however wide the planet is.
    _paint
      ..shader = ui.Gradient.radial(
        Offset(c.dx, surface),
        s * 0.52,
        const [Color(0xFF000000), Color(0x99000000), Color(0x00000000)],
        const [0.0, 0.5, 1.0],
      )
      ..blendMode = BlendMode.dstIn;
    canvas.drawRect(box.inflate(4), _paint);
    _paint
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    canvas.restore();
    // The dive: a head and its trail, coming down to the surface and going
    // into it with a little light.
    final ph = lit ? (t * 0.75) % 1.0 : 0.62;
    final b = _b..clear();
    final top = c.dy - s * 0.5;
    final y = top + (surface - top) * math.min(1.0, ph / 0.8);
    if (ph < 0.8) {
      for (var k = 0; k < 5; k++) {
        final ty = y - k * s * 0.07;
        if (ty < top) break;
        b.add(k == 0 ? 0 : (k < 3 ? 1 : 2), c.dx, ty);
      }
    }
    b.draw(canvas, 2, s * 0.06, m.grainDim.withValues(alpha: 0.45));
    b.draw(canvas, 1, s * 0.075, m.grainHot.withValues(alpha: 0.75));
    b.draw(canvas, 0, s * 0.18, m.essence.withValues(alpha: 0.22));
    b.draw(canvas, 0, s * 0.1, m.hot);
    // Where it goes in.
    final splash = ph < 0.8 ? 0.0 : 1 - (ph - 0.8) / 0.2;
    final glow = lit ? 0.35 + 0.65 * splash : 0.5;
    paintDisc(
      canvas,
      m.spark,
      Offset(c.dx, surface + s * 0.02),
      s * 0.16,
      glow,
    );
  }

  /// The hull the player flies, nose up, in its grains.
  void _ship(Canvas canvas, Offset c, double s, double t) {
    final grains = ship;
    final light = shipLight(skin);
    final pose = ShipPose(c + Offset(0, s * 0.04), s * 0.85 / 45, 0);
    if (grains != null) {
      paintShipGrains(canvas, grains, light, pose, t);
      return;
    }
    canvas.save();
    canvas.translate(pose.at.dx, pose.at.dy);
    canvas.scale(pose.scale);
    paintShipHull(canvas, skin, t);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpaceActionPainter old) =>
      old.kind != kind ||
      old.color != color ||
      !listEquals(old.cargo, cargo) ||
      old.lit != lit ||
      old.skin != skin ||
      old.ship != ship ||
      old.clock != clock ||
      old.time != time;
}
