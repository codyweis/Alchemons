@Tags(['preview'])
library;

// Every piece of the Athanor's home decor (HomeDecor.athanor), one sheet
// each, at the field's scale on a patch of a field row: by day, by night,
// and in use — a real Alchemon sitting in it, asleep in it, bowing at it or
// hopping beside it, as the home's life has it (home_life.dart). Curios are
// shown stirred (tapped) instead, with an Alchemon beside them for size.
// Then the Great Alembic carrying one through as its grains, the tray tiles
// the Arrange tray shows, and what a frame of each costs.
//
//   ATHANOR_DECOR_OUT=docs/athanor/content/decor flutter test -j 1 \
//     test/athanor_decor_preview_test.dart --tags preview
//
// ATHANOR_DECOR_ONLY=snow_globe,alembic renders a few. With no env var it
// writes nothing.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/creature_feet.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _bg = Color(0xFF09090B);
const _ink = Color(0xFFE6E2DA);
const _muted = Color(0xFF8E8C88);

/// A creature's sprite box in keepsake units: a row's size, 100, over the
/// field's ×0.62.
const double _boxU = 100 / 0.62;

/// Pixels to a keepsake unit on the sheets.
const double _px = 1.1;

final Map<String, Map<String, dynamic>> _rows = {};

Future<ui.Image> _still(String id, double side) async {
  final path = 'assets/images/${_rows[id]!['image']}';
  final codec = await ui.instantiateImageCodec(
    File(path).readAsBytesSync(),
    targetWidth: side.round(),
  );
  final img = (await codec.getNextFrame()).image;
  codec.dispose();
  return img;
}

void _text(
  Canvas c,
  String s,
  Offset at, {
  double size = 13,
  Color color = _ink,
  bool bold = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        color: color,
        letterSpacing: 1.1,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
  tp.dispose();
}

Future<void> _save(ui.PictureRecorder rec, Size size, String path) async {
  final pic = rec.endRecording();
  final img = await pic.toImage(size.width.round(), size.height.round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  img.dispose();
  pic.dispose();
}

/// What a resident does with a piece, for its "in use" picture.
enum _Use {
  /// Nothing: a Curio, shown stirred, with someone beside it for size.
  still,

  /// Sitting at its first seat (by day).
  sit,

  /// Asleep at its first seat (by night).
  sleep,

  /// Asleep on the ground beside it (by night).
  sleepBeside,

  /// Bowing beside it.
  bow,

  /// Hopping beside it.
  hop,

  /// One on the seat, two bowing at the other seats.
  court,

  /// One at each seat.
  climbAll,

  /// Going through it (the Great Alembic): shown on its own sheet.
  distil,
}

/// (piece, batch label, the resident, what it does).
const _plan = <(String, String, String, _Use)>[
  ('moth_lantern', 'The Black Work · Curio', 'LET15', _Use.still),
  ('inkcap_cluster', 'The Black Work · Curio', 'PIP13', _Use.still),
  ('ash_brazier', 'The Black Work · Living', 'MSK15', _Use.sleepBeside),
  ('nightbloom_bed', 'The Black Work · Living (bed)', 'MSK15', _Use.sleep),
  ('moonstone_cairn', 'The White Work · Curio', 'LET14', _Use.still),
  ('salt_pillar', 'The White Work · Curio', 'PIP11', _Use.still),
  ('moon_font', 'The White Work · Living', 'PIP02', _Use.bow),
  ('snow_globe', 'The White Work · Wonder (capstone)', 'LET09', _Use.sit),
  ('sundial', 'The Yellow Work · Curio', 'LET16', _Use.still),
  ('honey_lamp', 'The Yellow Work · Curio', 'PIP10', _Use.still),
  ('storm_coil', 'The Yellow Work · Living', 'LET07', _Use.hop),
  ('gilded_throne', 'The Yellow Work · Wonder (capstone)', 'HOR16', _Use.court),
  ('glass_rose', 'The Red Work · Curio', 'LET17', _Use.still),
  ('ember_bowl', 'The Red Work · Curio', 'PIP01', _Use.still),
  ('ember_nest', 'The Red Work · Living (bed)', 'LET01', _Use.sleep),
  ('pomegranate_tree', 'The Red Work · Living', 'PIP17', _Use.climbAll),
  ('herb_rack', 'The Still-Room · Curio', 'LET12', _Use.still),
  ('retort_shelf', 'The Still-Room · Curio', 'PIP05', _Use.still),
  ('alembic', 'The Still-Room · Living', 'PIP05', _Use.bow),
  ('bell_jar', 'The Still-Room · Living', 'LET11', _Use.sit),
  ('music_box', 'The Still-Room · Living', 'KIN03', _Use.hop),
  ('great_alembic', 'The Still-Room · Wonder (capstone)', 'MAN16', _Use.distil),
];

/// Those who come to bow at the throne.
const _bowers = ['PIP16', 'LET16'];

/// A climber for the second seat.
const _second = 'LET12';

void main() {
  final out = Platform.environment['ATHANOR_DECOR_OUT'];
  final only = Platform.environment['ATHANOR_DECOR_ONLY']?.split(',').toSet();
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final e in (data['creatures'] as List).cast<Map<String, dynamic>>()) {
      _rows[e['id'] as String] = e;
    }
    final f = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (f.existsSync()) {
      await (FontLoader('Roboto')
            ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer))))
          .load();
    }
  });

  /// A creature drawn with its feet at [feet] (keepsake units), turned to
  /// face right when [faceRight], tipped by [angle] (a bow), at [alpha].
  void creature(
    Canvas c,
    ui.Image img,
    String id,
    Offset feet, {
    bool faceRight = false,
    double angle = 0,
    double alpha = 1,
  }) {
    final drop = creatureFeetDrop(id);
    final mid = feet - Offset(0, _boxU * drop);
    c.save();
    c.translate(mid.dx, mid.dy);
    c.rotate(angle);
    if (faceRight) c.scale(-1, 1);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: _boxU, height: _boxU),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    c.restore();
  }

  /// A patch of field row: sky and ground for [night], the canvas left
  /// translated to the piece's feet and scaled to keepsake units.
  void patch(Canvas c, Rect cell, double night, double shift) {
    c.clipRect(cell);
    c.drawRect(
      cell,
      Paint()
        ..shader = ui.Gradient.linear(cell.topCenter, cell.bottomCenter, [
          Color.lerp(const Color(0xFF1E2833), const Color(0xFF07090F), night)!,
          Color.lerp(const Color(0xFF2B3542), const Color(0xFF0B0E16), night)!,
        ]),
    );
    final groundY = cell.bottom - 40;
    c.drawRect(
      Rect.fromLTRB(cell.left, groundY, cell.right, cell.bottom),
      Paint()
        ..color = Color.lerp(
          const Color(0xFF1A1F1B),
          const Color(0xFF0C0E11),
          night,
        )!,
    );
    c.translate(cell.center.dx + shift * _px, groundY);
    c.scale(_px);
  }

  test('athanor decor sheets', () async {
    if (out == null) return;
    for (final (id, batch, who, use) in _plan) {
      if (only != null && !only.contains(id)) continue;
      if (use == _Use.distil) continue;
      final decor = HomeDecor.byId(id)!;
      final probe = KeepsakeArt.of(id)!;
      final box = probe.box;
      probe.dispose();
      final side = await _still(who, 240);
      final cellW = (math.max(box.width, 140) + 2 * 200) * _px;
      final cellH = (box.height + 150) * _px + 40;
      const label = 34.0;
      final size = Size(cellW * 3, cellH + label);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(Offset.zero & size, Paint()..color = _bg);
      _text(
        c,
        decor.name.toUpperCase(),
        const Offset(12, 9),
        size: 14,
        bold: true,
      );
      _text(
        c,
        '$batch  ·  with ${_rows[who]!['name']}',
        const Offset(260, 11),
        size: 12,
        color: _muted,
      );
      final shift = -box.center.dx;
      final moods = [
        ('day', 0.0, 3.2, 0.0, false),
        ('night', 1.0, 7.9, 0.0, false),
        (
          switch (use) {
            _Use.still => 'stirred, at dusk',
            _Use.sleep || _Use.sleepBeside => 'in use, at night',
            _ => 'in use',
          },
          switch (use) {
            _Use.sleep || _Use.sleepBeside => 1.0,
            _Use.still => 0.6,
            _ => 0.25,
          },
          5.1,
          1.0,
          true,
        ),
      ];
      for (var m = 0; m < moods.length; m++) {
        final (mood, night, t, stir, inUse) = moods[m];
        final art = KeepsakeArt.of(id)!;
        final k = KeepsakeTime(
          t: t,
          night: night,
          daylight: 1 - night,
          stir: stir,
          hour: switch (m) {
            0 => 9.5,
            1 => 23,
            _ => night > 0.5 ? 23 : 16.5,
          },
        );
        final cell = Rect.fromLTWH(m * cellW, label, cellW - 4, cellH);
        c.save();
        patch(c, cell, night, shift);
        art.paint(c, k);
        final seats = art.seats(k);
        Offset seat(int i) => Offset(seats[i].dx, -seats[i].dy);
        final near = box.left - _boxU * 0.05;
        // Where a visitor stands to bow, hop or warm itself: the piece's
        // own place for it on its left, if it marks one, else beside it.
        final stand = seats.isNotEmpty && seats.first.dy == 0
            ? seats.first.dx
            : math.min(-100.0, near + 20);
        if (!inUse && m == 0 && use == _Use.still) {
          // Someone beside it for size.
          creature(c, side, who, Offset(box.right + _boxU * 0.4, 0));
        }
        if (inUse) {
          switch (use) {
            case _Use.still:
              creature(c, side, who, Offset(box.right + _boxU * 0.4, 0));
            case _Use.sit || _Use.sleep:
              creature(c, side, who, seat(0));
            case _Use.sleepBeside:
              creature(c, side, who, Offset(stand, 0), faceRight: true);
            case _Use.bow:
              creature(
                c,
                side,
                who,
                Offset(stand, 0),
                faceRight: true,
                angle: 0.16,
              );
            case _Use.hop:
              creature(c, side, who, Offset(stand, -14), faceRight: true);
            case _Use.court:
              creature(c, side, who, seat(0));
              for (var j = 0; j < 2; j++) {
                final img = await _still(_bowers[j], 240);
                creature(
                  c,
                  img,
                  _bowers[j],
                  seat(j + 1),
                  faceRight: j == 0,
                  angle: j == 0 ? 0.18 : -0.18,
                );
              }
            case _Use.climbAll:
              creature(c, side, who, seat(0));
              final img = await _still(_second, 240);
              creature(c, img, _second, seat(1), faceRight: true);
            case _Use.distil:
              break;
          }
        }
        if (art.hasFront) art.front(c, k);
        c.restore();
        _text(
          c,
          mood,
          Offset(m * cellW + 8, label + 6),
          size: 11,
          color: _muted,
        );
        art.dispose();
      }
      await _save(rec, size, '$out/$id.png');
    }
  });

  test('the great alembic carries one through', () async {
    if (out == null || (only != null && !only.contains('great_alembic'))) {
      return;
    }
    const who = 'MAN16';
    final img = await _still(who, 240);
    // Its grains, read from the same picture, in a row's units (the box
    // 100 across), as the field reads a sprite.
    final data = await img.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final grains = SpecimenGrains.fromRgba(
      data!.buffer.asUint8List(),
      img.width,
      img.height,
      pixelRatio: img.width / 100,
      maxGrains: 900,
      tones: 12,
    );
    final art = KeepsakeArt.of('great_alembic')!;
    final box = art.box;
    const moments = [0.0, 0.06, 0.14, 0.3, 0.5, 0.7, 0.84, 0.92, 1.0];
    const cols = 3;
    final cellW = (box.width + 260) * _px;
    final cellH = (box.height + 120) * _px + 40;
    final rows = (moments.length / cols).ceil();
    final size = Size(cellW * cols, cellH * rows + 34);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    _text(
      c,
      'GREAT STILL  ·  a resident carried through as its grains, '
      'with ${_rows[who]!['name']}',
      const Offset(12, 9),
      size: 14,
      bold: true,
    );
    final passenger = KeepsakePassenger(grains, scale: 1 / 0.62)
      ..rise = _boxU * creatureFeetDrop(who);
    for (var i = 0; i < moments.length; i++) {
      final p = moments[i];
      final k = KeepsakeTime(
        t: 4 + p * 10,
        night: 0.3,
        daylight: 0.7,
        stir: 0.6,
      );
      final cell = Rect.fromLTWH(
        (i % cols) * cellW,
        34 + (i ~/ cols) * cellH,
        cellW - 4,
        cellH - 4,
      );
      c.save();
      patch(c, cell, 0.3, -box.center.dx);
      art.passenger = passenger..progress = p;
      art.paint(c, k);
      final seats = art.seats(k);
      // The sprite thins as its grains let go, and fills as they gather.
      final going = p < 0.5;
      final alpha = going
          ? 1 - _smoothstep(0, 0.16, p)
          : _smoothstep(0.86, 0.97, p);
      final at = going ? seats[0] : seats[1];
      if (alpha > 0.01) {
        creature(c, img, who, Offset(at.dx, -at.dy), alpha: alpha);
      }
      art.front(c, k);
      c.restore();
      _text(
        c,
        'progress ${p.toStringAsFixed(2)}',
        Offset(cell.left + 8, cell.top + 6),
        size: 11,
        color: _muted,
      );
    }
    art.dispose();
    await _save(rec, size, '$out/great_alembic_passage.png');
    // And its plain sheet, with the visitor at its mouth.
    final rec2 = ui.PictureRecorder();
    final c2 = Canvas(rec2);
    final w2 = (box.width + 260) * _px;
    final size2 = Size(w2 * 2, cellH + 34);
    c2.drawRect(Offset.zero & size2, Paint()..color = _bg);
    _text(c2, 'GREAT STILL', const Offset(12, 9), size: 14, bold: true);
    _text(
      c2,
      'The Still-Room · Wonder (capstone)',
      const Offset(260, 11),
      size: 12,
      color: _muted,
    );
    for (var m = 0; m < 2; m++) {
      final night = m.toDouble();
      final a2 = KeepsakeArt.of('great_alembic')!;
      final k = KeepsakeTime(
        t: 3.2 + m * 4.7,
        night: night,
        daylight: 1 - night,
      );
      c2.save();
      patch(
        c2,
        Rect.fromLTWH(m * w2, 34, w2 - 4, cellH - 4),
        night,
        -box.center.dx,
      );
      a2.paint(c2, k);
      a2.front(c2, k);
      c2.restore();
      _text(
        c2,
        m == 0 ? 'day' : 'night',
        Offset(m * w2 + 8, 40),
        size: 11,
        color: _muted,
      );
      a2.dispose();
    }
    await _save(rec2, size2, '$out/great_alembic.png');
  });

  test('tray tiles', () async {
    if (out == null || only != null) return;
    // As the Arrange tray draws them: fitted to the tile, lit for dusk.
    const tile = Size(96, 76);
    const cols = 8;
    final pieces = HomeDecor.athanor;
    final rows = (pieces.length / cols).ceil();
    const scale = 2.0;
    final size = Size(
      tile.width * cols * scale,
      (tile.height + 16) * rows * scale,
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    c.drawRect(
      Offset.zero & (size / scale),
      Paint()..color = const Color(0xFF131316),
    );
    for (var i = 0; i < pieces.length; i++) {
      final art = KeepsakeArt.of(pieces[i].id)!;
      final x0 = (i % cols) * tile.width, y0 = (i ~/ cols) * (tile.height + 16);
      final b = art.box;
      final k = math.min(tile.width / b.width, tile.height / b.height) * 0.92;
      final time = KeepsakeTime(t: 3.2, night: 0.6, daylight: 0.4);
      c.save();
      c.clipRect(Rect.fromLTWH(x0, y0, tile.width, tile.height));
      c.translate(
        x0 + tile.width / 2 - b.center.dx * k,
        y0 + tile.height - b.bottom * k,
      );
      c.scale(k);
      art.paint(c, time);
      if (art.hasFront) art.front(c, time);
      c.restore();
      _text(
        c,
        pieces[i].name.toUpperCase(),
        Offset(x0 + 3, y0 + tile.height + 2),
        size: 6.5,
        color: _ink,
      );
      art.dispose();
    }
    await _save(rec, size, '$out/tray_tiles.png');
  });

  test('what a frame costs', () async {
    if (out == null || only != null) return;
    final lines = <String>[];
    for (final d in HomeDecor.athanor) {
      final art = KeepsakeArt.of(d.id)!;
      final k = KeepsakeTime(night: 0.5, daylight: 0.5, stir: 0.4);
      void frame(double t) {
        final r = ui.PictureRecorder();
        final c = Canvas(r);
        k.t = t;
        art.paint(c, k);
        if (art.hasFront) art.front(c, k);
        r.endRecording().dispose();
      }

      for (var f = 0; f < 30; f++) {
        frame(f / 60);
      }
      final sw = Stopwatch()..start();
      for (var f = 0; f < 240; f++) {
        frame(1 + f / 60);
      }
      lines.add(
        '${d.id}: ${(sw.elapsedMicroseconds / 240).toStringAsFixed(1)} µs',
      );
      art.dispose();
    }
    // ignore: avoid_print
    print('A frame of each (JIT, recording only):\n${lines.join('\n')}');
  });
}

double _smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
