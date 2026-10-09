// lib/games/planet_dungeon/planet_dungeon_game_dark_art.dart
//
// NYTHRALOR — THE BLACK SUN, drawn. The rooms are carved slabs of dark stone
// hanging over the void, and the void is a real hole: the planet's black
// hole shows through it. Glass only on puzzle things (§7.11) — obsidian
// panes that take a portal, rondel seals, the burning-glass, the doors, and
// the blood bridges, which are panes of red glass laid over nothing.
//
// THE PORTALS are the point. A mouth is a black sun set in an obsidian face:
// a pool of its Dark's color spilling onto the floor in front of it, an
// accretion disc of filled, tapered arms turning into it (brighter on one
// side, the way a real one is), motes spiralling down, and — while its pair
// is whole — a WINDOW: the other end's room, seen through it, bodies and
// beams and all. Casting throws a comet of color at the wall and the mouth
// tears open from a slit; walking through one pulls you in and throws you
// out of the other.
//
// COST. Every room's stone and glass are baked once into a ui.Picture (the
// same picture is the window's view). Per frame: the beams (a few rects and
// motes each), the bridges, the seals and doors that change, the mouths
// (each one clipped draw of a baked room), and whatever moment is playing.
// Material, never lines; no blur anywhere.

part of 'planet_dungeon_game.dart';

const GlassPalette _kSunStone = kUmbraGlass;

/// The walls: near-black carved stone, lit only at the arris — a dark planet
/// whose light is what you bring (mid-tone stone read as a cheap block).
const GlassPalette _kSunWall = GlassPalette(
  lead: Color(0xFF050408),
  leadLight: Color(0xFFC8B8E8),
  frost: [
    Color(0xFF26222E),
    Color(0xFF2C2836),
    Color(0xFF221E2A),
    Color(0xFF322C3C),
    Color(0xFF2A2532),
  ],
  liveDeep: Color(0xFF3A2462),
  live: Color(0xFF9A74D8),
  liveCore: Color(0xFFF0E8FF),
  smoke: Color(0xFF0B0A12),
  silver: Color(0xFFE2DEEC),
  gold: Color(0xFFE0B15C),
  goldDeep: Color(0xFF6B5A2E),
  stoneTop: Color(0xFF2A2633),
  stoneFace: Color(0xFF15131B),
  stoneFoot: Color(0xFF040307),
  floor: Color(0xFF24222C),
  floorAlt: Color(0xFF1E1C26),
  joint: Color(0xFF050408),
);

/// Baked rooms, keyed on room id.
final Map<String, ui.Picture> _sunBakeCache = {};

/// Each portal end's black hole (and the arena's), kept: their motes have
/// orbits.
final Map<String, BlackHoleArt> _sunHoles = {};

const Color _kSunPurple = Color(0xFFA77BFF);
const Color _kSunPurpleHot = Color(0xFFC6A2FF);
const Color _kSunOrange = Color(0xFFFF9A3D);
const Color _kSunOrangeHot = Color(0xFFFFBE6E);
const Color _kSunWhite = Color(0xFFFFF4DC);
const Color _kSunWhiteGlow = Color(0xFFFFE3A0);
const Color _kSunBlood = Color(0xFFD8354B);
const Color _kSunBloodHot = Color(0xFFFFC4C4);
const Color _kSunBronze = Color(0xFF8A6A36);
const Color _kSunGold = Color(0xFFD6B25E);

Color _sunOwnerColor(String o) => o == 'purple' ? _kSunPurple : _kSunOrange;
Color _sunOwnerHot(String o) => o == 'purple' ? _kSunPurpleHot : _kSunOrangeHot;

double _sunEase(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

double _sunHash(int n) {
  final s = sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

extension BlackSunArt on PlanetDungeonGame {
  void _updateDarkGlass(double dt) {
    if (!_isVault) return;
    // Doors in the rooms slide open and shut on their own clock.
    final e = _sunEval;
    final k = 1 - pow(0.0005, dt).toDouble();
    for (final d in kSunRooms.values) {
      for (final c in d.doors) {
        final key = sunKey(d.id, c.x, c.y);
        final want = e.open.contains(key) ? 1.0 : 0.0;
        final was = blackSun.doorShown[key] ?? want;
        blackSun.doorShown[key] = was + (want - was) * k;
      }
    }
  }

  // ═══════════════════════════ THE BAKE ═════════════════════════════════

  ui.Picture _sunBake(String roomId) => _sunBakeCache.putIfAbsent(roomId, () {
    final rec = ui.PictureRecorder();
    _sunBakeRoom(Canvas(rec), kSunRooms[roomId]!);
    return rec.endRecording();
  });

  bool _sunFloorish(String c) => '.pE*VDS|'.contains(c);

  void _sunBakeRoom(Canvas c, SunRoomDef def) {
    // The floor slabs first, with their cut edges where they meet the void.
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        final ch = def.at(x, y);
        final r = Rect.fromLTWH(x * kSunCell, y * kSunCell, kSunCell, kSunCell);
        if (_sunFloorish(ch)) _sunFlag(c, r, x * 31 + y * 17 + def.id.length);
      }
    }
    // Where floor meets the void: a lit lip on top, and a dark face falling
    // away under it — the slab hangs over nothing.
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        if (def.at(x, y) != '~') continue;
        final r = Rect.fromLTWH(x * kSunCell, y * kSunCell, kSunCell, kSunCell);
        // Floor to the north: its front face hangs down into this square.
        if (_sunFloorish(def.at(x, y - 1)) || def.at(x, y - 1) == '#') {
          c.drawRect(
            Rect.fromLTWH(r.left, r.top, r.width, 14),
            Paint()
              ..shader = ui.Gradient.linear(
                r.topLeft,
                r.topLeft + const Offset(0, 14),
                [const Color(0xFF1A1822), const Color(0x001A1822)],
              ),
          );
        }
      }
    }
    // Stone, obsidian, seals, stars: the walls.
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        final ch = def.at(x, y);
        final r = Rect.fromLTWH(x * kSunCell, y * kSunCell, kSunCell, kSunCell);
        switch (ch) {
          case '#':
          case '>':
          case '<':
          case '^':
          case 'v':
          case 'w':
          case 'r':
            paintCarvedBlock(
              c,
              Rect.fromLTRB(r.left, r.top - 8, r.right, r.bottom - 16),
              16,
              _kSunWall,
              radius: 1,
            );
            // A faint coursing joint across the block's top.
            c.drawRect(
              Rect.fromLTWH(r.left + 3, r.top + 12 + (x % 2) * 8, r.width - 6, 1),
              Paint()..color = Colors.black.withValues(alpha: .45),
            );
          case 'O':
            _sunObsidian(c, r, def, x, y);
        }
      }
    }
    // Floor furniture.
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        final ch = def.at(x, y);
        final cc = sunCentre(x, y);
        switch (ch) {
          case '*':
            // The burning-glass: a clear lens in a bronze ring.
            c.drawCircle(cc, 23, Paint()..color = const Color(0xFF3A2A18));
            c.drawCircle(
              cc,
              19,
              Paint()
                ..shader = ui.Gradient.radial(
                  cc - const Offset(6, 6),
                  22,
                  [const Color(0xFFE8E2D0), const Color(0xFF5E5A66)],
                ),
            );
            c.drawCircle(cc, 19, Paint()..color = const Color(0x55000000));
            paintStreak(c, Rect.fromCircle(center: cc, radius: 12), opacity: .5);
          case 'p':
            paintCarvedDisc(c, cc, 22, 12, 5, _kSunStone);
            c.drawOval(
              Rect.fromCenter(center: cc, width: 28, height: 14),
              Paint()..color = const Color(0xFF2A2230),
            );
          case 'E':
            // Gold inlay: where the three of you must stand.
            final band = Paint()..color = _kSunGold.withValues(alpha: .55);
            bool g(int dx, int dy) => def.at(x + dx, y + dy) == 'E';
            final r = Rect.fromCenter(center: cc, width: kSunCell, height: kSunCell);
            c.drawRect(r, Paint()..color = _kSunGold.withValues(alpha: .08));
            if (!g(-1, 0)) c.drawRect(Rect.fromLTWH(r.left, r.top, 3, r.height), band);
            if (!g(1, 0)) c.drawRect(Rect.fromLTWH(r.right - 3, r.top, 3, r.height), band);
            if (!g(0, -1)) c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 3), band);
            if (!g(0, 1)) c.drawRect(Rect.fromLTWH(r.left, r.bottom - 3, r.width, 3), band);
            for (var i = 0; i < 8; i++) {
              final a = i * pi / 4;
              final dir = Offset(cos(a), sin(a));
              final n = Offset(-dir.dy, dir.dx) * 2.5;
              final tip = cc + dir * (i.isEven ? 13.0 : 8.0);
              c.drawPath(
                Path()
                  ..moveTo(cc.dx + n.dx, cc.dy + n.dy)
                  ..lineTo(tip.dx, tip.dy)
                  ..lineTo(cc.dx - n.dx, cc.dy - n.dy)
                  ..close(),
                band,
              );
            }
          case 'S':
            // The island's stair: steps going down into the dark.
            for (var i = 0; i < 5; i++) {
              final w = 44.0 - i * 6;
              c.drawRect(
                Rect.fromCenter(center: cc + Offset(0, -14 + i * 7.0), width: w, height: 6),
                Paint()..color = Color.lerp(const Color(0xFF3A3644), Colors.black, i / 5)!,
              );
            }
        }
      }
    }
  }

  /// One flag of dark stone, with its own tint and a lit top edge.
  void _sunFlag(Canvas c, Rect r, int seed) {
    final t = _sunHash(seed);
    c.drawRect(r, Paint()..color = Color.lerp(_kSunStone.floor, _kSunStone.floorAlt, t)!);
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 1.5),
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    final joint = Paint()..color = _kSunStone.joint.withValues(alpha: 0.7);
    c.drawRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 1), joint);
    c.drawRect(Rect.fromLTWH(r.right - 1, r.top, 1, r.height), joint);
    // A faint vein of violet in some stones.
    if (seed % 5 == 0) {
      c.drawRect(
        Rect.fromLTWH(r.left + r.width * .2, r.top + r.height * (.3 + .4 * t), r.width * .6, 1),
        Paint()..color = _kSunPurple.withValues(alpha: .06),
      );
    }
  }

  /// An obsidian block: black glass in a bronze frame, lit at its edge.
  void _sunObsidian(Canvas c, Rect r, SunRoomDef def, int x, int y) {
    final top = Rect.fromLTRB(r.left, r.top - 8, r.right, r.bottom - 16);
    paintCarvedBlock(c, top, 16, _kSunWall, radius: 1, topColor: const Color(0xFF15121C));
    final pane = top.deflate(5);
    c.drawRect(pane, Paint()..color = const Color(0xFF07060B));
    c.drawRect(
      pane,
      Paint()
        ..shader = ui.Gradient.linear(
          pane.topLeft,
          pane.bottomRight,
          [
            const Color(0x44B8A4E8),
            const Color(0x00000000),
            const Color(0x22D8C8FF),
            const Color(0x00000000),
          ],
          const [0, .45, .55, 1],
        ),
    );
    paintLead(c, Path()..addRect(pane), _kSunStone, width: 2.2, opacity: .9);
    c.drawRect(
      pane.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _kSunBronze.withValues(alpha: .8),
    );
    // Its faces that can take a portal glint on the floor side.
    for (var d = 0; d < 4; d++) {
      if (def.faceAt(x, y, d) == null) continue;
      final m = sunCentre(x, y) + Offset(kSunDx[d] * 30.0, kSunDy[d] * 30.0);
      final along = kSunDx[d] == 0;
      c.drawRect(
        Rect.fromCenter(center: m, width: along ? 40 : 3, height: along ? 3 : 40),
        Paint()..color = const Color(0x33C8B8E8),
      );
    }
  }

  // ═══════════════════════════ LIVE ═════════════════════════════════════

  void _renderVault(Canvas canvas, DungeonRoom room) {
    final def = room.sun?.def;
    if (def == null) {
      _renderSunArena(canvas, room);
      return;
    }
    final e = _sunEval;
    canvas.drawPicture(_sunBake(def.id));
    _renderSunVoid(canvas, def, e);
    _renderSunStars(canvas, def);
    _renderSunSeals(canvas, def, e);
    _renderSunDoors(canvas, def);
    _renderSunLens(canvas, def);
    _renderSunBeams(canvas, def.id, e);
    _renderSunMouths(canvas, def, e);
    _renderSunAim(canvas, def, e);
    _renderSunMoments(canvas, def);
    if (def.id == 'sun_hall') _renderSunOuroboros(canvas);
    if (def.id == 'sun_heart') _renderSunRubedo(canvas);
    _renderGlassDoorPlugs(canvas, room);
  }

  /// The void: blood bridges as panes of red glass, and a solved chamber's
  /// void set solid, spreading out from its pads.
  void _renderSunVoid(Canvas canvas, SunRoomDef def, SunEval e) {
    final solvedAt = blackSun.solvedT[def.id];
    final solved = blackSun.solved.contains(def.id);
    Offset? pads;
    if (solved && def.exits.isNotEmpty) {
      pads = def.exits
              .map((q) => sunCentre(q.x, q.y))
              .reduce((a, b) => a + b) /
          def.exits.length.toDouble();
    }
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        if (def.at(x, y) != '~') continue;
        final r = Rect.fromLTWH(x * kSunCell, y * kSunCell, kSunCell, kSunCell);
        if (solved) {
          var k = 1.0;
          if (solvedAt != null && pads != null) {
            final d = (r.center - pads).distance / kSunCell;
            k = _sunEase((_time - solvedAt - d * 0.08) / 0.5);
          }
          if (k > 0) _sunBloodPane(canvas, r, x * 7 + y * 13, k, set: true);
          continue;
        }
        if ((e.litAt(def.id, x, y) & kSunBlood) != 0) {
          _sunBloodPane(canvas, r, x * 7 + y * 13, 1);
        }
      }
    }
  }

  /// A pane of blood-light over the void: dark red glass, hot at its heart,
  /// in black lead, with a slow pulse running through it.
  void _sunBloodPane(Canvas canvas, Rect r, int seed, double k, {bool set = false}) {
    final q = r.deflate(3);
    final pulse = .5 + .5 * sin(_time * 3 + seed * .7);
    final heart = q.center + Offset((_sunHash(seed) - .5) * 14, (_sunHash(seed + 3) - .5) * 14);
    final pane = Path()..addRRect(RRect.fromRectAndRadius(q, const Radius.circular(3)));
    canvas.drawPath(
      pane,
      Paint()
        ..shader = ui.Gradient.radial(
          heart,
          q.width * .8,
          [
            Color.lerp(_kSunBloodHot, _kSunBlood, set ? .6 : .25 - .2 * pulse)!.withValues(alpha: .92 * k),
            _kSunBlood.withValues(alpha: .8 * k),
            const Color(0xFF4A0A16).withValues(alpha: .9 * k),
          ],
          const [0, .5, 1],
        ),
    );
    paintLead(canvas, pane, _kSunStone, width: 2, opacity: .85 * k);
  }

  /// Stars set in the walls: a white core and a corona, rays toward where
  /// they shine. A star still waiting on its dungeon star is a cold ember.
  void _renderSunStars(Canvas canvas, SunRoomDef def) {
    for (final st in def.emitters) {
      final lit = st.star == null || hasStar(st.star!);
      final cc = sunCentre(st.x, st.y) + Offset(kSunDx[st.d] * 16.0, kSunDy[st.d] * 16.0 - 6);
      if (!lit) {
        canvas.drawCircle(cc, 9, Paint()..color = const Color(0xFF3A2A30));
        canvas.drawCircle(cc, 4, Paint()..color = const Color(0xFF6A4038));
        continue;
      }
      final tw = .85 + .15 * sin(_time * 5 + st.x);
      canvas.drawCircle(
        cc,
        30,
        Paint()
          ..shader = ui.Gradient.radial(cc, 30, [
            _kSunWhiteGlow.withValues(alpha: .55 * tw),
            _kSunWhiteGlow.withValues(alpha: 0),
          ]),
      );
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + _time * .4;
        final len = (i.isEven ? 18.0 : 11.0) * tw;
        final dir = Offset(cos(a), sin(a));
        final n = Offset(-dir.dy, dir.dx) * 2.2;
        canvas.drawPath(
          Path()
            ..moveTo(cc.dx + n.dx, cc.dy + n.dy)
            ..lineTo(cc.dx + dir.dx * len, cc.dy + dir.dy * len)
            ..lineTo(cc.dx - n.dx, cc.dy - n.dy)
            ..close(),
          Paint()..color = _kSunWhite.withValues(alpha: .8),
        );
      }
      canvas.drawCircle(cc, 5.5, Paint()..color = Colors.white);
    }
  }

  /// Seals: round leaded glass in the wall. White wants white; red wants
  /// blood. A lit one blooms.
  void _renderSunSeals(Canvas canvas, SunRoomDef def, SunEval e) {
    for (final q in def.seals) {
      final red = def.at(q.x, q.y) == 'r';
      final key = sunKey(def.id, q.x, q.y);
      final lit = e.sealsLit.contains(key);
      final since = blackSun.sealT[key];
      final k = lit ? _sunEase(since == null ? 1 : (_time - since) / .4) : 0.0;
      final cc = sunCentre(q.x, q.y) + const Offset(0, -6);
      final base = red ? _kSunBlood : _kSunWhite;
      if (k > 0) {
        canvas.drawCircle(
          cc,
          52,
          Paint()
            ..shader = ui.Gradient.radial(cc, 52, [
              base.withValues(alpha: .5 * k),
              base.withValues(alpha: 0),
            ]),
        );
      }
      canvas.drawCircle(cc, 21, Paint()..color = const Color(0xFF2A2018));
      canvas.drawCircle(
        cc,
        18,
        Paint()
          ..shader = ui.Gradient.radial(cc - const Offset(5, 5), 22, [
            Color.lerp(base.withValues(alpha: .35), red ? _kSunBloodHot : Colors.white, k)!,
            Color.lerp(base.withValues(alpha: .15), base, k)!,
          ]),
      );
      final lead = Path()
        ..moveTo(cc.dx - 18, cc.dy)
        ..lineTo(cc.dx + 18, cc.dy)
        ..moveTo(cc.dx, cc.dy - 18)
        ..lineTo(cc.dx, cc.dy + 18)
        ..addOval(Rect.fromCircle(center: cc, radius: 18));
      paintLead(canvas, lead, _kSunStone, width: 2, opacity: .9);
    }
  }

  /// Doors in a room: two leaves of leaded glass that part on their circuit.
  void _renderSunDoors(Canvas canvas, SunRoomDef def) {
    for (final q in def.doors) {
      final open = blackSun.doorShown[sunKey(def.id, q.x, q.y)] ?? 0;
      final r = Rect.fromLTWH(q.x * kSunCell, q.y * kSunCell, kSunCell, kSunCell);
      bool wallish(int x, int y) => kSunSolid.contains(def.at(x, y));
      final vertical = wallish(q.x, q.y - 1) && wallish(q.x, q.y + 1);
      final gap = open * kSunCell * .5;
      final leaf = Paint()..color = const Color(0xFF231C2C);
      final glass = Paint()..color = _kSunPurple.withValues(alpha: .18);
      final List<Rect> leaves;
      if (vertical) {
        leaves = [
          Rect.fromLTWH(r.left + 12, r.top, r.width - 24, kSunCell / 2 - gap),
          Rect.fromLTWH(r.left + 12, r.center.dy + gap, r.width - 24, kSunCell / 2 - gap),
        ];
      } else {
        leaves = [
          Rect.fromLTWH(r.left, r.top + 12, kSunCell / 2 - gap, r.height - 24),
          Rect.fromLTWH(r.center.dx + gap, r.top + 12, kSunCell / 2 - gap, r.height - 24),
        ];
      }
      for (final l in leaves) {
        if (l.width <= 1 || l.height <= 1) continue;
        canvas.drawRect(l, leaf);
        canvas.drawRect(l.deflate(4), glass);
        paintLead(canvas, Path()..addRect(l.deflate(4)), _kSunStone, width: 1.6, opacity: .8);
      }
    }
  }

  /// The burning-glass glows gold while Light shines from it.
  void _renderSunLens(Canvas canvas, SunRoomDef def) {
    final lp = blackSun.state.pos['light']!;
    if (lp.room != def.id || blackSun.state.shine < 0) return;
    if (def.at(lp.x, lp.y) != '*') return;
    final cc = sunCentre(lp.x, lp.y);
    final k = _sunEase((_time - blackSun.shineT) / .3);
    canvas.drawCircle(
      cc,
      40,
      Paint()
        ..shader = ui.Gradient.radial(cc, 40, [
          _kSunWhiteGlow.withValues(alpha: .6 * k),
          _kSunWhiteGlow.withValues(alpha: 0),
        ]),
    );
  }

  // ── Beams ────────────────────────────────────────────────

  /// Every beam's run through [room]: a wide soft glow, a bright body and a
  /// white core, with motes riding it in the color of the portals it has
  /// been through — white, purple, orange — and blood once it has been
  /// through both.
  void _renderSunBeams(Canvas canvas, String room, SunEval e, {double alpha = 1}) {
    for (final b in e.beams) {
      for (var i = 1; i < b.path.length; i++) {
        final p0 = b.path[i - 1], p1 = b.path[i];
        if (p1.jump || p1.room != room || p0.room != room) continue;
        final a = Offset((p0.x + .5) * kSunCell, (p0.y + .5) * kSunCell);
        final z = Offset((p1.x + .5) * kSunCell, (p1.y + .5) * kSunCell);
        _sunBeamSegment(canvas, a, z, p1.via, alpha);
      }
      // Where a beam is drunk by a Dark: motes pulled into it.
      if (b.end == 'drunk') {
        final last = b.path.last;
        if (last.room == room) {
          _sunSink(canvas, Offset((last.x + .5) * kSunCell, (last.y + .5) * kSunCell), last.via, alpha);
        }
      }
    }
  }

  void _sunBeamSegment(Canvas canvas, Offset a, Offset z, int via, double alpha) {
    final blood = via == 3;
    final glow = blood ? _kSunBlood : _kSunWhiteGlow;
    final core = blood ? _kSunBloodHot : Colors.white;
    final len = (z - a).distance;
    if (len < 1) return;
    final dir = (z - a) / len;
    final ang = atan2(dir.dy, dir.dx);
    canvas.save();
    canvas.translate(a.dx, a.dy);
    canvas.rotate(ang);
    final flick = .9 + .1 * sin(_time * 17 + a.dx * .1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-6, -14, len + 12, 28), const Radius.circular(14)),
      Paint()..color = glow.withValues(alpha: .10 * alpha),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-3, -6, len + 6, 12), const Radius.circular(6)),
      Paint()..color = glow.withValues(alpha: .35 * alpha * flick),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -1.8, len, 3.6),
      Paint()..color = core.withValues(alpha: .95 * alpha),
    );
    // The motes riding it.
    final tint = blood
        ? const Color(0xFFFF8A8A)
        : via == 1
        ? _kSunPurple
        : via == 2
        ? _kSunOrange
        : const Color(0xFFFFFAEA);
    final n = max(1, (len / 26).floor());
    for (var k = 0; k < n; k++) {
      final t = ((k + _time * 2.2) / n) % 1;
      final wob = sin((k * 3 + _time * 6)) * 3;
      canvas.drawCircle(
        Offset(len * t, wob),
        2.4,
        Paint()..color = tint.withValues(alpha: .9 * alpha),
      );
    }
    canvas.restore();
  }

  /// A Dark drinking a beam: the light's motes spiral down into it.
  void _sunSink(Canvas canvas, Offset c, int via, double alpha) {
    final col = via == 3 ? _kSunBlood : _kSunWhiteGlow;
    for (var i = 0; i < 8; i++) {
      final t = (_time * .9 + i / 8) % 1;
      final a = i * 2.4 + _time * 3;
      final rr = 30 * (1 - t);
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * rr,
        2.2 * (1 - t) + .6,
        Paint()..color = col.withValues(alpha: .8 * (1 - t) * alpha),
      );
    }
  }

  // ── The portals ──────────────────────────────────────────

  void _renderSunMouths(Canvas canvas, SunRoomDef def, SunEval e) {
    final s = blackSun.state;
    for (final o in kSunDarks) {
      for (var end = 0; end < 2; end++) {
        final at = s.ends[o]![end];
        final key = '$o$end';
        if (at != null && at.room == def.id) {
          final since = blackSun.castT[key];
          final open = since == null ? 1.0 : _sunEase((_time - since) / .45);
          _sunDrawMouth(canvas, def, at.face, o, end, s.ends[o]![1 - end], open, since);
        }
        // An end that has just closed falls in on itself and goes.
        final closed = blackSun.closedT[key];
        if (closed != null && closed.$1.room == def.id) {
          final t = (_time - closed.$2) / .35;
          if (t < 1 && (at == null || at.face != closed.$1.face)) {
            _sunDrawMouth(canvas, def, closed.$1.face, o, end, null, 1 - _sunEase(t), null);
          }
        }
      }
    }
  }

  /// The black hole each portal end is: the Dark planet's own recipe
  /// (hundreds of motes on real orbits round a black core), violet for the
  /// purple Dark and solar for the orange. One per end, kept.
  BlackHoleArt _sunHole(String owner, int end) => _sunHoles.putIfAbsent(
    '$owner$end',
    () => BlackHoleArt(
      seed: (owner == 'purple' ? 11 : 29) + end * 7,
      motes: 760,
      infall: 110,
      grain: 9,
      palette: owner == 'purple' ? DiskPalette.violet : DiskPalette.solar,
    ),
  );

  /// Where a mouth on face [f] of [def] sits: at the face, a little into the
  /// block; its disk lies along the wall (stood on end in a wall that runs
  /// north–south).
  (Offset, double) _sunMouthAt(SunRoomDef def, int f) {
    final face = def.faces[f];
    final c = sunCentre(face.x, face.y);
    return switch (face.d) {
      2 => (c + const Offset(0, 8), 0.0),
      0 => (c + const Offset(0, -26), 0.0),
      1 => (c + const Offset(24, -6), pi / 2),
      _ => (c + const Offset(-24, -6), pi / 2),
    };
  }

  /// One portal end: a black hole in the obsidian. The far half of its disk
  /// behind, the core — black, or while its pair is whole a WINDOW onto the
  /// other end — and the near half in front.
  void _sunDrawMouth(
    Canvas canvas,
    SunRoomDef def,
    int f,
    String owner,
    int end,
    SunEnd? partner,
    double open,
    double? since,
  ) {
    if (open <= 0.01) return;
    final (c, tilt) = _sunMouthAt(def, f);
    final hole = _sunHole(owner, end);
    final hot = _sunOwnerHot(owner);
    final paired = partner != null;
    final r = 17.0 * _sunEase(open);
    // It is born from a point: the core opens, the disk spins up round it.
    hole.paintBack(canvas, c, r, _time, tilt: tilt, alpha: paired ? 1 : .7);
    canvas.drawCircle(c, r, Paint()..color = Colors.black);
    if (paired && open > .5) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * .96)));
      _sunWindow(canvas, c, r, r, partner, owner);
      // Seen dimly and evenly through the dark — a hole with a view in it,
      // not a lit ball — with only the very edge falling away to black.
      canvas.drawCircle(c, r, Paint()..color = Colors.black.withValues(alpha: .6));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: .95),
          ], const [.78, 1]),
      );
      canvas.restore();
    }
    hole.paintFront(canvas, c, r, _time, tilt: tilt);

    // Its mark: one grain of light for I, two for II, riding just above.
    final mark = c + Offset(0, -r - 14);
    for (final dx in end == 0 ? const [0.0] : const [-4.0, 4.0]) {
      canvas.drawCircle(
        mark + Offset(dx, 0),
        2.2,
        Paint()..color = hot.withValues(alpha: .9 * open),
      );
    }

    // The moment it opens: matter flung outward before the disk settles.
    if (since != null) {
      final t = (_time - since) / .6;
      if (t < 1) {
        for (var i = 0; i < 28; i++) {
          final a = i * 2.39996;
          final rr = r + 60 * _sunEase(t) * (.6 + .4 * _sunHash(i));
          canvas.drawCircle(
            c + Offset(cos(a) * rr, sin(a) * rr * .6),
            1.8 * (1 - t),
            Paint()..color = hot.withValues(alpha: (1 - t) * .9),
          );
        }
      }
    }
  }

  /// The view through a mouth: the other end's room around the square in
  /// front of it, with its beams and the bodies standing there.
  void _sunWindow(
    Canvas canvas,
    Offset c,
    double rx,
    double ry,
    SunEnd partner,
    String owner,
  ) {
    final pd = kSunRooms[partner.room];
    if (pd == null) return;
    final face = pd.faces[partner.face];
    final front = face.front;
    final look = sunCentre(front.x, front.y);
    const zoom = .55;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(zoom);
    canvas.translate(-look.dx, -look.dy);
    canvas.drawPicture(_sunBake(partner.room));
    final e = _sunEval;
    for (var y = 0; y < pd.rows; y++) {
      for (var x = 0; x < pd.cols; x++) {
        if (pd.at(x, y) == '~' && (e.litAt(pd.id, x, y) & kSunBlood) != 0) {
          _sunBloodPane(canvas, Rect.fromLTWH(x * kSunCell, y * kSunCell, kSunCell, kSunCell), x + y, 1);
        }
      }
    }
    _renderSunBeams(canvas, pd.id, e, alpha: .9);
    for (final n in kSunBodies) {
      final p = blackSun.state.pos[n]!;
      if (p.room != pd.id) continue;
      final bc = sunCentre(p.x, p.y);
      final col = n == 'light' ? _kSunWhite : _sunOwnerColor(n);
      canvas.drawCircle(bc, 30, Paint()..shader = ui.Gradient.radial(bc, 30, [col.withValues(alpha: .7), col.withValues(alpha: 0)]));
      canvas.drawCircle(bc, 12, Paint()..color = col);
    }
    canvas.restore();
    // A tint of the owner's color over the view: you are looking through it.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
      Paint()..color = _sunOwnerColor(owner).withValues(alpha: .12),
    );
  }

  // ── Aim, and the moments ─────────────────────────────────

  /// Where the chosen body's press would land, from where it stands: a
  /// ghost mouth on the face a Dark is looking at; the beam's road for Light
  /// on the burning-glass.
  void _renderSunAim(Canvas canvas, SunRoomDef def, SunEval e) {
    final a = active;
    if (a == null || blackSun.inArena) return;
    final me = _sunName(a);
    final p = blackSun.state.pos[me]!;
    if (p.room != def.id) return;
    final dir = _sunAim(a);
    final pulse = .5 + .5 * sin(_time * 4);
    if (me == 'light') {
      if (blackSun.state.shine >= 0 || def.at(p.x, p.y) != '*') return;
      var x = p.x, y = p.y;
      for (var i = 0; i < 20; i++) {
        final nx = x + kSunDx[dir], ny = y + kSunDy[dir];
        if (!def.inside(nx, ny) || kSunSolid.contains(def.at(nx, ny))) break;
        x = nx;
        y = ny;
      }
      final from = sunCentre(p.x, p.y), to = sunCentre(x, y);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = 5
          ..color = _kSunWhiteGlow.withValues(alpha: .08 + .08 * pulse),
      );
      return;
    }
    final cf = sunCastFace(_sunWorld, blackSun.state, e, me, dir);
    if (cf.face == null) return;
    final (c, _) = _sunMouthAt(def, cf.face!);
    final col = _sunOwnerColor(me);
    // Where it would open: a few motes already circling the spot.
    for (var i = 0; i < 10; i++) {
      final a = i * 2 * pi / 10 + _time * 1.6;
      canvas.drawCircle(
        c + Offset(cos(a) * 16, sin(a) * 16 * .6),
        1.8,
        Paint()..color = col.withValues(alpha: .35 + .25 * pulse),
      );
    }
    // The line of sight, faint, from the Dark to the face.
    final from = sunCentre(p.x, p.y);
    final len = (c - from).distance;
    if (len > 1) {
      final d = (c - from) / len;
      for (var i = 0; i < (len / 18).floor(); i++) {
        final t = ((i + _time * 1.5) * 18) % len;
        canvas.drawCircle(from + d * t, 1.6, Paint()..color = col.withValues(alpha: .3));
      }
    }
  }

  void _renderSunMoments(Canvas canvas, SunRoomDef def) {
    // A cast: a comet of color thrown from the Dark to the wall.
    final cs = blackSun.castStreak;
    if (cs != null) {
      final (from, dir, owner, t0) = cs;
      final t = (_time - t0) / .22;
      final at = blackSun.state.ends[owner];
      if (t < 1 && at != null) {
        final col = _sunOwnerColor(owner);
        final head = from + Offset(kSunDx[dir] * 1.0, kSunDy[dir] * 1.0) * (t * 420);
        final tail = from + Offset(kSunDx[dir] * 1.0, kSunDy[dir] * 1.0) * (max(0.0, t - .35) * 420);
        final n = Offset(-kSunDy[dir] * 1.0, kSunDx[dir] * 1.0);
        canvas.drawPath(
          Path()
            ..moveTo(tail.dx, tail.dy)
            ..lineTo(head.dx + n.dx * 7, head.dy + n.dy * 7)
            ..lineTo(head.dx + kSunDx[dir] * 6.0, head.dy + kSunDy[dir] * 6.0)
            ..lineTo(head.dx - n.dx * 7, head.dy - n.dy * 7)
            ..close(),
          Paint()..color = col.withValues(alpha: .85),
        );
        canvas.drawCircle(head, 5, Paint()..color = _sunOwnerHot(owner));
      }
    }
    // Coming through: the body is thrown out of the mouth in a burst.
    for (final n in kSunBodies) {
      final t0 = blackSun.transitT[n];
      if (t0 == null) continue;
      final t = (_time - t0) / .45;
      final p = blackSun.state.pos[n]!;
      if (t >= 1 || p.room != def.id) continue;
      final c = sunCentre(p.x, p.y);
      final col = n == 'light' ? _kSunWhiteGlow : _sunOwnerColor(n);
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6 + t * 3;
        final rr = 8 + 44 * _sunEase(t);
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * rr,
          3 * (1 - t),
          Paint()..color = col.withValues(alpha: 1 - t),
        );
      }
      canvas.drawCircle(
        c,
        40 * (1 - t),
        Paint()..shader = ui.Gradient.radial(c, 40, [col.withValues(alpha: .5 * (1 - t)), col.withValues(alpha: 0)]),
      );
    }
  }

  /// THE LOST MAXIM'S MARK: once a light has gone round forever, a ring of
  /// gold turns over the Hall's island for good.
  void _renderSunOuroboros(Canvas canvas) {
    final found =
        discoveredClouds.contains(kDarkEggId) || _ritePendingEgg == kDarkEggId;
    if (!found) return;
    final c = sunCentre(5, 3) + const Offset(0, 30);
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * pi / 24 + _time * .5;
      final p = c + Offset(cos(a) * 92, sin(a) * 60);
      final w = 3.5 + 2.5 * sin(i * pi / 12 + _time);
      canvas.drawCircle(p, w, Paint()..color = _kSunGold.withValues(alpha: .55));
    }
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 200, height: 136),
      Paint()
        ..shader = ui.Gradient.radial(c, 110, [
          _kSunGold.withValues(alpha: 0),
          _kSunGold.withValues(alpha: .10),
          _kSunGold.withValues(alpha: 0),
        ], const [.6, .85, 1]),
    );
  }

  /// THE GREAT WORK'S MARK: once blood has burned on the Great Seal, a red
  /// black sun rises over it and stays — the rubedo, the work finished.
  /// The Dark planet's own recipe, in crimson.
  void _renderSunRubedo(Canvas canvas) {
    if (!blackSun.riteLatched && !hasStar(2)) return;
    final since = blackSun.riteT;
    final k = since < 0 ? 1.0 : _sunEase((_time - since) / 1.6);
    if (k <= 0) return;
    final hole = _sunHoles.putIfAbsent(
      'rubedo',
      () => BlackHoleArt(
        seed: 77,
        motes: 900,
        infall: 120,
        grain: 9,
        palette: DiskPalette.crimson,
      ),
    );
    // It rises from the seal to hang over the heart of the room.
    final seal = sunCentre(kSunGreatSeal.x, kSunGreatSeal.y);
    final c = Offset.lerp(seal, sunCentre(4, 3), k)!;
    final r = 22.0 * k;
    hole.paintBack(canvas, c, r, _time);
    canvas.drawCircle(c, r, Paint()..color = Colors.black);
    hole.paintFront(canvas, c, r, _time);
  }

  // ── The arena ────────────────────────────────────────────

  /// Noctryos' arena: black holes in the floor, where its enemies come out —
  /// the Dark planet's own black hole, four times over.
  void _renderSunArena(Canvas canvas, DungeonRoom room) {
    for (var h = 0; h < kSunArenaHoles.length; h++) {
      final c = kSunArenaHoles[h];
      final hole = _sunHoles.putIfAbsent(
        'arena$h',
        () => BlackHoleArt(seed: 101 + h * 13, motes: 640, infall: 90, grain: 7),
      );
      const r = 26.0;
      hole.paintBack(canvas, c, r, _time + h * 3.1);
      canvas.drawCircle(c, r, Paint()..color = Colors.black);
      hole.paintFront(canvas, c, r, _time + h * 3.1);
    }
  }
}
