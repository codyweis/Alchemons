@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/codex_stage.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The Codex's element orbs and its stage, as stills: every orb at rest
// (stage size and table size), each element's form coming out of its orb,
// and a formula playing from its two makers to what they make.
//
//   CODEX_OUT=/tmp/codex flutter test test/codex_stage_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['CODEX_OUT'];
  const glass = Color(0xFF0B0A10);

  Future<void> save(ui.Image image, String name) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  }

  test('orbs at rest', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const cell = 150.0, small = 60.0;
    final els = EssenceElement.values;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const w = cell * 6, h = cell * 3 + small * 3 + 20;
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = glass);
    for (var i = 0; i < els.length; i++) {
      final orb = ElementOrb(els[i], radius: 57);
      orb.paint(
        canvas,
        Offset((i % 6 + 0.5) * cell, (i ~/ 6 + 0.5) * cell),
        1.3,
      );
    }
    for (var i = 0; i < els.length + 1; i++) {
      final orb = ElementOrb(
        i < els.length ? els[i] : EssenceElement.fire,
        radius: 19,
        locked: i == els.length,
      );
      orb.paint(
        canvas,
        Offset((i % 9 + 0.5) * (w / 9), cell * 3 + 20 + (i ~/ 9 + 0.5) * small),
        1.3,
      );
    }
    final image = await rec.endRecording().toImage(w.round(), h.round());
    await save(image, 'orbs');
  });

  test('each element out of its orb', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const cell = 170.0;
    const times = [0.0, 0.45, 0.9, 1.35, 1.9, 2.3];
    final els = EssenceElement.values;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final w = cell * times.length, h = cell * els.length;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = glass);
    for (var r = 0; r < els.length; r++) {
      final orb = ElementOrb(els[r], radius: 57);
      final field = EssenceField(orb.grainsAt(1.3), els[r]);
      for (var k = 0; k < times.length; k++) {
        final c = Offset((k + 0.5) * cell, (r + 0.5) * cell);
        final t = times[k];
        orb.paint(
          canvas,
          c,
          1.3,
          opacity: t == 0 ? 1 : EssenceField.spriteOpacity(t),
          grains: t == 0,
        );
        if (t > 0) field.paint(canvas, c, t);
      }
    }
    final image = await rec.endRecording().toImage(w.round(), h.round());
    await save(image, 'essence');
  });

  testWidgets('a formula playing', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(360, 230);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = CodexStageController();
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(
            color: glass,
            child: CodexStage(controller: controller),
          ),
        ),
      ),
    );
    const r = 57.0;
    controller.show(OrbBody('Ice', radius: r));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    controller.combine(
      OrbBody('Air', radius: r),
      OrbBody('Water', radius: r),
      OrbBody('Ice', radius: r),
    );
    final shots = <ui.Image>[];
    var t = 0.0;
    const at = [0.05, 0.3, 0.6, 1.0, 1.4, 1.8, 2.1, 2.4, 2.8, 3.2, 3.6, 4.2];
    for (final when in at) {
      while (t < when) {
        await tester.pump(const Duration(milliseconds: 16));
        t += 0.016;
      }
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        shots.add(await b.toImage());
      });
    }
    await tester.runAsync(() async {
      const cols = 4;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < shots.length; i++) {
        canvas.drawImage(
          shots[i],
          Offset((i % cols) * 360.0, (i ~/ cols) * 230.0),
          Paint(),
        );
      }
      final image = await rec.endRecording().toImage(
        360 * cols,
        230 * ((shots.length + cols - 1) ~/ cols),
      );
      await save(image, 'formula');
      for (final s in shots) {
        s.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox());
  });
}
