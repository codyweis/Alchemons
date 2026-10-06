@Tags(['preview'])
library;

// Follows a costume's fitted place through every frame of a species' sheet,
// and prints the per-frame table for its `frameFits` (costume_fits.dart):
//
//   COSTUME=hat COSTUME_TRACK=WNG01,PIP01 flutter test test/costume_anchor_track_test.dart
//
// COSTUME is a costume's tag (hat, nose, sunglasses). Only frame 0 is
// fitted by hand (its `placements`). The rest are
// found by matching a patch of the creature next to that place — the face
// under a hat, the snout round a nose, the eyes behind sunglasses — in each
// later frame, so the costume rides on what it sits on and not on what
// sways near it (a Firewing's flames, a wing). A patch that a species animates can be moved with
// `_patchOverrides`.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/celebration_costume.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frames are matched at this fraction of the sheet's resolution.
const _down = 3;

/// The matched patch for a species' hat, if its default would catch
/// something that moves on its own: (centre dx, dy from the fitted place,
/// half width, half height), all as fractions of the frame.
const _hatPatchOverrides = <String, (double, double, double, double)>{
  // Earthwing's rocks repeat: the brows and eyes don't.
  'WNG03': (-0.045, 0.12, 0.07, 0.04),
  // Mudwing's and Dustwing's wings spread in behind the head in frame 3.
  'WNG08': (-0.01, 0.10, 0.05, 0.04),
  'WNG10': (0.01, 0.07, 0.06, 0.05),
};

void main() {
  test('track costume anchors', () async {
    final only = Platform.environment['COSTUME_TRACK'];
    if (only == null) return;
    final costume = FamilyCostume.ofTag(Platform.environment['COSTUME'])!;
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final entries = (data['creatures'] as List).cast<Map<String, dynamic>>();
    final out = StringBuffer();
    for (final id in only.split(',')) {
      final fit = costume.placements[id]!;
      final e = entries.singleWhere((x) => x['id'] == id);
      final sd = e['spriteData'] as Map<String, dynamic>;
      final frames = await _frames(
        'assets/images/${(e['image'] as String).replaceAll('.png', '_spritesheet.png')}',
        (sd['frameWidth'] as num).toInt() ~/ _down,
        (sd['frameHeight'] as num).toInt() ~/ _down,
        (sd['totalFrames'] as num).toInt(),
        (sd['rows'] as num?)?.toInt() ?? 1,
      );
      // The face under a hat, as big as the head the hat was sized to; the
      // snout round a nose; the eyes and brows behind sunglasses.
      final patch =
          (costume == FamilyCostume.partyHat ? _hatPatchOverrides[id] : null) ??
          switch (costume) {
            FamilyCostume.partyHat => (
              fit.$3 * 0.09,
              fit.$3 * 0.4,
              fit.$3 * 0.48,
              fit.$3 * 0.33,
            ),
            FamilyCostume.nose => (0.06, 0.0, 0.08, 0.06),
            FamilyCostume.sunglasses => (0.0, 0.0, fit.$3 * 0.95, fit.$3 * 0.5),
          };
      final row = <String>[];
      for (final f in frames) {
        // The fitted place, carried with the patch. Moves only: the frames
        // are drawn by hand, and a turn search reads their small redrawing
        // as the head tipping. A tilt can still be set in the table.
        // Frame 0 is the fit itself, not a match of it.
        final (dx, dy) = identical(f, frames.first)
            ? (0.0, 0.0)
            : _match(frames.first, f, fit, patch);
        row.add(
          '(${(fit.$1 + dx).toStringAsFixed(3)}, '
          '${(fit.$2 + dy).toStringAsFixed(3)}, 0.0)',
        );
      }
      out.writeln("    '$id': [${row.join(', ')}],");
      // ignore: avoid_print
      print('tracked $id');
    }
    // ignore: avoid_print
    print('\n$out');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

class _Frame {
  _Frame(this.w, this.h, this.px);
  final int w, h;

  /// Premultiplied r, g, b, a in 0..1, row by row.
  final Float32List px;

  /// Nearest sample at ([x], [y]) in frame fractions; clear outside.
  int at(double x, double y) {
    final i = (x * w).floor(), j = (y * h).floor();
    if (i < 0 || j < 0 || i >= w || j >= h) return -1;
    return (j * w + i) * 4;
  }
}

Future<List<_Frame>> _frames(
  String path,
  int w,
  int h,
  int count,
  int rows,
) async {
  final cols = (count + rows - 1) ~/ rows;
  final codec = await ui.instantiateImageCodec(
    File(path).readAsBytesSync(),
    targetWidth: w * cols,
    targetHeight: h * rows,
  );
  final image = (await codec.getNextFrame()).image;
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final sheetW = image.width;
  image.dispose();
  codec.dispose();
  return [
    for (var f = 0; f < count; f++)
      () {
        final ox = (f % cols) * w, oy = (f ~/ cols) * h;
        final px = Float32List(w * h * 4);
        for (var j = 0; j < h; j++) {
          for (var i = 0; i < w; i++) {
            final s = ((oy + j) * sheetW + ox + i) * 4, d = (j * w + i) * 4;
            for (var k = 0; k < 4; k++) {
              px[d + k] = bytes[s + k] / 255;
            }
          }
        }
        return _Frame(w, h, px);
      }(),
  ];
}

/// How far the patch beside [fit] has moved from [ref] to [frame]: the
/// least squared difference over moves of up to 6% of the frame, refined to
/// a fraction of a pixel.
(double, double) _match(
  _Frame ref,
  _Frame frame,
  (double, double, double) fit,
  (double, double, double, double) patch,
) {
  final cx = fit.$1 + patch.$1, cy = fit.$2 + patch.$2;
  final step = 1 / ref.w;
  final samples = <(double, double, int)>[];
  for (var v = -patch.$4; v <= patch.$4; v += step) {
    for (var u = -patch.$3; u <= patch.$3; u += step) {
      final i = ref.at(cx + u, cy + v);
      if (i >= 0) samples.add((u, v, i));
    }
  }
  double cost(double dx, double dy) {
    var sum = 0.0;
    for (final (u, v, i) in samples) {
      final j = frame.at(cx + dx + u, cy + dy + v);
      for (var k = 0; k < 4; k++) {
        final d = ref.px[i + k] - (j < 0 ? 0 : frame.px[j + k]);
        sum += d * d;
      }
    }
    return sum;
  }

  var best = (0.0, 0.0);
  var least = double.infinity;
  const reach = 0.06;
  for (var dy = -reach; dy <= reach; dy += step) {
    for (var dx = -reach; dx <= reach; dx += step) {
      final e = cost(dx, dy);
      if (e < least) {
        least = e;
        best = (dx, dy);
      }
    }
  }
  // A parabola through each axis for the sub-pixel move.
  double refine(double m, double z, double p) {
    final den = m - 2 * z + p;
    return den <= 0 ? 0 : (0.5 * (m - p) / den).clamp(-0.5, 0.5);
  }

  final (dx, dy) = best;
  final fx = refine(cost(dx - step, dy), least, cost(dx + step, dy));
  final fy = refine(cost(dx, dy - step), least, cost(dx, dy + step));
  return (dx + fx * step, dy + fy * step);
}
