@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/enemy_body_art.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Every ship hull with its wake and orbital sentinels, beside the enemies it
// fights: zoomed for detail, then at the size a phone draws it (the open
// world's default zoom, 0.72, on a 3x screen), flying a turn so the wake
// curves, and boosting.
//
//   SHIP_OUT=/tmp/ships flutter test \
//     test/ship_look_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SHIP_OUT'];

  setUpAll(() async {
    final file = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (!file.existsSync()) return;
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  });

  const skins = <(String?, String)>[
    (null, 'Standard'),
    ('skin_phantom', 'Phantom Viper'),
    ('skin_solar', 'Solar Dragoon'),
    ('skin_inferno', 'Inferno Raptor'),
    ('skin_crystal', 'Crystal Bastion'),
  ];

  /// A ship that has flown [seconds] of a steady turn and arrived at the
  /// origin heading up. [turn] is radians a second; 0 flies straight.
  ShipComponent flown(
    String? skin, {
    double turn = 0,
    double speed = 220,
    double boost = 0,
    double seconds = 1.2,
    double end = 4.0,
  }) {
    final ship = ShipComponent(pos: Offset.zero);
    final scratch = Canvas(ui.PictureRecorder());
    const dt = 1 / 60;
    final steps = (seconds / dt).round();
    // Integrate backwards from the end pose to find the start, then fly it.
    var pos = Offset.zero;
    var ang = -pi / 2;
    final path = <(Offset, double)>[];
    for (var i = 0; i < steps; i++) {
      path.add((pos, ang));
      pos -= Offset(cos(ang), sin(ang)) * speed * dt;
      ang -= turn * dt;
    }
    for (var i = path.length - 1; i >= 0; i--) {
      final (p, a) = path[i];
      ship
        ..pos = p
        ..angle = a;
      ship.render(scratch, end - i * dt, skin: skin, boost: boost);
    }
    return ship;
  }

  test('ship look sheet', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    const cell = 340.0;
    const w = cell * 5;
    const h = 60 + 440 + 40 + 360 + 40 + 360 + 40 + 300.0;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
    c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );
    // A few stars, so the dark hulls are judged against space, not black.
    final r = Random(3);
    for (var i = 0; i < 260; i++) {
      c.drawCircle(
        Offset(r.nextDouble() * w, r.nextDouble() * h),
        r.nextDouble() * 1.1 + 0.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15 + r.nextDouble() * 0.4),
      );
    }

    void label(String s, Offset at, {double size = 13}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: const Color(0xFFE8DCC0),
            fontSize: size,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, at);
    }

    void drones(String? skin, double t) {
      for (var i = 0; i < 3; i++) {
        final a = t * 2.5 + i * 2 * pi / 3;
        paintOrbitalSentinel(
          c,
          Offset(cos(a), sin(a)) * 50,
          shipLight(skin),
          time: t,
          seed: i * 1.7,
          radius: OrbitalSentinel.hitboxRadius * 0.6,
        );
      }
    }

    // Row 1: detail, cruising straight, with sentinels.
    var top = 60.0;
    label(
      'HULLS — 3 px/unit, cruising, with orbital sentinels',
      const Offset(12, 14),
      size: 16,
    );
    for (var i = 0; i < skins.length; i++) {
      final (id, name) = skins[i];
      label(name, Offset(cell * i + 12, top + 6), size: 12);
      final ship = flown(id);
      c.save();
      c.clipRect(Rect.fromLTWH(cell * i, top, cell, 440));
      c.translate(cell * i + cell / 2, top + 190);
      c.scale(3.0);
      drones(id, 4.0);
      ship.render(c, 4.0, skin: id);
      c.restore();
    }

    // Row 2: phone size, turning.
    top += 440 + 40;
    label(
      'PHONE SIZE (zoom 0.72 × 3x screen ≈ 2.2 px/unit) — turning',
      Offset(12, top - 26),
      size: 13,
    );
    for (var i = 0; i < skins.length; i++) {
      final (id, _) = skins[i];
      final ship = flown(id, turn: 1.6);
      c.save();
      c.clipRect(Rect.fromLTWH(cell * i, top, cell, 360));
      c.translate(cell * i + cell / 2 + 20, top + 120);
      c.scale(2.16);
      drones(id, 4.0);
      ship.render(c, 4.0, skin: id);
      c.restore();
    }

    // Row 3: phone size, boosting straight.
    top += 360 + 40;
    label('PHONE SIZE — boosting', Offset(12, top - 26), size: 13);
    for (var i = 0; i < skins.length; i++) {
      final (id, _) = skins[i];
      final ship = flown(id, speed: 550, boost: 1);
      c.save();
      c.clipRect(Rect.fromLTWH(cell * i, top, cell, 360));
      c.translate(cell * i + cell / 2, top + 70);
      c.scale(2.16);
      ship.render(c, 4.0, skin: id, boost: 1);
      c.restore();
    }

    // Row 4: the enemies, at the same phone scale.
    top += 360 + 40;
    label('ENEMIES at the same phone scale', Offset(12, top - 26), size: 13);
    final bodies = <(String, double, void Function(EnemyPalette))>[
      (
        'sentinel',
        32,
        (p) => paintSentinelBody(c, p, time: 0.6, seed: 1.3, heading: 0.4),
      ),
      (
        'drone',
        22,
        (p) => paintDroneBody(c, p, time: 0.6, seed: 0.7, heading: -1.2),
      ),
      (
        'wisp',
        15,
        (p) => paintWispBody(c, p, time: 0.6, seed: 0.7, heading: 2.2),
      ),
      (
        'colossus',
        60,
        (p) => paintColossusBody(c, p, time: 0.6, seed: 0.4, turn: 0.2),
      ),
      (
        'sentinel (Water)',
        32,
        (p) => paintSentinelBody(c, p, time: 1.1, seed: 2.1, heading: 2.0),
      ),
    ];
    const elems = ['Fire', 'Lightning', 'Air', 'Dark', 'Water'];
    for (var i = 0; i < bodies.length; i++) {
      final (name, radius, draw) = bodies[i];
      label(name, Offset(cell * i + 12, top), size: 11);
      c.save();
      c.clipRect(Rect.fromLTWH(cell * i, top, cell, 300));
      c.translate(cell * i + cell / 2, top + 150);
      c.scale(2.16 * radius);
      draw(enemyPalette(elems[i]));
      c.restore();
    }

    final pic = rec.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/ship_look.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
