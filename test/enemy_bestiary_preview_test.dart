@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic/enemy_body_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole roster on one labelled sheet — every body, what it does when
/// it attacks, the marks it can carry, and the six bosses — plus frame
/// sequences for animating the swarm and the bosses.
///
///   BESTIARY_OUT=dir flutter test test/enemy_bestiary_preview_test.dart \
///     --tags preview
///
/// With BESTIARY_FRAMES=n it also writes n frames of each loop to
/// dir/swarm_NNN.png and dir/bosses_NNN.png.
void main() {
  final outDir = Platform.environment['BESTIARY_OUT'];
  final frames = int.tryParse(Platform.environment['BESTIARY_FRAMES'] ?? '');

  String? font;
  setUpAll(() async {
    for (final path in const [
      '/System/Library/Fonts/Supplemental/Georgia.ttf',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      'C:/Windows/Fonts/georgia.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader('Bestiary')..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      font = 'Bestiary';
      return;
    }
  });

  const parchment = Color(0xFFE8DFC8);
  const amber = Color(0xFFC4A35A);
  const muted = Color(0xFF8A8474);
  const bg = Color(0xFF07060C);

  void text(
    Canvas c,
    String s,
    Offset at, {
    double size = 13,
    Color color = parchment,
    FontWeight weight = FontWeight.w400,
    double maxWidth = 1e4,
    double spacing = 0,
    bool centre = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: font,
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(c, centre ? at - Offset(tp.width / 2, 0) : at);
  }

  void rule(Canvas c, double y, double w) {
    c.drawRect(
      Rect.fromLTWH(40, y, w - 80, 1),
      Paint()..color = amber.withValues(alpha: 0.25),
    );
  }

  CosmicSurvivalEnemy make(
    EnemyTier tier,
    String element, {
    double? radius,
    double angle = -0.45,
    EnemyTrait? trait,
    bool elite = false,
    EliteAffix? affix,
    bool plague = false,
  }) => CosmicSurvivalEnemy(
    position: Offset.zero,
    hp: 100,
    maxHp: 100,
    speed: 60,
    damage: 10,
    radius: radius ?? tierRadius(tier),
    tier: tier,
    element: element,
    conduct: EnemyConduct.charge,
    trait: trait,
    target: CosmicEnemyTarget.orb,
    isElite: elite,
    eliteAffix: affix,
    isPlagueCore: plague,
  )..angle = angle;

  double inspect(EnemyTier t) => switch (t) {
    EnemyTier.wisp => 14,
    EnemyTier.drone => 17,
    EnemyTier.sentinel => 20,
    EnemyTier.phantom => 19,
    EnemyTier.brute => 25,
    EnemyTier.colossus => 30,
  };

  const swarm = [
    (
      EnemyTier.wisp,
      'WISP',
      'Loose essence — a spark with a comet tail. A horde streams in as light.',
    ),
    (
      EnemyTier.drone,
      'DRONE',
      'A dark shard split by a crack of light, an eye at its nose. '
          'Coils on the wind-up, then dashes.',
    ),
    (
      EnemyTier.sentinel,
      'SENTINEL',
      'A glass orb in a ring of orbiting grains. The ring gathers in, '
          'then is flung out as it fires.',
    ),
    (
      EnemyTier.phantom,
      'PHANTOM',
      'An eclipse you can see space through. Fades as it blinks; both '
          'limbs burn when it is exposed.',
    ),
    (
      EnemyTier.brute,
      'BRUTE',
      'A lava bomb of black obsidian, heat in its veins. Cracks open '
          'along every face to fire.',
    ),
    (
      EnemyTier.colossus,
      'COLOSSUS',
      'Standing stones round a fire. The ring closes on the flame, then '
          'is blown wide.',
    ),
  ];

  const bosses = [
    (
      BossForm.comet,
      'THE COMET',
      'charger',
      'A blazing nucleus trailing a river of embers; debris tumbles '
          'through its glow.',
    ),
    (
      BossForm.singularity,
      'THE SINGULARITY',
      'gunner',
      'A black hole in its accretion disk, the far side bent up over '
          'the top.',
    ),
    (
      BossForm.ouroboros,
      'THE OUROBOROS',
      'skirmisher',
      'A serpent of faceted vertebrae circling the egg it guards, head '
          'chasing tail.',
    ),
    (
      BossForm.spire,
      'THE SPIRE',
      'bulwark',
      'Black crystal with burning seams and debris wheeling round it; a '
          'glass barrier when shielded.',
    ),
    (
      BossForm.hive,
      'THE HIVE',
      'carrier',
      'Flocks of motes wheeling on breathing orbits round a dark core.',
    ),
    (
      BossForm.armillary,
      'THE ARMILLARY',
      'warden',
      'Brass rings turning on three axes round a sun, runes of light set '
          'in them.',
    ),
  ];

  const elements = ['Fire', 'Water', 'Plant', 'Lightning', 'Spirit', 'Dark'];

  void drawBoss(
    Canvas c,
    BossForm form,
    String element,
    Offset at,
    double r,
    double t, {
    bool enraged = false,
    bool shield = false,
    double charge = 0,
  }) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(r);
    final pal = enraged
        ? enemyPalette(
            element,
            Color.lerp(elementColor(element), const Color(0xFFE53935), 0.35),
          )
        : enemyPalette(element);
    paintBossForm(
      c,
      pal,
      form,
      time: t,
      seed: element.length * 0.9,
      heading: -0.35,
      enraged: enraged,
      shield: shield,
      charge: charge,
    );
    c.restore();
  }

  testWidgets('bestiary sheet', (tester) async {
    const w = 1400.0;
    const cell = 150.0;
    const labelW = 380.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // Height is laid out as we go; the backdrop is drawn generously.
    c.drawRect(const Rect.fromLTWH(0, 0, w, 6000), Paint()..color = bg);

    var y = 44.0;
    text(c, 'BESTIARY', Offset(w / 2, y), size: 34, color: parchment,
        spacing: 8, centre: true);
    y += 48;
    text(
      c,
      'dark glass and obsidian, with the element as the light caught inside',
      Offset(w / 2, y),
      size: 14,
      color: muted,
      centre: true,
    );
    y += 50;

    // ── the swarm ──
    text(c, 'THE SWARM', Offset(40, y), size: 18, color: amber, spacing: 4);
    for (var i = 0; i < elements.length; i++) {
      text(
        c,
        elements[i].toUpperCase(),
        Offset(labelW + i * cell + cell / 2, y + 4),
        size: 10,
        color: muted,
        spacing: 2,
        centre: true,
      );
    }
    y += 34;
    for (final (tier, name, blurb) in swarm) {
      rule(c, y, w);
      text(c, name, Offset(40, y + 36), size: 20, spacing: 2);
      text(c, blurb, Offset(40, y + 66), size: 13, color: muted,
          maxWidth: labelW - 70);
      for (var i = 0; i < elements.length; i++) {
        final centre = Offset(labelW + i * cell + cell / 2, y + cell / 2);
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: cell, height: cell));
        drawSurvivalEnemy(
          canvas: c,
          enemy: make(tier, elements[i], radius: inspect(tier))
            ..position = centre,
          time: 0.6 + i * 0.41,
        );
        c.restore();
      }
      y += cell;
    }
    y += 30;

    // ── attacks ──
    rule(c, y, w);
    y += 20;
    text(c, 'HOW THEY ATTACK', Offset(40, y), size: 18, color: amber,
        spacing: 4);
    const phases = [
      (null, 'idle'),
      (EnemyActionPhase.windUp, 'winding up'),
      (EnemyActionPhase.commit, 'striking'),
      (EnemyActionPhase.recover, 'recovering — open'),
    ];
    for (var i = 0; i < phases.length; i++) {
      text(
        c,
        phases[i].$2.toUpperCase(),
        Offset(labelW + i * 190 + 95, y + 4),
        size: 10,
        color: muted,
        spacing: 2,
        centre: true,
      );
    }
    y += 30;
    for (final (tier, name, _) in swarm) {
      if (!kEnemyActions.containsKey(tier)) continue;
      text(c, name, Offset(40, y + 50), size: 15, spacing: 2);
      for (var i = 0; i < phases.length; i++) {
        final centre = Offset(labelW + i * 190 + 95, y + 65);
        final e = make(tier, 'Fire', radius: inspect(tier) * 0.9)
          ..position = centre;
        final phase = phases[i].$1;
        if (phase != null) {
          final def = kEnemyActions[tier]!;
          e.action
            ..phase = phase
            ..aimAngle = -0.45
            ..timer = switch (phase) {
              EnemyActionPhase.windUp => def.windUp * 0.25,
              EnemyActionPhase.commit => def.commit * 0.6,
              EnemyActionPhase.recover => def.recover * 0.6,
              _ => 0,
            };
        }
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: 190, height: 130));
        drawSurvivalEnemy(canvas: c, enemy: e, time: 1.1 + i * 0.2);
        c.restore();
      }
      y += 130;
    }
    y += 20;

    // ── marks ──
    rule(c, y, w);
    y += 20;
    text(c, 'MARKS', Offset(40, y), size: 18, color: amber, spacing: 4);
    y += 34;
    final marks = <(String, CosmicSurvivalEnemy)>[
      for (final a in EliteAffix.values)
        (
          'elite · ${a.name}',
          make(EnemyTier.sentinel, 'Water', radius: 18, elite: true, affix: a),
        ),
      (
        'trait sigil',
        make(EnemyTier.sentinel, 'Lightning', radius: 18,
            trait: EnemyTrait.summoner),
      ),
      ('plague core', make(EnemyTier.brute, 'Poison', radius: 22, plague: true)),
    ];
    const markCell = 190.0;
    for (var i = 0; i < marks.length; i++) {
      final col = i % 7;
      final centre = Offset(40 + col * markCell + markCell / 2, y + 80);
      c.save();
      c.clipRect(
        Rect.fromCenter(center: centre, width: markCell, height: 160),
      );
      drawSurvivalEnemy(
        canvas: c,
        enemy: marks[i].$2..position = centre,
        time: 0.9 + i * 0.3,
      );
      c.restore();
      text(c, marks[i].$1.toUpperCase(), Offset(centre.dx, y + 152),
          size: 10, color: muted, spacing: 1.5, centre: true);
    }
    y += 190;

    // ── bosses ──
    rule(c, y, w);
    y += 20;
    text(c, 'THE SIX', Offset(40, y), size: 18, color: amber, spacing: 4);
    text(c, 'one boss per archetype; the element colors its light',
        Offset(160, y + 4), size: 13, color: muted);
    y += 34;
    const bossElements = ['Fire', 'Water', 'Crystal', 'Dark'];
    const bossCell = 250.0;
    for (final (form, name, archetype, blurb) in bosses) {
      rule(c, y, w);
      text(c, name, Offset(40, y + 70), size: 20, spacing: 2);
      text(c, archetype.toUpperCase(), Offset(40, y + 100), size: 11,
          color: amber, spacing: 3);
      text(c, blurb, Offset(40, y + 124), size: 13, color: muted,
          maxWidth: labelW - 70);
      for (var i = 0; i < bossElements.length; i++) {
        final centre = Offset(
          labelW + i * bossCell + bossCell / 2,
          y + bossCell / 2,
        );
        c.save();
        c.clipRect(
          Rect.fromCenter(center: centre, width: bossCell, height: bossCell),
        );
        drawBoss(c, form, bossElements[i], centre, 44, 0.8 + i * 0.53,
            shield: form == BossForm.spire && i == 3);
        c.restore();
      }
      y += bossCell;
    }
    y += 30;

    final pic = rec.endRecording();
    await tester.runAsync(() async {
      final img = await pic.toImage(w.round(), y.round());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir!).createSync(recursive: true);
      File('$outDir/bestiary.png').writeAsBytesSync(
        bytes!.buffer.asUint8List(),
      );
    });
  }, skip: outDir == null);

  testWidgets('animation frames', (tester) async {
    final n = frames!;
    const fps = 15.0;
    Future<void> write(String name, ui.Picture pic, int w, int h) async {
      await tester.runAsync(() async {
        final img = await pic.toImage(w, h);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(
          bytes!.buffer.asUint8List(),
        );
      });
    }

    Directory(outDir!).createSync(recursive: true);
    for (var f = 0; f < n; f++) {
      final t = 1.0 + f / fps;

      // The swarm: one of each, three across and two down.
      const sw = 900.0, sh = 560.0, sc = 300.0, sr = 280.0;
      var rec = ui.PictureRecorder();
      var c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, sw, sh), Paint()..color = bg);
      const swarmEls = ['Fire', 'Water', 'Crystal', 'Spirit', 'Lava', 'Plant'];
      for (var i = 0; i < swarm.length; i++) {
        final (tier, name, _) = swarm[i];
        final centre = Offset((i % 3) * sc + sc / 2, (i ~/ 3) * sr + sr / 2);
        final e = make(tier, swarmEls[i], radius: inspect(tier) * 1.6)
          ..position = centre;
        // Walk the ones that attack through it once a loop.
        final def = kEnemyActions[tier];
        if (def != null) {
          final loop = n / fps;
          final u = (t - 1.0) % loop;
          final start = loop * 0.35;
          final phases = [
            (EnemyActionPhase.windUp, def.windUp * 2.2),
            (EnemyActionPhase.commit, def.commit * 2.2),
            (EnemyActionPhase.recover, def.recover * 2.2),
          ];
          var at = start;
          for (final (phase, dur) in phases) {
            if (u >= at && u < at + dur) {
              e.action
                ..phase = phase
                ..aimAngle = -0.45
                ..timer = (at + dur - u) / 2.2;
              break;
            }
            at += dur;
          }
        }
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: sc, height: sr));
        drawSurvivalEnemy(canvas: c, enemy: e, time: t);
        c.restore();
        text(c, name, Offset(centre.dx, centre.dy + sr / 2 - 30), size: 13,
            color: muted, spacing: 3, centre: true);
      }
      await write('swarm_${f.toString().padLeft(3, '0')}', rec.endRecording(),
          sw.round(), sh.round());

      // The six bosses.
      const bw = 960.0, bh = 660.0, bc = 320.0, br = 330.0;
      rec = ui.PictureRecorder();
      c = Canvas(rec);
      c.drawRect(const Rect.fromLTWH(0, 0, bw, bh), Paint()..color = bg);
      const bossEls = ['Fire', 'Dark', 'Water', 'Crystal', 'Plant', 'Light'];
      for (var i = 0; i < bosses.length; i++) {
        final (form, name, _, _) = bosses[i];
        final centre = Offset((i % 3) * bc + bc / 2, (i ~/ 3) * br + br / 2 - 10);
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: bc, height: br));
        drawBoss(c, form, bossEls[i], centre, 50, t);
        c.restore();
        text(c, name, Offset(centre.dx, centre.dy + br / 2 - 22), size: 13,
            color: muted, spacing: 3, centre: true);
      }
      await write('bosses_${f.toString().padLeft(3, '0')}', rec.endRecording(),
          bw.round(), bh.round());
    }
  }, skip: outDir == null || frames == null);
}
