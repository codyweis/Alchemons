// lib/games/stadium/race_painter.dart
//
// A race, drawn as everything else in the game is: lit grains on black.
//
//  * Where it runs: the stadium's stands at the start, along the crowd's
//    stretches and before the line; between, the course's own country
//    (race_scenes.dart) — its sky, ranges and drifting air.
//  * The ground: the track's six lanes following the course's shape — the
//    rolling country, a hill up and over, a pond's water, ice, mud, nothing
//    over a gap but the dark down into it — over the face of the earth it
//    stands on; fine dust fixed to it that streams past underfoot.
//  * The six, back lane to front, each carried by its pose: running, up a
//    slope, half under water swimming, gliding a gap or climbing down and
//    out of it, sliding, wading; dust, spray, sparkle or mud thrown up
//    behind; a boost gathered in and poured out as a current of their
//    colour; at a station each comes apart into what its fusion makes
//    (EssenceField, the details screen's essence) and gathers again.
//  * The theatre: the count drawn in brass grains that gather and drift
//    apart, the curtains at the start and the line, a photo finish closing
//    in, and the podium — three plinths of stone grains, the winner bursting
//    into its element and back.
//
// Cost: everything is culled to the view and batched by tone into
// drawRawPoints; the ground is two vertex strips; a few thousand points a
// frame, no blurs, no saved layers except a label's fade and a swimmer's
// clip.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/shared/creature_looks.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_layout.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/games/stadium/race_stage.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bgTop = Color(0xFF09090B);
const Color _bgLow = Color(0xFF131316);
const Color _dust = Color(0xFFA89C88);

/// The count's numerals read into grains, once per run of the app.
Future<Map<int, SpecimenGrains>> loadRaceNumerals({
  TextStyle style = const TextStyle(),
}) async {
  final out = raceNumeralGrains;
  if (out.length == 3) return out;
  for (final n in const [3, 2, 1]) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$n',
        style: style.copyWith(
          color: Colors.white,
          fontSize: 120,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width.ceil() + 8, h = tp.height.ceil() + 8;
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), const Offset(4, 4));
    final image = await rec.endRecording().toImage(w, h);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) continue;
      out[n] = SpecimenGrains.fromRgba(
        Uint8List.view(data.buffer),
        w,
        h,
        pixelRatio: 1,
        maxGrains: 650,
        tones: 4,
      );
    } finally {
      image.dispose();
    }
  }
  return out;
}

/// The count's numerals as grains, filled by [loadRaceNumerals].
final Map<int, SpecimenGrains> raceNumeralGrains = {};

/// The stands: rows of grains that thin and shrink toward the back, broken
/// into clusters so they read as people, not as a ruled line. They brighten
/// round each x in [leaders], everywhere by [cheer], and bob when [lively];
/// [hush] dims them for a photo finish. [camX] scrolls them (slower than
/// the track: they are further away). Shared by the race and the stadium's
/// own screen.
void paintStadiumStands(
  Canvas c,
  Size size, {
  required double t,
  double camX = 0,
  List<double> leaders = const [],
  double cheer = 0,
  double hush = 1,
  bool lively = false,
  double opacity = 1,
}) {
  if (opacity <= 0.01) return;
  final w = size.width, h = size.height;
  final k0 = (h / 360).clamp(0.6, 1.6).toDouble();
  final standTop = h * 0.1, standBottom = h * 0.335;
  c.drawRect(
    Rect.fromLTRB(0, standTop, w, standBottom),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, standTop),
        Offset(0, standBottom),
        [
          const Color(0x00141418),
          const Color(0xFF141418).withValues(alpha: opacity),
        ],
      ),
  );
  final b = _standsBatch..clear();
  const rows = 13;
  for (var row = 0; row < rows; row++) {
    final back = 1 - row / (rows - 1);
    final step = (4.0 + 1.6 * (1 - back)) * k0;
    final par = 0.42 + 0.18 * (1 - back);
    final base = camX * k0 * par;
    final y0 =
        standTop +
        (standBottom - standTop) * (0.12 + 0.82 * (row / (rows - 1)));
    final from = (base / step).floor() - 2;
    final to = ((base + w) / step).ceil() + 2;
    for (var xi = from; xi <= to; xi++) {
      final hx = hash01(xi, row * 5 + 1), hy = hash01(xi, row * 5 + 2);
      final seats =
          0.5 + 0.5 * sin(xi * 0.21 + row * 1.7) * cos(xi * 0.053 + row);
      if (hash01(xi, row * 5 + 3) > 0.35 + seats * 0.6) continue;
      final x = xi * step - base + (hx - 0.5) * step * 0.8;
      var lit = cheer;
      for (final lx in leaders) {
        final d = (x - lx) / (260 * k0);
        lit += exp(-d * d) * 0.3;
      }
      lit = min(1.0, lit) * hush;
      final bob = lively
          ? sin(t * (5 + hx * 4) + hy * 6).abs() * 2.4 * k0 * lit
          : sin(t * 0.8 + hx * 9) * 0.5 * k0;
      final y = y0 + (hy - 0.5) * 3 * k0 - bob;
      final tone = (hy * 3).floor();
      final level = (lit * 2.6 + hx * 1.1 + (1 - back) * 0.6).floor().clamp(
        0,
        3,
      );
      b.add(tone * 4 + level, x, y);
    }
  }
  const tones = [Color(0xFFB8A27A), Color(0xFF9FA6B2), Color(0xFF9C8FB0)];
  for (var tone = 0; tone < 3; tone++) {
    for (var level = 0; level < 4; level++) {
      b.draw(
        c,
        tone * 4 + level,
        (1.3 + level * 0.35) * k0,
        tones[tone].withValues(alpha: (0.12 + level * 0.18) * opacity),
      );
    }
  }
}

final GrainBatch _standsBatch = GrainBatch(12);

/// The view: where the track sits on screen and how big a world pixel is.
class _Geo {
  _Geo(
    Size size,
    this.camX,
    double zoom, {
    this.camY = 0,
    double Function(double x)? ground,
  }) : w = size.width,
       h = size.height,
       k0 = (size.height / 360).clamp(0.6, 1.6).toDouble(),
       _ground = ground ?? _flat {
    k = k0 * zoom;
    gap = 26 * k;
    final cy = h * 0.655;
    top = cy - 3 * gap;
    bottom = cy + 3 * gap;
  }

  final double w, h, k0, camX;

  /// The ground's height the camera is held at (world px).
  final double camY;
  final double Function(double x) _ground;
  late final double k, gap, top, bottom;

  static double _flat(double _) => 0;

  double sx(double x) => w * 0.5 + (x - camX) * k;

  /// The track x at screen x [sx].
  double wx(double sx) => camX + (sx - w * 0.5) / k;

  /// How far the ground at track x [x] stands below where the camera holds
  /// it, on screen (up is negative).
  double dy(double x) => (camY - _ground(x)) * k;
  double get viewL => camX - w * 0.5 / k - 40;
  double get viewR => camX + w * 0.5 / k + 40;
  double laneY(int i) => top + (i + 0.6) * gap;

  /// Back lanes stand a little smaller.
  double depth(int i) => 0.84 + 0.032 * i;

  /// Where a row of the floor stands, from the back edge (0) to the front
  /// (1), and how deep it is there.
  double floorY(double v) => top + (0.1 + v * 5.95) * gap;
  double floorDepth(double v) => 0.84 + 0.16 * v;
}

/// The share of the screen the results take on the left once the race is
/// done; the podium stands aside, its middle this far across.
const double kRaceResultsSplit = .6;
const double kRaceResultsPodiumX = .8;

class RacePainter extends CustomPainter {
  RacePainter(this.stage, {this.textStyle = const TextStyle()})
    : super(repaint: stage);

  final RaceStage stage;

  /// The app's type, for the names and labels drawn on the track.
  final TextStyle textStyle;

  static final GrainBatch _batch = GrainBatch(24);
  static final Map<String, TextPainter> _labels = {};
  final Map<int, EssenceField> _essence = {};

  @override
  void paint(Canvas canvas, Size size) {
    final layout = stage.layout;
    final g = _Geo(
      size,
      stage.camX,
      stage.zoom,
      camY: stage.camY,
      ground: layout.groundAt,
    );
    final t = stage.clock;
    final look = kSceneLooks[stage.course.scene];
    // How much of the stadium the camera sees; the course's own country
    // shows through the rest.
    final stadium = look == null ? 1.0 : layout.stadiumAt(stage.camX);
    _sky(canvas, g);
    if (look != null && stadium < 0.99) {
      paintSceneBackdrop(
        canvas,
        size,
        look,
        camX: stage.camX,
        camY: stage.camY,
        k: g.k,
        horizon: g.top - 8 * g.k,
        reach: g.h * 0.42,
        t: t,
        amount: 1 - stadium,
      );
    }
    _crowd(canvas, g, t, stadium);
    _ground(canvas, g, t, look);
    _lines(canvas, g, t);
    _stations(canvas, g, t);
    // Back lane to front.
    if (stage.podiumT < 1) {
      for (var i = 0; i < stage.racers.length; i++) {
        _racer(canvas, g, i, t);
      }
    }
    _rail(canvas, g, stadium);
    if (look != null && stadium < 0.99) {
      paintSceneNear(
        canvas,
        size,
        look,
        camX: stage.camX,
        k: g.k,
        top: g.bottom + 14 * g.k + g.dy(stage.camX),
        amount: 1 - stadium,
      );
      paintSceneAir(
        canvas,
        size,
        look,
        camX: stage.camX,
        k: g.k,
        t: t,
        amount: 1 - stadium,
      );
    }
    _weather(canvas, g, t);
    _finishRipples(canvas, g);
    _photo(canvas, g);
    _count(canvas, g);
    if (stage.podiumT > 0) _podium(canvas, g, t);
  }

  // ── sky and crowd ─────────────────────────────────────────────────────────

  void _sky(Canvas c, _Geo g) {
    c.drawRect(
      Offset.zero & Size(g.w, g.h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, g.h),
          [_bgTop, _bgLow, _bgTop],
          const [0, 0.55, 1],
        ),
    );
    // Three lamps over the stands, warm and low.
    for (var j = -1; j <= 1; j++) {
      final at = Offset(g.w * (0.5 + j * 0.34), g.h * 0.05);
      c.drawCircle(
        at,
        g.h * 0.5,
        Paint()
          ..shader = ui.Gradient.radial(at, g.h * 0.5, [
            _brass.withValues(alpha: 0.07),
            _brass.withValues(alpha: 0),
          ]),
      );
    }
    final b = _batch..clear();
    final drift = g.camX * g.k0 * 0.06;
    for (var i = 0; i < 90; i++) {
      final x = (hash01(i, 11) * (g.w + 200) - drift) % (g.w + 200) - 100;
      final y = hash01(i, 12) * g.h * 0.12;
      b.add(hash01(i, 13) < 0.2 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.1 * g.k0, _ink.withValues(alpha: 0.25));
    b.draw(c, 1, 1.6 * g.k0, _ink.withValues(alpha: 0.5));
  }

  /// Stands of grains that brighten round the leaders, rise for the show
  /// and roar for the podium: rows that thin and shrink toward the back,
  /// broken into clusters so they read as people, not as a ruled line.
  void _crowd(Canvas c, _Geo g, double t, double opacity) {
    final roar = stage.podiumT;
    paintStadiumStands(
      c,
      Size(g.w, g.h),
      t: t,
      camX: g.camX,
      leaders: [
        for (var i = 0; i < stage.racers.length; i++)
          g.sx(stage.layout.xAt(stage.distance[i])),
      ],
      cheer: max(_crowdHeat() * 0.55, roar),
      hush:
          stage.photoAt != null && stage.finishedAtClock.every((f) => f == null)
          ? 0.5
          : 1.0,
      lively: stage.running || roar > 0,
      opacity: max(opacity, stage.podiumT),
    );
  }

  /// 0..1: how much of the field is on the crowd's stretch.
  double _crowdHeat() {
    var n = 0;
    for (var i = 0; i < stage.racers.length; i++) {
      final (leg, _) = stage.layout.legAt(stage.distance[i]);
      if (stage.course.legs[leg].kind == RaceLegKind.crowd &&
          stage.distance[i] < stage.course.length) {
        n++;
      }
    }
    return n / stage.racers.length;
  }

  // ── the track ─────────────────────────────────────────────────────────────

  /// What the track's top is made of at a stretch, near edge to far (two
  /// colours), and the earth's face under it, top to bottom.
  static const Color _floorFar = Color(0xFF0D0D10),
      _floorNear = Color(0xFF18181C),
      _faceStadium = Color(0xFF0B0B0E);

  ((Color, Color), (Color, Color)) _material(
    RaceLegKind? kind,
    double f,
    double stadium,
    SceneLook? look,
  ) {
    // The floor stays near black, as the stadium's: the country shows in a
    // little of its colour and in the grains lying on it.
    final tint = look == null ? 0.0 : 0.3 * (1 - stadium);
    var top = Color.lerp(_floorFar, look?.surface ?? _floorFar, tint)!;
    var low = Color.lerp(_floorNear, look?.surface ?? _floorNear, tint)!;
    var faceTop = Color.lerp(_faceStadium, look?.face ?? _faceStadium, tint)!;
    // Water, ice and mud come on over the first and last stretch of their
    // leg, not as a box.
    final edge = _smooth(min(f, 1 - f) / 0.12);
    // Only water takes a colour of its own, faintly; ice and mud are told
    // by what lies on them.
    if (kind == RaceLegKind.pond) {
      top = Color.lerp(top, const Color(0xFF0A1820), edge * 0.7)!;
      low = Color.lerp(low, const Color(0xFF0E2029), edge * 0.7)!;
      faceTop = Color.lerp(faceTop, const Color(0xFF0B1A22), edge * 0.7)!;
    }
    return ((top, low), (faceTop, Colors.black));
  }

  /// The ground under the six, following the course's shape (see the
  /// file's header), in two vertex strips per stretch of solid ground; the
  /// dust lying on it, its lit near edge, a few grains in the face under it;
  /// and over a gap the dark going down and its two walls.
  void _ground(Canvas c, _Geo g, double t, SceneLook? look) {
    final layout = stage.layout;
    const step = 6.0;
    final pad = 8 * g.k;
    final floats = look?.floats ?? false;
    final band = <double>[], bandC = <int>[];
    final face = <double>[], faceC = <int>[];
    final paint = Paint();
    void flush() {
      if (band.length >= 8) {
        c.drawVertices(
          ui.Vertices.raw(
            ui.VertexMode.triangleStrip,
            Float32List.fromList(band),
            colors: Int32List.fromList(bandC),
          ),
          BlendMode.dst,
          paint,
        );
      }
      if (face.length >= 8) {
        c.drawVertices(
          ui.Vertices.raw(
            ui.VertexMode.triangleStrip,
            Float32List.fromList(face),
            colors: Int32List.fromList(faceC),
          ),
          BlendMode.dst,
          paint,
        );
      }
      band.clear();
      bandC.clear();
      face.clear();
      faceC.clear();
    }

    for (var sx = -step; sx <= g.w + step; sx += step) {
      final x = g.wx(sx);
      if (!layout.solidAt(x)) {
        flush();
        continue;
      }
      final dy = g.dy(x);
      final at = layout.legAtX(x);
      final kind = at == null ? null : stage.course.legs[at.$1].kind;
      final st = look == null ? 1.0 : layout.stadiumAt(x);
      final ((top, low), (fTop, fLow)) = _material(kind, at?.$2 ?? 0, st, look);
      final yTop = g.top - pad + dy, yBot = g.bottom + pad + dy;
      band.addAll([sx, yTop, sx, yBot]);
      bandC.addAll([top.toARGB32(), low.toARGB32()]);
      if (!floats || st > 0.5) {
        face.addAll([sx, yBot, sx, max(yBot, g.h + 2)]);
        faceC.addAll([fTop.toARGB32(), fLow.toARGB32()]);
      }
    }
    flush();

    // Down into a gap: the dark, a little mist, and its walls, at the lips'
    // own places.
    for (var j = 0; j < stage.course.legs.length; j++) {
      if (stage.course.legs[j].kind != RaceLegKind.gap) continue;
      final x0 = layout.starts[j], wj = layout.widths[j];
      final lipA = x0 + kRaceGapLip * wj, lipB = x0 + (1 - kRaceGapLip) * wj;
      if (lipB < g.viewL || lipA > g.viewR) continue;
      final a = g.sx(lipA), z = g.sx(lipB);
      final yTop = g.top - pad + g.dy(lipA);
      final yFront = g.bottom + pad + g.dy(lipA);
      // The far wall going down from the track's far edge, lit at its top
      // and falling away into the dark; under the near edge, nothing.
      final wall = Rect.fromLTRB(a, yTop, z, g.h);
      c.drawRect(
        wall,
        Paint()
          ..shader = ui.Gradient.linear(
            wall.topCenter,
            wall.bottomCenter,
            [
              Color.lerp(_floorFar, look?.face ?? _faceStadium, 0.5)!,
              const Color(0xFF050507),
              Colors.black,
            ],
            [0, ((yFront - yTop) / (g.h - yTop)).clamp(0.05, 0.9), 1],
          ),
      );
      final b = _batch..clear();
      // Strata on the far wall.
      for (var row = 0; row < 18; row++) {
        final y = yTop + row * 4.2 * g.k;
        if (y > yFront + 30 * g.k) break;
        final fade = 1 - (y - yTop) / (yFront + 30 * g.k - yTop);
        for (var i = 0; i < 26; i++) {
          final h1 = hash01(j * 1000 + row * 41 + i, 523);
          if (h1 > fade * 0.55) continue;
          b.add(row < 2 ? 2 : 1, a + (i + h1) / 26 * (z - a), y + h1 * 2 * g.k);
        }
      }
      // Mist rising out of it.
      for (var i = 0; i < 40; i++) {
        final life = (t * 0.05 + hash01(i, 520 + j)) % 1.0;
        b.add(
          0,
          a + hash01(i, 521) * (z - a),
          wall.bottom - life * (wall.bottom - yFront) * 0.9,
        );
      }
      // The lips: ragged rock, down both sides.
      for (final (edge, side) in [(a, 1.0), (z, -1.0)]) {
        var row = 0;
        for (var y = yTop; y < g.h; y += 3.2 * g.k) {
          final h1 = hash01(j * 977 + (side > 0 ? 0 : 131) + row, 522);
          final h2 = hash01(j * 977 + (side > 0 ? 0 : 131) + row, 524);
          final out = (sin(row * 0.7 + j) * 0.5 + 0.5) * 6 * g.k;
          final x = edge + side * (out + h1 * 3 * g.k);
          b.add(h1 < 0.3 ? 2 : 1, x, y);
          if (h2 < 0.4) b.add(1, x - side * 3 * g.k, y + 1.5 * g.k);
          row++;
        }
      }
      b.draw(c, 0, 1.2 * g.k, (look?.airTone ?? _dust).withValues(alpha: 0.12));
      b.draw(
        c,
        1,
        1.8 * g.k,
        (look?.faceGrain ?? _dust).withValues(alpha: 0.6),
      );
      b.draw(c, 2, 2.0 * g.k, (look?.rim ?? _dust).withValues(alpha: 0.5));
    }

    // Grains: the dust on the top, the near edge, the face.
    final b = _batch..clear();
    const cell = 22.0;
    const rows = 14;
    final from = (g.viewL / cell).floor(), to = (g.viewR / cell).ceil();
    for (var xi = from; xi <= to; xi++) {
      for (var r = 0; r < rows; r++) {
        final h1 = hash01(xi * 17 + r, 500), h2 = hash01(xi * 17 + r, 501);
        final x = xi * cell + h1 * cell;
        if (!layout.solidAt(x)) continue;
        final at = layout.legAtX(x);
        final kind = at == null ? null : stage.course.legs[at.$1].kind;
        final v = (r + h2) / rows;
        final y = g.floorY(v) + g.dy(x);
        final st = look == null ? 1.0 : layout.stadiumAt(x);
        final edgeIn = _smooth(min(at?.$2 ?? 0, 1 - (at?.$2 ?? 0)) / 0.12);
        switch (kind) {
          case RaceLegKind.pond when edgeIn > h2:
            // Light moving on the water, in short streaks along it.
            final glint = sin(t * 2.2 + x * 0.045 + r * 1.3 + h1 * 6);
            if (glint > 0.3) {
              final sx = g.sx(x);
              b.add(glint > 0.8 ? 8 : 6, sx, y);
              b.add(6, sx + 2.5 * g.k, y);
              if (glint > 0.6) b.add(7, sx + 5 * g.k, y);
            }
          case RaceLegKind.ice when edgeIn > h2:
            // A pale sheen, and glints that come and go.
            b.add(7, g.sx(x), y);
            final tw = sin(t * 2.4 + h1 * 40 + r);
            if (tw > 0.82) b.add(8, g.sx(x) + 1.5 * g.k, y);
          case RaceLegKind.mud when edgeIn > h2:
            // Clots, and wet light on a few.
            b.add(9, g.sx(x), y);
            if (h1 < 0.5) b.add(9, g.sx(x) + 2 * g.k, y + 0.8 * g.k);
            if (h1 < 0.12) b.add(10, g.sx(x) + 1 * g.k, y - 0.6 * g.k);
          default:
            if (st > 0.5) {
              b.add(h1 < 0.15 ? 2 : (h1 < 0.55 ? 1 : 0), g.sx(x), y);
              break;
            }
            // The country's own ground: its grains, and here and there a
            // glint or an ember.
            b.add(3 + (h1 < 0.15 ? 2 : (h1 < 0.55 ? 1 : 0)), g.sx(x), y);
            final h3 = hash01(xi * 17 + r, 502);
            if (look != null && h3 < 0.1) {
              final px = g.sx(x) + (h3 - 0.05) * 40 * g.k;
              switch (look.air) {
                case SceneAir.embers:
                  if (sin(t * 1.6 + h3 * 60) > 0.3) b.add(15, px, y);
                case SceneAir.sparkle || SceneAir.stars:
                  if (sin(t * 2.1 + h3 * 70) > 0.6) b.add(16, px, y);
                default:
                  b.add(14, px, y);
              }
            }
        }
      }
    }
    // The near edge, lit (on the ground's own grid, so it holds still).
    final edgeStep = 3.4;
    for (
      var xi = (g.viewL / edgeStep).floor();
      xi <= (g.viewR / edgeStep).ceil();
      xi++
    ) {
      final x = xi * edgeStep;
      if (!layout.solidAt(x)) continue;
      final at = layout.legAtX(x);
      if (at != null && stage.course.legs[at.$1].kind == RaceLegKind.pond) {
        continue;
      }
      final y = g.bottom + pad + g.dy(x);
      final h1 = hash01(xi, 510);
      b.add(h1 < 0.25 ? 12 : 11, g.sx(x), y + (h1 - 0.5) * 1.5);
    }
    if (!floats) {
      const fc = 26.0;
      for (var xi = (g.viewL / fc).floor(); xi <= (g.viewR / fc).ceil(); xi++) {
        final x = xi * fc + hash01(xi, 530) * fc;
        if (!layout.solidAt(x)) continue;
        final y0 = g.bottom + pad + g.dy(x);
        for (var d = 7.0; d < 160; d += 11) {
          final h1 = hash01(xi * 13 + d.round(), 531);
          if (h1 > 0.42 - d / 160 * 0.3) continue;
          b.add(13, g.sx(x) + (h1 - 0.2) * 9, y0 + d * g.k);
        }
      }
    }
    final grain = look?.surfaceGrain ?? _dust;
    b.draw(c, 0, 1.0 * g.k, _dust.withValues(alpha: 0.07));
    b.draw(c, 1, 1.2 * g.k, _dust.withValues(alpha: 0.12));
    b.draw(c, 2, 1.5 * g.k, _dust.withValues(alpha: 0.2));
    b.draw(c, 3, 1.1 * g.k, grain.withValues(alpha: 0.16));
    b.draw(c, 4, 1.3 * g.k, grain.withValues(alpha: 0.28));
    b.draw(c, 5, 1.6 * g.k, grain.withValues(alpha: 0.45));
    b.draw(c, 14, 1.5 * g.k, (look?.rim ?? _dust).withValues(alpha: 0.55));
    b.draw(c, 15, 1.8 * g.k, (look?.airTone ?? _dust).withValues(alpha: 0.85));
    b.draw(c, 16, 1.8 * g.k, (look?.airTone ?? _dust).withValues(alpha: 0.9));
    b.draw(c, 6, 1.5 * g.k, const Color(0xFF8FD0E4).withValues(alpha: 0.4));
    b.draw(c, 7, 1.3 * g.k, const Color(0xFFCFEFF8).withValues(alpha: 0.28));
    b.draw(c, 8, 2.0 * g.k, const Color(0xFFF2FCFF).withValues(alpha: 0.85));
    b.draw(c, 9, 1.9 * g.k, const Color(0xFF4A3322).withValues(alpha: 0.75));
    b.draw(c, 10, 1.7 * g.k, const Color(0xFFC09A70).withValues(alpha: 0.7));
    final edge = look?.rim ?? _brass;
    b.draw(c, 11, 1.5 * g.k, edge.withValues(alpha: 0.28));
    b.draw(c, 12, 1.8 * g.k, edge.withValues(alpha: 0.5));
    b.draw(
      c,
      13,
      1.4 * g.k,
      (look?.faceGrain ?? const Color(0xFF3A3A40)).withValues(alpha: 0.4),
    );
  }

  /// Lane dots, the start, the finish, and each leg's markers.
  void _lines(Canvas c, _Geo g, double t) {
    final b = _batch..clear();
    final layout = stage.layout;
    const dot = 16.0;
    final from = (g.viewL / dot).floor(), to = (g.viewR / dot).ceil();
    for (var xi = from; xi <= to; xi++) {
      final x = xi * dot;
      if (!layout.solidAt(x)) continue;
      final at = layout.legAtX(x);
      final kind = at == null ? null : stage.course.legs[at.$1].kind;
      // No lane lines on water or mud, faint on ice.
      if (kind == RaceLegKind.pond || kind == RaceLegKind.mud) continue;
      final dy = g.dy(x);
      for (var l = 0; l <= 6; l++) {
        final y = g.top + (l + 0.1) * g.gap + dy;
        b.add(l == 0 || l == 6 ? 1 : 0, g.sx(x), y);
      }
    }
    b.draw(c, 0, 1.1 * g.k, _ink.withValues(alpha: 0.1));
    b.draw(c, 1, 1.5 * g.k, _brass.withValues(alpha: 0.26));
    b.clear();

    // The start and the finish: columns of grains across the lanes. The
    // start's rises as a curtain at the gun; the finish's always does.
    final gun =
        stage.running || stage.phase.index > RaceStagePhase.running.index
        ? stage.raceClock
        : -1.0;
    void column(double x, int bucket, {double rise = 0}) {
      if (x < g.viewL || x > g.viewR) return;
      final sx = g.sx(x);
      final dy = g.dy(x);
      for (var row = 0.0; row < g.bottom - g.top; row += 3 * g.k) {
        for (var col = 0; col < 2; col++) {
          b.add(bucket, sx + col * 3.2 * g.k, g.top + 0.1 * g.gap + row + dy);
        }
      }
      if (rise <= 0) return;
      for (var i = 0; i < 90; i++) {
        final life = (t * 0.22 + hash01(i, 21)) % 1.0;
        final y = g.bottom - life * (g.bottom - g.h * 0.36) * rise;
        final x =
            sx + (hash01(i, 22) - 0.5) * 10 * g.k + sin(life * 5 + i) * 2 * g.k;
        b.add(life < 0.5 ? bucket + 1 : 9, x, y);
      }
    }

    final startRise = gun < 0 ? 0.0 : max(0.0, 1 - gun / 1.8);
    column(0, 2, rise: startRise);
    column(stage.layout.finishX, 4, rise: 1);
    for (var j = 0; j < stage.course.legs.length; j++) {
      final leg = stage.course.legs[j];
      final x0 = stage.layout.starts[j], w = stage.layout.widths[j];
      // Switchback pylons: short posts, lane by lane, alternating.
      if (leg.kind == RaceLegKind.sprint && leg.level == 4) {
        for (var p = 0; p * 110 < w; p++) {
          final x = x0 + 55 + p * 110;
          if (x < g.viewL || x > g.viewR) continue;
          final dy = g.dy(x);
          for (var lane = p % 2; lane < 6; lane += 2) {
            for (var s = 0; s < 5; s++) {
              b.add(6, g.sx(x), g.laneY(lane) - (s * 3 + 2) * g.k + dy);
            }
          }
        }
      }
      // A grand leg: the floor's edges lit, a slow wave running along them.
      if (leg.level == 5 &&
          (leg.kind == RaceLegKind.sprint || leg.kind == RaceLegKind.crowd)) {
        final x1 = x0 + w;
        for (
          var x = max(x0, (g.viewL / 9).floor() * 9.0);
          x < min(x1, g.viewR);
          x += 9
        ) {
          final glow = 0.5 + 0.5 * sin(t * 4 - x * 0.03);
          final dy = g.dy(x);
          b.add(glow > 0.6 ? 8 : 7, g.sx(x), g.top - 4 * g.k + dy);
          b.add(glow > 0.6 ? 8 : 7, g.sx(x), g.bottom + 5 * g.k + dy);
        }
      }
    }
    b.draw(c, 2, 1.6 * g.k, _ink.withValues(alpha: 0.4));
    b.draw(c, 3, 1.5 * g.k, _ink.withValues(alpha: 0.35));
    b.draw(c, 4, 1.8 * g.k, _brassHot.withValues(alpha: 0.7));
    b.draw(c, 5, 1.5 * g.k, _brassHot.withValues(alpha: 0.45));
    b.draw(c, 9, 1.2 * g.k, _brassHot.withValues(alpha: 0.2));
    b.draw(c, 6, 1.9 * g.k, _brass.withValues(alpha: 0.6));
    b.draw(c, 7, 1.6 * g.k, _brass.withValues(alpha: 0.35));
    b.draw(c, 8, 2.0 * g.k, _brassHot.withValues(alpha: 0.7));
  }

  /// The brass rail along the near side of the track: closer than the
  /// lanes, so it passes faster than they do.
  void _rail(Canvas c, _Geo g, double opacity) {
    if (opacity <= 0.01) return;
    const par = 1.35;
    final b = _batch..clear();
    final y = g.bottom + 10 * g.k + g.dy(stage.camX);
    if (y > g.h + 4) return;
    final camR = stage.camX * par;
    final viewL = camR - g.w * 0.5 / g.k, viewR = camR + g.w * 0.5 / g.k;
    double sx(double x) => g.w * 0.5 + (x - camR) * g.k;
    for (var x = (viewL / 70).floor() * 70.0; x < viewR + 70; x += 70) {
      for (var s = 0; s < 5; s++) {
        b.add(1, sx(x), y + s * 3 * g.k);
      }
    }
    for (var x = (viewL / 8).floor() * 8.0; x < viewR + 8; x += 8) {
      b.add(0, sx(x), y + 1.5 * g.k);
    }
    b.draw(c, 0, 1.3 * g.k, _brass.withValues(alpha: 0.3 * opacity));
    b.draw(c, 1, 2.0 * g.k, _brass.withValues(alpha: 0.55 * opacity));
  }

  // ── set pieces ────────────────────────────────────────────────────────────

  /// The fusion stations' elements, every lane: a loose knot of the
  /// element's grains over a pool of its light. A racer draws its knot in
  /// as it fuses; after, only the pool is left.
  void _stations(Canvas c, _Geo g, double t) {
    for (var j = 0; j < stage.course.legs.length; j++) {
      final leg = stage.course.legs[j];
      if (leg.kind != RaceLegKind.fuse) continue;
      final x0 = stage.layout.starts[j], w = stage.layout.widths[j];
      if (x0 + w < g.viewL || x0 > g.viewR) continue;
      for (var lane = 0; lane < stage.racers.length; lane++) {
        _station(c, g, lane, j, leg, t);
      }
    }
  }

  void _station(Canvas c, _Geo g, int lane, int j, RaceLeg leg, double t) {
    final dep = g.depth(lane);
    final col = elementColor(leg.element!);
    final mid = stage.layout.starts[j] + stage.layout.widths[j] / 2;
    final cx = g.sx(mid);
    final dy = g.dy(mid);
    final cy = g.laneY(lane) - 18 * g.k * dep + dy;
    final d = stage.distance[lane];
    final legEnd = stage.course.legStarts[j] + leg.length;
    final fusing = stage.layout.fusionAt(d);
    final spent = d >= legEnd || (fusing != null && fusing > 0.3);
    final pull = fusing == null ? 0.0 : _smooth(fusing / 0.3);
    final ground = Offset(cx, g.laneY(lane) + 2 * g.k + dy);
    c.drawOval(
      Rect.fromCenter(center: ground, width: 52 * g.k * dep, height: 13 * g.k),
      Paint()
        ..shader = ui.Gradient.radial(ground, 26 * g.k * dep, [
          col.withValues(alpha: spent ? 0.12 : 0.32),
          col.withValues(alpha: 0),
        ]),
    );
    if (spent) return;
    final b = _batch..clear();
    final rx = g.sx(stage.layout.xAt(d));
    final ry = g.laneY(lane) - 14 * g.k * dep + dy;
    for (var i = 0; i < 80; i++) {
      final h1 = hash01(i, 40 + j), h2 = hash01(i, 41 + j);
      final a = h1 * pi * 2 + t * (0.5 + h2 * 0.9) * (i.isEven ? 1 : -1);
      final r = (4 + h2 * 10) * g.k * dep;
      var x = cx + cos(a) * r + sin(t * 0.7 + h1 * 5) * 2 * g.k;
      var y = cy + sin(a) * r * 0.75 + h2 * 3 * g.k;
      x += (rx - x) * pull;
      y += (ry - y) * pull;
      b.add(h2 < 0.25 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.9 * g.k * dep, col.withValues(alpha: 0.75 * (1 - pull)));
    b.draw(
      c,
      1,
      2.3 * g.k * dep,
      Color.lerp(col, Colors.white, 0.45)!.withValues(alpha: 0.9 * (1 - pull)),
    );
  }

  // ── the racers ────────────────────────────────────────────────────────────

  /// Who glides a gap, by lane.
  late final List<bool> _flyers = [
    for (final r in stage.racers)
      raceFlyer(r.entrant.element, r.entrant.family, scene: stage.course.scene),
  ];

  /// How far through a station's essence a fusion progress [fp] is.
  static double _essenceT(double fp) => fp < 0.3
      ? fp / 0.3 * 1.05
      : fp > 0.7
      ? 1.5 + (fp - 0.7) / 0.3 * (EssenceField.duration - 1.5)
      : 1.05 + (fp - 0.3) / 0.4 * 0.45;

  /// When a racer that fuses into something new hands its old form over.
  static const double _handOver = 1.15;

  void _racer(Canvas c, _Geo g, int lane, double t) {
    final s = stage.sim.states[lane];
    final dep = g.depth(lane);
    final d = stage.distance[lane];
    final layout = stage.layout;
    final legs = stage.course.legs;
    // What it is now: its own element, or what a fusion station back along
    // the course made it. At a station it turns part way through.
    final (legIdx, legF) = layout.legAt(d);
    final over = d >= stage.course.length;
    final els = stage.elements[lane];
    var element = over ? els.last : els[legIdx];
    final fp = over ? null : layout.fusionAt(d);
    final atStation = !over && legs[legIdx].kind == RaceLegKind.fuse;
    if (atStation) {
      final after = els[legIdx + 1];
      final turned = fp != null
          ? _essenceT(fp) >= _handOver + 0.15
          : legF > 0.5;
      if (turned) element = after;
    }
    final body = stage.bodyFor(lane, element);
    final wx = layout.xAt(d);
    var x = g.sx(wx);
    if (stage.phase == RaceStagePhase.intro) {
      x -= (1 - _easeOut(stage.introT)) * 180 * g.k;
    }
    final pose = layout.poseAt(d, flyer: _flyers[lane]);
    final scale = g.k * dep;
    final h = body.height;
    // The surface at its lane, and where its feet are: lifted off it over a
    // gap (or down into it), sunk into water or mud.
    final surface = g.laneY(lane) + g.dy(wx);
    final sunk = pose.sink * h * scale;
    final feet = surface - pose.lift * g.k * dep + sunk;
    final col = elementColor(element);
    final moving =
        stage.running || stage.phase.index > RaceStagePhase.running.index;
    final pace = moving ? (s.velocity / kRaceBasePace).clamp(0.0, 1.6) : 0.0;
    final motion = pose.motion;
    final onGround =
        pose.lift.abs() < 0.5 &&
        motion != RaceMotion.glide &&
        motion != RaceMotion.swim;

    // The ground under it, and the player's own light.
    if (onGround) {
      final shadowAt = Offset(x, feet + 1.5 * scale - sunk);
      c.drawOval(
        Rect.fromCenter(
          center: shadowAt,
          width: h * 0.9 * scale,
          height: 6 * scale,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      if (lane == stage.player) {
        c.drawOval(
          Rect.fromCenter(
            center: shadowAt,
            width: h * 1.6 * scale,
            height: 13 * scale,
          ),
          Paint()
            ..shader = ui.Gradient.radial(shadowAt, h * 0.8 * scale, [
              _brass.withValues(alpha: 0.28),
              _brass.withValues(alpha: 0),
            ]),
        );
      }
    }

    // What it throws up behind: dust, spray, sparkle, mud, a swimmer's
    // wake, stone as it climbs or clambers.
    if (pace > 0.15) {
      final (leg, _) = layout.legAt(d);
      final here = stage.course.legs[leg];
      final wet = here.kind == RaceLegKind.sprint && here.level == 2;
      switch (motion) {
        case RaceMotion.climb:
        case RaceMotion.clamber:
          _crumble(c, Offset(x, feet), scale, lane, t, h);
        case RaceMotion.swim:
          _wake(c, Offset(x, surface), scale, lane, t, h, pace);
        case RaceMotion.glide:
        case RaceMotion.fuse:
          break;
        case RaceMotion.slide:
          _kick(c, Offset(x, feet), scale, lane, d, pace, _Spray.ice);
        case RaceMotion.wade:
          _kick(c, Offset(x, surface), scale, lane, d, pace, _Spray.mud);
        case RaceMotion.run:
          _kick(
            c,
            Offset(x, feet),
            scale,
            lane,
            d,
            pace,
            wet ? _Spray.wet : _Spray.dust,
          );
      }
    }

    final stride = moving ? d * 0.11 : t * 3 + lane;
    final bob = switch (motion) {
      RaceMotion.run => -(sin(stride).abs()) * (moving ? 3.2 : 0.8) * scale,
      RaceMotion.climb => -(sin(stride * 1.4).abs()) * 2.2 * scale,
      RaceMotion.swim => sin(t * 3 + lane) * 1.4 * scale,
      RaceMotion.glide => sin(t * 2.2 + lane) * 2.0 * scale,
      RaceMotion.clamber => -(sin(stride * 1.8).abs()) * 1.6 * scale,
      RaceMotion.slide => 0.0,
      RaceMotion.wade => -(sin(stride * 0.6).abs()) * 1.5 * scale,
      RaceMotion.fuse => 0.0,
    };
    final centre = Offset(x, feet - h * scale / 2 + bob);

    final tick = stage.sim.tick;
    if (s.phase == RacerPhase.windup) {
      final p = ((tick - s.phaseFrom) / kRaceBoostWindupTicks).clamp(0.0, 1.0);
      _gather(c, centre, col, p, scale, lane);
    } else if (s.phase == RacerPhase.surge) {
      final p = ((tick - s.phaseFrom) / kRaceBoostSurgeTicks).clamp(0.0, 1.0);
      _trail(c, centre, col, p, scale, h, lane, t);
    }

    // A fusion: the racer comes apart into what it makes, holds that form,
    // and gathers back — the release and return at the essence's own pace.
    // Made into something new, it gathers back as that: the old form's
    // grains hand over to the new one's while they are the element.
    var spriteAlpha = 1.0;
    if (fp != null) {
      final before = stage.bodyFor(lane, els[legIdx]);
      final after = stage.bodyFor(lane, els[legIdx + 1]);
      final made = stage.fusionMade[lane][legIdx] ?? els[legIdx];
      final et = _essenceT(fp);
      spriteAlpha = EssenceField.spriteOpacity(et);
      final changes = !identical(before, after) && after.grains != null;
      final out = before.grains == null
          ? null
          : _essence.putIfAbsent(
              lane * 64 + legIdx,
              () =>
                  EssenceField(before.grains!, EssenceElement.of(made))
                    ..leaveAt = changes ? _handOver : null,
            );
      final into = !changes
          ? null
          : _essence.putIfAbsent(
              lane * 64 + legIdx + 32,
              () =>
                  EssenceField(after.grains!, EssenceElement.of(made))
                    ..reveal = true,
            );
      c.save();
      c.translate(centre.dx, centre.dy);
      c.scale(scale);
      out?.paint(c, Offset.zero, et);
      into?.paint(c, Offset.zero, et);
      c.restore();
    }

    if (spriteAlpha > 0.01) {
      // Half under water, or in mud to the knees: only what is above the
      // surface shows.
      final clip = sunk > 0.5;
      if (clip) {
        c.save();
        c.clipRect(
          Rect.fromLTRB(x - h * 2 * scale, 0, x + h * 2 * scale, surface + 1),
        );
      }
      final surgeLean = s.phase == RacerPhase.surge ? 0.08 : 0.03 * pace;
      _drawSprite(
        c,
        body,
        centre,
        scale,
        t,
        alpha: spriteAlpha,
        squash: s.phase == RacerPhase.windup ? 0.92 : 1.0,
        lean: switch (motion) {
          RaceMotion.slide => -0.06,
          RaceMotion.glide => pose.tilt * -1,
          _ => surgeLean - pose.tilt,
        },
      );
      if (clip) c.restore();
      if (motion == RaceMotion.swim) {
        _ripple(c, Offset(x, surface), scale, lane, t, h);
      }
    }

    // Names as they line up.
    if (stage.phase == RaceStagePhase.intro ||
        stage.phase == RaceStagePhase.countdown) {
      final a = stage.phase == RaceStagePhase.intro
          ? _smooth((stage.introT - lane * 0.08) / 0.3)
          : 1 - _smooth((3 - stage.countdownLeft) / 2.4);
      _label(
        c,
        body.member.displayName.toUpperCase(),
        lane == stage.player ? _brassHot : _ink.withValues(alpha: 0.8),
        Offset(x - h * scale * 0.7 - 6 * g.k, centre.dy),
        8.5 * g.k,
        a,
        alignRight: true,
      );
    }
  }

  /// A swimmer's wake: grains peeling back from it along the surface.
  void _wake(
    Canvas c,
    Offset at,
    double scale,
    int lane,
    double t,
    double h,
    double pace,
  ) {
    final b = _batch..clear();
    for (var i = 0; i < 22; i++) {
      final life = (t * 1.3 + hash01(i, 90 + lane)) % 1.0;
      final side = hash01(i, 91 + lane) < 0.5 ? -1.0 : 1.0;
      final x = at.dx - life * (26 + 20 * pace) * scale;
      final y = at.dy + side * life * 3.5 * scale;
      b.add(life < 0.35 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.3 * scale, const Color(0xFFBFE6F2).withValues(alpha: 0.3));
    b.draw(c, 1, 1.7 * scale, const Color(0xFFE6F8FF).withValues(alpha: 0.6));
  }

  /// The ring the water makes round a swimmer.
  void _ripple(
    Canvas c,
    Offset at,
    double scale,
    int lane,
    double t,
    double h,
  ) {
    final b = _batch..clear();
    final rx = h * 0.55 * scale, ry = 3.2 * scale;
    for (var i = 0; i < 30; i++) {
      final a = i / 30 * pi * 2 + t * 0.6;
      final front = sin(a) > 0;
      b.add(front ? 1 : 0, at.dx + cos(a) * rx, at.dy + sin(a) * ry);
    }
    b.draw(c, 0, 1.2 * scale, const Color(0xFFBFE6F2).withValues(alpha: 0.25));
    b.draw(c, 1, 1.5 * scale, const Color(0xFFE6F8FF).withValues(alpha: 0.55));
  }

  /// Dust from the feet: grains thrown back and up that settle again, each
  /// launched at its own point of the stride — spray in the wet, a glitter
  /// of ice, clots of mud.
  void _kick(
    Canvas c,
    Offset feet,
    double scale,
    int lane,
    double d,
    double pace,
    _Spray spray,
  ) {
    final b = _batch..clear();
    final n = (10 + 10 * pace).round();
    final high = switch (spray) {
      _Spray.wet => 9.0,
      _Spray.mud => 7.0,
      _Spray.ice => 3.0,
      _Spray.dust => 5.0,
    };
    for (var i = 0; i < n; i++) {
      final h1 = hash01(i, 70 + lane), h2 = hash01(i, 71 + lane);
      final life = (d * 0.016 + h1) % 1.0;
      final reach = (14 + h2 * 22) * pace;
      final x = feet.dx - life * reach * scale - 3 * scale;
      final y = feet.dy - sin(life * pi) * high * (0.5 + h2) * scale;
      b.add(life < 0.4 ? 1 : 0, x, y);
    }
    final col = switch (spray) {
      _Spray.wet => const Color(0xFFBFE6F2),
      _Spray.ice => const Color(0xFFEFFBFF),
      _Spray.mud => const Color(0xFF7A5A3A),
      _Spray.dust => _dust,
    };
    b.draw(c, 0, 1.2 * scale, col.withValues(alpha: 0.22));
    b.draw(c, 1, 1.6 * scale, col.withValues(alpha: 0.4));
  }

  /// Stone grains crumbling from under a climber and tumbling down.
  void _crumble(
    Canvas c,
    Offset feet,
    double scale,
    int lane,
    double t,
    double h,
  ) {
    final b = _batch..clear();
    for (var i = 0; i < 12; i++) {
      final life = (t * 1.6 + hash01(i, 80 + lane)) % 1.0;
      final side = hash01(i, 81 + lane) - 0.5;
      final x = feet.dx + side * h * 0.7 * scale - life * 6 * scale;
      final y = feet.dy + life * life * 26 * scale - 2 * scale;
      b.add(life < 0.5 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.6 * scale, const Color(0xFF8E8676).withValues(alpha: 0.45));
    b.draw(c, 1, 2.0 * scale, const Color(0xFFB8AE9C).withValues(alpha: 0.7));
  }

  void _drawSprite(
    Canvas c,
    RaceBody body,
    Offset centre,
    double scale,
    double t, {
    double alpha = 1,
    double squash = 1,
    double lean = 0.03,
    bool faceRight = true,
  }) {
    final ticker = body.ticker;
    if (ticker == null) {
      c.drawCircle(
        centre,
        9 * scale,
        Paint()
          ..color = elementColor(
            body.member.element,
          ).withValues(alpha: 0.85 * alpha),
      );
      return;
    }
    final sprite = ticker.getSprite();
    final looks = body.looks;
    final auraR = wornAuraRadius(body.height);
    c.save();
    c.translate(centre.dx, centre.dy);
    c.scale(scale);
    paintWornAura(c, looks, auraR, t, opacity: alpha);
    c.rotate(faceRight ? lean : -lean);
    c.scale(
      faceRight ? -body.spriteScale : body.spriteScale,
      body.spriteScale * squash,
    );
    final paint = Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..color = Colors.white.withValues(alpha: alpha);
    if (looks != null) paint.colorFilter = creatureGeneticsFilter(looks, t);
    sprite.render(c, anchor: Anchor.center, overridePaint: paint);
    paintWornCostumes(c, looks, sprite, ticker.currentIndex, t, opacity: alpha);
    c.restore();
    c.save();
    c.translate(centre.dx, centre.dy);
    c.scale(scale);
    paintWornAura(c, looks, auraR, t, front: true, opacity: alpha);
    c.restore();
  }

  /// A boost winding up: grains of its colour drawn in round it.
  void _gather(
    Canvas c,
    Offset at,
    Color col,
    double p,
    double scale,
    int lane,
  ) {
    final b = _batch..clear();
    for (var i = 0; i < 48; i++) {
      final h1 = hash01(i, 60 + lane), h2 = hash01(i, 61 + lane);
      final q = (p * 1.3 - h2 * 0.3).clamp(0.0, 1.0);
      final a = h1 * pi * 2 + q * 3.2;
      final r = (32 - 26 * _easeOut(q)) * scale;
      b.add(h2 < 0.3 ? 1 : 0, at.dx + cos(a) * r, at.dy + sin(a) * r * 0.8);
    }
    final fade = _smooth(p / 0.25);
    b.draw(c, 0, 1.8 * scale, col.withValues(alpha: 0.6 * fade));
    b.draw(
      c,
      1,
      2.2 * scale,
      Color.lerp(col, Colors.white, 0.5)!.withValues(alpha: 0.8 * fade),
    );
  }

  /// A surge: a current of grains streaming off behind it, thinning out —
  /// each grain drawn with two earlier points of its path, fainter.
  void _trail(
    Canvas c,
    Offset at,
    Color col,
    double p,
    double scale,
    double h,
    int lane,
    double t,
  ) {
    final env = _smooth(p / 0.15) * (1 - _smooth((p - 0.7) / 0.3));
    if (env <= 0) return;
    c.drawOval(
      Rect.fromCenter(
        center: at.translate(-14 * scale, 0),
        width: 70 * scale,
        height: h * scale * 0.9,
      ),
      Paint()
        ..shader = ui.Gradient.radial(at, 40 * scale, [
          col.withValues(alpha: 0.18 * env),
          col.withValues(alpha: 0),
        ]),
    );
    final b = _batch..clear();
    for (var i = 0; i < 110; i++) {
      final h1 = hash01(i, 70 + lane), h2 = hash01(i, 71 + lane);
      final life = (t * (1.4 + h2 * 0.8) + h1) % 1.0;
      for (var k = 0; k < 3; k++) {
        final l = life - k * 0.035;
        if (l < 0) break;
        final x = at.dx - (6 + l * 72) * scale;
        final y =
            at.dy +
            (h2 - 0.5) * h * scale * 0.75 * (1 - l * 0.5) +
            sin(l * 7 + h1 * 9) * 3.5 * scale * l;
        b.add(k == 0 ? (l < 0.3 ? 1 : 0) : 2, x, y);
      }
    }
    b.draw(c, 2, 1.3 * scale, col.withValues(alpha: 0.22 * env));
    b.draw(c, 0, 1.7 * scale, col.withValues(alpha: 0.55 * env));
    b.draw(
      c,
      1,
      2.1 * scale,
      Color.lerp(col, Colors.white, 0.4)!.withValues(alpha: 0.8 * env),
    );
  }

  // ── light and weather ─────────────────────────────────────────────────────

  void _cone(Canvas c, _Geo g, Offset at, double a, double halfW) {
    final src = Offset(at.dx - 40 * g.k0, g.h * 0.12);
    final path = Path()
      ..moveTo(src.dx - 4 * g.k0, src.dy)
      ..lineTo(src.dx + 4 * g.k0, src.dy)
      ..lineTo(at.dx + halfW * g.k, at.dy + 4 * g.k)
      ..lineTo(at.dx - halfW * g.k, at.dy + 4 * g.k)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(src, at, [
          _brassHot.withValues(alpha: 0),
          _brassHot.withValues(alpha: 0.11 * a),
        ]),
    );
    final pool = at.translate(0, 2 * g.k);
    c.drawOval(
      Rect.fromCenter(center: pool, width: halfW * 2.4 * g.k, height: 12 * g.k),
      Paint()
        ..shader = ui.Gradient.radial(pool, halfW * 1.2 * g.k, [
          _brassHot.withValues(alpha: 0.25 * a),
          _brassHot.withValues(alpha: 0),
        ]),
    );
  }

  /// Rain over a wet lane, and the storm's lightning over the stands.
  void _weather(Canvas c, _Geo g, double t) {
    var wet = 0.0, storm = 0.0;
    for (var j = 0; j < stage.course.legs.length; j++) {
      final leg = stage.course.legs[j];
      if (leg.kind != RaceLegKind.sprint) continue;
      final x0 = stage.layout.starts[j], x1 = x0 + stage.layout.widths[j];
      final cover =
          (min(x1, g.viewR) - max(x0, g.viewL)).clamp(0.0, double.infinity) /
          (g.viewR - g.viewL);
      if (leg.level == 2) wet += cover;
      if (leg.level == 3) storm += cover;
    }
    if (wet > 0.01) {
      final b = _batch..clear();
      final n = (160 * min(1.0, wet)).round();
      for (var i = 0; i < n; i++) {
        final h1 = hash01(i, 80), h2 = hash01(i, 81);
        final fall = (t * (0.9 + h2 * 0.5) + h1) % 1.0;
        final y = fall * g.h;
        final x = (h2 * (g.w + 60) - fall * 30 * g.k0) % g.w;
        b.add(0, x, y);
        b.add(1, x + 1.2 * g.k0, y - 5 * g.k0);
        b.add(1, x + 2.4 * g.k0, y - 10 * g.k0);
      }
      b.draw(c, 0, 1.4 * g.k0, const Color(0xFFBFE6F2).withValues(alpha: 0.5));
      b.draw(c, 1, 1.1 * g.k0, const Color(0xFFBFE6F2).withValues(alpha: 0.2));
    }
    if (storm > 0.01) {
      final slot = (t / 2.3).floor();
      final into = t - slot * 2.3;
      if (into < 0.22 && hash01(slot, 90) < 0.8) {
        final a = (1 - into / 0.22) * min(1.0, storm * 1.5);
        final x0 = g.w * (0.15 + hash01(slot, 91) * 0.7);
        final pts = <Offset>[Offset(x0, 0)];
        var x = x0;
        for (var s = 1; s <= 7; s++) {
          x += (hash01(slot * 9 + s, 92) - 0.5) * 26 * g.k0;
          pts.add(Offset(x, g.h * 0.3 * s / 7));
        }
        c.drawRect(
          Offset.zero & Size(g.w, g.h * 0.36),
          Paint()..color = const Color(0xFF9C8FB0).withValues(alpha: 0.06 * a),
        );
        // The bolt in grains, dense along its line, a few thrown off it.
        final b = _batch..clear();
        for (var s = 0; s < pts.length - 1; s++) {
          final p0 = pts[s], p1 = pts[s + 1];
          final n = ((p1 - p0).distance / (2.2 * g.k0)).ceil();
          for (var i = 0; i < n; i++) {
            final p = Offset.lerp(p0, p1, i / n)!;
            final h1 = hash01(s * 97 + i, 93);
            b.add(h1 < 0.7 ? 1 : 0, p.dx + (h1 - 0.5) * 2 * g.k0, p.dy);
            if (h1 > 0.92) {
              b.add(0, p.dx + (h1 - 0.5) * 22 * g.k0, p.dy + 4 * g.k0);
            }
          }
        }
        b.draw(
          c,
          0,
          1.6 * g.k0,
          const Color(0xFFB9C7FF).withValues(alpha: 0.4 * a),
        );
        b.draw(
          c,
          1,
          2.2 * g.k0,
          const Color(0xFFF2F4FF).withValues(alpha: 0.9 * a),
        );
      }
    }
  }

  // ── the theatre ───────────────────────────────────────────────────────────

  /// Where each crosses, the curtain at the line lifts round it.
  void _finishRipples(Canvas c, _Geo g) {
    final x = stage.layout.finishX;
    if (x < g.viewL || x > g.viewR) return;
    final b = _batch..clear();
    for (var i = 0; i < stage.racers.length; i++) {
      final at = stage.finishedAtClock[i];
      if (at == null) continue;
      final p = (stage.clock - at) / 1.4;
      if (p < 0 || p > 1) continue;
      for (var n = 0; n < 46; n++) {
        final h1 = hash01(n, 700 + i), h2 = hash01(n, 701 + i);
        final q = (p * 1.25 - h2 * 0.25).clamp(0.0, 1.0);
        final lop = h1 < 0.7 ? 1.0 : -0.5;
        final px = g.sx(x) + lop * q * (10 + h2 * 26) * g.k;
        final py = g.laneY(i) - q * (14 + h1 * 40) * g.k + q * q * 18 * g.k;
        b.add(q < 0.6 ? 1 : 0, px, py);
      }
    }
    b.draw(c, 0, 1.5 * g.k, _brassHot.withValues(alpha: 0.35));
    b.draw(c, 1, 2.1 * g.k, _brassHot.withValues(alpha: 0.85));
  }

  /// A photo finish: the edges darken as time slows, and lift once the line
  /// is crossed.
  void _photo(Canvas c, _Geo g) {
    final at = stage.photoAt;
    if (at == null) return;
    final first = stage.finishedAtClock.whereType<double>().fold<double?>(
      null,
      (a, b) => a == null ? b : min(a, b),
    );
    final on = _smooth((stage.clock - at) / 0.5);
    final off = first == null
        ? 0.0
        : _smooth((stage.clock - first - 0.4) / 0.8);
    final a = on * (1 - off);
    if (a <= 0.01) return;
    final centre = Offset(g.w / 2, g.h * 0.62);
    c.drawRect(
      Offset.zero & Size(g.w, g.h),
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          g.w * 0.62,
          [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.62 * a),
          ],
          const [0.45, 1],
        ),
    );
  }

  /// The count: brass grains gather into each numeral, hold, and drift
  /// apart upward.
  void _count(Canvas c, _Geo g) {
    final left = stage.countdownLeft;
    if (left <= 0) return;
    final n = left.ceil();
    final grains = stage.numerals[n];
    if (grains == null) return;
    final p = 1 - (left - (n - 1));
    final gather = _easeOut(_smooth(p / 0.38));
    final part = _smooth((p - 0.72) / 0.28);
    final at = Offset(g.w / 2, g.h * 0.58);
    final s = 0.85 * g.k0;
    final b = _batch..clear();
    for (var i = 0; i < grains.length; i++) {
      final h1 = hash01(i, 800 + n), h2 = hash01(i, 801 + n);
      final a = h1 * pi * 2;
      final r = (90 + h2 * 130) * g.k0;
      final hx = at.dx + grains.hx[i] * s, hy = at.dy + grains.hy[i] * s;
      var x = at.dx + cos(a) * r + (hx - at.dx - cos(a) * r) * gather;
      var y =
          at.dy + sin(a) * r * 0.6 + (hy - at.dy - sin(a) * r * 0.6) * gather;
      x += sin(stage.clock * 3 + i) * 0.6 * g.k0 * (1 - part);
      x += (h1 - 0.5) * 30 * part * g.k0;
      y -= part * (20 + h2 * 40) * g.k0;
      b.add(h2 < 0.2 ? 1 : 0, x, y);
    }
    final alpha = _smooth(p / 0.15) * (1 - part);
    b.draw(c, 0, 2.2 * g.k0, _brass.withValues(alpha: 0.75 * alpha));
    b.draw(c, 1, 2.6 * g.k0, _brassHot.withValues(alpha: 0.95 * alpha));
  }

  /// The podium: three plinths of stone grains rise centre stage under
  /// spotlights; the first three stand on them; the winner comes apart into
  /// its element and gathers again while the stands roar.
  void _podium(Canvas c, _Geo g, double t) {
    final rise = _easeOut(stage.podiumT);
    final order = stage.standings;
    c.drawRect(
      Rect.fromLTRB(0, g.h * 0.34, g.w, g.h),
      Paint()..color = Colors.black.withValues(alpha: 0.9 * rise),
    );
    // Once the results come up, it stands aside for them, a little smaller.
    final aside = Curves.easeInOutCubic.transform(stage.resultsT);
    // Three plinths span about 316 of k; aside they keep within the
    // screen's right edge.
    final fit = (g.w * (1 - kRaceResultsPodiumX) - 10) / 158;
    final k = g.k0 + (min(g.k0 * .88, fit) - g.k0) * aside;
    final floor = g.h * 0.86;
    final centre = g.w / 2 + (g.w * kRaceResultsPodiumX - g.w / 2) * aside;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(centre, floor),
        width: 420 * k,
        height: 60 * k,
      ),
      Paint()
        ..shader = ui.Gradient.radial(Offset(centre, floor), 210 * k, [
          _brass.withValues(alpha: 0.2 * rise),
          _brass.withValues(alpha: 0),
        ]),
    );
    // 2nd, 1st, 3rd.
    const slots = [1, 0, 2];
    const heights = [62.0, 44.0, 30.0];
    for (var s = 0; s < 3 && s < order.length; s++) {
      final place = slots[s];
      if (place >= order.length) continue;
      final lane = order[place];
      final x = centre + (s - 1) * 118 * k;
      final hh = heights[place] * k * rise;
      _plinth(c, Offset(x, floor), 80 * k, hh, place, t);
      final top = floor - hh;
      _cone(
        c,
        g,
        Offset(x, top),
        rise * (place == 0 ? 1.0 : 0.6),
        place == 0 ? 34 : 26,
      );
      // It stands as it finished — whatever its fusions made it — then
      // comes apart into that element and gathers back as itself (the
      // author, 2026-10-12: "they can form back ... on the podium"), first,
      // second and third in turn. The winner bursts into its element and
      // back even when nothing changed it.
      final finalElement = stage.finalElement(lane);
      final own = stage.racers[lane].entrant.element;
      final asFinished = stage.bodyFor(lane, finalElement);
      final itself = stage.bodyFor(lane, own);
      final changed = !identical(asFinished, itself) && itself.grains != null;
      final et = stage.podiumClock - (0.9 + place * 0.45);
      final back = changed && et >= _handOver + 0.15;
      final body = back ? itself : asFinished;
      final scale = k * 1.75;
      final bob = -(sin(t * 2.4 + s).abs()) * 1.5 * k;
      final at = Offset(x, top - body.height * scale / 2 + bob);
      var alpha = rise;
      if ((place == 0 || changed) &&
          asFinished.grains != null &&
          et > 0 &&
          et < EssenceField.duration) {
        final out = _essence.putIfAbsent(
          9900 + place * 2,
          () =>
              EssenceField(asFinished.grains!, EssenceElement.of(finalElement))
                ..leaveAt = changed ? _handOver : null,
        );
        final into = !changed
            ? null
            : _essence.putIfAbsent(
                9901 + place * 2,
                () => EssenceField(
                  itself.grains!,
                  EssenceElement.of(finalElement),
                )..reveal = true,
              );
        alpha *= EssenceField.spriteOpacity(et);
        c.save();
        c.translate(at.dx, at.dy);
        c.scale(scale);
        out.paint(c, Offset.zero, et);
        into?.paint(c, Offset.zero, et);
        c.restore();
      }
      if (alpha > 0.01) {
        _drawSprite(
          c,
          body,
          at,
          scale,
          t,
          alpha: alpha,
          lean: 0,
          faceRight: s == 0,
        );
      }
      final finish = stage.sim.states[lane].finishTime;
      _label(
        c,
        body.member.displayName.toUpperCase(),
        lane == stage.player ? _brassHot : _ink,
        Offset(x, floor + 14 * k),
        9.5 * k,
        rise,
      );
      _label(
        c,
        '${ordinal(place + 1).toUpperCase()}${finish == null ? '' : '  ${finish.toStringAsFixed(2)}s'}',
        _brass,
        Offset(x, floor + 27 * k),
        8 * k,
        rise,
      );
    }
    // Brass grains lifting off behind the winner's plinth.
    final b = _batch..clear();
    for (var i = 0; i < 70; i++) {
      final life = (t * 0.3 + hash01(i, 900)) % 1.0;
      final x =
          centre + (hash01(i, 901) - 0.5) * 120 * k + sin(life * 5 + i) * 6 * k;
      final y = floor - life * g.h * 0.5;
      b.add(life < 0.6 ? 1 : 0, x, y);
    }
    b.draw(c, 0, 1.4 * k, _brassHot.withValues(alpha: 0.25 * rise));
    b.draw(c, 1, 2.0 * k, _brassHot.withValues(alpha: 0.6 * rise));
  }

  /// One plinth: a block of stone grains with a lit brass crest, the
  /// winner's warmest.
  void _plinth(Canvas c, Offset foot, double w, double h, int place, double t) {
    if (h <= 1) return;
    final b = _batch..clear();
    final step = 3.4 * (w / 80);
    final depth = 16 * (w / 80);
    for (var x = -w / 2; x <= w / 2; x += step) {
      final hx = hash01((x * 10).round(), 950 + place);
      // The top, receding.
      for (var v = 0.0; v <= depth; v += step) {
        final hv = hash01((x * 10).round() * 7 + (v * 10).round(), 952 + place);
        b.add(
          v > depth - step * 1.2 ? 3 : 2,
          foot.dx + x + (hv - 0.5) * step * 0.9,
          foot.dy - h - depth + v + (hx - 0.5) * step * 0.6,
        );
      }
      // The face.
      for (var y = 0.0; y < h; y += step * 0.9) {
        final hy = hash01((x * 10).round() * 31 + (y * 10).round(), 951);
        final hz = hash01((y * 10).round() * 13 + (x * 10).round(), 953);
        b.add(
          hy < 0.18 ? 1 : 0,
          foot.dx + x + (hy - 0.5) * step * 0.9,
          foot.dy - h + y + (hz - 0.5) * step * 0.7,
        );
      }
    }
    final crest = place == 0
        ? _brassHot
        : (place == 1 ? const Color(0xFFC8CCD2) : const Color(0xFFC08A5A));
    b.draw(
      c,
      0,
      2.3 * (w / 80),
      const Color(0xFF3E3A35).withValues(alpha: 0.85),
    );
    b.draw(
      c,
      1,
      2.3 * (w / 80),
      const Color(0xFF6A6258).withValues(alpha: 0.85),
    );
    b.draw(
      c,
      2,
      2.4 * (w / 80),
      Color.lerp(const Color(0xFF3E3A35), crest, 0.45)!.withValues(alpha: 0.85),
    );
    b.draw(c, 3, 2.6 * (w / 80), crest.withValues(alpha: 0.95));
  }

  // ── small things ──────────────────────────────────────────────────────────

  void _label(
    Canvas c,
    String text,
    Color color,
    Offset at,
    double size,
    double alpha, {
    bool alignRight = false,
  }) {
    if (alpha <= 0.01) return;
    final key = '$text|${color.toARGB32()}|${size.toStringAsFixed(1)}';
    final tp = _labels[key] ??= TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? at.dx - tp.width : at.dx - tp.width / 2;
    if (alpha >= 0.99) {
      tp.paint(c, Offset(dx, at.dy - tp.height / 2));
      return;
    }
    c.saveLayer(
      Rect.fromLTWH(
        dx - 2,
        at.dy - tp.height / 2 - 2,
        tp.width + 4,
        tp.height + 4,
      ),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
    c.restore();
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _easeOut(double x) {
    final t = x.clamp(0.0, 1.0);
    return 1 - (1 - t) * (1 - t) * (1 - t);
  }

  @override
  bool shouldRepaint(RacePainter old) => old.stage != stage;
}

/// What a racer's feet throw up.
enum _Spray { dust, wet, ice, mud }
