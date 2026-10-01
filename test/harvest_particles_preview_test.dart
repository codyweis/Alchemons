@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_particles.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The harvest in particles, per harvester: the field closing, biting and
// held against, then a take and a break — with a real sprite standing in it.
//
//   HARVEST_OUT=/tmp/harvest.png flutter test \
//     test/harvest_particles_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['HARVEST_OUT'];

  testWidgets('harvest particles preview', (tester) async {
    if (out == null) return;
    const box = 208.0, ratio = 2.6, cage = 126.0;
    const stage = Size(420, 420);
    const c = Offset(210, 210);
    late ui.Image sprite;
    late SpecimenGrains grains;
    await tester.runAsync(() async {
      final data = await rootBundle.load(
        'assets/images/creatures/rare/HOR01_firehorn_spritesheet.png',
      );
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final sheet = (await codec.getNextFrame()).image;
      final f = sheet.height.toDouble();
      final px = (box * ratio).round();
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(
        sheet,
        Rect.fromLTWH(0, 0, f, f),
        Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      sprite = rec.endRecording().toImageSync(px, px);
      final bytes = await sprite.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      grains = SpecimenGrains.fromRgba(
        bytes!.buffer.asUint8List(),
        px,
        px,
        pixelRatio: ratio,
      );
    });

    const minSeize = 1.6;
    double norm(double t, double a, double b) =>
        ((t - a) / (b - a)).clamp(0.0, 1.0);

    ui.Image shoot(
      HarvestParticleField f, {
      required double t,
      double take = 0,
      double shatter = 0,
    }) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Offset.zero & stage,
        Paint()..color = const Color(0xFF13101C),
      );
      final pressure = norm(t, minSeize * 0.55, minSeize);
      final strain = (t / 0.9) % 1.0;
      final resolving = take > 0 || shatter > 0;
      final push = resolving
          ? 1 - norm(take + shatter, 0, 0.22)
          : pressure * (0.5 - 0.5 * math.cos(strain * 6.2832));
      void layer(bool back) => f.paint(
        canvas,
        c,
        closing: norm(t / minSeize, 0.02, 0.42),
        lock: norm(t / minSeize, 0.38, 0.55),
        push: push,
        strain: strain,
        time: t,
        take: take,
        shatter: shatter,
        back: back,
      );
      layer(true);
      // The sprite, cut away behind the take's crest.
      final cut = f.cutY(take);
      if (cut != double.infinity) {
        canvas.save();
        if (cut.isFinite) {
          canvas.clipRect(
            Rect.fromLTRB(0, c.dy + cut, stage.width, stage.height),
          );
        }
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(
            0,
            0,
            sprite.width.toDouble(),
            sprite.height.toDouble(),
          ),
          Rect.fromCenter(center: c, width: box, height: box),
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
      layer(false);
      return rec.endRecording().toImageSync(
        stage.width.toInt(),
        stage.height.toInt(),
      );
    }

    final rows = <(String, List<ui.Image>)>[];
    for (final biome in [
      'volcanic',
      'oceanic',
      'earthen',
      'verdant',
      'arcane',
      'universal',
    ]) {
      final f = HarvestParticleField(
        profile: HarvesterProfile.forBiome(biome),
        cage: cage,
        specimenColor: const Color(0xFFFF6B3D),
      )..setSpecimen(grains, at: Offset.zero);
      rows.add((
        biome,
        [
          shoot(f, t: 0.25),
          shoot(f, t: 0.7),
          shoot(f, t: 1.4),
          shoot(f, t: 1.8, take: 0.15),
          shoot(f, t: 1.8, take: 0.35),
          shoot(f, t: 1.8, take: 0.55),
          shoot(f, t: 1.8, take: 0.75),
          shoot(f, t: 1.8, take: 0.9),
          shoot(f, t: 1.8, shatter: 0.2),
          shoot(f, t: 1.8, shatter: 0.5),
        ],
      ));
    }

    await tester.runAsync(() async {
      const s = 0.5;
      final w = stage.width * s, h = stage.height * s;
      final cols = rows.first.$2.length;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var r = 0; r < rows.length; r++) {
        for (var k = 0; k < cols; k++) {
          canvas.drawImageRect(
            rows[r].$2[k],
            Offset.zero & stage,
            Rect.fromLTWH(k * (w + 4), r * (h + 4), w, h),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + 4)).round(),
        (rows.length * (h + 4)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
