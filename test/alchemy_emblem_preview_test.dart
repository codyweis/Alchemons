@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/alchemy_emblem.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ALCHEMY's home emblem: the icon locked at a few points of progress and
// open, then its way in over a 390×844 phone, frame by frame — ending on the
// title where the level select draws it.
//
//   ALCHEMY_OUT=/tmp/alchemy flutter test \
//     test/alchemy_emblem_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['ALCHEMY_OUT'];

  testWidgets('alchemy emblem sheet', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      await (FontLoader('Roboto')
            ..addFont(Future.value(ByteData.view(File('/System/Library/Fonts/Supplemental/Arial Bold.ttf').readAsBytesSync().buffer))))
          .load();
      await alchemyTitleWord();
    });
    Future<void> save(String name, ui.Image image) async {
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // Icons: locked at 0, 40%, 90%, then open at three moments.
    const icon = 120.0;
    final cells = [(false, 0.0, 1.0), (false, .4, 2.0), (false, .9, 3.0), (true, 1.0, 1.0), (true, 1.0, 4.0), (true, 1.0, 9.0)];
    var rec = ui.PictureRecorder();
    var c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, icon * cells.length, icon), Paint()..color = const Color(0xFF0B0B10));
    for (var i = 0; i < cells.length; i++) {
      final (open, p, t) = cells[i];
      c.save();
      c.translate(i * icon, 0);
      paintAlchemyEmblem(
        c,
        EmblemStage(box: const Rect.fromLTWH(0, 0, icon, icon), screen: const Size(icon, icon), time: t),
        open: open,
        progress: p,
      );
      c.restore();
    }
    await save('icons', rec.endRecording().toImageSync((icon * cells.length).toInt(), icon.toInt()));

    // The way in: the icon under the hero of a 390×844 phone, growing.
    const screen = Size(390, 844);
    const pad = EdgeInsets.only(top: 44);
    const box = Rect.fromLTWH(153, 500, 84, 84);
    final frames = [0.0, .25, .5, .7, .85, 1.0];
    rec = ui.PictureRecorder();
    c = Canvas(rec);
    for (var i = 0; i < frames.length; i++) {
      c.save();
      c.translate(i * screen.width, 0);
      c.clipRect(Offset.zero & screen);
      c.drawRect(Offset.zero & screen, Paint()..color = const Color(0xFF1A2230));
      paintAlchemyEmblem(
        c,
        EmblemStage(box: box, screen: screen, pad: pad, time: 2 + frames[i] * 1.25, open: frames[i]),
      );
      c.restore();
    }
    await save('passage', rec.endRecording().toImageSync((screen.width * frames.length).toInt(), screen.height.toInt()));
  });
}
