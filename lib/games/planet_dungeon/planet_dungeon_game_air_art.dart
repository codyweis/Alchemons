// lib/games/planet_dungeon/planet_dungeon_game_air_art.dart
//
// THE WIND-CROWN SPIRE, IN GLASS (docs/dungeons.md §7.11) — Air's stone and
// the glass it signals with, as a part of planet_dungeon_game.dart.
//
// Air is open sky, not a building, so its "carved diorama" is carved ISLAND:
// every plain room is a slab of cloud-slate hanging in the shader sky, with a
// front face, rock trailing underneath, and a balustrade where a cathedral
// would have walls. The platforms are the same stone. The glass is the sky's
// own colour, and it sits only where Air asks something of you:
//
//   · the compass in the hub is a rose of glass set into the floor — three
//     rings of panes, one per star, each filling as its star comes on (wind
//     sky-blue, loom gold, storm lightning-white). When the First Wind is
//     found the whole rose turns for good: the maxim's mark;
//   · a gust shrine's breath-slots are glass that fills with wind when woken;
//   · a gale vent is a glass eye with its breath cut into the lead;
//   · a storm rod counts its rank in glass beads.
//
// COST. The stages and islands are baked once per rect into a Picture; the
// hub's rose is ~50 panes, drawn only in the hub.

part of 'planet_dungeon_game.dart';

const GlassPalette _kSkyGlass = kZephyrGlass;

final Map<String, ui.Picture> _skyFabricCache = {};

/// Where each room's parapet pennants stand (filled when its stage bakes).
final Map<String, List<Offset>> _skyPennants = {};

/// Each wonder room's cloud: its grains, the haze under them, the centre it
/// turns about and how fast. Keyed like its baked stage.
final Map<String, (GrainShape, ui.Picture, Offset, double)?> _skyCloudShapes =
    {};

/// How many grains each room's cloud is made of (the ring is the biggest).
const Map<String, int> _kWonderCloudGrains = {
  'anvil_cloud': 2400,
  'ring_cloud': 4200,
};

/// Grains streaming along a curve: each has a place along it (u, 0..1), a
/// side (-1..1, packed toward the middle) and its own pace; the caller says
/// where (u, side) is at a moment. The curve may move as a whole (a spiral
/// turning) but nothing winds up, because every grain is placed afresh each
/// frame. Drawn in six brightness groups, one call each, from buffers made
/// once.
class _ArmFlow {
  _ArmFlow(this.count, int seed)
    : _u0 = Float32List(count),
      _side = Float32List(count),
      _pace = Float32List(count),
      _lvl = Uint8List(count),
      _buf = Float32List(count * 4) {
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      _u0[i] = rng.nextDouble();
      _side[i] = rng.nextDouble() + rng.nextDouble() - 1;
      _pace[i] = 0.75 + 0.5 * rng.nextDouble();
    }
  }

  static const int _levels = 6;
  final int count;
  final Float32List _u0, _side, _pace, _buf;
  final Uint8List _lvl;
  final Int32List _n = Int32List(_levels), _at = Int32List(_levels);
  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// [at] places grain [i] at (u, side) at time t. [speed] is how far along
  /// the curve a grain goes in a second (negative runs it backwards).
  /// [light] is 0..1 for a grain at (u, side); the ends fade on their own.
  void paint(
    Canvas canvas,
    double t, {
    required Offset Function(int i, double u, double side, double t) at,
    required double Function(double u, double side) light,
    required List<Color> ramp,
    double speed = 0.05,
    double trail = 0.05,
    double alpha = 1,
    double width = 1.7,
  }) {
    double frac(double v) => v - v.floorToDouble();
    double fade(double u) => min(1.0, min(u, 1 - u) * 12);
    _n.fillRange(0, _levels, 0);
    for (var i = 0; i < count; i++) {
      final u = frac(_u0[i] + t * speed * _pace[i]);
      final l = (light(u, _side[i]) * fade(u)).clamp(0.0, 1.0);
      final k = min(_levels - 1, (l * _levels).floor());
      _lvl[i] = k;
      _n[k]++;
    }
    var acc = 0;
    for (var k = 0; k < _levels; k++) {
      _at[k] = acc;
      acc += _n[k];
    }
    final back = t - trail;
    for (var i = 0; i < count; i++) {
      final u = frac(_u0[i] + t * speed * _pace[i]);
      var u0 = frac(_u0[i] + back * speed * _pace[i]);
      if ((u - u0).abs() > 0.5) u0 = u; // wrapped: no streak across
      final p = at(i, u, _side[i], t);
      var q = at(i, u0, _side[i], back);
      if ((p - q).distanceSquared < 0.09) q = p - const Offset(0.3, 0);
      final o = _at[_lvl[i]]++ * 4;
      _buf[o] = q.dx;
      _buf[o + 1] = q.dy;
      _buf[o + 2] = p.dx;
      _buf[o + 3] = p.dy;
    }
    var from = 0;
    for (var k = 0; k < _levels; k++) {
      final c = _n[k];
      if (c == 0) continue;
      final shade = (k + 0.5) / _levels;
      _paint
        ..strokeWidth = width
        ..color = ramp[(shade * (ramp.length - 1)).round()].withValues(
          alpha: (alpha * (0.25 + 0.75 * shade)).clamp(0.0, 1.0),
        );
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.sublistView(_buf, from * 4, (from + c) * 4),
        _paint,
      );
      from += c;
    }
  }
}

final _ArmFlow _spiralRoomFlow = _ArmFlow(3200, 17);
final _ArmFlow _spiralTrophyFlow = _ArmFlow(2200, 41);
final Map<String, ui.Picture> _spiralHaze = {};

/// The cloud pickups' and plumes' shapes, built once.
final Map<String, GrainShape> _skyIconShapes = {};

/// A wing's light: the wash over its stone, and the colour its carving and
/// pennants catch.
class _SkyZone {
  const _SkyZone(this.wash, this.light);
  final Color wash;
  final Color light;
}

const _kDawnZone = _SkyZone(Color(0x30E8A050), Color(0xFFF2C878));
const _kDayZone = _SkyZone(Color(0x14BFE0FF), Color(0xFFE8F4FF));
const _kStormZone = _SkyZone(Color(0x2A6A4AA8), Color(0xFFB89CF0));

/// Loom glass (gold) and storm glass (lightning), for the compass's rings.
const Color _kLoomGlass = Color(0xFFE4C16A);
const Color _kStormGlass = Color(0xFFFFF59A);

extension WindCrownArt on PlanetDungeonGame {
  /// Ease Air's glass toward what it shows. A negative value snaps.
  void _updateSkyGlass(double dt) {
    final target = altarOpen || guardianAwake ? 1.0 : 0.0;
    if (_altarShown < 0) {
      _altarShown = target;
    } else if (_altarShown < target) {
      _altarShown = min(target, _altarShown + dt / 2.0);
    } else if (_altarShown > target) {
      _altarShown = max(target, _altarShown - dt / 0.8);
    }
  }

  // ── The stone: sky-islands ──────────────────────────────

  static const double _kSkyStageR = 34;

  /// A plain room as an island of carved cloud-slate.
  void _renderSkyStage(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = 'stage|${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _skyFabricCache.putIfAbsent(key, () => _bakeSkyStage(room)),
    );
    // The room's own cloud, live: grains wandering about its shape over a
    // faint haze of it — the dust ring's recipe, many small lights on real
    // motion over a soft lane. The ring turns, inner faster than outer; the
    // spiral's arm stays put and streams; the anvil only churns.
    if (room.id == 'spiral_cloud') {
      _paintSpiralCloud(canvas, room, b.deflate(8));
    }
    final cloud = _skyCloudShapes.putIfAbsent(
      key,
      () => _buildWonderCloud(room, b.deflate(8)),
    );
    if (cloud != null) {
      final (grains, haze, centre, turn) = cloud;
      canvas.save();
      if (turn != 0) {
        canvas
          ..translate(centre.dx, centre.dy)
          ..rotate(turn * _time)
          ..translate(-centre.dx, -centre.dy);
      }
      canvas.drawPicture(haze);
      canvas.restore();
      paintGrainShape(
        canvas,
        grains,
        _time,
        drift: 4,
        alpha: 0.9,
        glint: 0.012,
        width: 1.6,
        trail: 0.035,
      );
    }
    _renderSkyPennants(canvas, room);
  }

  _SkyZone _skyZoneOf(DungeonRoom room) => switch (_themeFor(room)) {
    _AirRoomTheme.wonderCloud || _AirRoomTheme.loom => _kDayZone,
    _AirRoomTheme.storm ||
    _AirRoomTheme.guardian ||
    _AirRoomTheme.relic => _kStormZone,
    _ => _kDawnZone,
  };

  ui.Picture _bakeSkyStage(DungeonRoom room) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final b = room.bounds;
    final rng = GlassRng(glassSeed(room.id, b));
    final top = RRect.fromRectAndRadius(
      b.deflate(8),
      const Radius.circular(_kSkyStageR),
    );

    // Rock trailing under the slab: the island hangs in the sky.
    final under = Path()..moveTo(top.left + 40, top.bottom - 6);
    const n = 11;
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final x = top.left + 40 + (top.width - 80) * u;
      final drop = 30 + sin(u * pi) * (60 + rng.next() * 50) + rng.next() * 18;
      under.lineTo(x, top.bottom + drop);
    }
    under
      ..lineTo(top.right - 40, top.bottom - 6)
      ..close();
    c.drawPath(
      under,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _kSkyGlass.stoneFace.withValues(alpha: 0.9),
                _kSkyGlass.stoneFoot.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromLTRB(b.left, top.bottom, b.right, b.bottom + 130),
            ),
    );
    // The slab's front face: its thickness, seen from three-quarters.
    final face = top.shift(const Offset(0, 16));
    c.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kSkyGlass.stoneFace, _kSkyGlass.stoneFoot],
        ).createShader(face.outerRect),
    );

    // The top: flags laid in the slab, translucent so the sky shows (§8).
    // A DARK BED under them first (2026-09-24): floor, walls and carving were
    // all one slate value, so every room feature was dark-on-dark.
    c.save();
    c.clipRRect(top);
    c.drawRect(
      top.outerRect,
      Paint()..color = const Color(0xFF121A26).withValues(alpha: 0.5),
    );
    paintFlagFloor(
      c,
      top.outerRect,
      _kSkyGlass,
      rng,
      // Thin: the sky is this planet's mood, and a stage that hides it makes
      // every room the same grey slab (the author, 2026-09-19).
      opacity: 0.3,
      course: 84,
      jointOpacity: 0.24,
    );
    // THE WING'S LIGHT: dawn gold up the spire, clear day among the clouds,
    // violet in the storm — so the climb is a journey through the sky.
    final zone = _skyZoneOf(room);
    c.drawRect(top.outerRect, Paint()..color = zone.wash);
    c.restore();
    c.drawRRect(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kSkyGlass.stoneTop.withValues(alpha: 0.75),
    );

    // THE ROOM'S OWN GROUND. Every stage used to be the same flagged slab
    // with one prop in the middle, which made ten of the spire's rooms one
    // room (§7.11). Each now has a carved feature of its own, in the stone
    // and so in this bake: a dais, rings, an aisle, troughs.
    c.save();
    c.clipRRect(top);
    _paintSkyGround(c, room, top.outerRect);
    c.restore();

    // THE PARAPET (2026-09-24). A post every 34px round every room was the
    // loudest pattern in all of them and made them one room. Now: heavy
    // wind-worn posts far apart, a rail between most of them and a gap where
    // the wind has taken it, and a pennant on some of the posts along the
    // top edge — drawn live, streaming the way the air moves.
    final doors = room.doors.map((d) => d.rect.inflate(18)).toList();
    final inner = top.deflate(10);
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _kSkyGlass.stoneTop.withValues(alpha: 0.5);
    final pennants = <Offset>[];
    void posts(Offset a, Offset z, {bool flags = false}) {
      final len = (z - a).distance;
      final steps = max(1, (len / 150).round());
      Offset? last;
      for (var i = 0; i <= steps; i++) {
        final p = Offset.lerp(a, z, i / steps)!;
        if (doors.any((d) => d.contains(p))) {
          last = null;
          continue;
        }
        // Most spans keep their rail; the wind has had the rest.
        if (last != null && rng.next() > 0.3) c.drawLine(last, p, rail);
        paintCarvedBlock(
          c,
          Rect.fromCenter(
            center: p - const Offset(0, 6),
            width: 16,
            height: 11,
          ),
          12,
          _kSkyGlass,
          radius: 2.5,
        );
        if (flags && i.isOdd) pennants.add(p - const Offset(0, 12));
        last = p;
      }
    }

    final r = inner.outerRect;
    const k = _kSkyStageR - 6;
    posts(Offset(r.left + k, r.top), Offset(r.right - k, r.top), flags: true);
    posts(Offset(r.left, r.top + k), Offset(r.left, r.bottom - k));
    posts(Offset(r.right, r.top + k), Offset(r.right, r.bottom - k));
    posts(Offset(r.left + k, r.bottom), Offset(r.right - k, r.bottom));
    _skyPennants[room.id] = pennants;

    return rec.endRecording();
  }

  /// The wind off the parapet: from some of the posts along the top edge a
  /// thread of grains streams away downwind and thins out (they were cloth
  /// pennants). ~14 grains a post, worked out from time alone.
  void _renderSkyPennants(Canvas canvas, DungeonRoom room) {
    final at = _skyPennants[room.id];
    if (at == null || at.isEmpty) return;
    final light = _skyZoneOf(room).light;
    const n = 26;
    for (var i = 0; i < at.length; i++) {
      final p = at[i] + const Offset(0, 4);
      for (var j = 0; j < n; j++) {
        Offset where(double t) {
          final u = (t * 0.32 + j / n + i * 0.37) % 1.0;
          final gust = sin(t * 1.3 + i * 1.7) * 0.5 + 0.5;
          return p +
              Offset(
                u * (54 + 26 * gust),
                -u * 10 + sin(t * 3.1 + j * 0.9 + i) * 3 * u,
              );
        }

        final u = (_time * 0.32 + j / n + i * 0.37) % 1.0;
        final q = where(_time), q0 = where(_time - 0.08);
        if ((q - q0).distance > 20) continue; // wrapped this frame
        _skyBatch.add(
          q0.dx,
          q0.dy,
          q.dx,
          q.dy,
          light,
          alpha: min(1.0, u * 8) * (1 - u * 0.7),
          width: 2.4,
        );
      }
    }
    _skyBatch.paint(canvas);
  }

  (GrainShape, ui.Picture, Offset, double)? _buildWonderCloud(
    DungeonRoom room,
    Rect r,
  ) {
    if (room.id == 'spiral_cloud') return null; // its own flow, below
    final puffs = _wonderCloudPuffs(room, r);
    if (puffs == null) return null;
    final centre = Offset(r.left + r.width * 0.5, r.top + r.height * 0.46);
    final grains = GrainShape.puffs(
      puffs,
      _kWonderCloudGrains[room.id] ?? 2000,
      seed: room.id.length,
    );
    var turn = 0.0;
    if (room.id == 'ring_cloud') {
      final rad = min(r.width, r.height) * 0.47;
      grains.orbit(centre, (d) => 0.07 * pow(rad / d, 1.5).toDouble());
    }
    return (grains, _bakeCloudHaze(puffs), centre, turn);
  }

  /// The haze under a cloud: one soft gradient per puff, so they gather into
  /// a lane.
  ui.Picture _bakeCloudHaze(List<(Offset, double)> puffs, {double a = 0.08}) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (final (o, rad) in puffs) {
      final rr = rad * 1.5;
      c.drawCircle(
        o,
        rr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFC8D6E8).withValues(alpha: a),
              const Color(0x00C8D6E8),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: rr)),
      );
    }
    return rec.endRecording();
  }

  /// THE SPIRAL CLOUD: its arm stays where it is (it used to turn whole,
  /// which in a minute or two carried it over the door), and its grains
  /// stream along it from the thick tail toward the thin head, the way wind
  /// is drawn round into an eye. ~3,200 grains over a baked haze.
  void _paintSpiralCloud(Canvas canvas, DungeonRoom room, Rect r) {
    final o = Offset(r.left + r.width * 0.5, r.top + r.height * 0.46);
    canvas.drawPicture(
      _spiralHaze.putIfAbsent(
        '${r.width.round()}x${r.height.round()}',
        () => _bakeCloudHaze(_wonderCloudPuffs(room, r)!, a: 0.11),
      ),
    );
    _spiralRoomFlow.paint(
      canvas,
      _time,
      speed: -0.022,
      trail: 0.06,
      width: 1.7,
      alpha: 0.95,
      ramp: kAirGrainRamp,
      at: (i, u, side, t) {
        final a = -pi / 2 + u * pi * 1.6;
        final size = 10.0 + u * 22;
        final rad = 262.0 + u * 30 + side * size;
        return o + Offset(cos(a), sin(a) * 0.9) * rad;
      },
      light: (u, side) => 0.35 + 0.65 * (1 - side.abs()) * (0.55 + 0.45 * u),
    );
  }

  /// THE WONDER CLOUDS were only a name and a faint floor carving. Each now
  /// has a cloud of its own shape in the room — a thunderhead's flat anvil,
  /// a ring, a spiral arm — laid out as overlapping puffs and filled with
  /// grains (2026-10-08; it was a baked union of discs, which read as a
  /// sticker on the sky). Null for a room without one.
  List<(Offset, double)>? _wonderCloudPuffs(DungeonRoom room, Rect r) {
    final puffs = <(Offset, double)>[];
    Offset at(double fx, double fy) =>
        Offset(r.left + r.width * fx, r.top + r.height * fy);
    switch (room.id) {
      case 'anvil_cloud':
        // The anvil: a broad flat top along the north, a narrower stem.
        for (var i = 0; i <= 10; i++) {
          puffs.add((
            at(0.12 + i * 0.076, 0.1 + (i % 2) * 0.02),
            36.0 + (i % 3) * 6,
          ));
        }
        for (var i = 0; i < 3; i++) {
          puffs.add((at(0.44 + i * 0.06, 0.2), 30.0));
        }
      case 'ring_cloud':
        // Densely overlapped so the outline billows rather than beads.
        final o = at(0.5, 0.46);
        final rad = min(r.width, r.height) * 0.47;
        for (var i = 0; i < 96; i++) {
          final a = i / 96 * 2 * pi;
          final wob = sin(i * 0.9) * 7 + sin(i * 2.3) * 4;
          final size =
              22.0 + 8 * (sin(i * 0.7) * 0.5 + 0.5) + 6 * sin(i * 1.9).abs();
          puffs.add((o + Offset(cos(a), sin(a)) * (rad + wob), size));
        }
      case 'spiral_cloud':
        // An arm that thickens as it winds out.
        final o = at(0.5, 0.46);
        for (var i = 0; i < 90; i++) {
          final t = i / 89;
          final a = -pi / 2 + t * pi * 1.6;
          final rad = 262.0 + t * 30;
          final size = 10.0 + t * 20 + 5 * (sin(i * 1.3) * 0.5 + 0.5);
          puffs.add((o + Offset(cos(a), sin(a) * 0.9) * rad, size));
        }
      default:
        return null;
    }
    return puffs;
  }

  /// The carved feature that makes one stage a particular room. Dark, jointed
  /// stone and cut grooves only — decoration is carved, never glazed.
  void _paintSkyGround(Canvas c, DungeonRoom room, Rect r) {
    final p = _kSkyGlass;
    // Lighter than the (now dark) floor, so a dais reads as raised stone.
    final daisTop = Color.lerp(p.stoneFace, p.stoneTop, 0.25)!;
    Offset at(double fx, double fy) =>
        Offset(r.left + r.width * fx, r.top + r.height * fy);

    void groove(Path path, {double w = 3}) {
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 1.5
          ..strokeCap = StrokeCap.round
          ..color = p.joint.withValues(alpha: 0.85),
      );
      c.drawPath(
        path.shift(const Offset(0, 1.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.4)
          ..strokeCap = StrokeCap.round
          ..color = _skyZoneOf(room).light.withValues(alpha: 0.42),
      );
    }

    void ring(Offset o, double rad, {double squash = 1, double w = 3}) =>
        groove(
          Path()..addOval(
            Rect.fromCenter(
              center: o,
              width: rad * 2,
              height: rad * 2 * squash,
            ),
          ),
          w: w,
        );

    void dais(Offset o, double rx, double ry, double h, {int joints = 8}) {
      paintCarvedDisc(c, o, rx, ry, h, p, topColor: daisTop);
      for (var i = 0; i < joints; i++) {
        final a = i / joints * 2 * pi + 0.2;
        c.drawLine(
          o + Offset(cos(a) * rx * 0.42, sin(a) * ry * 0.42),
          o + Offset(cos(a) * rx * 0.97, sin(a) * ry * 0.97),
          Paint()
            ..strokeWidth = 1.2
            ..color = p.joint.withValues(alpha: 0.75),
        );
      }
      c.drawOval(
        Rect.fromCenter(center: o, width: rx * 0.84, height: ry * 0.84),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = p.joint.withValues(alpha: 0.75),
      );
    }

    void trough(Rect t) {
      final rr = RRect.fromRectAndRadius(
        t,
        Radius.circular(t.shortestSide / 2),
      );
      c.drawRRect(rr, Paint()..color = p.stoneFoot.withValues(alpha: 0.55));
      c.drawRRect(
        rr.shift(const Offset(0, 3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = p.stoneTop.withValues(alpha: 0.18),
      );
      c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.joint.withValues(alpha: 0.8),
      );
    }

    switch (room.id) {
      case 'entry':
        // The landing: a low ring of set stone where the crossing puts you
        // down, and the path to the spire cut into the floor.
        dais(at(0.5, 0.55), 150, 84, 6, joints: 12);
      case 'anvil_cloud':
        // The anvil: a thunderhead's flat top, sunk into the floor as a
        // panel in its own shape — horn, face, waist and foot — and the
        // blow-lane beside it scored with the wind's direction.
        final o = at(0.5, 0.5);
        final anvil = Path()
          ..moveTo(o.dx - 170, o.dy - 62)
          ..lineTo(o.dx + 150, o.dy - 62)
          ..quadraticBezierTo(o.dx + 190, o.dy - 58, o.dx + 200, o.dy - 40)
          ..quadraticBezierTo(o.dx + 150, o.dy - 30, o.dx + 110, o.dy - 14)
          ..lineTo(o.dx + 60, o.dy + 20)
          ..lineTo(o.dx + 60, o.dy + 50)
          ..lineTo(o.dx + 110, o.dy + 80)
          ..lineTo(o.dx - 110, o.dy + 80)
          ..lineTo(o.dx - 60, o.dy + 50)
          ..lineTo(o.dx - 60, o.dy + 20)
          ..lineTo(o.dx - 130, o.dy - 14)
          ..quadraticBezierTo(o.dx - 170, o.dy - 30, o.dx - 170, o.dy - 62)
          ..close();
        c.drawPath(anvil, Paint()..color = p.stoneFoot.withValues(alpha: 0.5));
        c.save();
        c.clipPath(anvil);
        c.drawPath(
          anvil.shift(const Offset(0, 5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = Colors.black.withValues(alpha: 0.35),
        );
        c.restore();
        groove(anvil, w: 2.4);
        groove(
          Path()
            ..moveTo(o.dx - 140, o.dy - 30)
            ..lineTo(o.dx + 150, o.dy - 30),
          w: 1.4,
        );
        for (var i = 0; i < 3; i++) {
          final y = 225.0 + i * 32;
          groove(
            Path()
              ..moveTo(r.left + 548, r.top + y)
              ..lineTo(r.left + 650, r.top + y),
            w: 2,
          );
        }
      case 'ring_cloud':
        // Rings in rings: the cloud's shape, cut three times into the floor.
        final o = at(0.5, 0.46);
        for (final rad in const [96.0, 150.0, 204.0]) {
          ring(o, rad, w: rad == 150 ? 4 : 2.4);
        }
      case 'spiral_cloud':
        // The eye: a dais under the spiral, and the vents' own ring cut
        // round it so the eight eyes read as one wheel.
        final o = at(0.5, 0.46);
        dais(o, 128, 128, 6, joints: 16);
        ring(o, 210, w: 2.6);
      case 'veil_cloud':
        // Three long troughs the veils hang down into.
        for (final fx in const [0.2, 0.47, 0.73]) {
          trough(
            Rect.fromCenter(
              center: at(fx, 0.52),
              width: 46,
              height: r.height * 0.66,
            ),
          );
        }
      case 'sky_loom':
        // The loom's wheel: a ring cut round the core, and a spoke run out
        // to every anchor it is waiting on.
        final o = at(0.5, 0.49);
        ring(o, 116, w: 3.4);
        for (final a in room.anchors) {
          final d = a.position - o;
          final u = d / d.distance;
          groove(
            Path()
              ..moveTo((o + u * 116).dx, (o + u * 116).dy)
              ..lineTo((a.position - u * 22).dx, (a.position - u * 22).dy),
            w: 2,
          );
        }
      case 'relic_chamber':
        // The reliquary: two steps up to what the spire keeps.
        final o = room.vaultCache ?? at(0.5, 0.5);
        dais(o.translate(0, 26), 150, 84, 10, joints: 10);
        dais(o.translate(0, 14), 92, 52, 9, joints: 6);
      case 'storm_rune_hall':
        // An aisle of long flags up to the mural, between column bases.
        final aisle = Rect.fromLTRB(
          r.center.dx - 90,
          r.top + r.height * 0.36,
          r.center.dx + 90,
          r.bottom,
        );
        c.drawRect(aisle, Paint()..color = daisTop.withValues(alpha: 0.7));
        for (var y = aisle.top; y < aisle.bottom; y += 56) {
          c.drawLine(
            Offset(aisle.left, y),
            Offset(aisle.right, y),
            Paint()
              ..strokeWidth = 1.4
              ..color = p.joint.withValues(alpha: 0.8),
          );
        }
        c.drawLine(
          Offset(aisle.center.dx, aisle.top),
          Offset(aisle.center.dx, aisle.bottom),
          Paint()
            ..strokeWidth = 1.2
            ..color = p.joint.withValues(alpha: 0.55),
        );
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 3; i++) {
            final o = Offset(
              aisle.center.dx + side * 150,
              aisle.top + 40 + i * 110,
            );
            paintCarvedBlock(
              c,
              Rect.fromCenter(center: o, width: 36, height: 26),
              8,
              p,
              radius: 3,
              topColor: daisTop,
            );
          }
        }
      case 'twin_conduit':
        // The rod field on a raised terrace; the two conduits' plinths
        // joined by a channel cut through the floor.
        final conduits = [for (final cd in room.conduits) cd.position];
        if (conduits.length >= 2) {
          final a = conduits[0], b = conduits[1];
          final mid = Offset((a.dx + b.dx) / 2, max(a.dy, b.dy) + 60);
          groove(
            Path()
              ..moveTo(a.dx, a.dy)
              ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
            w: 6,
          );
          for (final o in conduits) {
            dais(o.translate(0, 10), 46, 26, 6, joints: 6);
          }
        }
      case 'storm_altar':
        // Three steps up to the altar, and the storm's eight lanes cut
        // out from its foot.
        final o = at(0.5, 0.49);
        for (var i = 0; i < 8; i++) {
          final a = i / 8 * 2 * pi;
          groove(
            Path()
              ..moveTo(o.dx + cos(a) * 190, o.dy + sin(a) * 150)
              ..lineTo(o.dx + cos(a) * 320, o.dy + sin(a) * 250),
            w: 2,
          );
        }
        dais(o.translate(0, 34), 180, 118, 10, joints: 12);
        dais(o.translate(0, 22), 128, 84, 9, joints: 8);
      case 'guardian_summit':
        // The duelling floor: one wide ring, and the storm's scoring run
        // out from it past the stones.
        final o = at(0.5, 0.41);
        ring(o, 160, w: 4);
        ring(o, 60, w: 2.4);
        for (var i = 0; i < 16; i++) {
          final a = i / 16 * 2 * pi;
          groove(
            Path()
              ..moveTo(o.dx + cos(a) * 60, o.dy + sin(a) * 60)
              ..lineTo(
                o.dx + cos(a) * (i.isEven ? 230 : 160),
                o.dy + sin(a) * (i.isEven ? 230 : 160),
              ),
            w: i.isEven ? 2.2 : 1.4,
          );
        }
      case 'spire_summit':
        // The crown: an octagonal terrace raised under the ring of stones.
        final o = at(0.5, 0.47);
        final oct = Path();
        for (var i = 0; i < 8; i++) {
          final a = i / 8 * 2 * pi + pi / 8;
          final q = o + Offset(cos(a) * 200, sin(a) * 170);
          i == 0 ? oct.moveTo(q.dx, q.dy) : oct.lineTo(q.dx, q.dy);
        }
        oct.close();
        c.drawPath(
          oct.shift(const Offset(0, 10)),
          Paint()..color = p.stoneFoot.withValues(alpha: 0.7),
        );
        c.drawPath(oct, Paint()..color = daisTop);
        groove(oct, w: 2);
        for (var i = 0; i < 8; i++) {
          final a = i / 8 * 2 * pi + pi / 8;
          c.drawLine(
            o + Offset(cos(a) * 70, sin(a) * 60),
            o + Offset(cos(a) * 200, sin(a) * 170),
            Paint()
              ..strokeWidth = 1.2
              ..color = p.joint.withValues(alpha: 0.75),
          );
        }
        ring(o, 70, squash: 60 / 70, w: 2);
    }
  }

  /// A floating ledge, carved: the same jagged rock hanging beneath it, and a
  /// flagged top of the same cloud-slate as the stages.
  void _renderSkyIsland(Canvas canvas, Rect rect) {
    final storm = _isStormRoom(currentRoom);
    final key =
        'isle|${rect.left.round()},${rect.top.round()},'
        '${rect.width.round()}x${rect.height.round()}|${storm ? 1 : 0}'
        '|${currentRoom.id}';
    final zone = _skyZoneOf(currentRoom);
    canvas.drawPicture(
      _skyFabricCache.putIfAbsent(key, () => _bakeSkyIsland(rect, storm, zone)),
    );
    // Thin mist clinging to the underside only.
    if (_fx.ready) {
      final n = (rect.width / 140).clamp(2, 6).toInt();
      for (var i = 0; i < n; i++) {
        final x = rect.left + (i + 0.5) / n * rect.width;
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, rect.bottom + 6),
          70,
          const Color(0xFF2A3850).withValues(alpha: storm ? 0.28 : 0.4),
        );
      }
    }
  }

  ui.Picture _bakeSkyIsland(Rect rect, bool storm, _SkyZone zone) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final geom = _cachedIslandGeometry(rect, stormVariant: storm);
    final rng = GlassRng(glassSeed('isle', rect));
    final stone = storm
        ? Color.lerp(_kSkyGlass.stoneFace, const Color(0xFF1E2733), 0.5)!
        : _kSkyGlass.stoneFace;
    c.drawPath(
      geom.underside.shift(const Offset(0, 5)),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [stone, _kSkyGlass.stoneFoot.withValues(alpha: 0.0)],
            ).createShader(
              Rect.fromLTRB(
                rect.left,
                rect.top,
                rect.right,
                rect.bottom + rect.height * 0.8,
              ),
            ),
    );
    // A THICK EDGE and a dark bed (2026-09-24): the ledges were pale see-
    // through slabs with no weight — a platform in the sky has to look like
    // something you would trust to stand on.
    c.drawPath(geom.top.shift(const Offset(0, 18)), Paint()..color = stone);
    c.drawPath(
      geom.top.shift(const Offset(0, 18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    c.save();
    c.clipPath(geom.top);
    c.drawRect(
      rect.inflate(4),
      Paint()..color = const Color(0xFF141C28).withValues(alpha: 0.72),
    );
    paintFlagFloor(
      c,
      rect.inflate(4),
      _kSkyGlass,
      rng,
      opacity: storm ? 0.5 : 0.55,
      course: 56,
      jointOpacity: 0.3,
    );
    c.drawRect(rect.inflate(4), Paint()..color = zone.wash);
    c.restore();
    c.drawPath(
      geom.top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = zone.light.withValues(alpha: storm ? 0.4 : 0.55),
    );
    return rec.endRecording();
  }

  // ── The hub: a rose of glass for a compass ──────────────

  List<RosePane> _compassRose(Offset c, double r) =>
      _cathedralRoseCache.putIfAbsent(
        'compass@${c.dx},${c.dy},$r',
        () => buildRose(c, [
          (r * 0.2, r * 0.44, 12, -pi / 2),
          (r * 0.44, r * 0.7, 16, -pi / 2),
          (r * 0.7, r * 0.96, 20, -pi / 2),
        ]),
      );

  /// The hub's compass, as a rose of glass set in the floor. Three rings, one
  /// per star, each filling round from north as its star comes on: the inner
  /// ring is the WIND, the middle the LOOM, the outer the STORM. Found, the
  /// First Wind turns the whole rose for good — the maxim's mark on the hub.
  void _drawGlassCompass(
    Canvas canvas,
    Offset c,
    double r, {
    required double windProgress,
    required double loomProgress,
    required double stormProgress,
    double spin = 0,
  }) {
    // The kerb it is set in.
    paintCarvedDisc(
      canvas,
      c + const Offset(0, -6),
      r * 1.08,
      r * 1.08,
      8,
      _kSkyGlass,
    );
    canvas.drawCircle(c, r, Paint()..color = _kSkyGlass.lead);

    canvas.save();
    if (spin != 0) {
      canvas.translate(c.dx, c.dy);
      canvas.rotate(spin);
      canvas.translate(-c.dx, -c.dy);
    }
    final panes = _compassRose(c, r);
    final progress = [windProgress, loomProgress, stormProgress];
    final live = [_kSkyGlass.live, _kLoomGlass, _kStormGlass];
    final counts = [12, 16, 20];
    for (final p in panes) {
      final prog = progress[p.ring].clamp(0.0, 1.0);
      final n = counts[p.ring];
      // Each pane takes its share of the ring, in order round from north.
      final lit = (prog * n - p.index).clamp(0.0, 1.0);
      final base = _kSkyGlass.frostAt(p.index + p.ring * 2);
      final fill = lit <= 0
          ? base
          : Color.lerp(base, live[p.ring], 0.25 + 0.4 * lit)!;
      paintPane(canvas, p.path, fill, _kSkyGlass, lead: 2.4);
      if (prog >= 1) {
        // A star banked: its ring breathes, pane by pane.
        final b = 0.08 * (0.5 + 0.5 * sin(_time * 1.4 + p.index * 0.7));
        paintPaneFill(canvas, p.path, Colors.white, opacity: b);
      }
    }
    // The cardinals, cut deep in gold lead across every ring.
    final spokes = Path();
    for (var i = 0; i < 4; i++) {
      final a = -pi / 2 + i * pi / 2;
      spokes
        ..moveTo(c.dx + cos(a) * r * 0.2, c.dy + sin(a) * r * 0.2)
        ..lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r);
    }
    canvas.drawPath(
      spokes,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _kSkyGlass.gold.withValues(alpha: 0.75),
    );
    canvas.restore();
    paintLead(
      canvas,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      _kSkyGlass,
      width: 4,
    );

    // The boss: the star the whole instrument points at, gold once all
    // three rings are full.
    final all = windProgress >= 1 && loomProgress >= 1 && stormProgress >= 1;
    paintRondel(
      canvas,
      c,
      r * 0.18,
      _kSkyGlass,
      fill: all ? const Color(0xFFFFE9A8) : const Color(0xFF17202C),
    );
    _drawStarGlyph(
      canvas,
      c,
      r * 0.11,
      (all ? const Color(0xFF5A3A08) : _kSkyGlass.gold).withValues(
        alpha: all ? 0.9 : 0.65,
      ),
    );
    final total = (windProgress + loomProgress + stormProgress) / 3;
    if (total > 0.02 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        r * (0.6 + 0.5 * total),
        _kSkyGlass.live.withValues(alpha: 0.06 + 0.08 * total),
      );
    }
  }

  // ── Gust shrines, gale vents, storm rods ────────────────

  /// A gust shrine: a carved cairn with three glass breath-slots in its face,
  /// gold-rimmed while asleep, filling with wind as its gale wakes.
  void _drawGlassShrine(
    Canvas canvas,
    Offset p, {
    required double swell,
    required bool woken,
  }) {
    paintContactShadow(canvas, p + const Offset(0, 22), 34, 10, opacity: 0.45);
    paintCarvedBlock(
      canvas,
      Rect.fromCenter(center: p + const Offset(0, -12), width: 26, height: 9),
      30,
      _kSkyGlass,
      radius: 2,
    );
    final pulse = woken ? 1.0 : 0.72 + 0.28 * sin(_time * 2.4);
    for (var i = 0; i < 3; i++) {
      final slot = Rect.fromCenter(
        center: p + Offset(0, -1 + i * 8.0),
        width: 16,
        height: 5,
      );
      paintPane(
        canvas,
        Path()..addRect(slot),
        woken ? _kSkyGlass.heat(0.45 + 0.5 * swell) : _kSkyGlass.frostAt(i),
        _kSkyGlass,
        lead: 1.6,
      );
      if (woken) {
        // The wind moving IN the glass.
        final t = (_time * (1.2 + swell) + i * 0.3) % 1.0;
        canvas.drawLine(
          Offset(slot.left + slot.width * t - 3, slot.center.dy),
          Offset(slot.left + slot.width * t + 3, slot.center.dy),
          Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.7 * swell),
        );
      }
    }
    // The gold rim round the slots: a thing you can act on.
    canvas.drawRect(
      Rect.fromCenter(center: p + const Offset(0, 7), width: 21, height: 26),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kSkyGlass.gold.withValues(
          alpha: (woken ? 0.45 : 0.85) * pulse,
        ),
    );
  }

  /// A gale vent: a glass eye on a carved stone, its breath cut into the lead
  /// as a shaft and a chevron — readable before it is ever touched.
  void _drawGlassVent(
    Canvas canvas,
    Offset p,
    Offset dir, {
    required double swell,
    required bool open,
    required bool culprit,
  }) {
    paintCarvedDisc(canvas, p + const Offset(0, 6), 17, 8, 7, _kSkyGlass);
    final pulse = open ? 1.0 : 0.74 + 0.26 * sin(_time * 2.2);
    final fill = culprit
        ? const Color(0xFFD07A4A)
        : open
        ? _kSkyGlass.heat(0.45 + 0.5 * swell)
        : _kSkyGlass.frostAt(2);
    paintRondel(canvas, p, 12, _kSkyGlass, fill: fill, rim: pulse);
    final head = p + dir * 9;
    final wing = Offset(-dir.dy, dir.dx);
    final carve = Path()
      ..moveTo((p - dir * 9).dx, (p - dir * 9).dy)
      ..lineTo(head.dx, head.dy)
      ..moveTo((head - dir * 5 + wing * 4).dx, (head - dir * 5 + wing * 4).dy)
      ..lineTo(head.dx, head.dy)
      ..lineTo((head - dir * 5 - wing * 4).dx, (head - dir * 5 - wing * 4).dy);
    paintLead(canvas, carve, _kSkyGlass, width: 2.2, light: _kSkyGlass.gold);
  }

  /// A storm rod's rank, in glass beads up its iron: lit to the rank it
  /// stands at, smoked above — countable at a glance, which is the puzzle.
  void _drawRodBeads(Canvas canvas, Offset foot, int rank, double unit) {
    for (var i = 1; i <= kStormRodMaxHeight; i++) {
      final at = Offset(foot.dx + 7, foot.dy + 4 - i * unit + unit * 0.5);
      paintRondel(
        canvas,
        at,
        3.4,
        _kSkyGlass,
        fill: i <= rank ? _kStormGlass : _kSkyGlass.smoke,
        rim: i <= rank ? 0.9 : 0.35,
        lead: 1.4,
      );
    }
  }
}

extension WindCrownGlassPieces on PlanetDungeonGame {
  /// The crown's standing stones: carved blocks round the summit, not the
  /// dark rounded bars they were (which read as UI chips on the sky).
  void _drawGlassCrownStones(
    Canvas canvas,
    Offset c,
    double r, {
    bool storm = false,
  }) {
    for (var i = 0; i < 9; i++) {
      final a = -pi * 0.95 + i * pi * 1.9 / 8;
      final pos = c + Offset(cos(a), sin(a)) * r * (0.72 + 0.08 * (i % 3));
      final h = 30 + (i % 4) * 9.0;
      paintContactShadow(
        canvas,
        pos + const Offset(0, 6),
        36,
        10,
        opacity: 0.4,
      );
      paintCarvedBlock(
        canvas,
        Rect.fromCenter(center: pos - Offset(0, h), width: 24, height: 9),
        h,
        _kSkyGlass,
        radius: 2,
        topColor: storm ? const Color(0xFF5A6676) : null,
      );
    }
  }

  List<RosePane> _altarRose(Offset c) => _cathedralRoseCache.putIfAbsent(
    'airaltar@${c.dx},${c.dy}',
    () => buildRose(c, [
      (0.0, 22.0, 6, 0.2),
      (22.0, 44.0, 10, 0.0),
      (44.0, 64.0, 14, 0.25),
    ]),
  );

  /// The storm altar: a rose of glass on a carved dais, smoked while the
  /// conduits are cold and lit from the heart out when the altar opens.
  void _drawGlassStormAltar(Canvas canvas, Offset c, {required bool active}) {
    _drawAnvilLightningRods(canvas, c, 170, 8, dim: !active);
    paintCarvedDisc(canvas, c + const Offset(0, -4), 74, 74, 9, _kSkyGlass);
    final open = _altarShown.clamp(0.0, 1.0);
    for (final p in _altarRose(c)) {
      final r = (p.mid - c).distance / 64;
      final heat = ((open * 1.4 - r) / 0.4).clamp(0.0, 1.0);
      final fill = Color.lerp(
        _kSkyGlass.smoke,
        _kStormGlass,
        heat * (0.7 + 0.2 * sin(_time * 3 + p.index)),
      )!;
      paintPane(canvas, p.path, fill, _kSkyGlass, lead: 2.2);
    }
    paintLead(
      canvas,
      Path()..addOval(Rect.fromCircle(center: c, radius: 64)),
      _kSkyGlass,
      width: 3.4,
    );
    if (open > 0 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        60 + 40 * open,
        _kStormGlass.withValues(alpha: 0.2 * open),
      );
    }
  }

  /// The rune hall's mural as a window: smoked glass in a carved frame, the
  /// diagram in gold lead. A pylon the mural remembers is filled with sky
  /// glass; a Mask's reading fills the other and sets both arcs pulsing.
  void _drawGlassStormMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final c = Offset(b.center.dx, b.top + 140);
    final panel = Rect.fromCenter(center: c, width: 340, height: 150);
    final complete = revealTier >= 1;
    paintCarvedBlock(canvas, panel.inflate(10), 10, _kSkyGlass, radius: 6);
    canvas.drawRect(panel.inflate(2), Paint()..color = _kSkyGlass.lead);
    const cols = 7, rows = 3;
    for (var i = 0; i < cols; i++) {
      for (var k = 0; k < rows; k++) {
        final r = Rect.fromLTWH(
          panel.left + panel.width * i / cols,
          panel.top + panel.height * k / rows,
          panel.width / cols,
          panel.height / rows,
        );
        paintPane(
          canvas,
          Path()..addRect(r),
          Color.lerp(_kSkyGlass.frostAt(i + k), _kSkyGlass.smoke, 0.4)!,
          _kSkyGlass,
          lead: 1.8,
        );
      }
    }
    final left = c + const Offset(-110, 28);
    final right = c + const Offset(110, 28);
    final altar = c + const Offset(0, -34);
    Path tri(Offset p) => Path()
      ..moveTo(p.dx - 14, p.dy + 16)
      ..lineTo(p.dx, p.dy - 18)
      ..lineTo(p.dx + 14, p.dy + 16)
      ..close();
    final sync = 0.5 + 0.5 * sin(_time * 3.0);
    for (final (p, lit) in [(left, true), (right, complete)]) {
      paintPane(
        canvas,
        tri(p),
        lit
            ? _kSkyGlass.heat(0.55 + (complete ? 0.3 * sync : 0))
            : _kSkyGlass.smoke,
        _kSkyGlass,
        lead: 2.2,
      );
      paintLead(canvas, tri(p), _kSkyGlass, width: 1.2, light: _kSkyGlass.gold);
    }
    paintRondel(
      canvas,
      altar,
      12,
      _kSkyGlass,
      fill: complete
          ? _kSkyGlass.heat(0.5 + 0.35 * sync)
          : _kSkyGlass.frostAt(1),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (p, on) in [(left, true), (right, complete)]) {
      final mid = Offset((p.dx + altar.dx) / 2, (p.dy + altar.dy) / 2 - 10);
      arc.color = (on ? _kSkyGlass.live : _kSkyGlass.goldDeep).withValues(
        alpha: on ? (complete ? 0.3 + 0.5 * sync : 0.35) : 0.3,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - 16)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(altar.dx, altar.dy + 10),
        arc,
      );
    }
    paintLead(canvas, Path()..addRect(panel), _kSkyGlass, width: 3.4);
  }

  /// One of the Four Winds' pillars: a carved stone with its rune in glass.
  /// Wear is the whole puzzle, so the rune keeps fewer and shorter panes the
  /// longer its face was blown.
  void _drawWindPillar(
    Canvas canvas,
    Offset at, {
    required int strokes,
    required bool spoken,
    required bool cleaned,
    required double wear,
    required double flare,
  }) {
    const h = 46.0;
    paintContactShadow(canvas, at + const Offset(0, 8), 40, 12, opacity: 0.45);
    paintCarvedBlock(
      canvas,
      Rect.fromCenter(center: at - const Offset(0, h), width: 30, height: 10),
      h,
      _kSkyGlass,
      radius: 2,
    );
    final face = Rect.fromLTRB(at.dx - 15, at.dy - h + 5, at.dx + 15, at.dy);
    for (var k = 0; k < strokes; k++) {
      final dy = (k - (strokes - 1) / 2) * 11.0;
      final half = 10.0 * (cleaned ? (1 - wear * 0.55) : 0.8);
      final slot = Rect.fromCenter(
        center: face.center + Offset(0, dy),
        width: half * 2,
        height: 6,
      );
      paintPane(
        canvas,
        Path()..addRect(slot),
        spoken
            ? _kSkyGlass.heat(0.7 + 0.15 * sin(_time * 2 + k))
            : cleaned
            ? Color.lerp(
                _kSkyGlass.frostAt(k),
                _kSkyGlass.live,
                0.25 + 0.3 * (1 - wear),
              )!
            : Color.lerp(_kSkyGlass.smoke, _kSkyGlass.live, flare * 0.6)!,
        _kSkyGlass,
        lead: 1.6,
      );
    }
  }

  /// The loom's heart: a glass rondel on a carved kerb, brightening with every
  /// echo laid into it.
  void _drawGlassLoomCore(Canvas canvas, Offset c, double fill) {
    paintCarvedDisc(canvas, c + const Offset(0, -4), 50, 50, 8, _kSkyGlass);
    paintRondel(
      canvas,
      c,
      40,
      _kSkyGlass,
      fill: fill <= 0
          ? _kSkyGlass.frostAt(3)
          : _kSkyGlass.heat(0.2 + 0.6 * fill),
    );
    paintStreak(canvas, Rect.fromCircle(center: c, radius: 26), opacity: fill);
  }

  /// A loom anchor: a gold-rimmed glass seat, frosted until an echo is laid
  /// in, sky-lit once one is.
  void _drawGlassAnchor(Canvas canvas, Offset p, {required bool filled}) {
    paintRondel(
      canvas,
      p,
      15,
      _kSkyGlass,
      fill: filled ? _kSkyGlass.heat(0.62) : _kSkyGlass.frostAt(2),
      rim: filled ? 1.0 : 0.7,
    );
  }

  /// A conduit's channel, in glass: three panes up the obelisk, cold smoke
  /// until it holds charge.
  void _drawConduitGlass(Canvas canvas, Offset c, Color color, bool charged) {
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromCenter(
        center: c + Offset(0, -20 + i * 18.0),
        width: 10,
        height: 16,
      );
      paintPane(
        canvas,
        Path()..addRect(r),
        charged
            ? Color.lerp(color, Colors.white, 0.25 + 0.2 * sin(_time * 9 + i))!
            : _glass.smoke,
        _glass,
        lead: 1.6,
      );
    }
  }

  // ── Clouds, plumes and veils, in grains (grain_cloud.dart) ──

  /// A wonder-cloud pickup (or its echo in a loom socket) as grains: the
  /// spiral winds, the ring turns, the anvil stands flat-topped, the
  /// thundercloud flickers inside, the plume lies on its diagonal, the veil
  /// falls. 110–450 grains, one batch.
  void _paintCloudGrains(
    Canvas canvas,
    Offset c,
    String type,
    Color col, {
    bool echo = false,
  }) {
    if (col.a <= 0.02) return;
    // A faint pool under it so it holds against a busy sky — never a ring.
    if (_fx.ready && !echo) {
      drawGlow(canvas, _fx.glow!, c, 34, col.withValues(alpha: col.a * 0.1));
    }
    final ramp = grainRampFrom(col);
    final a = (col.a * (echo ? 0.95 : 1.15)).clamp(0.0, 1.0);
    final shape = _skyIconShapes.putIfAbsent(type, () => _cloudIconShape(type));
    switch (type) {
      case 'Spiral':
        paintGrainShape(
          canvas,
          shape,
          _time,
          origin: c,
          rotation: _time * 0.45,
          spin: 0.45,
          drift: 0.7,
          alpha: a,
          ramp: ramp,
        );
      case 'Ring':
        paintGrainShape(
          canvas,
          shape,
          _time,
          origin: c,
          rotation: _time * 0.7,
          spin: 0.7,
          drift: 0.7,
          alpha: a,
          ramp: ramp,
        );
      case 'Feather':
        paintGrainShape(
          canvas,
          shape,
          _time,
          origin: c + Offset(0, sin(_time * 0.9 + c.dy * 0.01) * 2.5),
          rotation: -0.62 + sin(_time * 1.1 + c.dx * 0.01) * 0.05,
          drift: 0.6,
          alpha: a,
          ramp: ramp,
        );
      case 'Veil':
        paintGrainShape(
          canvas,
          shape,
          _time,
          origin: c,
          fall: 64,
          fallSpeed: 13,
          drift: 1.4,
          alpha: a * 0.8,
          ramp: ramp,
        );
        paintGrainShape(
          canvas,
          _skyIconShapes.putIfAbsent(
            'Veil|hem',
            () => _cloudIconShape('Veil|hem'),
          ),
          _time,
          origin: c,
          drift: 0.5,
          alpha: a,
          ramp: ramp,
        );
      default:
        paintGrainShape(
          canvas,
          shape,
          _time,
          origin: c,
          drift: 1.0,
          alpha: a,
          ramp: ramp,
          glint: type == 'Thundercloud' ? 0.06 : 0,
        );
    }
  }

  /// Each pickup's shape, centred on its origin, at the size the old
  /// drawings were.
  GrainShape _cloudIconShape(String type) {
    final rng = Random(type.hashCode & 0xFFFF);
    switch (type) {
      case 'Spiral':
        // One arm wound out from a bright core.
        final pts = <Offset>[];
        final shade = <double>[];
        for (var i = 1; i <= 38; i++) {
          final th = i * 0.34;
          final r = i * 0.68;
          for (var k = 0; k < 4; k++) {
            final j = (rng.nextDouble() - 0.5) * (1.2 + r * 0.18);
            pts.add(Offset(cos(th) * (r + j), sin(th) * (r + j)));
            shade.add(1 - 0.75 * r / 26);
          }
        }
        for (var k = 0; k < 10; k++) {
          pts.add(Offset(rng.nextDouble() * 4 - 2, rng.nextDouble() * 4 - 2));
          shade.add(1);
        }
        return GrainShape.points(pts, shade, seed: 5);
      case 'Ring':
        // A band with three thicker arcs, so its turning shows; lit on top.
        final pts = <Offset>[];
        final shade = <double>[];
        while (pts.length < 170) {
          final a = rng.nextDouble() * 2 * pi;
          if (rng.nextDouble() > 0.35 + 0.65 * (0.5 + 0.5 * cos(3 * a))) {
            continue;
          }
          final r = 14 + rng.nextDouble() * 9;
          pts.add(Offset(cos(a), sin(a)) * r);
          shade.add(0.5 - 0.5 * sin(a));
        }
        return GrainShape.points(pts, shade, seed: 6);
      case 'Anvil':
      case 'Thundercloud':
        // Built from its parts at their own densities, or it is a blob: the
        // sheared flat top packed bright with a hard top edge, a thinner
        // column under it, and the base lobes rounded and dim.
        final pts = <Offset>[];
        final shade = <double>[];
        void fill(int n, Rect box, bool Function(Offset) inside, double lit) {
          var made = 0;
          while (made < n) {
            final p = Offset(
              box.left + rng.nextDouble() * box.width,
              box.top + rng.nextDouble() * box.height,
            );
            if (!inside(p)) continue;
            pts.add(p);
            shade.add(lit + 0.2 * (box.bottom - p.dy) / box.height);
            made++;
          }
        }

        // The top: a trapezoid sheared downwind, and its edge.
        bool slab(Offset p) {
          final u = (p.dy + 17) / 8; // 0 at the top edge .. 1 at the base
          return p.dx > -23 - 8 * u && p.dx < 28 + 10 * u;
        }

        fill(95, const Rect.fromLTRB(-31, -17, 38, -9), slab, 0.75);
        for (var x = -23.0; x <= 28; x += 1.7) {
          pts.add(Offset(x, -17 + (rng.nextDouble() - 0.5) * 0.8));
          shade.add(1);
        }
        // The column, narrowing from the top down to the lobes.
        fill(55, const Rect.fromLTRB(-27, -9, 33, 12), (p) {
          final u = (p.dy + 9) / 21;
          return p.dx > -27 + 9 * u && p.dx < 33 - 16 * u;
        }, 0.4);
        // The lobes.
        for (final (o, r) in const [
          (Offset(-17, 12), 11.0),
          (Offset(3, 14), 13.0),
          (Offset(20, 12), 10.0),
        ]) {
          fill(
            (r * 2.6).round(),
            Rect.fromCircle(center: o, radius: r),
            (p) => (p - o).distance < r * (0.55 + 0.45 * rng.nextDouble()),
            0.15,
          );
        }
        return GrainShape.points(pts, shade, seed: 7);
      case 'Feather':
        return GrainShape.feather(76);
      case 'Veil':
        return GrainShape.region(
          const Rect.fromLTRB(-20, -32, 20, 32),
          (p) => p.dx.abs() < 20 - (p.dy + 32) / 64 * 7,
          150,
          seed: 8,
        );
      case 'Veil|hem':
        // The hem the veil hangs from: a bowed line of grains, still.
        final pts = <Offset>[];
        final shade = <double>[];
        for (var x = -22.0; x <= 22; x += 1.5) {
          final y = -33 - 4 * (1 - (x / 22) * (x / 22));
          pts.add(Offset(x, y + (rng.nextDouble() - 0.5)));
          shade.add(1);
        }
        return GrainShape.points(pts, shade, seed: 9);
      default:
        return GrainShape.puffs(const [
          (Offset(-8, 2), 8.0),
          (Offset(8, 2), 8.0),
          (Offset(0, -4), 10.0),
        ], 110);
    }
  }

  /// A plume of [len] at [c], in grains, on its diagonal and drifting.
  void _paintFeatherGrains(Canvas canvas, Offset c, double len, Color col) {
    final shape = _skyIconShapes.putIfAbsent(
      'plume|${len.round()}',
      () => GrainShape.feather(len.roundToDouble()),
    );
    paintGrainShape(
      canvas,
      shape,
      _time,
      origin: c + Offset(0, sin(_time * 0.9 + c.dy * 0.01) * 2.5),
      rotation: -0.62 + sin(_time * 1.1 + c.dx * 0.01) * 0.05,
      drift: len * 0.012,
      alpha: min(1.0, col.a * 1.6),
      ramp: grainRampFrom(col),
    );
  }

  /// A falling plume comes apart: caught, its grains fold into the catcher
  /// ([to]); missed, they loosen and fall away into the void.
  void _loosenFeather(Offset p, {Offset? to}) {
    const lie = -0.62;
    for (var i = 0; i < 46; i++) {
      final along = (_combatRng.nextDouble() - 0.5) * 34;
      final across = (_combatRng.nextDouble() - 0.5) * 9;
      _skyGrains.add(
        RiteGrain(
          x: p.dx + along * cos(lie) - across * sin(lie),
          y: p.dy + along * sin(lie) + across * cos(lie),
          vx: (_combatRng.nextDouble() - 0.5) * 20,
          vy: to == null ? 6 : -6,
          life: to == null ? 1.5 : 0.9 + _combatRng.nextDouble() * 0.3,
          color: i.isEven ? const Color(0xFFE8F2FA) : const Color(0xFFC9E6EC),
          lift: to == null ? -24 : 0,
          wander: to == null ? 14 : 6,
          to: to,
          pull: to == null ? 0 : 9,
          drag: to == null ? 1.6 : 3.2,
          seed: _combatRng.nextDouble() * 9,
        ),
      );
    }
  }

  /// THE SPIRAL'S TROPHY, in grains: three arms that turn TOGETHER, about
  /// once every 20 s, while their grains stream outward along them, with a
  /// bright bar across the core. The arms used to turn faster inside than
  /// outside with nothing to stop it, so within a minute they wound into
  /// rings that looked still (in the old stroked drawing too). ~2,200 grains.
  void _paintSpiralTrophy(Canvas canvas, Offset c) {
    const turn = 0.32;
    final ramp = grainRampFrom(const Color(0xFF5BC8E8));
    _spiralTrophyFlow.paint(
      canvas,
      _time,
      speed: 0.06,
      trail: 0.035,
      width: 1.8,
      ramp: ramp,
      at: (i, u, side, t) {
        // Just over one winding from core to rim: wound tighter (it was
        // three) the arms read as rings.
        final r = 8 + u * 104;
        final w = 3 + r * 0.2;
        final a = (i % 3) * pi * 2 / 3 + 0.072 * r + turn * t + side * w / r;
        return c + Offset(cos(a), sin(a)) * r;
      },
      light: (u, side) => (1 - 0.7 * u) * (0.45 + 0.55 * (1 - side.abs())),
    );
    // The bar of light across the core, turning with the arms.
    final bar = _skyIconShapes.putIfAbsent('spiral|bar', () {
      final rng = Random(43);
      final pts = <Offset>[];
      final shade = <double>[];
      for (var j = 0; j < 80; j++) {
        final x = (rng.nextDouble() - 0.5) * 44;
        pts.add(Offset(x, (rng.nextDouble() - 0.5) * (12 - x.abs() * 0.2)));
        shade.add(1 - x.abs() / 30);
      }
      return GrainShape.points(pts, shade, seed: 43);
    });
    paintGrainShape(
      canvas,
      bar,
      _time,
      origin: c,
      rotation: turn * _time,
      spin: turn,
      drift: 0.6,
      ramp: ramp,
      width: 1.8,
    );
  }

  /// The veil room's three curtains: grains falling slowly down each from a
  /// bowed hem, into the troughs cut for them. ~1,700 grains.
  void _paintVeilCurtains(Canvas canvas, Rect b) {
    const col = Color(0xFFBFD2E6);
    final ramp = grainRampFrom(col);
    final top = b.top + 105;
    final bottom = b.bottom - 80;
    final h = bottom - top;
    // Over the troughs carved for them (see _paintSkyGround).
    final r = b.deflate(8);
    for (var i = 0; i < 3; i++) {
      final x = r.left + r.width * const [0.2, 0.47, 0.73][i];
      const w = 96.0;
      final body = _skyIconShapes.putIfAbsent('veil|$i|${h.round()}', () {
        // Gossamer: thick down the middle, thinning to nothing at the sides.
        final rng = Random(50 + i);
        return GrainShape.region(
          Rect.fromLTRB(-w / 2, -h / 2, w / 2, h / 2),
          (p) {
            final u = p.dx / (w / 2);
            return rng.nextDouble() < 1 - u * u;
          },
          (w * h / 34).round(),
          seed: 50 + i,
        );
      });
      paintGrainShape(
        canvas,
        body,
        _time + i * 3.1,
        origin: Offset(x, top + h / 2),
        fall: h,
        fallSpeed: 9,
        drift: 7,
        alpha: 0.42,
        ramp: ramp,
        width: 1.6,
        trail: 0.05,
      );
      final hem = _skyIconShapes.putIfAbsent('veil|hem|$i', () {
        final pts = <Offset>[];
        final shade = <double>[];
        for (var dx = -w / 2 - 4; dx <= w / 2 + 4; dx += 1.6) {
          final u = dx / (w / 2);
          pts.add(Offset(dx, -10 * (1 - u * u)));
          shade.add(1);
        }
        return GrainShape.points(pts, shade, seed: 60 + i);
      });
      paintGrainShape(
        canvas,
        hem,
        _time,
        origin: Offset(x, top),
        drift: 0.8,
        alpha: 0.7,
        ramp: ramp,
      );
    }
  }
}
