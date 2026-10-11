@Tags(['preview'])
library;

// The Athanor's wearables as the game draws them (docs/athanor/
// pieces_wearables.md), each beside a real Alchemon on the game's dark:
//
//   ATHANOR_WEARABLES_OUT=docs/athanor/content/wearables flutter test -j 1 \
//     test/athanor_wearables_preview_test.dart --tags preview
//
// writes into that directory
//   auras.png     Ink Bloom, the Peacock's Tail, Quicksilver, Gold Leaf and
//                 Cinnabar: four moments each at the details size, then the
//                 party HUD's 48 px
//   costumes.png  the Crown of the Red King and the Brass Monocle worn
//                 (CostumePaint.paintWorn) on a Wing, a Pip, a Horn and a
//                 Let, frames 0–2, a close look, and in another color
//   pieces.png    every piece as the Athanor's tiles draw it
//                 (paintAthanorPiece), dock sets with their Let loaded
//
// and prints what a frame of each costs. With no env var it writes nothing.
// The dock itself: NAV_EMBLEMS_FACTIONS=athanor in nav_emblems_preview_test.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/athanor/athanor_piece_art.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _bg = Color(0xFF09090B); // ForgeTokens bg0
const _ink = Color(0xFFE6E2DA);
const _muted = Color(0xFF8E8C88);

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

Future<(ui.Image, int, int, int)> _sheet(String id) async {
  final e = _row(id);
  final sd = e['spriteData'] as Map<String, dynamic>;
  final frames = (sd['totalFrames'] as num).toInt();
  final rows = (sd['rows'] as num?)?.toInt() ?? 1;
  final cols = (frames + rows - 1) ~/ rows;
  final codec = await ui.instantiateImageCodec(
    File(
      'assets/images/${(e['image'] as String).replaceAll('.png', '_spritesheet.png')}',
    ).readAsBytesSync(),
  );
  final img = (await codec.getNextFrame()).image;
  codec.dispose();
  return (img, frames, rows, cols);
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
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        color: color,
        letterSpacing: 1.2,
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

void _drawImage(Canvas c, ui.Image img, Rect dst, {Rect? src}) {
  c.drawImageRect(
    img,
    src ?? Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

void _cost(String label, void Function(Canvas c, double t) frame) {
  const frames = 240;
  for (var f = 0; f < 30; f++) {
    final r = ui.PictureRecorder();
    frame(Canvas(r), f / 60);
    r.endRecording().dispose();
  }
  final sw = Stopwatch()..start();
  for (var f = 0; f < frames; f++) {
    final r = ui.PictureRecorder();
    frame(Canvas(r), 2 + f / 60);
    r.endRecording().dispose();
  }
  // ignore: avoid_print
  print(
    '$label: ${(sw.elapsedMicroseconds / frames).toStringAsFixed(1)} '
    'µs per frame (JIT, recording only)',
  );
}

/// The pieces, as docs/athanor/pieces_wearables.md lists them.
const _pieces = [
  ('The Black Work', 'Inkmaker', AthanorPieceKind.title, 'inkmaker'),
  (
    'The Black Work',
    'Ink Bloom',
    AthanorPieceKind.alchemyEffect,
    InvKeys.alchemyInkBloom,
  ),
  ('The Black Work', 'Darklet Dock', AthanorPieceKind.dockSet, 'darklet'),
  (
    'The Black Work',
    "The Peacock's Tail",
    AthanorPieceKind.alchemyEffect,
    InvKeys.alchemyPeacockTail,
  ),
  ('The White Work', 'Silversmith', AthanorPieceKind.title, 'silversmith'),
  (
    'The White Work',
    'Quicksilver',
    AthanorPieceKind.alchemyEffect,
    InvKeys.alchemyQuicksilver,
  ),
  ('The White Work', 'Spiritlet Dock', AthanorPieceKind.dockSet, 'spiritlet'),
  ('The Yellow Work', 'Gilder', AthanorPieceKind.title, 'gilder'),
  (
    'The Yellow Work',
    'Gold Leaf',
    AthanorPieceKind.alchemyEffect,
    InvKeys.alchemyGoldLeaf,
  ),
  ('The Yellow Work', 'Lightlet Dock', AthanorPieceKind.dockSet, 'lightlet'),
  ('The Red Work', 'Ember Keeper', AthanorPieceKind.title, 'ember_keeper'),
  (
    'The Red Work',
    'Cinnabar',
    AthanorPieceKind.alchemyEffect,
    InvKeys.alchemyCinnabar,
  ),
  ('The Red Work', 'Bloodlet Dock', AthanorPieceKind.dockSet, 'bloodlet'),
  (
    'The Red Work',
    'Crown of the Red King',
    AthanorPieceKind.costume,
    InvKeys.alchemyRedKingCrown,
  ),
  ('The Still-Room', 'Distiller', AthanorPieceKind.title, 'distiller'),
  ('The Still-Room', 'Crystalet Dock', AthanorPieceKind.dockSet, 'crystalet'),
  (
    'The Still-Room',
    'Brass Monocle',
    AthanorPieceKind.costume,
    InvKeys.alchemyBrassMonocle,
  ),
];

void main() {
  final out = Platform.environment['ATHANOR_WEARABLES_OUT'];
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await _loadCatalog();
    await _font();
  });

  test('auras', () async {
    if (out == null) return;
    const auras = [
      (AlchemyEffectPaint.inkBloom, 'INK BLOOM', 'The Black Work', 'PIP15'),
      (
        AlchemyEffectPaint.peacockTail,
        "THE PEACOCK'S TAIL",
        'The Black Work · capstone',
        'PIP13',
      ),
      (
        AlchemyEffectPaint.quicksilver,
        'QUICKSILVER',
        'The White Work',
        'HOR09',
      ),
      (AlchemyEffectPaint.goldLeaf, 'GOLD LEAF', 'The Yellow Work', 'MAN16'),
      (AlchemyEffectPaint.cinnabar, 'CINNABAR', 'The Red Work', 'HOR17'),
    ];
    const cell = 260.0, side = 200.0, label = 34.0;
    const times = [1.3, 3.7, 6.1, 8.9];
    const cols = 5;
    final size = Size(cell * cols, (cell + label) * auras.length);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    for (var row = 0; row < auras.length; row++) {
      final (key, name, batch, species) = auras[row];
      final sprite = await _still(species, side);
      final small = await _still(species, 56);
      final y0 = row * (cell + label);
      _text(c, name, Offset(12, y0 + 8), size: 14, bold: true);
      _text(
        c,
        '$batch  ·  on ${_row(species)['name']}',
        Offset(260, y0 + 10),
        size: 12,
        color: _muted,
      );
      for (var i = 0; i < times.length; i++) {
        final at = Offset(i * cell + cell / 2, y0 + label + cell / 2);
        AlchemyEffectPaint.paint(c, key, at, side / 2, times[i]);
        _drawImage(
          c,
          sprite,
          Rect.fromCenter(center: at, width: side, height: side),
        );
        AlchemyEffectPaint.paint(c, key, at, side / 2, times[i], front: true);
        _text(
          c,
          't ${times[i]}s',
          Offset(i * cell + 8, y0 + label + cell - 20),
          size: 10,
          color: _muted,
        );
      }
      for (var k = 0; k < 4; k++) {
        final at = Offset(
          4 * cell + 65 + (k % 2) * 130,
          y0 + label + 65 + (k ~/ 2) * 130,
        );
        AlchemyEffectPaint.paint(c, key, at, 24, times[k]);
        _drawImage(
          c,
          small,
          Rect.fromCenter(center: at, width: 48, height: 48),
        );
        AlchemyEffectPaint.paint(c, key, at, 24, times[k], front: true);
      }
      _text(
        c,
        'HUD 48 px',
        Offset(4 * cell + 8, y0 + label + cell - 20),
        size: 10,
        color: _muted,
      );
      _cost(name, (cv, t) {
        AlchemyEffectPaint.paint(cv, key, const Offset(100, 100), 55, t);
        AlchemyEffectPaint.paint(
          cv,
          key,
          const Offset(100, 100),
          55,
          t,
          front: true,
        );
      });
    }
    await _save(rec, size, '$out/auras.png');
  });

  test('costumes', () async {
    if (out == null) return;
    const species = ['WNG01', 'PIP02', 'HOR03', 'LET09'];
    const cell = 210.0, label = 30.0;
    const cols = 5; // frames 0–2, a close look, another color
    final size = Size(cell * cols * 2, (cell + label) * species.length + 40);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    _text(
      c,
      "CROWN OF THE RED KING  ·  on the party hat's fits",
      const Offset(12, 10),
      size: 13,
      bold: true,
    );
    _text(
      c,
      "BRASS MONOCLE  ·  on the sunglasses' fits",
      Offset(cell * cols + 12, 10),
      size: 13,
      bold: true,
    );
    for (var i = 0; i < species.length; i++) {
      final id = species[i];
      final (sheet, frames, sheetRows, sheetCols) = await _sheet(id);
      final fw = sheet.width / sheetCols, fh = sheet.height / sheetRows;
      final y0 = 40 + i * (cell + label);
      _text(c, '${_row(id)['name']}', Offset(12, y0 + 4), size: 12,
          color: _muted);
      for (final costume in [FamilyCostume.crown, FamilyCostume.monocle]) {
        final x0 = costume == FamilyCostume.crown ? 0.0 : cell * cols;
        for (var f = 0; f < cols; f++) {
          final frameIndex = math.min(f, 2) % frames;
          final close = f == 3;
          final recolor = f == 4;
          final fit = costume.fitAt(id, frameIndex);
          if (fit == null) continue;
          final s = close ? cell * 2.4 : cell * 0.92;
          final ox = x0 + f * cell, oy = y0 + label;
          c.save();
          c.clipRect(Rect.fromLTWH(ox, oy, cell, cell));
          final frame = close
              ? Rect.fromLTWH(
                  ox + cell / 2 - fit.x * s,
                  oy + cell / 2 - fit.y * s,
                  s,
                  s,
                )
              : Rect.fromLTWH(ox + (cell - s) / 2, oy + (cell - s) / 2, s, s);
          _drawImage(
            c,
            sheet,
            frame,
            src: Rect.fromLTWH(
              (frameIndex % sheetCols) * fw,
              (frameIndex ~/ sheetCols) * fh,
              fw,
              fh,
            ),
          );
          final worn = WornCostumes(id, {
            costume: recolor ? costume.presets[4] : costume.defaultColor,
          });
          CostumePaint.paintWorn(c, worn.encode(), frame, frameIndex, 1.7);
          c.restore();
          _text(
            c,
            close
                ? 'close'
                : recolor
                ? 'another color'
                : 'frame $frameIndex',
            Offset(ox + 6, oy + cell - 16),
            size: 10,
            color: _muted,
          );
        }
      }
      sheet.dispose();
    }
    await _save(rec, size, '$out/costumes.png');
    for (final costume in [FamilyCostume.crown, FamilyCostume.monocle]) {
      final worn = WornCostumes('WNG01', {
        costume: costume.defaultColor,
      }).encode();
      _cost(
        costume.title,
        (cv, t) => CostumePaint.paintWorn(
          cv,
          worn,
          const Rect.fromLTWH(0, 0, 200, 200),
          (t * 8).floor() % 4,
          t,
        ),
      );
    }
  });

  testWidgets('pieces', (tester) async {
    if (out == null) return;
    // The dock sets' Lets, loaded as the dock loads them.
    final lets = <String, NavLetSprite>{};
    await tester.runAsync(() async {
      final raw = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      final catalog = CreatureCatalog.fromList([
        for (final j
            in (jsonDecode(raw) as Map<String, dynamic>)['creatures']
                as List<dynamic>)
          Creature.fromJson(j as Map<String, dynamic>),
      ]);
      final images = Images();
      for (final s in DockSet.athanorSets) {
        final sheet = navLetSheets(catalog, s, NavEmblemKind.home).first;
        lets[s.id] = NavLetSprite(
          sheet,
          await loadCreatureSheet(images, sheet.path),
        );
      }
    });

    const tile = 132.0, gap = 14.0, label = 40.0, across = 4;
    final batches = {for (final p in _pieces) p.$1}.toList();
    final rows = [
      for (final b in batches) [for (final p in _pieces) if (p.$1 == b) p],
    ];
    final size = Size(
      gap + (tile + gap) * across + 150,
      gap + (tile + label + gap) * rows.length,
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & size, Paint()..color = _bg);
    for (var r = 0; r < rows.length; r++) {
      final y0 = gap + r * (tile + label + gap);
      _text(c, rows[r].first.$1.toUpperCase(), Offset(gap, y0 + tile / 2 - 8),
          size: 12, bold: true);
      for (var i = 0; i < rows[r].length; i++) {
        final (_, name, kind, ref) = rows[r][i];
        final rect = Rect.fromLTWH(150 + gap + i * (tile + gap), y0, tile, tile);
        c.drawRect(rect, Paint()..color = const Color(0xFF131316));
        final piece = AthanorPiece(
          id: ref,
          name: name,
          description: '',
          kind: kind,
          rarity: AthanorRarity.rare,
          grantRef: ref,
        );
        if (kind == AthanorPieceKind.dockSet) {
          // As paintAthanorPiece draws it once the Let has loaded.
          final set = DockSet.byId(ref)!;
          final side = rect.shortestSide * 0.9;
          c.save();
          c.translate(rect.center.dx - side / 2, rect.center.dy - side / 2);
          NavEmblemPainter(
            kind: NavEmblemKind.home,
            element: set.element,
            let: lets[ref],
            time: 1.1,
          ).paint(c, Size.square(side));
          c.restore();
        } else {
          paintAthanorPiece(
            c,
            piece,
            rect,
            2.6,
            titleStyle: const TextStyle(fontFamily: 'Roboto'),
          );
        }
        _text(c, name, Offset(rect.left, rect.bottom + 6), size: 10.5,
            color: _muted);
      }
    }
    await tester.runAsync(() => _save(rec, size, '$out/pieces.png'));
    for (final p in _pieces.where(
      (p) =>
          p.$3 == AthanorPieceKind.costume || p.$3 == AthanorPieceKind.dockSet,
    )) {
      final piece = AthanorPiece(
        id: p.$4,
        name: p.$2,
        description: '',
        kind: p.$3,
        rarity: AthanorRarity.rare,
        grantRef: p.$4,
      );
      _cost(
        'tile ${p.$2}',
        (cv, t) => paintAthanorPiece(
          cv,
          piece,
          const Rect.fromLTWH(0, 0, 132, 132),
          t,
        ),
      );
    }
  });
}
