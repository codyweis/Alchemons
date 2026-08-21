@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the enemy roster to PNG contact sheets so the silhouettes can be
/// judged side by side instead of one at a time mid-fight.
///
/// Main look only — one neutral element per row, since element tinting is a
/// recolour rather than a different shape.
///
///   ENEMY_SHEET_OUT=docs/ability_sheets flutter test \
///     test/enemy_vfx_contact_sheet_test.dart --tags preview
void main() {
  final outDir = Platform.environment['ENEMY_SHEET_OUT'];

  String? labelFont;
  setUpAll(() async {
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader('SheetLabel')..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      labelFont = 'SheetLabel';
      return;
    }
  });

  CosmicSurvivalEnemy make({
    required EnemyTier tier,
    required String element,
    EnemyConduct conduct = EnemyConduct.charge,
    EnemyTrait? trait,
    CosmicEnemyRole role = CosmicEnemyRole.striker,
    bool isElite = false,
    EliteAffix? affix,
    double radius = 16,
    double hpFraction = 1.0,
  }) {
    const maxHp = 100.0;
    return CosmicSurvivalEnemy(
      position: Offset.zero,
      hp: maxHp * hpFraction,
      maxHp: maxHp,
      speed: 60,
      damage: 10,
      radius: radius,
      tier: tier,
      element: element,
      role: role,
      conduct: conduct,
      trait: trait,
      target: CosmicEnemyTarget.orb,
      isElite: isElite,
      eliteAffix: affix,
    );
  }

  Future<void> sheetOf(
    WidgetTester tester,
    String name,
    String title,
    List<(String, String, void Function(Canvas, Offset, double))> rows,
  ) async {
    const cell = 150.0;
    const labelW = 168.0;
    const headerH = 52.0;
    const times = [0.0, 0.45, 0.95, 1.6];

    final w = labelW + cell * times.length;
    final h = headerH + cell * rows.length;

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );

    void label(
      String s,
      Offset at,
      Color c, {
      double size = 11,
      FontWeight weight = FontWeight.w700,
      double maxWidth = double.infinity,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: c,
            fontSize: size,
            fontWeight: weight,
            fontFamily: labelFont,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);
      tp.paint(canvas, at);
    }

    label(title, const Offset(12, 10), const Color(0xFFE8DCC0), size: 15);
    label(
      'silhouette only — element tint is a recolour, not a different shape',
      const Offset(12, 30),
      const Color(0xFF6B7688),
      size: 9,
      weight: FontWeight.w500,
    );
    for (var c = 0; c < times.length; c++) {
      label(
        't = ${times[c].toStringAsFixed(2)}s',
        Offset(labelW + c * cell + 8, 38),
        const Color(0xFF8C99AB),
        size: 10,
      );
    }

    for (var r = 0; r < rows.length; r++) {
      final (rowLabel, subLabel, draw) = rows[r];
      final top = headerH + r * cell;
      if (r.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, w, cell),
          Paint()..color = const Color(0x0AFFFFFF),
        );
      }
      canvas.drawLine(
        Offset(0, top),
        Offset(w, top),
        Paint()..color = const Color(0x14FFFFFF),
      );
      label(
        rowLabel,
        Offset(10, top + 14),
        const Color(0xFFE0D6BC),
        size: 13,
        maxWidth: labelW - 16,
      );
      label(
        subLabel,
        Offset(10, top + 34),
        const Color(0xFF7C8798),
        size: 9,
        weight: FontWeight.w600,
        maxWidth: labelW - 16,
      );

      for (var c = 0; c < times.length; c++) {
        final centre = Offset(labelW + c * cell + cell / 2, top + cell / 2);
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(labelW + c * cell, top, cell, cell));
        draw(canvas, centre, times[c]);
        canvas.restore();
      }
    }

    final pic = rec.endRecording();
    ByteData? bytes;
    await tester.runAsync(() async {
      final img = await pic.toImage(w.round(), h.round());
      bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory(outDir!).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  void Function(Canvas, Offset, double) enemyDrawer(
    CosmicSurvivalEnemy enemy,
  ) => (canvas, centre, t) {
    enemy.position = centre;
    drawSurvivalEnemy(canvas: canvas, enemy: enemy, time: t);
  };

  testWidgets('enemy tiers', (tester) async {
    await sheetOf(
      tester,
      'enemy_tiers_sheet',
      'ENEMY TIERS — the six body types',
      [
        for (final tier in EnemyTier.values)
          (
            tier.name.toUpperCase(),
            '${tier.name} · striker',
            enemyDrawer(
              make(
                tier: tier,
                element: 'Fire',
                radius: switch (tier) {
                  EnemyTier.wisp => 9,
                  EnemyTier.drone => 11,
                  EnemyTier.sentinel => 16,
                  EnemyTier.phantom => 15,
                  EnemyTier.brute => 22,
                  EnemyTier.colossus => 30,
                },
              ),
            ),
          ),
      ],
    );
  }, skip: outDir == null);

  testWidgets('enemy variants', (tester) async {
    await sheetOf(
      tester,
      'enemy_variants_sheet',
      'TRAITS & CONDUCTS — the converged taxonomy',
      [
        for (final t in [null, ...EnemyTrait.values])
          (
            (t?.name ?? 'none').toUpperCase(),
            'sentinel · trait',
            enemyDrawer(
              make(
                tier: EnemyTier.sentinel,
                element: 'Lightning',
                trait: t,
                radius: 17,
              ),
            ),
          ),
        for (final c in EnemyConduct.values)
          (
            'CONDUCT: ${c.name.toUpperCase()}',
            'sentinel · conduct',
            enemyDrawer(
              make(
                tier: EnemyTier.brute,
                element: 'Lightning',
                conduct: c,
                radius: 20,
              ),
            ),
          ),
      ],
    );
  }, skip: outDir == null);

  testWidgets('enemy roles and elites', (tester) async {
    await sheetOf(tester, 'enemy_roles_sheet', 'ROLES & ELITE AFFIXES', [
      for (final role in CosmicEnemyRole.values)
        (
          'ROLE: ${role.name.toUpperCase()}',
          'sentinel · ${role.name}',
          enemyDrawer(
            make(
              tier: EnemyTier.sentinel,
              element: 'Water',
              role: role,
              radius: 17,
            ),
          ),
        ),
      for (final affix in EliteAffix.values)
        (
          'ELITE: ${affix.name.toUpperCase()}',
          'brute · elite',
          enemyDrawer(
            make(
              tier: EnemyTier.brute,
              element: 'Dark',
              radius: 20,
              isElite: true,
              affix: affix,
            ),
          ),
        ),
    ]);
  }, skip: outDir == null);

  testWidgets('boss disciplines', (tester) async {
    final template = kBossTemplates.first;
    await sheetOf(
      tester,
      'enemy_bosses_sheet',
      'SURVIVAL BOSSES — disciplines and archetypes',
      [
        for (final d in SurvivalBossDiscipline.values)
          (
            d.name.toUpperCase(),
            'discipline · ${template.element}',
            (canvas, centre, t) {
              final boss = SurvivalBoss(
                template: template,
                type: BossType.charger,
                discipline: d,
                level: 5,
                position: centre,
                hp: 800,
                maxHp: 1000,
                speed: 70,
                baseSpeed: 70,
                radius: 34,
                color: elementColor(template.element),
              );
              drawSurvivalBoss(canvas: canvas, boss: boss, time: t);
            },
          ),
        for (final bt in BossType.values)
          (
            'TYPE: ${bt.name.toUpperCase()}',
            'archetype',
            (canvas, centre, t) {
              final boss = SurvivalBoss(
                template: template,
                type: bt,
                level: 5,
                position: centre,
                hp: 800,
                maxHp: 1000,
                speed: 70,
                baseSpeed: 70,
                radius: 34,
                color: elementColor(template.element),
              );
              drawSurvivalBoss(canvas: canvas, boss: boss, time: t);
            },
          ),
      ],
    );
  }, skip: outDir == null);

  testWidgets('open world enemies', (tester) async {
    CosmicEnemy ow(
      EnemyTier tier,
      double radius, {
      CosmicEnemyVariant variant = CosmicEnemyVariant.standard,
      String element = 'Fire',
    }) => CosmicEnemy(
      position: Offset.zero,
      element: element,
      tier: tier,
      radius: radius,
      health: 80,
      speed: 50,
      variant: variant,
    );

    double radiusFor(EnemyTier t) => switch (t) {
      EnemyTier.wisp => 9,
      EnemyTier.drone => 11,
      EnemyTier.sentinel => 16,
      EnemyTier.phantom => 15,
      EnemyTier.brute => 22,
      EnemyTier.colossus => 30,
    };

    await sheetOf(
      tester,
      'enemy_open_world_sheet',
      'OPEN WORLD — now the same renderer as survival',
      [
        for (final tier in EnemyTier.values)
          (
            tier.name.toUpperCase(),
            'open world · standard',
            (canvas, centre, t) {
              final e = ow(tier, radiusFor(tier))..position = centre;
              drawOpenWorldEnemy(canvas: canvas, e: e, time: t);
            },
          ),
        for (final v in CosmicEnemyVariant.values)
          (
            'VARIANT: ${v.name.toUpperCase()}',
            'open world · sentinel',
            (canvas, centre, t) {
              final e = ow(EnemyTier.sentinel, 17, variant: v)
                ..position = centre
                ..angle = 1.2;
              drawOpenWorldEnemy(canvas: canvas, e: e, time: t);
            },
          ),
      ],
    );
  }, skip: outDir == null);

  testWidgets('open world bosses', (tester) async {
    CosmicBoss owBoss(
      BossType type, {
      bool titanic = false,
      bool enraged = false,
      String element = 'Fire',
    }) => CosmicBoss(
      position: Offset.zero,
      name: type.name,
      element: element,
      level: 3,
      radius: titanic ? 52 : 34,
      maxHealth: 1000,
      speed: 60,
      isTitanic: titanic,
      forcedType: type,
    )..enraged = enraged;

    await sheetOf(
      tester,
      'enemy_open_world_boss_sheet',
      'OPEN WORLD BOSSES — the lair fight',
      [
        for (final bt in BossType.values)
          (
            bt.name.toUpperCase(),
            'open world boss · lv3',
            (canvas, centre, t) {
              final b = owBoss(bt)..position = centre;
              drawOpenWorldBoss(canvas: canvas, boss: b, time: t);
            },
          ),
        (
          'TITANIC',
          'open world boss · titanic',
          (canvas, centre, t) {
            final b = owBoss(BossType.charger, titanic: true)
              ..position = centre;
            drawOpenWorldBoss(canvas: canvas, boss: b, time: t);
          },
        ),
        (
          'ENRAGED',
          'open world boss · enraged',
          (canvas, centre, t) {
            final b = owBoss(BossType.warden, enraged: true)..position = centre;
            drawOpenWorldBoss(canvas: canvas, boss: b, time: t);
          },
        ),
      ],
    );
  }, skip: outDir == null);

  testWidgets('boss lairs', (tester) async {
    await sheetOf(
      tester,
      'enemy_boss_lair_sheet',
      'BOSS LAIRS — the spawn marker you fly into',
      [
        for (final t in kBossTemplates.take(5))
          (
            t.name.toUpperCase(),
            'lair · ${t.element}',
            (canvas, centre, time) {
              final lair = BossLair(position: centre, template: t, level: 3);
              drawBossLair(canvas: canvas, lair: lair, time: time);
            },
          ),
      ],
    );
  }, skip: outDir == null);
}
