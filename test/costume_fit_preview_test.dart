@Tags(['preview'])
library;

// Every species of a family wearing its costume, frame by frame, close on
// the head — for checking fits by eye:
//
//   COSTUME_FIT=HOR COSTUME=hat COSTUME_FIT_OUT=/tmp/fit.png \
//     flutter test test/costume_fit_preview_test.dart
//
// COSTUME is a costume's tag (hat, nose, sunglasses), or leave it out for
// all of them at once.
//
// COSTUME_FIT_ZOOM (default 2) is how much closer than the whole frame;
// COSTUME_FIT_COLORS (RRGGBB,RRGGBB,…) dresses each species in the next one.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('costume fit preview', () async {
    final family = Platform.environment['COSTUME_FIT'];
    final out = Platform.environment['COSTUME_FIT_OUT'];
    if (family == null || out == null) return;
    final zoom = double.parse(Platform.environment['COSTUME_FIT_ZOOM'] ?? '2');
    final time = double.parse(Platform.environment['COSTUME_FIT_T'] ?? '1.7');
    final colors = [
      for (final hex
          in (Platform.environment['COSTUME_FIT_COLORS'] ?? '').split(','))
        if (hex.isNotEmpty) Color(0xFF000000 | int.parse(hex, radix: 16)),
    ];
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final entries = (data['creatures'] as List).cast<Map<String, dynamic>>();
    final only = FamilyCostume.ofTag(Platform.environment['COSTUME']);
    final costumes = only == null ? FamilyCostume.values : [only];
    final species = {
      for (final c in costumes)
        ...c.placements.keys.where((k) => k.startsWith(family)),
    }.toList()..sort();
    const cell = 200.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final width = cell * 4 * 2, height = cell * ((species.length + 1) ~/ 2);
    c.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF182030),
    );
    for (var i = 0; i < species.length; i++) {
      final id = species[i];
      final e = entries.singleWhere((x) => x['id'] == id);
      final sd = e['spriteData'] as Map<String, dynamic>;
      final frames = (sd['totalFrames'] as num).toInt();
      final rows = (sd['rows'] as num?)?.toInt() ?? 1;
      final cols = (frames + rows - 1) ~/ rows;
      final codec = await ui.instantiateImageCodec(
        File(
          'assets/images/${(e['image'] as String).replaceAll('.png', '_spritesheet.png')}',
        ).readAsBytesSync(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final fw = image.width / cols, fh = image.height / rows;
      final fit0 = costumes
          .map((c) => c.fitAt(id, 0))
          .firstWhere((f) => f != null)!;
      for (var f = 0; f < 4 && f < frames; f++) {
        final ox = ((i % 2) * 4 + f) * cell, oy = (i ~/ 2) * cell;
        c.save();
        c.clipRect(Rect.fromLTWH(ox, oy, cell, cell));
        // The whole frame, drawn [zoom] times the cell, the frame-0 fit in
        // the middle.
        final size = cell * zoom;
        final frame = Rect.fromLTWH(
          ox + cell / 2 - fit0.x * size,
          oy + cell / 2 - fit0.y * size,
          size,
          size,
        );
        c.drawImageRect(
          image,
          Rect.fromLTWH((f % cols) * fw, (f ~/ cols) * fh, fw, fh),
          frame,
          Paint()..filterQuality = FilterQuality.medium,
        );
        var worn = WornCostumes(id, const {});
        for (final costume in costumes) {
          if (!costume.fits(id)) continue;
          worn = worn.wear(
            costume,
            color: colors.isEmpty ? null : colors[i % colors.length],
          );
        }
        CostumePaint.paintWorn(c, worn.encode(), frame, f, time);
        c.restore();
      }
      final tp = TextPainter(
        text: TextSpan(
          text: id,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((i % 2) * 4 * cell + 4, (i ~/ 2) * cell + 4));
      tp.dispose();
      image.dispose();
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(width.toInt(), height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
    pic.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
