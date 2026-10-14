@Tags(['preview'])
library;

// Real sheets through the real variant bake: each species in its own colors
// and as a variant of every faction with a palette, frame 0, as one PNG.
//
//   VARIANT_PREVIEW=/tmp/variants.png flutter test test/variant_look_preview_test.dart
//   VARIANT_SPECIES=LET01,PIP12 VARIANT_PREVIEW=… flutter test …

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/albino_look.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/variant_look.dart';
import 'package:flutter_test/flutter_test.dart';

const _cell = 160;

void main() {
  test('variant preview', () async {
    final out = Platform.environment['VARIANT_PREVIEW'];
    if (out == null) return;
    final ids =
        (Platform.environment['VARIANT_SPECIES'] ??
                'LET01,LET02,PIP12,PIP06,HOR12,HOR15,WNG04,WNG17')
            .split(',');
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final entries = (data['creatures'] as List).cast<Map<String, dynamic>>();
    final looks = [
      for (final f in kVariantPalette.keys) MutationLook.variant(f)!,
    ];
    final w = _cell * (looks.length + 1), h = _cell * ids.length;
    final page = Uint8List(w * h * 4);
    for (var o = 0; o < page.length; o += 4) {
      page[o] = 14;
      page[o + 1] = 13;
      page[o + 2] = 17;
      page[o + 3] = 255;
    }
    for (var row = 0; row < ids.length; row++) {
      final e = entries.singleWhere((x) => x['id'] == ids[row]);
      final sd = e['spriteData'] as Map<String, dynamic>;
      final path = (e['image'] as String).replaceAll(
        '.png',
        '_spritesheet.png',
      );
      final frames = (sd['totalFrames'] as num).toInt();
      final rows = (sd['rows'] as num?)?.toInt() ?? 1;
      final cols = (frames + rows - 1) ~/ rows;
      final (fw, fh) = bakedFrameSize(
        (sd['frameWidth'] as num).toDouble(),
        (sd['frameHeight'] as num).toDouble(),
      );
      final sw = fw * cols, sh = fh * rows;
      final rgba = await _read('assets/images/$path', sw, sh);
      final eyesPath = albinoEyesPath(path);
      final eyes = eyesPath == null
          ? null
          : await _read('assets/images/$eyesPath', sw, sh);
      // Its own colors, premultiplied as the bakes come out.
      final own = Uint8List.fromList(rgba);
      for (var o = 0; o < own.length; o += 4) {
        for (var k = 0; k < 3; k++) {
          own[o + k] = (own[o + k] * own[o + 3] / 255).round();
        }
      }
      final cells = [
        own,
        for (final look in looks)
          bakeMutation(
            MutationBakeJob(
              rgba: rgba,
              width: sw,
              height: sh,
              frameW: fw,
              frameH: fh,
              cols: cols,
              frames: frames,
              look: look,
              eyes: eyes,
            ),
          ),
      ];
      for (var c = 0; c < cells.length; c++) {
        _blit(page, w, cells[c], sw, fw, fh, c * _cell, row * _cell);
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      page,
      w,
      h,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    final image = await done.future;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(png!.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'variants: $out (${ids.join(' ')}; own, ${kVariantPalette.keys.join(', ')})',
    );
  });
}

/// Straight RGBA of the image at [path], [w]×[h].
Future<Uint8List> _read(String path, int w, int h) async {
  final codec = await ui.instantiateImageCodec(
    File(path).readAsBytesSync(),
    targetWidth: w,
    targetHeight: h,
  );
  final image = (await codec.getNextFrame()).image;
  final bytes = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  codec.dispose();
  return Uint8List.fromList(bytes!.buffer.asUint8List());
}

/// Frame 0 of a premultiplied sheet [sw] wide, shrunk into the cell at
/// ([x0], [y0]) over the page's ink.
void _blit(
  Uint8List page,
  int pageW,
  Uint8List sheet,
  int sw,
  int fw,
  int fh,
  int x0,
  int y0,
) {
  const pad = 6, inner = _cell - pad * 2;
  for (var y = 0; y < inner; y++) {
    for (var x = 0; x < inner; x++) {
      final sx = (x + 0.5) * fw ~/ inner, sy = (y + 0.5) * fh ~/ inner;
      final o = (sy * sw + sx) * 4;
      final a = sheet[o + 3] / 255.0;
      if (a == 0) continue;
      final d = ((y0 + pad + y) * pageW + x0 + pad + x) * 4;
      for (var k = 0; k < 3; k++) {
        page[d + k] = (page[d + k] * (1 - a) + sheet[o + k]).round().clamp(
          0,
          255,
        );
      }
    }
  }
}
