@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// How the planets look in open space, as pictures to judge.
//
//   PLANET_OUT=/tmp/planets flutter test \
//     test/planet_look_preview_test.dart --tags preview
//
// Writes, for PLANET_ELEMENT (default Lava; `all` writes one scene per
// planet and the sheet):
//   scene_<el>_t<N>.png   — the planet at the default zoom on a landscape
//                           phone, with the star field and territory wash,
//                           at a few moments so animation can be judged
//   close_<el>.png        — the closest zoom
//   backdrop_<el>.png     — the encounter-backdrop render (scaled UP, so it
//                           is where a weak surface shows first)
// and sheet_all.png — every planet side by side at in-game scale.
void main() {
  final outDir = Platform.environment['PLANET_OUT'];
  final element = Platform.environment['PLANET_ELEMENT'] ?? 'Lava';

  const w = 915.0, h = 412.0, dpr = 2.0;
  const zoomMid = 0.72, zoomClose = 0.85;

  Future<void> save(ui.Image image, String name) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  void paintSpace(Canvas canvas, Rect view, int seed) {
    canvas.drawRect(view, Paint()..color = const Color(0xFF020010));
    final rng = Random(seed);
    final star = Paint();
    final count = (view.width * view.height / 5200).round();
    for (var i = 0; i < count; i++) {
      star.color = Colors.white.withValues(
        alpha: 0.15 + rng.nextDouble() * 0.55,
      );
      canvas.drawCircle(
        Offset(
          view.left + rng.nextDouble() * view.width,
          view.top + rng.nextDouble() * view.height,
        ),
        0.5 + rng.nextDouble() * 1.1,
        star,
      );
    }
  }

  ui.Image scene(
    String el, {
    required double zoom,
    required double t,
    Offset shipOffset = const Offset(-260, 60),
  }) {
    final planet = CosmicPlanet(
      element: el,
      position: const Offset(5000, 5000),
      radius: kPlanetRadius[el]!,
      discovered: true,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    // Camera: the planet sits right of centre, the way it does when you
    // fly toward it.
    final viewW = w / zoom, viewH = h / zoom;
    final centre = planet.position + shipOffset;
    final cam = Offset(centre.dx - viewW / 2, centre.dy - viewH / 2);
    canvas.scale(zoom);
    canvas.translate(-cam.dx, -cam.dy);
    final view = Rect.fromLTWH(cam.dx, cam.dy, viewW, viewH);
    paintSpace(canvas, view, 7);
    // As CosmicGameWild._renderTerritories does, the view being well inside.
    paintTerritoryWash(canvas, planet, planet.position);
    planetArtFor(planet).paintTerritory(canvas, planet.position, view, 1.0, t);
    PlanetComponent(planet: planet).render(canvas, t);
    final pic = recorder.endRecording();
    final img = pic.toImageSync((w * dpr).round(), (h * dpr).round());
    pic.dispose();
    return img;
  }

  testWidgets('planet look previews', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    final tag = element.toLowerCase();

    Future<void> single() async {
      for (final t in [0.0, 3.0, 9.0]) {
        await save(
          scene(element, zoom: zoomMid, t: t),
          'scene_${tag}_t${t.round()}',
        );
      }
      await save(
        scene(
          element,
          zoom: zoomClose,
          t: 5,
          shipOffset: const Offset(-120, 20),
        ),
        'close_$tag',
      );

      final planet = CosmicPlanet(
        element: element,
        position: const Offset(5000, 5000),
        radius: kPlanetRadius[element]!,
        discovered: true,
      );
      // PLANET_WAKE="dx,dy" (planet radii from centre) renders the close-up
      // again with the ship there, to judge matter parting round it.
      final wakeSpec = Platform.environment['PLANET_WAKE'];
      if (wakeSpec != null) {
        final parts = wakeSpec.split(',').map(double.parse).toList();
        final art = planetArtFor(planet);
        art.wake = planet.position +
            Offset(parts[0], parts[1]) * kPlanetRadius[element]!;
        await save(
          scene(element, zoom: zoomClose, t: 5,
              shipOffset: const Offset(-120, 20)),
          'close_${tag}_wake',
        );
        art.wake = null;
      }

      // The backdrop is transparent round the planet; judge it over space.
      final backdrop = renderPlanetBackdropImage(planet, elapsed: 5);
      final bs = backdrop.width.toDouble();
      final brec = ui.PictureRecorder();
      final bc = Canvas(brec);
      paintSpace(bc, Rect.fromLTWH(0, 0, bs, bs), 11);
      bc.drawImage(backdrop, Offset.zero, Paint());
      final bpic = brec.endRecording();
      await save(
        bpic.toImageSync(bs.round(), bs.round()),
        'backdrop_$tag',
      );

      // A strip of moments, planet only, for judging motion: the plumes,
      // the surges, the turn. PLANET_STRIP="t0,t1,…" overrides the times.
      final times = (Platform.environment['PLANET_STRIP'] ??
              '0.5,1.0,1.5,2.0,2.5,3.0,6.5,7.0,7.5,8.0,8.5,9.0')
          .split(',')
          .map(double.parse)
          .toList();
      {
        const cell = 340.0;
        const per = 6;
        final rowsN = (times.length / per).ceil();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        final sheet = Rect.fromLTWH(0, 0, per * cell, rowsN * cell);
        paintSpace(c, sheet, 5);
        for (var i = 0; i < times.length; i++) {
          final centre = Offset(
            (i % per) * cell + cell / 2,
            (i ~/ per) * cell + cell / 2,
          );
          final p = CosmicPlanet(
            element: element,
            position: const Offset(5000, 5000),
            radius: kPlanetRadius[element]!,
            discovered: true,
          );
          c.save();
          c.clipRect(Rect.fromCenter(center: centre, width: cell, height: cell));
          c.translate(centre.dx, centre.dy);
          c.scale(min(zoomMid, cell * 0.3 / p.radius));
          c.translate(-p.position.dx, -p.position.dy);
          PlanetComponent(planet: p).render(c, times[i], drawLabel: false);
          c.restore();
        }
        final pic = rec.endRecording();
        await save(
          pic.toImageSync(sheet.width.round(), sheet.height.round()),
          'strip_$tag',
        );
      }

    }

    await tester.runAsync(() async {
      if (element == 'all') {
        for (final el in kPlanetRadius.keys) {
          await save(
            scene(el, zoom: zoomMid, t: 6),
            'scene_${el.toLowerCase()}',
          );
        }
      } else {
        await single();
      }

      // Every planet, same in-game scale, on a grid.
      const cols = 6;
      const cell = 300.0;
      final elements = kPlanetRadius.keys.toList();
      final rows = (elements.length / cols).ceil();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final sheet = Rect.fromLTWH(0, 0, cols * cell, rows * cell);
      paintSpace(canvas, sheet, 3);
      for (var i = 0; i < elements.length; i++) {
        final el = elements[i];
        final p = CosmicPlanet(
          element: el,
          position: Offset(
            (i % cols) * cell + cell / 2,
            (i ~/ cols) * cell + cell / 2 - 10,
          ),
          radius: kPlanetRadius[el]!,
          discovered: true,
        );
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH((i % cols) * cell, (i ~/ cols) * cell, cell, cell),
        );
        // Big worlds are shrunk to fit the cell; note the scale is not the
        // in-game one for those two.
        final fit = min(1.0, (cell * 0.36) / (p.radius * zoomMid));
        canvas.translate(p.position.dx, p.position.dy);
        canvas.scale(zoomMid * fit);
        canvas.translate(-p.position.dx, -p.position.dy);
        PlanetComponent(planet: p).render(canvas, 5);
        canvas.restore();
      }
      final pic = recorder.endRecording();
      await save(
        pic.toImageSync(sheet.width.round(), sheet.height.round()),
        'sheet_all',
      );
    });
  });
}
