@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The shop's alchemy effects as they sit behind a creature.
//
//   FX_OUT=/tmp/alchemy_fx.png flutter test \
//     test/alchemy_effects_preview_test.dart --tags preview
//
// writes
//   /tmp/alchemy_fx_0.png, _1.png   every effect as the app shows it, through
//                                   the shared view, at two moments
//   /tmp/alchemy_fx_painters.png    each rebuilt effect, one row apiece: the
//                                   details hero at four moments on the dark
//                                   plate and two on the light one, then the
//                                   party HUD size (dark top, light bottom)
//   /tmp/alchemy_fx_elements.png    the Elemental Aura, one row per element,
//                                   each on its own element's Horn
//
// and prints what a frame of each costs.
const _plateDark = Color(0xFF0B0A10);
const _plateLight = Color(0xFFEDE6D8);

const _horns = {
  'Fire': 'HOR01_firehorn',
  'Water': 'HOR02_waterhorn',
  'Earth': 'HOR03_earthhorn',
  'Air': 'HOR04_airhorn',
  'Steam': 'HOR05_steamhorn',
  'Lava': 'HOR06_lavahorn',
  'Lightning': 'HOR07_lightninghorn',
  'Mud': 'HOR08_mudhorn',
  'Ice': 'HOR09_icehorn',
  'Dust': 'HOR10_dusthorn',
  'Crystal': 'HOR11_crystalhorn',
  'Plant': 'HOR12_planthorn',
  'Poison': 'HOR13_poisonhorn',
  'Spirit': 'HOR14_spirithorn',
  'Dark': 'HOR15_darkhorn',
  'Light': 'HOR16_lighthorn',
  'Blood': 'HOR17_bloodhorn',
};

Future<ui.Image> _loadSprite(WidgetTester tester, String name, double side) async {
  late ui.Image sprite;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(
      File('assets/images/creatures/rare/$name.png').readAsBytesSync(),
      targetWidth: (side * 2).round(),
    );
    sprite = (await codec.getNextFrame()).image;
  });
  return sprite;
}

Future<void> _save(WidgetTester tester, ui.Image image, String path) async {
  await tester.runAsync(() async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Also writes each row of [sheet] on its own, [zoom]x, for a close look
/// (FX_ROWS=1).
Future<void> _saveRows(
  WidgetTester tester,
  ui.Image sheet,
  double rowH,
  String path, {
  double zoom = 2.5,
  int perChunk = 4,
}) async {
  if (Platform.environment['FX_ROWS'] != '1') return;
  final rows = (sheet.height / rowH).round();
  final cols = (sheet.width / rowH).round();
  for (var i = 0; i < rows; i++) {
    for (var c0 = 0, part = 0; c0 < cols; c0 += perChunk, part++) {
      final w = rowH * (cols - c0).clamp(0, perChunk);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(zoom);
      c.drawImageRect(
        sheet,
        Rect.fromLTWH(c0 * rowH, i * rowH, w, rowH),
        Rect.fromLTWH(0, 0, w, rowH),
        Paint()..filterQuality = FilterQuality.none,
      );
      final img = rec.endRecording().toImageSync(
        (w * zoom).round(),
        (rowH * zoom).round(),
      );
      await _save(tester, img, path.replaceFirst('.png', '_r${i}_$part.png'));
    }
  }
}

/// One creature wearing [key] at [t], centred in [cell] at [origin].
void _cell(
  Canvas canvas,
  Offset origin,
  double cell,
  ui.Image sprite,
  double side,
  String key,
  double t, {
  required bool dark,
  String? element,
}) {
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.clipRect(Rect.fromLTWH(0, 0, cell, cell));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, cell, cell),
    Paint()..color = dark ? _plateDark : _plateLight,
  );
  final at = Offset(cell / 2, cell / 2);
  AlchemyEffectPaint.paint(
    canvas,
    key,
    at,
    side / 2,
    t,
    element: element,
    dark: dark,
  );
  canvas.drawImageRect(
    sprite,
    Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
    Rect.fromCenter(center: at, width: side, height: side),
    Paint()..filterQuality = FilterQuality.medium,
  );
  AlchemyEffectPaint.paint(
    canvas,
    key,
    at,
    side / 2,
    t,
    element: element,
    dark: dark,
    front: true,
  );
  canvas.restore();
}

/// Four HUD-sized creatures in one cell: dark on top, light below.
void _hudBlock(
  Canvas canvas,
  Offset origin,
  double cell,
  ui.Image sprite,
  String key,
  List<double> times, {
  String? element,
}) {
  const side = 48.0;
  final half = cell / 2;
  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 2; col++) {
      _cell(
        canvas,
        origin + Offset(col * half, row * half),
        half,
        sprite,
        side,
        key,
        times[col],
        dark: row == 0,
        element: element,
      );
    }
  }
}

void _timing(String label, String key, {String? element}) {
  const frames = 240;
  final sw = Stopwatch()..start();
  for (var f = 0; f < frames; f++) {
    final r = ui.PictureRecorder();
    AlchemyEffectPaint.paint(
      Canvas(r),
      key,
      const Offset(100, 100),
      55,
      f / 60,
      element: element,
    );
    r.endRecording().dispose();
  }
  // ignore: avoid_print
  print(
    '$label: ${(sw.elapsedMicroseconds / frames).toStringAsFixed(1)} '
    'µs per frame (JIT, recording only)',
  );
}

void main() {
  final out = Platform.environment['FX_OUT'];

  testWidgets('alchemy effect sheet', (tester) async {
    if (out == null) return;
    const side = 110.0;
    const cell = 250.0;
    const steps = [Duration(milliseconds: 300), Duration(milliseconds: 900)];

    final sprite = await _loadSprite(tester, 'HOR16_lighthorn', side);

    // The rebuilt ones wrap the sprite, as the app's hosts do: behind it
    // and, for an effect with a near side, over it.
    Widget shared(String key, {String? element}) => AlchemyEffectView(
      effectKey: key,
      element: element,
      dark: true,
      child: RawImage(image: sprite, width: side, height: side),
    );

    final effects = <String, Widget Function()>{
      for (final key in AlchemyEffectPaint.keys)
        key: () => shared(
          key,
          element: switch (key) {
            AlchemyEffectPaint.elementalAura => 'Fire',
            AlchemyEffectPaint.dustRing => 'Dust',
            _ => null,
          },
        ),
    };

    tester.view.physicalSize = Size(cell * effects.length / 2, cell * 2);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(
            color: _plateDark,
            child: Wrap(
              children: [
                for (final make in effects.values)
                  SizedBox.square(
                    dimension: cell,
                    child: ClipRect(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          OverflowBox(
                            maxWidth: cell * 2,
                            maxHeight: cell * 2,
                            child: make(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    var i = 0;
    for (final step in steps) {
      await tester.pump(step);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          out.replaceFirst('.png', '_$i.png'),
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      i++;
    }
  });

  testWidgets('shared painter sheet', (tester) async {
    if (out == null) return;
    const cell = 180.0;
    const side = 110.0;
    const darkTimes = [0.6, 1.9, 3.4, 5.2];
    const lightTimes = [1.9, 4.4];
    final sprite = await _loadSprite(tester, 'HOR16_lighthorn', side);
    final hud = await _loadSprite(tester, 'HOR16_lighthorn', 48);
    final keys = AlchemyEffectPaint.keys.toList();
    const cols = 7;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var row = 0; row < keys.length; row++) {
      final key = keys[row];
      final element = switch (key) {
        AlchemyEffectPaint.elementalAura => 'Light',
        AlchemyEffectPaint.dustRing => 'Dust',
        _ => null,
      };
      var col = 0;
      for (final t in darkTimes) {
        _cell(
          canvas,
          Offset(col++ * cell, row * cell),
          cell,
          sprite,
          side,
          key,
          t,
          dark: true,
          element: element,
        );
      }
      for (final t in lightTimes) {
        _cell(
          canvas,
          Offset(col++ * cell, row * cell),
          cell,
          sprite,
          side,
          key,
          t,
          dark: false,
          element: element,
        );
      }
      _hudBlock(
        canvas,
        Offset(col * cell, row * cell),
        cell,
        hud,
        key,
        const [1.9, 3.4],
        element: element,
      );
      _timing(key, key, element: element);
    }
    final image = rec.endRecording().toImageSync(
      (cell * cols).round(),
      (cell * keys.length).round(),
    );
    await _save(tester, image, out.replaceFirst('.png', '_painters.png'));
    await _saveRows(
      tester,
      image,
      cell,
      out.replaceFirst('.png', '_painters.png'),
    );
  });

  testWidgets('elemental aura sheet', (tester) async {
    if (out == null) return;
    const cell = 180.0;
    const side = 110.0;
    const darkTimes = [0.7, 2.1, 3.6];
    const lightTime = 2.9;
    const cols = 5;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    var row = 0;
    for (final entry in _horns.entries) {
      final sprite = await _loadSprite(tester, entry.value, side);
      final hud = await _loadSprite(tester, entry.value, 48);
      var col = 0;
      for (final t in darkTimes) {
        _cell(
          canvas,
          Offset(col++ * cell, row * cell),
          cell,
          sprite,
          side,
          AlchemyEffectPaint.elementalAura,
          t,
          dark: true,
          element: entry.key,
        );
      }
      _cell(
        canvas,
        Offset(col++ * cell, row * cell),
        cell,
        sprite,
        side,
        AlchemyEffectPaint.elementalAura,
        lightTime,
        dark: false,
        element: entry.key,
      );
      _hudBlock(
        canvas,
        Offset(col * cell, row * cell),
        cell,
        hud,
        AlchemyEffectPaint.elementalAura,
        const [1.2, 2.9],
        element: entry.key,
      );
      _timing(
        'elemental_aura ${entry.key}',
        AlchemyEffectPaint.elementalAura,
        element: entry.key,
      );
      row++;
    }
    final image = rec.endRecording().toImageSync(
      (cell * cols).round(),
      (cell * row).round(),
    );
    await _save(tester, image, out.replaceFirst('.png', '_elements.png'));
    await _saveRows(
      tester,
      image,
      cell,
      out.replaceFirst('.png', '_elements.png'),
    );
  });

  testWidgets('dust ring per element sheet', (tester) async {
    if (out == null) return;
    const cell = 180.0;
    const side = 110.0;
    const cols = 6;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    var i = 0;
    for (final entry in _horns.entries) {
      final sprite = await _loadSprite(tester, entry.value, side);
      _cell(
        canvas,
        Offset((i % cols) * cell, (i ~/ cols) * cell),
        cell,
        sprite,
        side,
        AlchemyEffectPaint.dustRing,
        1.7 + i * 0.37,
        dark: i != 16,
        element: entry.key,
      );
      i++;
    }
    final rows = (i / cols).ceil();
    final image = rec.endRecording().toImageSync(
      (cell * cols).round(),
      (cell * rows).round(),
    );
    await _save(tester, image, out.replaceFirst('.png', '_dust_rings.png'));
    await _saveRows(
      tester,
      image,
      cell,
      out.replaceFirst('.png', '_dust_rings.png'),
    );
  });
}
