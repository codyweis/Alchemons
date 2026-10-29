@Tags(['preview'])
library;

// The 17 elemental caches as they sit in open space, and their unsealing,
// to judge as a set.
//
//   CACHE_SPACE_OUT=/tmp/caches flutter test \
//     test/cache_space_preview_test.dart --tags preview
//
// Writes:
//   sealed.png   each cache at rest, with the label the game draws when the
//                ship is near; a portrait phone's middle zoom at 2x, the
//                last cell holding the ship for size
//   strip.png    every element through its unsealing, left to right
//   space/NNN.png
//                frames at 30 fps of all 17 opening together; join them
//                with ffmpeg -framerate 30 -i space/%03d.png space.mp4

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_cache_data.dart';
import 'package:alchemons/games/cosmic/cosmic_cache_vfx.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['CACHE_SPACE_OUT'];

  void space(Canvas c, Rect r, int seed) {
    c.drawRect(r, Paint()..color = const Color(0xFF020010));
    final rng = Random(seed);
    final p = Paint();
    for (var i = 0; i < r.width * r.height / 2600; i++) {
      p.color = Colors.white.withValues(alpha: 0.12 + rng.nextDouble() * 0.5);
      c.drawCircle(
        Offset(
          r.left + rng.nextDouble() * r.width,
          r.top + rng.nextDouble() * r.height,
        ),
        0.4 + rng.nextDouble() * 0.9,
        p,
      );
    }
  }

  TextPainter label(String text, Color color, double size, double spacing) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: color,
            fontSize: size,
            fontWeight: size > 10 ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: spacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  Future<void> save(ui.Picture pic, Size size, String path) async {
    final img = pic.toImageSync(size.width.round(), size.height.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  }

  final elements = kElementColors.keys.toList();
  const r = ElementalCache.visualRadius;

  /// All 17 caches plus the ship, 3 across: sealed while [t] is null.
  ui.Picture spaceSheet({
    required double unit,
    required double Function(int i) life,
    double? t,
    bool labels = false,
  }) {
    const world = 330.0; // world units per cell
    final cell = world * unit;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, Rect.fromLTWH(0, 0, cell * 3, cell * 6), 3);
    for (var i = 0; i < 18; i++) {
      final centre = Offset(
        (i % 3) * cell + cell / 2,
        (i ~/ 3) * cell + cell / 2,
      );
      c.save();
      c.clipRect(Rect.fromCenter(center: centre, width: cell, height: cell));
      c.translate(centre.dx, centre.dy);
      c.scale(unit);
      if (i >= elements.length) {
        paintShipHull(c, null, 3);
        c.restore();
        continue;
      }
      final element = elements[i];
      const p = Offset(0, -18);
      if (t == null) {
        paintSealedCache(c, p, element, life(i));
      } else {
        paintCacheUnseal(c, p, element, life(i), t);
      }
      if (labels) {
        final title = label(
          '${element.toUpperCase()} CACHE',
          elementColor(element).withValues(alpha: 0.85),
          11,
          2,
        );
        title.paint(c, Offset(-title.width / 2, p.dy + r + 12));
        final hint = label(
          'needs ${cacheHintFor(element)}',
          Colors.white.withValues(alpha: 0.55),
          9,
          1,
        );
        hint.paint(c, Offset(-hint.width / 2, p.dy + r + 27));
      }
      c.restore();
    }
    return rec.endRecording();
  }

  test('caches in space', () async {
    if (out == null) return;
    final arial = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (arial.existsSync()) {
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.view(arial.readAsBytesSync().buffer)),
          ))
          .load();
    }

    // Sealed, labelled.
    const unit = 0.72 * 2; // mid zoom, drawn at 2x
    await save(
      spaceSheet(unit: unit, life: (i) => 2.4 + i * 0.37, labels: true),
      const Size(330 * unit * 3, 330 * unit * 6),
      '$out/sealed.png',
    );

    // The unsealing as a strip per element.
    const stops = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9];
    const cell = 200.0;
    const k = 0.62;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final strip = Size(cell * stops.length + 110, cell * elements.length);
    space(c, Offset.zero & strip, 5);
    for (var row = 0; row < elements.length; row++) {
      final e = elements[row];
      label(
        e.toUpperCase(),
        elementColor(e),
        12,
        1.5,
      ).paint(c, Offset(10, row * cell + cell / 2 - 7));
      for (var col = 0; col < stops.length; col++) {
        c.save();
        c.clipRect(Rect.fromLTWH(110 + col * cell, row * cell, cell, cell));
        c.translate(110 + col * cell + cell / 2, row * cell + cell / 2);
        c.scale(k);
        final t = stops[col];
        final life = 2.4 + t * 3;
        if (t == 0) {
          paintSealedCache(c, Offset.zero, e, life);
        } else {
          paintCacheUnseal(c, Offset.zero, e, life, t);
        }
        c.restore();
      }
    }
    for (var col = 0; col < stops.length; col++) {
      label(
        't ${stops[col]}',
        Colors.white54,
        10,
        1,
      ).paint(c, Offset(110 + col * cell + 6, 4));
    }
    await save(rec.endRecording(), strip, '$out/strip.png');

    // Space: all 17 open together over the game's three seconds, with half
    // a second sealed before and after.
    const fps = 30;
    const lead = 0.5;
    const openS = ElementalCache.openDuration;
    final spaceFrames = ((lead + openS + 0.5) * fps).round();
    for (var f = 0; f < spaceFrames; f++) {
      final s = f / fps;
      final t = s < lead ? null : ((s - lead) / openS);
      await save(
        spaceSheet(
          unit: 0.72,
          life: (i) => 2.4 + i * 0.37 + s,
          // After the ritual the cache is gone; a t of 1 paints nothing.
          t: t?.clamp(0.0, 1.0),
        ),
        const Size(330 * 0.72 * 3, 330 * 0.72 * 6),
        '$out/space/${f.toString().padLeft(3, '0')}.png',
      );
    }
  });
}
