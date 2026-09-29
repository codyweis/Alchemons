@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the enemy look for judging: the roster across elements, a strip
/// through time, a horde field at phone scale (live bodies and the atlas),
/// and the bosses.
///
///   ENEMY_LOOK_OUT=dir flutter test test/enemy_look_preview_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['ENEMY_LOOK_OUT'];

  CosmicSurvivalEnemy make(
    EnemyTier tier,
    String element, {
    double? radius,
    double angle = -0.5,
    EnemyConduct conduct = EnemyConduct.charge,
    EnemyTrait? trait,
    bool elite = false,
    EliteAffix? affix,
  }) => CosmicSurvivalEnemy(
    position: Offset.zero,
    hp: 100,
    maxHp: 100,
    speed: 60,
    damage: 10,
    radius: radius ?? tierRadius(tier),
    tier: tier,
    element: element,
    conduct: conduct,
    trait: trait,
    target: CosmicEnemyTarget.orb,
    isElite: elite,
    eliteAffix: affix,
  )..angle = angle;

  Future<void> save(
    WidgetTester tester,
    String name,
    ui.Picture pic,
    int w,
    int h,
  ) async {
    await tester.runAsync(() async {
      final img = await pic.toImage(w, h);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir!).createSync(recursive: true);
      File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  void space(Canvas c, double w, double h, {int seed = 3}) {
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );
    final rng = Random(seed);
    final star = Paint();
    for (var i = 0; i < (w * h / 2500).round(); i++) {
      star.color = Colors.white.withValues(
        alpha: 0.15 + rng.nextDouble() * 0.45,
      );
      c.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h),
        0.4 + rng.nextDouble() * 0.9,
        star,
      );
    }
  }

  const elements = [
    'Fire',
    'Water',
    'Plant',
    'Dark',
    'Lightning',
    'Crystal',
    'Spirit',
    'Mud',
  ];

  // Roughly how big each tier is on the phone, times two for inspection.
  double inspect(EnemyTier t) => switch (t) {
    EnemyTier.wisp => 14,
    EnemyTier.drone => 17,
    EnemyTier.sentinel => 20,
    EnemyTier.phantom => 19,
    EnemyTier.brute => 25,
    EnemyTier.colossus => 30,
  };

  testWidgets('roster across elements', (tester) async {
    const cell = 150.0;
    final w = cell * elements.length;
    final h = cell * EnemyTier.values.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, w, h);
    for (var row = 0; row < EnemyTier.values.length; row++) {
      final tier = EnemyTier.values[row];
      for (var col = 0; col < elements.length; col++) {
        final e = make(tier, elements[col], radius: inspect(tier))
          ..position = Offset(col * cell + cell / 2, row * cell + cell / 2);
        drawSurvivalEnemy(canvas: c, enemy: e, time: 0.8 + col * 0.13);
      }
    }
    await save(tester, 'roster', rec.endRecording(), w.round(), h.round());
  }, skip: outDir == null);

  testWidgets('through time', (tester) async {
    const cell = 150.0;
    const times = [0.0, 0.3, 0.6, 0.9, 1.2, 1.5];
    final w = cell * times.length;
    final h = cell * EnemyTier.values.length * 2;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, w, h);
    var row = 0;
    for (final element in ['Fire', 'Spirit']) {
      for (final tier in EnemyTier.values) {
        for (var col = 0; col < times.length; col++) {
          final e = make(tier, element, radius: inspect(tier))
            ..position = Offset(col * cell + cell / 2, row * cell + cell / 2);
          if (kEnemyActions.containsKey(tier)) {
            // Walk every body that has one through its attack.
            final phase = [
              EnemyActionPhase.idle,
              EnemyActionPhase.windUp,
              EnemyActionPhase.windUp,
              EnemyActionPhase.commit,
              EnemyActionPhase.recover,
              EnemyActionPhase.idle,
            ][col];
            final def = kEnemyActions[tier]!;
            e.action.phase = phase;
            e.action.timer = switch (phase) {
              EnemyActionPhase.windUp => def.windUp * (col == 1 ? 0.8 : 0.1),
              EnemyActionPhase.commit => def.commit * 0.5,
              EnemyActionPhase.recover => def.recover * 0.5,
              _ => 0,
            };
            e.action.aimAngle = -0.5;
          }
          drawSurvivalEnemy(canvas: c, enemy: e, time: times[col]);
        }
        row++;
      }
    }
    await save(tester, 'through_time', rec.endRecording(), w.round(), h.round());
  }, skip: outDir == null);

  /// A phone-sized frame of survival: zoom 0.595 at DPR ~2.6.
  Future<void> field(
    WidgetTester tester,
    String name, {
    required bool atlas,
    required int wisps,
    required int drones,
    required int sentinels,
    required int phantoms,
    int brutes = 3,
    int colossi = 1,
    List<String> mix = const ['Fire', 'Poison', 'Ice'],
  }) async {
    const w = 1080.0, h = 1400.0;
    const scale = 0.595 * 2.6;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, w, h, seed: 9);
    c.save();
    c.translate(w / 2, h / 2);
    c.scale(scale);
    final rng = Random(5);
    final centre = Offset.zero;
    final bodies = <CosmicSurvivalEnemy>[];
    void scatter(EnemyTier tier, int n, double minD, double maxD) {
      for (var i = 0; i < n; i++) {
        final a = rng.nextDouble() * 2 * pi;
        final d = minD + rng.nextDouble() * (maxD - minD);
        final p = centre + Offset(cos(a), sin(a)) * d;
        // Heading in toward the centre, with some scatter.
        final heading = atan2(-p.dy, -p.dx) + (rng.nextDouble() - 0.5) * 0.5;
        bodies.add(
          make(tier, mix[rng.nextInt(mix.length)], angle: heading)
            ..position = p,
        );
      }
    }

    scatter(EnemyTier.wisp, wisps, 60, 520);
    scatter(EnemyTier.drone, drones, 80, 500);
    scatter(EnemyTier.sentinel, sentinels, 160, 420);
    scatter(EnemyTier.phantom, phantoms, 120, 420);
    scatter(EnemyTier.brute, brutes, 150, 360);
    scatter(EnemyTier.colossus, colossi, 220, 300);

    final batch = SurvivalSwarmBatch();
    for (final b in bodies) {
      if (atlas && batch.add(b, 1.3, dense: true)) continue;
      drawSurvivalEnemy(canvas: c, enemy: b, time: 1.3);
    }
    if (atlas) {
      await tester.runAsync(() async {
        batch.flush(c, 1.3);
      });
    }
    c.restore();
    await save(tester, name, rec.endRecording(), w.round(), h.round());
  }

  testWidgets('field, live bodies', (tester) async {
    await field(
      tester,
      'field_live',
      atlas: false,
      wisps: 120,
      drones: 50,
      sentinels: 8,
      phantoms: 6,
    );
  }, skip: outDir == null);

  testWidgets('field, horde atlas', (tester) async {
    await field(
      tester,
      'field_horde_atlas',
      atlas: true,
      wisps: 900,
      drones: 300,
      sentinels: 30,
      phantoms: 20,
      brutes: 6,
      colossi: 2,
      mix: const ['Fire', 'Dark', 'Lightning'],
    );
  }, skip: outDir == null);

  testWidgets('bosses', (tester) async {
    const cell = 300.0;
    const elements = ['Fire', 'Water', 'Crystal', 'Dark'];
    final cells = <void Function(Canvas, Offset, double)>[];
    for (final type in BossType.values) {
      for (final element in elements) {
        cells.add((c, at, t) {
          final b = CosmicBoss(
            position: at,
            name: type.name,
            element: element,
            level: 3,
            radius: 40,
            maxHealth: 1000,
            speed: 60,
            forcedType: type,
          )..angle = -0.4;
          drawOpenWorldBoss(canvas: c, boss: b, time: t);
        });
      }
    }
    // States: charging, shielded, enraged, and a survival boss.
    cells
      ..add((c, at, t) {
        final b = CosmicBoss(
          position: at,
          name: 'charging',
          element: 'Lava',
          level: 3,
          radius: 40,
          maxHealth: 1000,
          speed: 60,
          forcedType: BossType.charger,
          charging: true,
        )..angle = 0.3;
        drawOpenWorldBoss(canvas: c, boss: b, time: t);
      })
      ..add((c, at, t) {
        final b = CosmicBoss(
          position: at,
          name: 'shielded',
          element: 'Ice',
          level: 3,
          radius: 40,
          maxHealth: 1000,
          speed: 60,
          forcedType: BossType.bulwark,
          shieldUp: true,
          shieldHealth: 1e9,
        );
        drawOpenWorldBoss(canvas: c, boss: b, time: t);
      })
      ..add((c, at, t) {
        final b = CosmicBoss(
          position: at,
          name: 'enraged',
          element: 'Plant',
          level: 3,
          radius: 40,
          maxHealth: 1000,
          speed: 60,
          forcedType: BossType.warden,
        )..enraged = true;
        drawOpenWorldBoss(canvas: c, boss: b, time: t);
      })
      ..add((c, at, t) {
        final template = kBossTemplates.first;
        drawSurvivalBoss(
          canvas: c,
          boss: SurvivalBoss(
            template: template,
            type: BossType.carrier,
            discipline: SurvivalBossDiscipline.conductor,
            level: 5,
            position: at,
            hp: 800,
            maxHp: 1000,
            speed: 70,
            baseSpeed: 70,
            radius: 40,
            color: elementColor(template.element),
          ),
          time: t,
        );
      });
    const cols = 4;
    final w = cell * cols;
    final h = cell * (cells.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, w, h, seed: 11);
    for (var i = 0; i < cells.length; i++) {
      final at = Offset(
        (i % cols) * cell + cell / 2,
        (i ~/ cols) * cell + cell / 2 + 20,
      );
      c.save();
      c.clipRect(Rect.fromCenter(center: at, width: cell, height: cell));
      cells[i](c, at, 0.7 + i * 0.37);
      c.restore();
    }
    await save(tester, 'bosses', rec.endRecording(), w.round(), h.round());
  }, skip: outDir == null);
}
