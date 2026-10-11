// The Mystic cast overlay (MysticGraphxOverlay) is a Flutter layer over the
// survival game, so the ability audit's sheets cannot show it.
//
// 1. Its ticker runs only while a cast is playing. It used to keep the
//    full-screen layer repainting every frame of the whole run.
// 2. A preview sheet of every element's cast, written only when asked:
//      MYSTIC_OVERLAY_OUT=/path/to/dir flutter test test/mystic_graphx_overlay_test.dart
//    The seal is the ringed octagram {8/3} in grains (never a hexagram),
//    every element's form is filled material and grains (no stroked rings,
//    spokes or zig-zags), and nothing flashes white. The grain sprite is
//    awaited first, so the sheet shows grains, not the fallback discs.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ability_grains.dart';
import 'package:alchemons/games/cosmic_survival/components/mystic_graphx_overlay.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _cell = 200.0;
const _caster = Offset(72, 122);
const _target = Offset(150, 64);

const _elements = [
  'Fire',
  'Lava',
  'Lightning',
  'Water',
  'Ice',
  'Steam',
  'Earth',
  'Mud',
  'Dust',
  'Crystal',
  'Air',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

/// Frames after the cast at which the sheet is photographed (60 fps):
/// the gather, the form, its height, its release and how it goes out.
const _moments = [3, 9, 18, 30, 48];

Widget _host(MysticGraphxOverlayController controller, Key key) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: _cell,
            height: _cell,
            child: ColoredBox(
              color: const Color(0xFF07080B),
              child: MysticGraphxOverlay(controller: controller),
            ),
          ),
        ),
      ),
    );

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUpAll(() async {
    // The grain sprite is built off the frame; without it every grain is
    // drawn as the fallback hard disc and the sheet lies about the look.
    await AbilityGrainSprite.ensureLoaded();
  });

  testWidgets('the overlay only ticks while a cast is playing', (tester) async {
    final controller = MysticGraphxOverlayController();
    await tester.pumpWidget(_host(controller, GlobalKey()));
    await _frames(tester, 3);
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: 'an empty overlay kept ticking',
    );

    controller.spawn(
      const MysticSpecialCastEvent(
        originScreen: _caster,
        targetScreen: _target,
        element: 'Steam',
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.binding.transientCallbackCount,
      greaterThan(0),
      reason: 'a cast did not wake the overlay',
    );

    // Steam is the longest cast (its last puff ends ~1.3 s in).
    await _frames(tester, 120);
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: 'the overlay kept ticking after the cast ended',
    );

    // And it wakes again for the next one.
    controller.spawn(
      const MysticSpecialCastEvent(originScreen: _caster, element: 'Light'),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await _frames(tester, 120);
    expect(tester.binding.transientCallbackCount, 0);
    controller.dispose();
  });

  testWidgets('preview sheet', (tester) async {
    final out = Platform.environment['MYSTIC_OVERLAY_OUT'];
    final controller = MysticGraphxOverlayController();
    final key = GlobalKey();
    await tester.pumpWidget(_host(controller, key));
    await _frames(tester, 2);

    final cells = <List<ui.Image>>[];
    for (final element in _elements) {
      final row = <ui.Image>[];
      for (final moment in _moments) {
        controller.clear();
        await _frames(tester, 2);
        controller.spawn(
          MysticSpecialCastEvent(
            originScreen: _caster,
            targetScreen: _target,
            element: element,
          ),
        );
        await _frames(tester, moment);
        if (out == null) continue;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await tester.runAsync(() => boundary.toImage());
        row.add(image!);
      }
      cells.add(row);
    }
    controller.clear();
    await _frames(tester, 2);
    if (out == null) return;

    await tester.runAsync(() async {
      final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
      if (font.existsSync()) {
        await (FontLoader('OverlaySans')..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
      const label = 96.0, head = 40.0, gap = 4.0;
      final w = label + _moments.length * (_cell + gap);
      final h = head + _elements.length * (_cell + gap);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF15161A),
      );
      void text(String s, Offset at, double size) {
        final tp = TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontFamily: 'OverlaySans',
              fontSize: size,
              color: const Color(0xFFCDB98A),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, at);
      }

      text(
        'Mystic cast overlay (screen px, cast at the left, target up-right)',
        const Offset(8, 6),
        13,
      );
      for (var m = 0; m < _moments.length; m++) {
        text(
          't + ${(_moments[m] * 16 / 1000).toStringAsFixed(2)} s',
          Offset(label + m * (_cell + gap) + 4, 24),
          11,
        );
      }
      for (var r = 0; r < cells.length; r++) {
        final y = head + r * (_cell + gap);
        text(_elements[r], Offset(8, y + 8), 13);
        for (var m = 0; m < cells[r].length; m++) {
          c.drawImage(
            cells[r][m],
            Offset(label + m * (_cell + gap), y),
            Paint(),
          );
        }
      }
      final pic = rec.endRecording();
      final sheet = await pic.toImage(w.round(), h.round());
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File('$out/mystic_cast_overlay.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
      for (final row in cells) {
        for (final img in row) {
          img.dispose();
        }
      }
    });
    controller.dispose();
  });
}
