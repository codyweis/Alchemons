@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Home's three right-side emblems (UPGRADE, RELICS, RITE) as icons, and
// each one's way in, frame by frame, at phone size.
//
//   EMBLEM_OUT=/tmp/emblems flutter test \
//     test/home_emblems_preview_test.dart --tags preview
//
// EMBLEM_PAGES=dir with altar.png / constellation.png / rite.png lays a
// screenshot of the destination under the landing frames (the passage puts
// the page between its ground and its grains); without it, a flat stand-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['EMBLEM_OUT'];
  final pages = Platform.environment['EMBLEM_PAGES'];

  Future<void> save(ui.Picture picture, int w, int h, String name) async {
    final image = await picture.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  }

  Future<ui.Image?> page(String name) async {
    if (pages == null) return null;
    final file = File('$pages/$name.png');
    if (!file.existsSync()) return null;
    final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }

  test('icons', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // Big: each at four moments, 3x, on home's ink.
    const cell = 80.0, scale = 3.0;
    const times = [0.0, 0.9, 1.8, 2.7];
    final w = (cell * times.length * scale).round();
    final h = (cell * 3 * scale).round();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF09090B),
      )
      ..scale(scale);
    for (final (row, kind) in HomeEmblemKind.values.indexed) {
      for (final (col, t) in times.indexed) {
        canvas.save();
        canvas.translate(col * cell, row * cell);
        paintEmblem(
          canvas,
          kind,
          EmblemStage(
            box: const Offset(0, 0) & const Size.square(cell),
            screen: const Size.square(cell),
            time: 5 + t,
          ),
        );
        canvas.restore();
      }
    }
    await save(rec.endRecording(), w, h, 'icons_big');

    // As home shows them: the right-side column at phone scale, labelled.
    const colW = 110.0, colH = 330.0, px = 3.0;
    final rec2 = ui.PictureRecorder();
    final c2 = Canvas(rec2)
      ..drawRect(
        Rect.fromLTWH(0, 0, colW * px, colH * px),
        Paint()..color = const Color(0xFF0C0C0F),
      )
      ..scale(px);
    const labels = ['UPGRADE', 'RELICS', 'RITE'];
    for (final (i, kind) in HomeEmblemKind.values.indexed) {
      final top = 10 + i * 104.0;
      c2.save();
      c2.translate((colW - 80) / 2, top);
      paintEmblem(
        c2,
        kind,
        EmblemStage(
          box: Offset.zero & const Size.square(80),
          screen: const Size.square(80),
          time: 7.3,
        ),
      );
      c2.restore();
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFFE6E2DA),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c2, Offset((colW - tp.width) / 2, top + 80));
    }
    await save(
      rec2.endRecording(),
      (colW * px).round(),
      (colH * px).round(),
      'icons_column',
    );
  });

  test('passages', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const screen = Size(390, 844);
    const pad = EdgeInsets.only(top: 44, bottom: 30);
    const px = 1.0;
    // Where the column stands on home: right edge, under the title.
    const boxes = {
      HomeEmblemKind.constellation: Rect.fromLTWH(298, 248, 80, 80),
      HomeEmblemKind.altar: Rect.fromLTWH(298, 354, 80, 80),
      HomeEmblemKind.rite: Rect.fromLTWH(304, 456, 68, 68),
    };
    const pageNames = {
      HomeEmblemKind.constellation: 'constellation',
      HomeEmblemKind.altar: 'altar',
      HomeEmblemKind.rite: 'rite',
    };
    // (open, land) through the way in, and back out.
    const frames = [
      (0.0, 0.0, false),
      (0.15, 0.0, false),
      (0.3, 0.0, false),
      (0.45, 0.0, false),
      (0.6, 0.0, false),
      (0.75, 0.0, false),
      (1.0, 0.0, false),
      (1.0, 0.25, false),
      (1.0, 0.5, false),
      (1.0, 0.75, false),
      (1.0, 1.0, false),
      (0.5, 0.0, true),
    ];
    for (final kind in HomeEmblemKind.values) {
      final dest = await page(pageNames[kind]!);
      final cols = 6;
      final rows = (frames.length / cols).ceil();
      final w = screen.width * cols * px, h = screen.height * rows * px;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec)..scale(px);
      for (final (i, (open, land, closing)) in frames.indexed) {
        canvas.save();
        canvas.translate(
          (i % cols) * screen.width,
          (i ~/ cols) * screen.height,
        );
        canvas.clipRect(Offset.zero & screen);
        // A stand-in for home: its ink and a faint realm.
        canvas.drawRect(
          Offset.zero & screen,
          Paint()
            ..shader = ui.Gradient.radial(const Offset(195, 420), 460, const [
              Color(0xFF2A2430),
              Color(0xFF0C0C0F),
            ]),
        );
        // The rest of the column, as home has it.
        for (final other in HomeEmblemKind.values) {
          if (other == kind) continue;
          paintEmblem(
            canvas,
            other,
            EmblemStage(box: boxes[other]!, screen: screen, time: 4),
          );
        }
        final stage = EmblemStage(
          box: boxes[kind]!,
          screen: screen,
          pad: pad,
          time: 4 + i * 0.08,
          open: open,
          land: land,
          closing: closing,
        );
        paintEmblem(canvas, kind, stage, layer: EmblemLayer.back);
        if (land > 0) {
          final p = Paint()..color = Color.fromRGBO(255, 255, 255, land);
          if (dest != null) {
            canvas.drawImageRect(
              dest,
              Offset.zero & Size(dest.width.toDouble(), dest.height.toDouble()),
              Offset.zero & screen,
              p,
            );
          } else {
            canvas.drawRect(
              Offset.zero & screen,
              Paint()..color = const Color(0xFF101014).withValues(alpha: land),
            );
          }
        }
        paintEmblem(canvas, kind, stage, layer: EmblemLayer.front);
        final tp = TextPainter(
          text: TextSpan(
            text:
                '${closing ? 'back ' : ''}open ${open.toStringAsFixed(2)}'
                '  land ${land.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFFFF66CC), fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(8, 8));
        canvas.restore();
      }
      await save(
        rec.endRecording(),
        w.round(),
        h.round(),
        'passage_${kind.name}',
      );
    }
  });

  // Going back, as the route plays it: the page sinks (route value 1 down
  // to the split), then the scene gathers home.
  test('backs', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const screen = Size(390, 844);
    const pad = EdgeInsets.only(top: 44, bottom: 30);
    const boxes = {
      HomeEmblemKind.constellation: Rect.fromLTWH(298, 248, 80, 80),
      HomeEmblemKind.altar: Rect.fromLTWH(298, 354, 80, 80),
      HomeEmblemKind.rite: Rect.fromLTWH(304, 456, 68, 68),
    };
    const split = 0.42;
    const values = [
      1.0,
      0.8,
      0.6,
      0.45,
      0.38,
      0.32,
      0.26,
      0.2,
      0.14,
      0.09,
      0.05,
      0.0,
    ];
    for (final kind in HomeEmblemKind.values) {
      final dest = await page(kind.name);
      const cols = 6;
      final rows = (values.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (final (i, v) in values.indexed) {
        final open = (v / split).clamp(0.0, 1.0);
        final land = ((v - split) / (1 - split)).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(
          (i % cols) * screen.width,
          (i ~/ cols) * screen.height,
        );
        canvas.clipRect(Offset.zero & screen);
        canvas.drawRect(
          Offset.zero & screen,
          Paint()
            ..shader = ui.Gradient.radial(const Offset(195, 420), 460, const [
              Color(0xFF2A2430),
              Color(0xFF0C0C0F),
            ]),
        );
        for (final other in HomeEmblemKind.values) {
          if (other == kind) continue;
          paintEmblem(
            canvas,
            other,
            EmblemStage(box: boxes[other]!, screen: screen, time: 4),
          );
        }
        final stage = EmblemStage(
          box: boxes[kind]!,
          screen: screen,
          pad: pad,
          time: 4 + i * 0.07,
          open: open,
          land: land,
          closing: true,
        );
        paintEmblem(canvas, kind, stage, layer: EmblemLayer.back);
        if (land > 0 && dest != null) {
          canvas.drawImageRect(
            dest,
            Offset.zero & Size(dest.width.toDouble(), dest.height.toDouble()),
            Offset.zero & screen,
            Paint()..color = Color.fromRGBO(255, 255, 255, land),
          );
        }
        paintEmblem(canvas, kind, stage, layer: EmblemLayer.front);
        final tp = TextPainter(
          text: TextSpan(
            text: 'back v ${v.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFFFF66CC), fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(8, 8));
        canvas.restore();
      }
      await save(
        rec.endRecording(),
        (screen.width * cols).round(),
        (screen.height * rows).round(),
        'back_${kind.name}',
      );
    }
  });

  // The real route over a stand-in home, frame by frame: the page laid
  // between the scene's ground and its grains, held until ready.
  testWidgets('route frames', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 44 * 2, bottom: 30 * 2);
    addTearDown(tester.view.reset);
    final shot = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    final keys = {for (final k in HomeEmblemKind.values) k: GlobalKey()};
    final lifted = {
      for (final k in HomeEmblemKind.values) k: ValueNotifier(false),
    };
    const tops = {
      HomeEmblemKind.constellation: 248.0,
      HomeEmblemKind.altar: 354.0,
      HomeEmblemKind.rite: 456.0,
    };
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: MaterialApp(
          navigatorKey: nav,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF0C0C0F),
            body: Stack(
              children: [
                for (final k in HomeEmblemKind.values)
                  Positioned(
                    right: 12,
                    top: tops[k],
                    child: HomeEmblem(
                      key: keys[k],
                      kind: k,
                      size: k == HomeEmblemKind.rite ? 68 : 80,
                      lifted: lifted[k],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    Future<void> grab(String name) => tester.runAsync(() async {
      final boundary =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    for (final kind in HomeEmblemKind.values) {
      final ready = ValueNotifier(false);
      // Decoded for real: an Image.file never loads under the test clock.
      final picture = await tester.runAsync(() => page(kind.name));
      final Widget shown = picture != null
          ? RawImage(image: picture, fit: BoxFit.cover)
          : const ColoredBox(color: Color(0xFF101014));
      EmblemPassage.push<void>(
        nav.currentContext!,
        kind: kind,
        from: keys[kind]!,
        page: SizedBox.expand(child: shown),
        ready: ready,
        lifted: lifted[kind],
      );
      for (var f = 0; f < 6; f++) {
        await tester.pump(const Duration(milliseconds: 220));
        await grab('route_${kind.name}_in_$f');
      }
      // Let the picture decode, then say ready.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      ready.value = true;
      await tester.pump();
      for (var f = 0; f < 3; f++) {
        await tester.pump(const Duration(milliseconds: 300));
        await grab('route_${kind.name}_land_$f');
      }
      await tester.pump(const Duration(milliseconds: 1200));
      nav.currentState!.pop();
      await tester.pump();
      for (var f = 0; f < 3; f++) {
        await tester.pump(const Duration(milliseconds: 260));
        await grab('route_${kind.name}_back_$f');
      }
      await tester.pump(const Duration(milliseconds: 1200));
    }
  });
}
