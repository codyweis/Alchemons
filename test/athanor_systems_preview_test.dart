@Tags(['preview'])
library;

// The Athanor's four new cosmetic systems, rendered for looking at:
//
//   ATHANOR_SYSTEMS_OUT=docs/athanor/content/systems flutter test -j 1 \
//     test/athanor_systems_preview_test.dart --tags preview
//
// writes into that directory
//   cases.png        the five case styles beside the plain case, on six
//                    species, at Creatures-tab size (×2)
//   cases_close.png  each case large, for judging its material
//   trails.png       Frost Steps and Gold Steps behind walking
//                    Alchemons, four moments each
//   ambience_*.png   each ambience over home realms, by day and by night
//   previews.png     every piece's tile as the Athanor draws it
//
// and prints what a frame of each costs. With no env var it writes nothing.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_previews.dart';
import 'package:alchemons/widgets/fx/cosmetics/home_ambience_art.dart';
import 'package:alchemons/widgets/fx/cosmetics/case_style_art.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:alchemons/widgets/fx/cosmetics/trail_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _bg = Color(0xFF09090B);
const _ink = Color(0xFFE6E2DA);
const _muted = Color(0xFF8E8C88);
const _brass = Color(0xFFCDB07A);

final String? out = Platform.environment['ATHANOR_SYSTEMS_OUT'];

final Map<String, Map<String, dynamic>> _rows = {};
Map<String, dynamic> _row(String id) => _rows[id]!;

Future<void> _loadCatalog() async {
  if (_rows.isNotEmpty) return;
  final data =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final e in (data['creatures'] as List).cast<Map<String, dynamic>>()) {
    _rows[e['id'] as String] = e;
  }
}

Future<ui.Image> _still(String id, double side) async {
  final codec = await ui.instantiateImageCodec(
    File('assets/images/${_row(id)['image']}').readAsBytesSync(),
    targetWidth: (side * 1.5).round(),
  );
  final img = (await codec.getNextFrame()).image;
  codec.dispose();
  return img;
}

Color _light(String id) {
  final types = (_row(id)['types'] as List?)?.cast<String>() ?? const [];
  return _tints[types.isEmpty ? '' : types.first] ?? const Color(0xFFE0CDA6);
}

/// The element lights (element_orb.dart's tints), copied so this render
/// pulls in nothing but the art.
const _tints = {
  'Fire': Color(0xFFFF7A1A),
  'Water': Color(0xFF2E8BD0),
  'Earth': Color(0xFFB07A44),
  'Air': Color(0xFF8FE0CC),
  'Steam': Color(0xFFCDB9CC),
  'Lava': Color(0xFFFF4A12),
  'Lightning': Color(0xFFFFE45C),
  'Mud': Color(0xFF6E5038),
  'Ice': Color(0xFF8FC4FF),
  'Dust': Color(0xFFE0CDA6),
  'Crystal': Color(0xFF8A68FF),
  'Plant': Color(0xFF5FC46B),
  'Poison': Color(0xFF8E52D6),
  'Spirit': Color(0xFFE6DCFF),
  'Dark': Color(0xFF5A3A96),
  'Light': Color(0xFFFFE08A),
  'Blood': Color(0xFFD01E2A),
};

/// Today's plain case (CaseLightPainter in specimen_case.dart), copied so
/// this render does not pull in the whole widget tree.
class _PlainCase extends CustomPainter {
  const _PlainCase(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xE60B0A10),
    );
    final w = size.width, h = size.height;
    final back = Offset(w / 2, h * 0.46);
    final br = math.min(w, h) * 0.7;
    canvas.drawCircle(
      back,
      br,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: back, radius: br)),
    );
    final fr = w * 0.46;
    canvas.save();
    canvas.translate(w / 2, h * 0.88);
    canvas.scale(1, 0.22);
    canvas.drawCircle(
      Offset.zero,
      fr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: fr)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlainCase old) => old.color != color;
}

Future<void> _font() async {
  final f = File('/System/Library/Fonts/Supplemental/Arial.ttf');
  if (!f.existsSync()) return;
  for (final family in ['Roboto', 'monospace']) {
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)))).load();
  }
}

void _text(
  Canvas c,
  String s,
  Offset at, {
  double size = 13,
  Color color = _ink,
  bool bold = false,
  double spacing = 1.2,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        color: color,
        letterSpacing: spacing,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
  tp.dispose();
}

Future<void> _save(ui.PictureRecorder rec, Size size, String name) async {
  final pic = rec.endRecording();
  final img = await pic.toImage(size.width.round(), size.height.round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  Directory(out!).createSync(recursive: true);
  File('$out/$name').writeAsBytesSync(png!.buffer.asUint8List());
  img.dispose();
  pic.dispose();
}

void _image(Canvas c, ui.Image img, Rect dst) => c.drawImageRect(
  img,
  Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
  dst,
  Paint()..filterQuality = FilterQuality.medium,
);

/// Microseconds a frame of [paint] costs, recorded only (no raster).
double _cost(void Function(Canvas c) paint, {int frames = 200}) {
  for (var i = 0; i < 20; i++) {
    final r = ui.PictureRecorder();
    paint(Canvas(r));
    r.endRecording().dispose();
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < frames; i++) {
    final r = ui.PictureRecorder();
    paint(Canvas(r));
    r.endRecording().dispose();
  }
  return sw.elapsedMicroseconds / frames;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (out == null) return;
    await _loadCatalog();
    await _font();
  });

  // ── cases ────────────────────────────────────────────────────────────────
  test('cases', () async {
    if (out == null) return;
    // A case on the Creatures tab is about 104 × 132 logical px; drawn ×2.
    const cw = 104.0, ch = 132.0, scale = 2.0, gap = 14.0;
    final cases = <(String, CaseStyle?)>[
      ('Plain', null),
      for (final s in CaseStyle.values) (s.title, s),
    ];
    const who = [
      ['KIN16', 'MAN16', 'MSK15', 'WNG09', 'HOR17', 'PIP11'],
      ['WNG09', 'HOR17', 'PIP11', 'KIN16', 'MAN16', 'MSK15'],
      ['MSK15', 'PIP11', 'KIN16', 'HOR17', 'WNG09', 'MAN16'],
    ];
    final size = Size(
      (gap + (cw + gap) * cases.length) * scale,
      (34 + (ch + 40) * who.length) * scale,
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    c.drawRect(Offset.zero & (size / scale), Paint()..color = _bg);
    _text(
      c,
      'SPECIMEN CASE STYLES  ·  per creature  ·  one common per batch',
      const Offset(gap, 9),
      size: 9,
      bold: true,
    );
    for (var row = 0; row < who.length; row++) {
      for (var i = 0; i < cases.length; i++) {
        final (title, style) = cases[i];
        final id = who[row][i % who[row].length];
        final sprite = await _still(id, ch * scale);
        final light = _light(id);
        final at = Offset(gap + i * (cw + gap), 30 + row * (ch + 40));
        c.save();
        c.translate(at.dx, at.dy);
        c.clipRect(const Rect.fromLTWH(0, 0, cw, ch));
        final CustomPainter painter = style == null
            ? _PlainCase(light)
            : CaseStylePainter(style: style, color: light);
        painter.paint(c, const Size(cw, ch));
        final s = math.min(cw, ch) * 0.78;
        _image(c, sprite, Rect.fromLTWH((cw - s) / 2, ch * 0.9 - s, s, s));
        c.restore();
        _text(
          c,
          '${_row(id)['name']}'.toUpperCase(),
          at + const Offset(2, ch + 5),
          size: 6.5,
          bold: true,
        );
        _text(
          c,
          title,
          at + const Offset(2, ch + 17),
          size: 7,
          color: style == null ? _muted : _brass,
        );
      }
    }
    await _save(rec, size, 'cases.png');

    // Large, for the material.
    const bw = 260.0, bh = 330.0;
    final big = Size(gap + (bw + gap) * 5, bh + gap * 2 + 20);
    final r2 = ui.PictureRecorder();
    final c2 = Canvas(r2);
    c2.drawRect(Offset.zero & big, Paint()..color = _bg);
    for (var i = 0; i < CaseStyle.values.length; i++) {
      final style = CaseStyle.values[i];
      final id = who[0][(i + 1) % 6];
      final at = Offset(gap + i * (bw + gap), gap);
      c2.save();
      c2.translate(at.dx, at.dy);
      c2.clipRect(const Rect.fromLTWH(0, 0, bw, bh));
      CaseStylePainter(
        style: style,
        color: _light(id),
      ).paint(c2, const Size(bw, bh));
      final sprite = await _still(id, bh);
      final s = bw * 0.78;
      _image(c2, sprite, Rect.fromLTWH((bw - s) / 2, bh * 0.9 - s, s, s));
      c2.restore();
      _text(c2, style.title, at + Offset(0, bh + 4), size: 12, color: _brass);
    }
    await _save(r2, big, 'cases_close.png');

    for (final style in CaseStyle.values) {
      // The first of its kind (a size never drawn before), then one replayed.
      var n = 0;
      final first = _cost(
        (c) => CaseStylePainter(
          style: style,
          color: _brass,
        ).paint(c, Size(cw + (n++) * 0.37, ch)),
      );
      final again = _cost(
        (c) => CaseStylePainter(
          style: style,
          color: _brass,
        ).paint(c, const Size(cw, ch)),
      );
      // ignore: avoid_print
      print(
        'case ${style.id}: ${first.toStringAsFixed(1)} µs drawn, '
        '${again.toStringAsFixed(1)} µs replayed',
      );
    }
  });

  // ── trails ───────────────────────────────────────────────────────────────
  test('trails', () async {
    if (out == null) return;
    // A home field's near row at landscape scale: a creature about 100
    // units across walking left over dark ground, a step every 0.55 sizes.
    const w = 900.0, band = 190.0, gap = 10.0, creature = 100.0;
    const moments = [1.6, 3.4, 5.6, 9.0];
    final cases = [
      (TrailStyle.hoarfrost, 'HOR03'),
      (TrailStyle.hoarfrost, 'LET09'),
      (TrailStyle.gilt, 'KIN16'),
      (TrailStyle.gilt, 'MAN16'),
    ];
    final size = Size(
      w,
      30 + cases.length * (moments.length * (band + gap) + 30),
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    final ground = CosmeticAtlas(600), light = CosmeticAtlas(600);
    var y0 = 30.0;
    _text(
      c,
      'TRAILS  ·  per creature  ·  left where it walks at home',
      const Offset(gap, 9),
      size: 13,
      bold: true,
    );
    for (final (style, id) in cases) {
      _text(
        c,
        '${style.title}  ·  ${_row(id)['name']} walking left',
        Offset(gap, y0 + 4),
        size: 12,
        color: _brass,
      );
      y0 += 26;
      final still = await _still(id, creature);
      const speed = creature * 0.34; // home life's walk
      double xAt(double t) => w - 140 - speed * t;
      for (final tEnd in moments) {
        final r = Rect.fromLTWH(0, y0, w, band);
        c.save();
        c.clipRect(r);
        c.drawRect(r, Paint()..color = const Color(0xFF0D1014));
        final groundY = y0 + band - 34;
        c.drawRect(
          Rect.fromLTRB(0, groundY - 6, w, y0 + band),
          Paint()..color = const Color(0xFF151A16),
        );
        final prints = TrailPrints(style);
        var walked = 0.0, foot = 0;
        const stride = creature * 0.55;
        for (var t = 0.0; t <= tEnd; t += 1 / 60) {
          walked += speed / 60;
          if (walked >= stride) {
            walked -= stride;
            final near = foot.isEven;
            foot++;
            prints.step(
              xAt(t) + (near ? -6 : 8),
              groundY + (near ? 4 : -3),
              t,
              size: creature * 0.2,
            );
          }
        }
        prints.paint(ground, light, tEnd);
        ground.draw(c);
        light.draw(c, blend: BlendMode.plus);
        _image(
          c,
          still,
          Rect.fromLTWH(
            xAt(tEnd) - creature / 2,
            groundY - creature + 6,
            creature,
            creature,
          ),
        );
        c.restore();
        _text(
          c,
          't ${tEnd.toStringAsFixed(1)} s',
          Offset(8, y0 + 6),
          size: 10,
          color: _muted,
        );
        y0 += band + gap;
      }
      y0 += 4;
    }
    await _save(rec, size, 'trails.png');

    // Close: each trail ×2.5 at 4.6 s.
    const z = 2.5;
    final cs = Size(560 * z, (cases.length * 170 + 10) * z);
    final r2 = ui.PictureRecorder();
    final c2 = Canvas(r2)..scale(z);
    c2.drawRect(Offset.zero & (cs / z), Paint()..color = _bg);
    for (var i = 0; i < cases.length; i++) {
      final (style, id) = cases[i];
      final still = await _still(id, creature * z);
      final top = 10.0 + i * 170;
      final groundY = top + 130;
      c2.drawRect(
        Rect.fromLTWH(0, top, 560, 160),
        Paint()..color = const Color(0xFF0D1014),
      );
      c2.drawRect(
        Rect.fromLTRB(0, groundY - 6, 560, top + 160),
        Paint()..color = const Color(0xFF151A16),
      );
      final prints = TrailPrints(style);
      const t = 4.6;
      // Walking left: the newest print nearest it.
      for (var k = 4; k >= 0; k--) {
        prints.step(
          120.0 + k * 55 + (k.isEven ? -6 : 8),
          groundY + (k.isEven ? 4 : -3),
          t - 0.25 - k * 0.62,
          size: creature * 0.2,
        );
      }
      prints.paint(ground, light, t);
      ground.draw(c2);
      light.draw(c2, blend: BlendMode.plus);
      _image(
        c2,
        still,
        Rect.fromLTWH(60, groundY - creature + 6, creature, creature),
      );
      _text(c2, style.title, Offset(8, top + 6), size: 10, color: _brass);
    }
    await _save(r2, cs, 'trails_close.png');

    // Cost: twelve creatures each wearing a trail, ten prints alive each.
    for (final style in TrailStyle.values) {
      final prints = [
        for (var k = 0; k < 12; k++)
          TrailPrints(style)..let((p) {
            for (var i = 0; i < 10; i++) {
              p.step(40.0 * i, 100.0 + k * 20, i * 0.4, size: 20);
            }
          }),
      ];
      final g = CosmeticAtlas(12 * 10 * TrailPrints.entriesPerPrint);
      final l = CosmeticAtlas(12 * 10 * TrailPrints.entriesPerPrint);
      final us = _cost((cv) {
        for (final p in prints) {
          p.paint(g, l, 4.1);
        }
        g.draw(cv);
        l.draw(cv, blend: BlendMode.plus);
      });
      // ignore: avoid_print
      print(
        'trail ${style.id}: ${us.toStringAsFixed(1)} µs a frame for 12 creatures × 10 prints',
      );
    }
  });

  // ── the pieces' tiles ───────────────────────────────────────────────────
  test('previews', () async {
    if (out == null) return;
    final pieces = <(AthanorPieceKind, String, String)>[
      for (final s in CaseStyle.values)
        (AthanorPieceKind.caseStyle, s.id, s.title),
      for (final s in TrailStyle.values)
        (AthanorPieceKind.trail, s.id, s.title),
      for (final s in FusionStyle.values)
        (AthanorPieceKind.fusionStyle, s.id, s.title),
      for (final s in HomeAmbience.values)
        (AthanorPieceKind.ambience, s.id, s.title),
    ];
    // The grid tile (about 78 px) and the detail (150 px), at three moments.
    const small = 78.0, large = 150.0, gap = 12.0;
    final colW = large + gap;
    final size = Size(
      gap + colW * 4 + (small + gap) * 3,
      30 + pieces.length * (large + 26),
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    _text(
      c,
      "THE ATHANOR'S TILES  ·  grid size ×3 moments, then the detail size ×4",
      const Offset(gap, 9),
      size: 13,
      bold: true,
    );
    for (var i = 0; i < pieces.length; i++) {
      final (kind, id, title) = pieces[i];
      final y = 30 + i * (large + 26);
      _text(c, title, Offset(gap, y + 2), size: 11, color: _brass);
      for (var k = 0; k < 3; k++) {
        final r = Rect.fromLTWH(gap + k * (small + gap), y + 20, small, small);
        c.drawRect(r, Paint()..color = const Color(0xFF131316));
        paintCosmeticPreview(c, kind, id, r, 0.6 + k * 1.3);
      }
      for (var k = 0; k < 4; k++) {
        final r = Rect.fromLTWH(
          gap + 3 * (small + gap) + k * colW,
          y + 20,
          large,
          large,
        );
        c.drawRect(r, Paint()..color = const Color(0xFF131316));
        paintCosmeticPreview(c, kind, id, r, 0.4 + k * 1.1);
      }
    }
    await _save(rec, size, 'previews.png');
    for (final (kind, id, _) in pieces) {
      final us = _cost(
        (cv) => paintCosmeticPreview(
          cv,
          kind,
          id,
          const Rect.fromLTWH(0, 0, 78, 78),
          1.3,
        ),
      );
      // ignore: avoid_print
      print('tile $id: ${us.toStringAsFixed(1)} µs');
    }
  });

  // ── ambiences on a plain field (quick look) ──────────────────────────────
  test('ambience_sketch', () async {
    if (out == null) return;
    const w = 915.0, h = 412.0;
    final rows = [
      for (final a in HomeAmbience.values)
        for (final hour in const [12.0, 18.8, 23.0]) (a, hour),
    ];
    final size = Size(w, rows.length * (h + 10.0));
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    final over = CosmeticAtlas(700), light = CosmeticAtlas(1200);
    for (var i = 0; i < rows.length; i++) {
      final (a, hour) = rows[i];
      final top = i * (h + 10);
      c.save();
      c.translate(0, top);
      c.clipRect(const Rect.fromLTWH(0, 0, w, h));
      final night = hour > 20 || hour < 6;
      c.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = night ? const Color(0xFF0A0D16) : const Color(0xFF2A3A4A),
      );
      double ground(double x) => h * 0.8 + math.sin(x / 140) * 8;
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 10) {
        path.lineTo(x, ground(x));
      }
      path
        ..lineTo(w, h)
        ..close();
      c.drawPath(
        path,
        Paint()
          ..color = night ? const Color(0xFF141A14) : const Color(0xFF3E5A34),
      );
      final shown = ambienceShows(a, hour);
      paintHomeAmbience(
        a,
        AmbienceView(
          left: 0,
          right: w,
          top: 0,
          bottom: h,
          height: h,
          time: 20,
          ground: ground,
          feet: [Offset(300, ground(300)), Offset(620, ground(620))],
          rowSize: 100,
        ),
        shown,
        over,
        light,
      );
      over.draw(c);
      light.draw(c, blend: BlendMode.plus);
      c.restore();
      _text(
        c,
        '${a.title}  ·  ${hour.toStringAsFixed(1)} h  ·  shows ${shown.toStringAsFixed(2)}',
        Offset(10, top + 8),
        size: 12,
        color: _brass,
      );
    }
    await _save(rec, size, 'ambience_sketch.png');
    for (final a in HomeAmbience.values) {
      final us = _cost((cv) {
        paintHomeAmbience(
          a,
          AmbienceView(
            left: 0,
            right: w,
            top: 0,
            bottom: h,
            height: h,
            time: 20,
            ground: (x) => h * 0.8,
            rowSize: 100,
          ),
          1,
          over,
          light,
        );
        over.draw(cv);
        light.draw(cv, blend: BlendMode.plus);
      });
      // ignore: avoid_print
      print('ambience ${a.id}: ${us.toStringAsFixed(1)} µs a frame');
    }
  });
}

extension<T> on T {
  void let(void Function(T) f) => f(this);
}
