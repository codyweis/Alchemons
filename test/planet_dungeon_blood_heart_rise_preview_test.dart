// THE HEART'S ELEMENTS, ON ONE PLATE — every element a fusion can make,
// pouring up its column in grains (HeartRiseFx), one row each, left to right
// through its beats: coming apart, rising, at the head, washing over what
// hangs there, coming back down. Under it, the elements that hang in the
// open space (their Codex orbs) whole and being drawn in. With
// `build/room_audit` present it writes HeartRise_all.png and
// HeartMatter_all.png. A camera, not a judge.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _elements = [
  'Steam', 'Lava', 'Mud', 'Ice', 'Dust', 'Lightning', 'Poison', 'Dark', //
  'Spirit', 'Crystal', 'Light', 'Plant', 'Fire', 'Water', 'Earth', 'Air',
];

const _color = {
  'Steam': Color(0xFFC8D0D8), 'Lava': Color(0xFFE2541C), 'Mud': Color(0xFF6E5038),
  'Ice': Color(0xFF9FD8EC), 'Dust': Color(0xFFD8B98A), 'Lightning': Color(0xFFF2D65A),
  'Poison': Color(0xFF86C94A), 'Dark': Color(0xFF5A3A8A), 'Spirit': Color(0xFFD8D0FF),
  'Crystal': Color(0xFFB7A2F2), 'Light': Color(0xFFFFF0B0), 'Plant': Color(0xFF5FB04A),
  'Fire': Color(0xFFEE7A3A), 'Water': Color(0xFF4F9BD8), 'Earth': Color(0xFFA9794A),
  'Air': Color(0xFFDCEBF2),
};

Future<void> _write(ui.Image img, String name) async {
  if (!Directory('build/room_audit').existsSync()) return;
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('build/room_audit/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every element pours up its column in grains', () async {
    const cw = 110.0, chh = 300.0, reach = 224.0;
    const beats = 8;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = cw * beats, h = chh * _elements.length;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF070304));
    final batch = RiteGrainBatch();
    var drawn = 0;
    for (var r = 0; r < _elements.length; r++) {
      final el = _elements[r];
      final body = RiteBody(_color[el]!)..force(radius: 18);
      for (var k = 0; k < beats; k++) {
        final at = Offset(k * cw + cw / 2, r * chh + chh - 40);
        final fx = HeartRiseFx(body: body, el: el, at: at, reach: reach, hits: true);
        final times = [
          .12, .3, HeartRiseFx.release + fx.travel * .4, fx.hitAt, fx.hitAt + .35,
          fx.returnAt - .05, fx.returnAt + .45, fx.returnAt + .8,
        ];
        c.save();
        c.clipRect(Rect.fromLTWH(k * cw, r * chh, cw, chh));
        fx.paint(c, batch, times[k], 3.0 + times[k]);
        c.restore();
        drawn++;
        if (k == 0) {
          final tp = TextPainter(
            text: TextSpan(text: el, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset(4, r * chh + 4));
        }
      }
    }
    await _write(await rec.endRecording().toImage(w.round(), h.round()), 'HeartRise_all');
    expect(drawn, _elements.length * beats);
  });

  test('what hangs in the open space: its orb, and drawn in', () async {
    const cw = 120.0, chh = 110.0;
    const kinds = ['Spirit', 'Lava', 'Earth', 'Ice', 'Crystal', 'Light'];
    const beats = [0.0, .15, .3, .45, .6];
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = cw * (beats.length + 2), h = chh * kinds.length;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF070304));
    final batch = RiteGrainBatch();
    for (var r = 0; r < kinds.length; r++) {
      final orb = ElementOrb(EssenceElement.of(kinds[r]), radius: kHeartOrbRadius);
      expect(orb.length, greaterThan(100), reason: '${kinds[r]} is grains');
      orb.paint(c, Offset(cw / 2, r * chh + 55), 1.0);
      orb.paint(c, Offset(cw * 1.5, r * chh + 55), 2.3);
      final g = orb.grainsAt(2.3);
      for (var k = 0; k < beats.length; k++) {
        final at = Offset((k + 2.5) * cw, r * chh + 55);
        final glass = (1 - beats[k] / .3).clamp(0.0, 1.0);
        if (glass > .01) orb.paint(c, at, 2.3, grains: false, opacity: glass);
        paintHeartMeet(batch, g, at, beats[k]);
        batch.paint(c);
      }
    }
    await _write(await rec.endRecording().toImage(w.round(), h.round()), 'HeartMatter_all');
  });
}
