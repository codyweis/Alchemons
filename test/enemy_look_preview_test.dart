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
    List<(EnemyTier, String, EliteAffix)> elites = const [],
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
    // Elites stand in the crowd at their 1.3x, in their own element, drawn
    // over it as the game draws them.
    final champions = <CosmicSurvivalEnemy>[];
    for (final (tier, element, affix) in elites) {
      final a = rng.nextDouble() * 2 * pi;
      final p = Offset(cos(a), sin(a)) * (160 + rng.nextDouble() * 240);
      champions.add(
        make(
          tier,
          element,
          radius: tierRadius(tier) * 1.3,
          angle: atan2(-p.dy, -p.dx),
          elite: true,
          affix: affix,
        )..position = p,
      );
    }

    if (atlas) await tester.runAsync(ensureSurvivalSwarmAtlas);
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
    for (final b in champions) {
      drawSurvivalEnemy(canvas: c, enemy: b, time: 1.3);
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

  // The elite tier: each tier an elite can be, plain first and then under
  // each affix, at 1.3x the inspection size; then the same through an
  // attack.
  testWidgets('elites', (tester) async {
    const cell = 170.0;
    const tiers = [
      (EnemyTier.sentinel, 'Water'),
      (EnemyTier.phantom, 'Spirit'),
      (EnemyTier.brute, 'Fire'),
      (EnemyTier.colossus, 'Earth'),
    ];
    const affixes = [null, ...EliteAffix.values];
    final w = cell * affixes.length;
    final h = cell * tiers.length * 2;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, w, h);
    for (var pass = 0; pass < 2; pass++) {
      for (var row = 0; row < tiers.length; row++) {
        final (tier, element) = tiers[row];
        for (var col = 0; col < affixes.length; col++) {
          final affix = affixes[col];
          final e =
              make(
                  tier,
                  element,
                  radius: inspect(tier) * (affix == null ? 1 : 1.3),
                  elite: affix != null,
                  affix: affix,
                )
                ..position = Offset(
                  col * cell + cell / 2,
                  (pass * tiers.length + row) * cell + cell / 2,
                );
          if (pass == 1 && kEnemyActions.containsKey(tier)) {
            final def = kEnemyActions[tier]!;
            e.action
              ..phase = EnemyActionPhase.windUp
              ..timer = def.windUp * 0.15
              ..aimAngle = -0.5;
          }
          drawSurvivalEnemy(canvas: c, enemy: e, time: 0.8 + col * 0.21);
        }
      }
    }
    await save(tester, 'elites', rec.endRecording(), w.round(), h.round());
  }, skip: outDir == null);

  testWidgets('field, elites in a horde', (tester) async {
    await field(
      tester,
      'field_elites',
      atlas: true,
      wisps: 600,
      drones: 220,
      sentinels: 24,
      phantoms: 16,
      brutes: 5,
      colossi: 1,
      mix: const ['Fire', 'Dark', 'Lightning'],
      elites: const [
        (EnemyTier.sentinel, 'Water', EliteAffix.bulwarked),
        (EnemyTier.sentinel, 'Plant', EliteAffix.vampiric),
        (EnemyTier.phantom, 'Spirit', EliteAffix.relentless),
        (EnemyTier.phantom, 'Ice', EliteAffix.overclocked),
        (EnemyTier.brute, 'Mud', EliteAffix.volatile),
        (EnemyTier.brute, 'Crystal', EliteAffix.bulwarked),
        (EnemyTier.colossus, 'Poison', EliteAffix.vampiric),
        (EnemyTier.sentinel, 'Fire', EliteAffix.overclocked),
      ],
    );
  }, skip: outDir == null);

  // Every type, a row each, for the labelled roster the user refers to by
  // code (docs/audits/survival_enemy_pass_2026-11-09/label_roster.py adds
  // the codes): A wisp; B, C, D the drone's forms; E sentinel; F phantom;
  // G brute; H colossus; I outbreak core; J the behaviour marks; K elites.
  // The bosses go on a sheet of their own: M and N the six forms in two
  // elements, O their states.
  testWidgets('every type', (tester) async {
    const cell = 180.0;
    const els = ['Fire', 'Water', 'Plant', 'Lightning', 'Spirit', 'Dark'];
    double size(EnemyTier t) => 1.5 * inspect(t);
    CosmicSurvivalEnemy body(
      EnemyTier tier,
      String element, {
      int form = -1,
      EnemyTrait? trait,
      bool core = false,
      EliteAffix? affix,
    }) =>
        CosmicSurvivalEnemy(
            position: Offset.zero,
            hp: 100,
            maxHp: 100,
            speed: 60,
            damage: 10,
            radius: size(tier) * (affix == null ? 1 : 1.3),
            tier: tier,
            element: element,
            conduct: EnemyConduct.charge,
            trait: trait,
            isPlagueCore: core,
            target: CosmicEnemyTarget.orb,
            isElite: affix != null,
            eliteAffix: affix,
          )
          ..angle = -0.5
          ..droneForm = form;
    final rows = <List<CosmicSurvivalEnemy>>[
      [for (final e in els) body(EnemyTier.wisp, e)],
      for (var f = 0; f < 3; f++)
        [for (final e in els) body(EnemyTier.drone, e, form: f)],
      [for (final e in els) body(EnemyTier.sentinel, e)],
      [for (final e in els) body(EnemyTier.phantom, e)],
      [for (final e in els) body(EnemyTier.brute, e)],
      [for (final e in els) body(EnemyTier.colossus, e)],
      [for (final e in els) body(EnemyTier.brute, e, core: true)],
      [
        body(EnemyTier.sentinel, 'Fire', trait: EnemyTrait.summoner),
        body(EnemyTier.sentinel, 'Water', trait: EnemyTrait.splitter),
        body(EnemyTier.sentinel, 'Plant', trait: EnemyTrait.breaker),
        body(EnemyTier.sentinel, 'Spirit', trait: EnemyTrait.mender),
        body(EnemyTier.brute, 'Dark', trait: EnemyTrait.breaker),
        body(EnemyTier.phantom, 'Lightning', trait: EnemyTrait.splitter),
      ],
      [
        body(EnemyTier.sentinel, 'Water', affix: EliteAffix.bulwarked),
        body(EnemyTier.sentinel, 'Plant', affix: EliteAffix.vampiric),
        body(EnemyTier.phantom, 'Spirit', affix: EliteAffix.relentless),
        body(EnemyTier.phantom, 'Ice', affix: EliteAffix.volatile),
        body(EnemyTier.brute, 'Mud', affix: EliteAffix.overclocked),
        body(EnemyTier.colossus, 'Poison', affix: EliteAffix.vampiric),
      ],
    ];
    final w = cell * 6, h = cell * rows.length;
    var rec = ui.PictureRecorder();
    var c = Canvas(rec);
    space(c, w, h, seed: 7);
    for (var r = 0; r < rows.length; r++) {
      for (var k = 0; k < rows[r].length; k++) {
        final e = rows[r][k]
          ..position = Offset(k * cell + cell / 2, r * cell + cell / 2);
        drawSurvivalEnemy(canvas: c, enemy: e, time: 0.9 + k * 0.29);
      }
    }
    await save(tester, 'every_type', rec.endRecording(), w.round(), h.round());

    const bcell = 260.0;
    rec = ui.PictureRecorder();
    c = Canvas(rec);
    space(c, bcell * 6, bcell * 3, seed: 8);
    CosmicBoss boss(
      int k,
      int row,
      String element, {
      BossType? type,
      bool charging = false,
      bool shield = false,
    }) => CosmicBoss(
      position: Offset(k * bcell + bcell / 2, row * bcell + bcell / 2),
      name: '',
      element: element,
      level: 3,
      radius: 30,
      maxHealth: 1000,
      speed: 60,
      forcedType: type ?? BossType.values[k],
      charging: charging,
      shieldUp: shield,
      shieldHealth: shield ? 1e9 : 0,
    )..angle = -0.4;
    for (var k = 0; k < BossType.values.length; k++) {
      drawOpenWorldBoss(
        canvas: c,
        boss: boss(k, 0, 'Fire'),
        time: 1.1 + k * 0.4,
      );
      drawOpenWorldBoss(
        canvas: c,
        boss: boss(k, 1, 'Crystal'),
        time: 1.1 + k * 0.4,
      );
    }
    drawOpenWorldBoss(
      canvas: c,
      boss: boss(0, 2, 'Lava', type: BossType.charger, charging: true),
      time: 1.3,
    );
    drawOpenWorldBoss(
      canvas: c,
      boss: boss(1, 2, 'Ice', type: BossType.bulwark, shield: true),
      time: 1.3,
    );
    drawOpenWorldBoss(
      canvas: c,
      boss: boss(2, 2, 'Plant', type: BossType.warden)..enraged = true,
      time: 1.3,
    );
    drawSurvivalBoss(
      canvas: c,
      boss: SurvivalBoss(
        template: kBossTemplates.first,
        type: BossType.gunner,
        discipline: SurvivalBossDiscipline.conductor,
        level: 5,
        position: const Offset(3 * bcell + bcell / 2, 2 * bcell + bcell / 2),
        hp: 640,
        maxHp: 1000,
        speed: 70,
        baseSpeed: 70,
        radius: 30,
        color: elementColor('Dark'),
      ),
      time: 1.3,
    );
    await save(
      tester,
      'every_boss',
      rec.endRecording(),
      (bcell * 6).round(),
      (bcell * 3).round(),
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
