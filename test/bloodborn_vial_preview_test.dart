@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/bloodborn_vial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// THE BLOODBORN VIAL, painted straight from its field: a sheet of chambers
// at stages of the brew (VIAL_OUT/sheet.png), and the rise the extraction
// plays, as frames and rise.mp4 when ffmpeg is on the path.
//
//   VIAL_OUT=/tmp/vial flutter test test/bloodborn_vial_preview_test.dart \
//     --tags preview
//
// VIAL_SPECIES=HOR03 picks the Alchemon.
void main() {
  testWidgets('bloodborn vial preview', (tester) async {
    final out = Platform.environment['VIAL_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final id = Platform.environment['VIAL_SPECIES'] ?? 'HOR03';
    final creatures =
        (jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['creatures']
            as List;
    final image =
        (creatures.cast<Map<String, dynamic>>().firstWhere(
              (c) => c['id'] == id,
            )['image']
            as String);

    await tester.runAsync(() async {
      Future<void> png(ui.Image img, String name) async {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
        img.dispose();
      }

      // The chamber's budget, and a big one for the stage.
      final small = BloodbornVialField(
        (await BloodbornVialGrains.read(image, maxGrains: 420))!,
        pool: 220,
      );
      final big = BloodbornVialField(
        (await BloodbornVialGrains.read(image, height: 260, maxGrains: 1400))!,
        pool: 700,
      );

      // The sheet: five chambers, then the same big.
      const stages = [
        (0.0, 0.0, 'pool'),
        (0.3, 0.0, '30%'),
        (0.55, 0.0, '55%'),
        (0.85, 0.0, '85%'),
        (1.0, 1.0, 'ready'),
      ];
      const cell = 170.0, bigCell = 340.0;
      final w = cell * stages.length, h = cell + bigCell;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec)
        ..drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF0B0B0D),
        );
      for (var k = 0; k < stages.length; k++) {
        final (p, ready, _) = stages[k];
        final c = Offset(cell * k + cell / 2, cell / 2);
        final r = cell * 0.44;
        canvas
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)))
          ..drawCircle(c, r, Paint()..color = const Color(0xFF000000));
        small.paintVessel(
          canvas,
          c,
          r * 0.98,
          progress: p,
          ready: ready,
          time: 3.05,
        );
        canvas.restore();
      }
      for (var k = 0; k < 2; k++) {
        final c = Offset(
          w / 2 + (k == 0 ? -bigCell * 0.55 : bigCell * 0.55),
          cell + bigCell / 2,
        );
        final r = bigCell * 0.46;
        canvas
          ..save()
          ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)))
          ..drawCircle(c, r, Paint()..color = const Color(0xFF000000));
        big.paintVessel(
          canvas,
          c,
          r * 0.98,
          progress: k == 0 ? 0.55 : 1,
          ready: k == 0 ? 0 : 1,
          time: k == 0 ? 2.0 : 3.05,
        );
        canvas.restore();
      }
      await png(
        await rec.endRecording().toImage(w.round(), h.round()),
        'sheet.png',
      );

      // The rise on an open floor, as the extraction plays it.
      const fw = 412.0, fh = 412.0, fps = 24;
      final dir = Directory('$out/rise')..createSync(recursive: true);
      for (final f in dir.listSync()) {
        f.deleteSync();
      }
      for (var i = 0; i < fps * 6; i++) {
        final t = i / fps;
        final p = ((t - 0.6) / 2.6).clamp(0.0, 1.0);
        final ready = ((t - 3.4) / 1.0).clamp(0.0, 1.0);
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec)
          ..drawRect(
            const Rect.fromLTWH(0, 0, fw, fh),
            Paint()..color = const Color(0xFF000000),
          );
        big.paintOpen(
          canvas,
          const Offset(fw / 2, fh * 0.8),
          fh * 0.6,
          progress: p,
          ready: ready,
          time: t,
        );
        await png(
          await rec.endRecording().toImage(fw.round(), fh.round()),
          'rise/f_${i.toString().padLeft(4, '0')}.png',
        );
      }
      try {
        await Process.run('ffmpeg', [
          '-y',
          '-framerate',
          '$fps',
          '-i',
          '${dir.path}/f_%04d.png',
          '-pix_fmt',
          'yuv420p',
          '-vf',
          'scale=trunc(iw/2)*2:trunc(ih/2)*2',
          '$out/rise.mp4',
        ]);
      } catch (_) {}
    });
  });
}
