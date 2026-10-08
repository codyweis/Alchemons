// lib/games/planet_dungeon/planet_dungeon_game_mud_art.dart
//
// PALUSIA, IN GLASS (docs/dungeons.md §7.11) — Mud's banks and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// The fen is open ground, so its carved edge is BANKED PEAT rather than a
// wall (the same shell, in earth). The bog itself — fords, plank roads,
// knolls, the heave and the settle, all of the 2026-09-13 pass — is untouched.
// The glass:
//
//   · a moor-altar's offering is a pane of still water in the bowl — the sky
//     in it while the knoll stands dry-footed, a smoked empty bowl while it
//     drinks the water away;
//   · and NO MUD, NO LOTUS — the maxim — comes up as a lotus of leaded pink
//     glass, its petals opening in turn as the rite binds, and it stays open
//     on every later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kPeatGlass = kPeatGlass;

final Map<String, ui.Picture> _bogShellCache = {};

extension SinkingAltarArt on PlanetDungeonGame {
  void _updateMudGlass(double dt) {
    final target =
        discoveredClouds.contains(kMudNoLotusEggId) ||
            _ritePendingEgg == kMudNoLotusEggId
        ? 1.0
        : 0.0;
    if (_lotusOpen < 0) {
      _lotusOpen = target;
    } else if (_lotusOpen < target) {
      _lotusOpen = min(target, _lotusOpen + dt / 2.6);
    } else if (_lotusOpen > target) {
      _lotusOpen = target;
    }
    // The crossings' glass follows the fen, a pane at a time.
    for (final ford in kBogFords) {
      final st = _fen.stateOf(ford.id);
      final ts = st == BogFordState.sod ? 1.0 : 0.0;
      final td = st == BogFordState.drowned ? 1.0 : 0.0;
      final was = _fordGlass[ford.id];
      if (was == null) {
        _fordGlass[ford.id] = (ts, td);
        continue;
      }
      double ease(double v, double to) =>
          v < to ? min(to, v + dt / 1.1) : max(to, v - dt / 1.1);
      _fordGlass[ford.id] = (ease(was.$1, ts), ease(was.$2, td));
    }
  }

  /// A CROSSING'S GLASS — the state of the ground, in a leaded strip down its
  /// spine. Murky and quaking while it is mire; clear moss-glass laid flat,
  /// streaked, once it is dragged to sod; sunk, cracked and smoked once it
  /// drowns. A drag runs down the strip from the head you worked it at, pane
  /// after pane, so the change is watched rather than swapped.
  void _drawFordGlass(
    Canvas canvas,
    BogFord ford,
    Offset Function(double) at,
    Offset norm,
  ) {
    final (s, d) = _fordGlass[ford.id] ?? (0.0, 0.0);
    const n = 7;
    const t0 = 0.16, t1 = 0.84;
    const murk = Color(0xFF3B4429);
    const clear = Color(0xFFA6B77C);
    const sunk = Color(0xFF12292E);
    for (var i = 0; i < n; i++) {
      final lead = i / (n - 1);
      final ks = (s * 1.6 - lead * 0.6).clamp(0.0, 1.0);
      final kd = (d * 1.6 - lead * 0.6).clamp(0.0, 1.0);
      final quake = (1 - ks) * (1 - kd) * 1.6;
      final wA = 8.5 * (1 - kd * 0.18), wB = wA;
      Offset corner(double t, double side, int k) {
        final wob = sin(bog.clock * 1.7 + i * 1.3 + k * 2.1) * quake;
        return at(t) + norm * (side * (side > 0 ? wA : wB) + wob);
      }

      final ta = t0 + (t1 - t0) * i / n;
      final tb = t0 + (t1 - t0) * (i + 1) / n;
      final a = corner(ta, 1, 0), b = corner(tb, 1, 1);
      final c = corner(tb, -1, 2), e = corner(ta, -1, 3);
      final pane = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(e.dx, e.dy)
        ..close();
      final tone = Color.lerp(
        Color.lerp(Color.lerp(murk, _kPeatGlass.frostAt(i), 0.35), clear, ks),
        sunk,
        kd,
      )!;
      paintPane(
        canvas,
        pane,
        tone,
        _kPeatGlass,
        lead: 1.7,
        opacity: 0.92 - kd * 0.3,
      );
      if (ks > 0) {
        paintStreak(canvas, pane.getBounds().deflate(2), opacity: ks * 0.55);
      }
      if (kd > 0) {
        // Cracked across as it went under.
        canvas.drawLine(
          Offset.lerp(a, e, 0.3)!,
          Offset.lerp(b, c, 0.75)!,
          Paint()
            ..strokeWidth = 1.1
            ..color = _kPeatGlass.leadLight.withValues(alpha: 0.28 * kd),
        );
      }
      // The pane being set catches the light as it takes.
      final setting = ks * (1 - ks) * 4;
      if (setting > 0.05 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at((ta + tb) / 2),
          26,
          _kPeatGlass.live.withValues(alpha: 0.45 * setting),
        );
      }
    }
  }

  /// The fen's banks: peat, baked once per room.
  void _renderBogShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _bogShellCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          paintCarvedRoomShell(
            Canvas(rec),
            b,
            _kPeatGlass,
            GlassRng(glassSeed(room.id, b)),
            doors: room.doors.map((d) => d.rect),
            arcade: false,
            flags: false,
            faceDepth: 30,
          );
          return rec.endRecording();
        },
      ),
    );
  }

  /// A moor-altar's bowl, as glass: still water with the sky in it while it
  /// holds, smoked and empty while the ground drinks it.
  void _drawOfferingGlass(Canvas canvas, Rect bowl, {required bool holding}) {
    final pane = Path()..addOval(bowl);
    paintPane(
      canvas,
      pane,
      holding
          ? _kPeatGlass.heat(0.45 + 0.05 * sin(bog.clock * 1.2))
          : _kPeatGlass.smoke,
      _kPeatGlass,
      lead: 1.8,
    );
    if (holding) {
      paintStreak(canvas, bowl.deflate(bowl.height * 0.25), opacity: 0.6);
    }
  }

  /// NO MUD, NO LOTUS. A lotus of leaded pink glass come up through the
  /// thickest peat in the fane — the outer petals opening first, the inner
  /// after, the heart last — and open for good.
  void _drawGlassLotus(Canvas canvas, Offset c) {
    final o = _lotusOpen.clamp(0.0, 1.0);
    if (o <= 0) return;
    // Big enough to find across the fane: it is the room's trophy.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1.9);
    canvas.translate(-c.dx, -c.dy);
    _drawGlassLotusBody(canvas, c, o);
    canvas.restore();
  }

  void _drawGlassLotusBody(Canvas canvas, Offset c, double o) {
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        40 + 24 * o,
        const Color(
          0xFFF2D7E6,
        ).withValues(alpha: o < 1 ? 0.35 * o : 0.18 + 0.05 * sin(bog.clock)),
      );
    }
    // Two rings of petals: eight outer, five inner.
    for (final (n, r, ry, w, delay, tone) in const [
      (8, 22.0, 12.0, 15.0, 0.0, Color(0xFFE8B8D0)),
      (5, 12.0, 7.0, 11.0, 0.3, Color(0xFFF6D8E8)),
    ]) {
      for (var i = 0; i < n; i++) {
        final k = ((o - delay - i * 0.03) / 0.45).clamp(0.0, 1.0);
        if (k <= 0) continue;
        final a = i / n * 2 * pi + delay;
        final tip = c + Offset(cos(a) * r * k, sin(a) * ry * k - 6 * k);
        final base = c + Offset(cos(a) * 3, sin(a) * 2);
        final side = Offset(-sin(a), cos(a) * 0.55) * (w * 0.5 * k);
        final petal = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            (base + tip).dx / 2 + side.dx,
            (base + tip).dy / 2 + side.dy,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            (base + tip).dx / 2 - side.dx,
            (base + tip).dy / 2 - side.dy,
            base.dx,
            base.dy,
          )
          ..close();
        paintPane(canvas, petal, tone, _kPeatGlass, lead: 1.5);
      }
    }
    final heart = ((o - 0.7) / 0.3).clamp(0.0, 1.0);
    if (heart > 0) {
      paintRondel(
        canvas,
        c - const Offset(0, 4),
        6 * heart,
        _kPeatGlass,
        fill: const Color(0xFFF7E9A8),
        lead: 1.4,
      );
    }
  }

  /// A WALLOW, as a hatch in the fen: a peat-stone collar and a round leaded
  /// lid. Smoked and dead while it will not take you; still water with the
  /// light in it, turning slowly, while it will.
  void _drawWallowHatch(Canvas canvas, Rect r, {required bool open}) {
    final c = r.center;
    final rx = r.width * 0.62, ry = r.height * 0.40;
    paintCarvedDisc(canvas, c, rx, ry, 7, _kPeatGlass);
    final lid = Rect.fromCenter(center: c, width: rx * 1.52, height: ry * 1.52);
    final spin = open ? bog.clock * 0.25 : 0.0;
    for (var i = 0; i < 6; i++) {
      final a0 = spin + i * pi / 3, a1 = a0 + pi / 3;
      final pane = ellipseSectorPath(
        c,
        lid.width * 0.14,
        lid.height * 0.14,
        lid.width / 2,
        lid.height / 2,
        a0,
        a1,
      );
      paintPane(
        canvas,
        pane,
        open
            ? Color.lerp(
                _kPeatGlass.liveDeep,
                _kPeatGlass.live,
                0.25 + 0.2 * sin(bog.clock * 1.1 + i),
              )!
            : Color.lerp(_kPeatGlass.smoke, _kPeatGlass.frostAt(i), 0.4)!,
        _kPeatGlass,
        lead: 1.6,
      );
    }
    paintRondel(
      canvas,
      c,
      lid.height * 0.13,
      _kPeatGlass,
      fill: open ? _kPeatGlass.liveCore : _kPeatGlass.smoke,
      rim: open ? 1 : 0.35,
      lead: 1.6,
    );
    if (open) {
      paintStreak(canvas, lid.deflate(4), opacity: 0.5);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          rx * 1.4,
          _kPeatGlass.live.withValues(alpha: 0.16),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────
// THE PROPS, AGAIN (2026-10-08)
// ─────────────────────────────────────────────────────────
// The fen's banks, pools and crossings are untouched; its props were still
// clip-art next to a game that had moved on to lit grains on black: plank
// roads drawn as ladders, Y-shaped dead trees, grey signboard stones with
// icons on them, a pale obelisk, a sarsen with polka-dot moss, lily-pad
// hummocks, pale stroked ribs, circle bubbles. The rules now:
//
//   · FEN WATER'S BREATH — bubbles, silt, the cotton's seed — is GRAINS.
//   · SOLID THINGS (stones, boards, bog-oak, bones) are FEWER, DARKER CARVED
//     SILHOUETTES in peat-black, lit only at the rim by the fen's cold dusk
//     light. No pale fills, no outlines.
//   · WHAT YOU READ keeps its signal in leaded glass: a crossing's strip, a
//     marker stone's watercourse rondel, an altar's offering (§7.11).
//
// COST. Still props are baked once per room; the only live grains are the
// ones that move (a wallow's bubbles, the silt going up, the cotton).

/// A dark carved silhouette's body, in peat-black: its top and its foot.
const Color _kFenSilTop = Color(0xFF221D16);
const Color _kFenSilFoot = Color(0xFF080706);

/// The fen's light, caught on a rim: cold dusk over the water.
const Color _kFenRim = Color(0xFFA9B59A);

final Map<String, ui.Picture> _fenStillCache = {};

/// The entry rite's weed mat: its grains and the haze under them.
final Map<String, (GrainShape, ui.Picture)> _fenWeedCache = {};

/// A still prop, painted once and kept.
ui.Picture _fenStill(String key, void Function(Canvas c) paint) =>
    _fenStillCache.putIfAbsent(key, () {
      final rec = ui.PictureRecorder();
      paint(Canvas(rec));
      return rec.endRecording();
    });

/// A DARK CARVED SILHOUETTE: the body in peat-black, and the fen's light on
/// it only where the shape faces that light — the crescent the body leaves
/// when it is nudged away from the light. A rim, no outline, no blur.
void _fenCarve(
  Canvas c,
  Path body, {
  Offset light = const Offset(1.8, 2.4),
  double rim = 0.45,
  Color rimColor = _kFenRim,
  Color top = _kFenSilTop,
  Color foot = _kFenSilFoot,
}) {
  final b = body.getBounds();
  c.drawPath(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, foot],
      ).createShader(b.inflate(1)),
  );
  c.drawPath(
    Path.combine(ui.PathOperation.difference, body, body.shift(light)),
    Paint()..color = rimColor.withValues(alpha: rim),
  );
}

/// A cut in a dark surface: the cut, and the light on its lip.
void _fenGroove(Canvas c, Path p, {double w = 1.5}) {
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.6),
  );
  c.drawPath(
    p.shift(const Offset(0, 1.1)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = _kFenRim.withValues(alpha: 0.12),
  );
}

/// A tapering limb or rib from [a] through [ctrl] to [b], [w0] wide at its
/// root and [w1] at its tip, as a closed outline.
Path _fenTaper(Offset a, Offset ctrl, Offset b, double w0, double w1) {
  final left = <Offset>[], right = <Offset>[];
  const n = 10;
  for (var k = 0; k <= n; k++) {
    final t = k / n;
    final p = Offset.lerp(
      Offset.lerp(a, ctrl, t)!,
      Offset.lerp(ctrl, b, t)!,
      t,
    )!;
    final d =
        Offset.lerp(ctrl - a, b - ctrl, t)! /
        max(1e-6, Offset.lerp(ctrl - a, b - ctrl, t)!.distance);
    final nrm = Offset(-d.dy, d.dx);
    final w = (w0 + (w1 - w0) * t) / 2;
    left.add(p + nrm * w);
    right.add(p - nrm * w);
  }
  return Path()..addPolygon([...left, ...right.reversed], true);
}

/// LOOSE GRAINS worked out from time alone — bubbles, silt, cotton seed —
/// bucketed by colour and drawn in a handful of calls, each a short streak
/// from where it was a moment ago.
class _FenInk {
  final Map<int, List<Offset>> _runs = {};

  void add(Offset from, Offset to, Color c, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 10).round();
    if (a <= 0) return;
    final k = ((c.toARGB32() & 0x00FFFFFF) << 4) | a;
    final f = (to - from).distance < 0.3 ? from - const Offset(0.3, 0) : from;
    (_runs[k] ??= <Offset>[])
      ..add(f)
      ..add(to);
  }

  void paint(Canvas canvas, {double width = 1.6}) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    for (final e in _runs.entries) {
      if (e.value.isEmpty) continue;
      p.color = Color(
        0xFF000000 | (e.key >> 4),
      ).withValues(alpha: (e.key & 15) / 10);
      canvas.drawPoints(ui.PointMode.lines, e.value, p);
      e.value.clear();
    }
  }
}

final _FenInk _fenInk = _FenInk();

double _fenHash(int n) {
  final v = sin(n * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}
