@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/daily_reliquary.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/nav_emblems.dart';
import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The dock's emblems: for each dock set, the dock's strip once per open tab
// (open 80, closed 55) at a phone's pixel ratio, then the same large. Then
// home's daily reliquary for each division, and Earthen's (crystal)
// unsealing. NAV_EMBLEMS_FACTIONS narrows the sets to those factions' (e.g.
// 'oceanic').
//
//   NAV_EMBLEMS_OUT=/tmp/nav.png flutter test \
//     test/nav_emblems_preview_test.dart --tags preview
//
// The large sheet lands beside it as nav_big.png, the reliquary sheet as
// nav_reliquary.png.
void main() {
  final out = Platform.environment['NAV_EMBLEMS_OUT'];

  testWidgets('nav emblem sheet', (tester) async {
    if (out == null) return;
    const dpr = 2.625;
    const kinds = NavEmblemKind.values;
    final factions = [
      for (final name in (Platform.environment['NAV_EMBLEMS_FACTIONS'] ??
              'volcanic,oceanic,earthen,verdant')
          .split(','))
        FactionId.values.byName(name.trim()),
    ];
    final sets = [for (final f in factions) ...DockSet.ofFaction(f)];
    // Every set's sheets, resolved and baked the way the dock does.
    final lets = <(DockSet, NavEmblemKind), List<NavLetSprite>>{};
    await tester.runAsync(() async {
      final raw = await rootBundle.loadString(
        'assets/data/alchemons_creatures.json',
      );
      final catalog = CreatureCatalog.fromList([
        for (final j in (jsonDecode(raw) as Map<String, dynamic>)['creatures']
            as List<dynamic>)
          Creature.fromJson(j as Map<String, dynamic>),
      ]);
      final images = Images();
      for (final f in sets) {
        for (final k in kinds) {
          lets[(f, k)] = [
            for (final sheet in navLetSheets(catalog, f, k))
              NavLetSprite(sheet, await loadCreatureSheet(images, sheet.path)),
          ];
        }
      }
    });

    NavEmblemPainter painter(DockSet f, NavEmblemKind k, {double? time}) {
      final sprites = lets[(f, k)]!;
      return NavEmblemPainter(
        kind: k,
        element: f.element,
        let: sprites.first,
        behind: sprites.skip(1).toList(),
        time: time,
      );
    }

    Future<void> save(ui.PictureRecorder rec, double w, double h, String to) async {
      final image = await tester.runAsync(
        () => rec.endRecording().toImage((w * dpr).round(), (h * dpr).round()),
      );
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      File(to).writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    // The dock, a phone wide: 60 high, 8 padding, five even slots; the open
    // icon is 80, lifted 30. For each set, one strip per open tab.
    {
      const width = 400.0, rowH = 60.0 + 64;
      final strips = [
        for (final f in sets)
          for (final open in kinds) (f, open),
      ];
      final height = rowH * strips.length + 16;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec)..scale(dpr);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF0B0B0E),
      );
      for (var row = 0; row < strips.length; row++) {
        final (f, openKind) = strips[row];
        final dockTop = 16 + row * rowH + 52;
        canvas.drawRect(
          Rect.fromLTWH(0, dockTop, width, 60),
          Paint()..color = const Color(0xFF1D1D21),
        );
        for (var i = 0; i < kinds.length; i++) {
          final open = kinds[i] == openKind;
          final size = open ? 80.0 : 55.0;
          final cx = 8 + (width - 16) / 5 * (i + 0.5);
          final cy = dockTop + 30 - (open ? 37 : 0);
          canvas.save();
          canvas.translate(cx - size / 2, cy - size / 2);
          painter(f, kinds[i]).paint(canvas, Size.square(size));
          canvas.restore();
        }
      }
      await save(rec, width, height, out);
    }

    // Large: each set's five, at rest and on a later idle frame.
    {
      const big = 160.0, gap = 12.0;
      const w = gap + (big + gap) * 5;
      final h = gap + (big + gap) * sets.length * 2;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec)..scale(dpr);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF1D1D21),
      );
      for (var row = 0; row < sets.length; row++) {
        for (var i = 0; i < kinds.length; i++) {
          for (final (j, time) in [(0, null), (1, 2.6)]) {
            canvas.save();
            canvas.translate(
              gap + (big + gap) * i,
              gap + (big + gap) * (row * 2 + j),
            );
            painter(sets[row], kinds[i], time: time)
                .paint(canvas, const Size.square(big));
            canvas.restore();
          }
        }
      }
      await save(rec, w, h, out.replaceFirst(RegExp(r'\.png$'), '_big.png'));
    }
  });

  testWidgets('daily reliquary sheet', (tester) async {
    if (out == null) return;
    const box = 160.0;
    final frames = <(String, double)>[
      for (final f in FactionId.values) (dailyCacheElementFor(f), 0),
      ('Crystal', 0.2),
      ('Crystal', 0.45),
      ('Crystal', 0.7),
      ('Crystal', 0.9),
    ];
    const cell = box * 1.6;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    const width = cell * 4;
    const height = cell * 2;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF07090C),
    );
    for (var i = 0; i < frames.length; i++) {
      final (element, t) = frames[i];
      canvas.save();
      canvas.translate(
        (i % 4) * cell + (cell - box) / 2,
        (i ~/ 4) * cell + (cell - box) / 2,
      );
      DailyReliquaryPainter(
        element: element,
        life: 2.0,
        open: t,
      ).paint(canvas, const Size.square(box));
      canvas.restore();
    }
    final image = await tester.runAsync(
      () => rec.endRecording().toImage(width.toInt(), height.toInt()),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File(
      out.replaceFirst(RegExp(r'\.png$'), '_reliquary.png'),
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
