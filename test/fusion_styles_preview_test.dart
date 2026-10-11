@Tags(['preview'])
library;

// The fusion styles (the Athanor's), each as a strip of twelve moments from
// the pair standing to the cultivation at rest — the merge (the breed tab's,
// the space ram's, the wild's) and then the cinematic — beside the plain
// fusion, for two pairs:
//
//   FUSION_STYLES_OUT=docs/athanor/content/fusion flutter test -j 1 \
//     test/fusion_styles_preview_test.dart --tags preview
//
// writes <pair>_<style>.png, and prints what a frame of each costs.
// FUSION_STYLES_ONLY=ink,frost picks styles (plain is "plain").

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

final String? out = Platform.environment['FUSION_STYLES_OUT'];
final Set<String>? only = Platform.environment['FUSION_STYLES_ONLY']
    ?.split(',')
    .toSet();

final Map<String, Map<String, dynamic>> _rows = {};

Future<ui.Image> _still(String id, double side) async {
  final codec = await ui.instantiateImageCodec(
    File('assets/images/${_rows[id]!['image']}').readAsBytesSync(),
    targetWidth: side.round(),
  );
  final img = (await codec.getNextFrame()).image;
  codec.dispose();
  return img;
}

Future<SpecimenGrains> _grains(ui.Image img, double side) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return SpecimenGrains.fromRgba(
    data!.buffer.asUint8List(),
    img.width,
    img.height,
    pixelRatio: img.width / side,
  );
}

const _tints = {
  'Fire': Color(0xFFFF7A1A),
  'Water': Color(0xFF2E8BD0),
  'Earth': Color(0xFFB07A44),
  'Air': Color(0xFF8FE0CC),
  'Ice': Color(0xFF8FC4FF),
  'Plant': Color(0xFF5FC46B),
  'Light': Color(0xFFFFE08A),
  'Dark': Color(0xFF5A3A96),
  'Crystal': Color(0xFF8A68FF),
  'Lightning': Color(0xFFFFE45C),
};

Color _light(String id) {
  final t = (_rows[id]!['types'] as List).cast<String>();
  return _tints[t.isEmpty ? '' : t.first] ?? const Color(0xFFE0CDA6);
}

void _text(Canvas c, String s, Offset at, {double size = 12, Color? color}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        color: color ?? const Color(0xFFCDB07A),
        letterSpacing: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
  tp.dispose();
}

void _pool(Canvas c, Offset at, double r, Color col, double a) {
  if (a <= 0) return;
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        at,
        r,
        [
          col.withValues(alpha: a),
          col.withValues(alpha: a * 0.3),
          col.withValues(alpha: 0),
        ],
        const [0.0, 0.45, 1.0],
      ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fusion styles, as strips', () async {
    if (out == null) return;
    Directory(out!).createSync(recursive: true);
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final e in (data['creatures'] as List).cast<Map<String, dynamic>>()) {
      _rows[e['id'] as String] = e;
    }
    final f = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (f.existsSync()) {
      await (FontLoader('Roboto')
            ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer))))
          .load();
    }

    const cw = 340.0, ch = 250.0, box = 108.0;
    const pairs = [
      ('horn_let', 'HOR01', 'LET02'),
      ('kin_wing', 'KIN16', 'WNG09'),
    ];
    // Twelve moments: the pair standing, the merge, then the cinematic.
    const merge = [0.0, 0.62, 1.0, 1.35, 1.7, 2.05, 2.4];
    const cinematic = [0.35, 0.8, 1.3, 1.9, 3.0];
    final styles = <FusionStyle?>[null, ...FusionStyle.values];

    for (final (name, ida, idb) in pairs) {
      final sa = await _still(ida, box * 2), sb = await _still(idb, box * 2);
      final ga = await _grains(sa, box), gb0 = await _grains(sb, box);
      // The second faces the first.
      final gb = gb0.mirrored();
      final ca = _light(ida), cb = _light(idb);
      for (final style in styles) {
        if (only != null && !only!.contains(style?.id ?? 'plain')) continue;
        const across = 6;
        final rows = ((merge.length + cinematic.length) / across).ceil();
        final size = Size(cw * across, ch * rows + 28);
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF040406),
        );
        _text(
          c,
          '${style?.title ?? 'Plain fusion'}  ·  ${_rows[ida]!['name']} + '
          '${_rows[idb]!['name']}  ·  the merge, then the cinematic',
          const Offset(10, 7),
          size: 13,
        );
        final moments = [
          for (final t in merge) (true, t),
          for (final u in cinematic) (false, u),
        ];
        for (var k = 0; k < moments.length; k++) {
          final (isMerge, t) = moments[k];
          final at = Offset((k % across) * cw, 28 + (k ~/ across) * ch);
          c.save();
          c.translate(at.dx, at.dy);
          c.clipRect(const Rect.fromLTWH(1, 1, cw - 2, ch - 2));
          c.drawRect(
            const Rect.fromLTWH(0, 0, cw, ch),
            Paint()..color = const Color(0xFF0B0A10),
          );
          const centres = [
            Offset(cw * 0.22, ch * 0.56),
            Offset(cw * 0.78, ch * 0.56),
          ];
          const core = Offset(cw / 2, ch * 0.5);
          if (isMerge) {
            final field = FusionParticleField(
              specimens: [ga, gb],
              centres: centres,
              scales: const [1, 1],
              core: core,
              coreRadius: 44,
              colors: [ca, cb],
              style: style,
              useWornStyle: false,
            );
            if (t == 0) {
              // Standing, before anything: the sprites themselves.
              for (var s = 0; s < 2; s++) {
                final img = s == 0 ? sa : sb;
                c.save();
                c.translate(centres[s].dx, centres[s].dy);
                if (s == 1) c.scale(-1, 1);
                c.drawImageRect(
                  img,
                  Rect.fromLTWH(
                    0,
                    0,
                    img.width.toDouble(),
                    img.height.toDouble(),
                  ),
                  const Rect.fromLTWH(-box / 2, -box / 2, box, box),
                  Paint()..filterQuality = FilterQuality.medium,
                );
                c.restore();
              }
            } else {
              field.paint(c, t, back: true, clock: t);
              field.paint(c, t, back: false, clock: t);
            }
          } else {
            final burst = FusionBurstField(
              grains: [ga, gb],
              radius: 62,
              style: style,
              useWornStyle: false,
            );
            final light = burst.styleLight ?? const Color(0xFFFFFFFF);
            final mix = Color.lerp(ca, cb, 0.5)!;
            // The cinematic's own light under it, as it tints it.
            final heat = (t / FusionBurstField.burstAt).clamp(0.0, 1.0);
            if (t < FusionBurstField.burstAt + 0.2) {
              _pool(
                c,
                core,
                62 * (0.35 + 0.45 * heat),
                Color.lerp(light, mix, 0.3)!,
                (0.25 + 0.5 * heat) * burst.styleFlare * 0.6,
              );
            }
            final formed = ((t - 0.7) / 1.3).clamp(0.0, 1.0);
            _pool(c, core, 62 * 1.7, mix, 0.3 * formed);
            burst.paint(c, core, t, colors: [ca, cb], clock: t);
          }
          c.restore();
          _text(
            c,
            isMerge
                ? 'merge  t ${t.toStringAsFixed(2)}'
                : 'cinematic  u ${t.toStringAsFixed(2)}',
            at + const Offset(8, 6),
            size: 10,
            color: const Color(0xFF8E8C88),
          );
        }
        final pic = rec.endRecording();
        final img = await pic.toImage(size.width.round(), size.height.round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${name}_${style?.id ?? 'plain'}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
        pic.dispose();
      }
    }

    // What a frame costs (recording only), merge then cinematic, against
    // the plain fusion.
    final sa = await _still('HOR01', box * 2),
        sb = await _still('LET02', box * 2);
    final ga = await _grains(sa, box), gb = await _grains(sb, box);
    for (final style in styles) {
      final field = FusionParticleField(
        specimens: [ga, gb],
        centres: const [Offset(70, 130), Offset(270, 130)],
        scales: const [1, 1],
        core: const Offset(170, 120),
        coreRadius: 44,
        colors: const [Color(0xFFFF7A1A), Color(0xFF2E8BD0)],
        style: style,
        useWornStyle: false,
      );
      final burst = FusionBurstField(
        grains: [ga, gb],
        radius: 62,
        style: style,
        useWornStyle: false,
      );
      double cost(void Function(Canvas c, double t) paint, List<double> ts) {
        final sw = Stopwatch();
        var n = 0;
        for (var rep = 0; rep < 3; rep++) {
          for (final t in ts) {
            final r = ui.PictureRecorder();
            if (rep > 0) sw.start();
            paint(Canvas(r), t);
            if (rep > 0) {
              sw.stop();
              n++;
            }
            r.endRecording().dispose();
          }
        }
        return sw.elapsedMicroseconds / n;
      }

      final ts = [for (var t = 0.7; t < 2.55; t += 0.05) t];
      final us = [for (var u = 0.0; u < 3.0; u += 0.05) u];
      final m = cost((c, t) {
        field.paint(c, t, back: true, clock: t);
        field.paint(c, t, back: false, clock: t);
      }, ts);
      final b = cost(
        (c, u) => burst.paint(
          c,
          const Offset(170, 120),
          u,
          colors: const [Color(0xFFFF7A1A), Color(0xFF2E8BD0)],
          clock: u,
        ),
        us,
      );
      // ignore: avoid_print
      print(
        '${style?.id ?? 'plain'}: merge ${m.toStringAsFixed(0)} µs, '
        'cinematic ${b.toStringAsFixed(0)} µs a frame',
      );
    }
  });
}
