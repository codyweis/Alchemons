@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/mystic_altar/altar_hub_field.dart';
import 'package:alchemons/screens/mystic_altar/altar_rite_field.dart';
import 'package:alchemons/screens/mystic_altar/boss_altar_detail_screen.dart';
import 'package:alchemons/screens/mystic_altar/mystic_altar_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Mystic Altar's fields, painted straight to PNGs: the hub ring in its
// stages of waking.
//
//   ALTAR_OUT=/tmp/altar flutter test \
//     test/mystic_altar_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['ALTAR_OUT'];
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadFont(String family, List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      return;
    }
  }

  setUpAll(() async {
    await loadFont('monospace', [
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    ]);
    await loadFont('Roboto', [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]);
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await loadFont('packages/phosphoricons_flutter/$family', [
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      ]);
    }
  });

  /// A save part-way through the altar: some relics held, some set with
  /// offerings given, some Mystics awake.
  Future<void> seedMidgame(AlchemonsDatabase db) async {
    // Already arrived once, so no task toast covers the frame.
    await OnboardingTaskService(db).markVisited('rite');
    String id(String el) => altarEntryForElement(el)!.id;
    for (final el in ['Water', 'Lightning', 'Blood']) {
      await db.inventoryDao.addItemQty(BossLootKeys.traitKeyForElement(el), 1);
    }
    for (final el in ['Fire', 'Ice']) {
      await db.altarDao.setRelicPlaced(id(el));
    }
    for (var k = 0; k < 3; k++) {
      await db.altarDao.placeAlchemon(
        bossId: id('Fire'),
        speciesId: 'sp$k',
        instanceId: 'i$k',
      );
    }
    for (final el in ['Earth', 'Air', 'Plant', 'Crystal', 'Light', 'Steam']) {
      await db.altarDao.setRelicPlaced(id(el));
      await db.settingsDao.setSetting('altar_summoned_${id(el)}', '2026');
    }
  }

  Future<void> shootWidget(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });

  Future<void> settle(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  Future<void> save(String name, Size size, void Function(Canvas) draw) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(2);
    draw(canvas);
    final img = await rec.endRecording().toImage(
      (size.width * 2).round(),
      (size.height * 2).round(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  }

  test('rite field stages', () async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    final catalog = CreatureCatalog();
    await catalog.load();
    for (final el in ['Fire', 'Water']) {
      final mystic = catalog.mysticByElement(el)!;
      final species = catalog
          .byType(el)
          .where((s) => s.id != mystic.id)
          .toList();
      final field = AltarRiteField(
        element: el,
        offerings: [for (final s in species) RiteOffering(s)],
      );
      field.mystic = await AltarGrains.creature(
        mystic,
        width: AltarRiteField.mysticWidth.round(),
        maxGrains: 2600,
        tones: 14,
      );
      field.relic = await AltarGrains.relic(altarEntryForElement(el)!);
      for (final o in field.offerings) {
        o.grains = await AltarGrains.creature(
          o.species,
          width: 72,
          maxGrains: 620,
          tones: 12,
        );
        o.available = 2;
      }
      const size = Size(412, 560);
      final stage = Offset.zero & size;
      Future<void> shot(String name, double t) async {
        field.time = t;
        await save(
          'rite_${el}_$name',
          size,
          (c) => field.paint(c, size, stage),
        );
      }

      await shot('0_empty', 3);
      for (var i = 0; i < 3; i++) {
        field.offerings[i].given = true;
      }
      field.offerings[2].giving = 0.5;
      await shot('1_giving', 3);
      field.offerings[2].giving = 0.76;
      await shot('2_landing', 3);
      for (final o in field.offerings) {
        o
          ..given = true
          ..giving = 1;
      }
      await shot('3_ready', 4);
      field.charge = 0.7;
      await shot('4_charging', 4.2);
      field.charge = 1;
      for (final (n, s) in const [
        ('5_pour', 0.8),
        ('6_crush', 1.8),
        ('7_knot', 2.55),
        ('8_burst', 2.85),
        ('9_spray', 3.15),
        ('10_form', 3.7),
        ('11_gather', 4.6),
      ]) {
        field.summon = s;
        await shot(n, 5 + s);
      }
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (final (label, t) in const [
        ('idle', -1.0),
        ('knot', 2.2),
        ('form', 3.6),
      ]) {
        field.summon = t;
        final w = Stopwatch()..start();
        for (var i = 0; i < 60; i++) {
          field.time = i / 60;
          field.paint(c, size, stage);
        }
        w.stop();
        // ignore: avoid_print
        print('rite $el $label ≈ ${(w.elapsedMicroseconds / 60).round()} µs');
      }
      rec.endRecording().dispose();
      field.summon = 6;
      field.sealTo = Offset(size.width / 2, size.height + 40);
      for (final (n, s) in const [('12_seal', 0.3), ('13_drop', 0.75)]) {
        field.seal = s;
        await shot(n, 9 + s);
      }
    }
  });

  test('hub field stages', () async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    // Assets through the test bundle.
    final ring = <AltarSeat>[];
    for (final e in kAltarEntries.where((e) => e.element != 'Blood')) {
      final s = AltarSeat(e)..relic = await AltarGrains.relic(e);
      s.required = 7;
      ring.add(s);
    }
    final blood = kAltarEntries.firstWhere((e) => e.element == 'Blood');
    final heart = AltarSeat(blood)..relic = await AltarGrains.relic(blood);
    final field = AltarHubField(ring, heart);

    const size = Size(400, 460);
    final sw = Stopwatch();

    void stage(String name) {}
    stage('');

    Future<void> shot(String name, {double t = 4}) async {
      field.time = t;
      sw
        ..reset()
        ..start();
      await save(name, size, (c) => field.paint(c, size, Offset.zero & size));
      sw.stop();
    }

    // Nothing earned.
    await shot('hub_1_asleep');

    // A run in progress: a few relics held, some set with offerings, some
    // awake.
    for (var i = 0; i < 16; i++) {
      ring[i].state = switch (i % 5) {
        0 => SeatState.awakened,
        1 => SeatState.placed,
        2 => SeatState.held,
        3 => SeatState.awakened,
        _ => SeatState.unearned,
      };
      ring[i].offerings = i % 8;
    }
    field.selected = 0;
    await shot('hub_2_midgame');
    field.rotation = 0.9;
    field.selected = 14;
    await shot('hub_3_turned', t: 7);

    // All sixteen awake: the heart is blood.
    for (final s in ring) {
      s.state = SeatState.awakened;
    }
    heart.state = SeatState.placed;
    field.rotation = 0;
    field.selected = -1;
    await shot('hub_4_witnessed');
    heart.state = SeatState.awakened;
    await shot('hub_5_complete', t: 9.1);

    // One seat waking, back from its summoning.
    for (final s in ring) {
      s.state = SeatState.placed;
    }
    heart.state = SeatState.unearned;
    ring[0]
      ..state = SeatState.awakened
      ..waking = 0.45;
    field.selected = 0;
    await shot('hub_6_waking', t: 3);
    ring[0].waking = 1;

    // The last relic set: the heart tears open.
    for (final a in [0.5, 0.86]) {
      field.arcane = a;
      await shot('hub_7_arcane_${(a * 100).round()}', t: 3 + a);
    }
    field.arcane = 0;

    // Cost of a frame, roughly (JIT, recording only).
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      field.time = i / 60;
      field.paint(c, size, Offset.zero & size);
    }
    w.stop();
    rec.endRecording().dispose();
    // ignore: avoid_print
    print('hub frame ≈ ${(w.elapsedMicroseconds / 60).round()} µs');
  });

  testWidgets('altar screen and rite', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    final fire = altarEntryForElement('Fire')!;
    late List<String> species;
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
      await OnboardingTaskService(db).markVisited('rite');
      await db.settingsDao.setBossRelicScreenStoryIntroSeen();
      await db.settingsDao.setSetting('campaign_mystic_presence_seen_v1', '1');
      await db.altarDao.setRelicPlaced(fire.id);
      final mystic = catalog.mysticByElement('Fire')!;
      species = [
        for (final c in catalog.byType('Fire'))
          if (c.id != mystic.id) c.id,
      ];
      var n = 0;
      for (final sp in species) {
        for (var k = 0; k < 2; k++) {
          await db.creatureDao.insertInstance(
            instanceId: 'inst${n++}',
            baseId: sp,
            level: 3 + n,
            natureId: k == 0 ? 'Placid' : null,
            statSpeedPotential: 40.0 + n * 3 % 50,
            statIntelligencePotential: 55,
            statStrengthPotential: 60.0 + n % 30,
            statBeautyPotential: 82,
          );
        }
      }
      // Four already given.
      for (final sp in species.take(4)) {
        await db.altarDao.placeAlchemon(
          bossId: fire.id,
          speciesId: sp,
          instanceId: 'gone-$sp',
          snapshotJson:
              '{"scaleVersion":2,"speedPotential":70,'
              '"intelligencePotential":60,"strengthPotential":66,'
              '"beautyPotential":74,"natureId":"Placid"}',
        );
      }
    });
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    Future<void> mount() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<CreatureCatalog>.value(value: catalog),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(),
              home: BossAltarDetailScreen(boss: fire),
            ),
          ),
        ),
      );
      await settle(tester, 60);
    }

    await mount();
    await shootWidget(tester, key, 'screen_rite_1_waiting');

    // Tap the first empty seat: the offering sheet.
    // The screen's own layout: header 62, panel 200, no insets here.
    final f = AltarRiteField(
      element: 'Fire',
      offerings: [
        for (final sp in species) RiteOffering(catalog.getCreatureById(sp)!),
      ],
    )..layout(const Rect.fromLTRB(0, 62, 412, 692));
    await tester.tapAt(f.seatCentre(4));
    await settle(tester, 20);
    await tester.tap(find.textContaining('LV ').first);
    await settle(tester, 6);
    await shootWidget(tester, key, 'screen_rite_2_sheet');
    final give = await tester.startGesture(
      tester.getCenter(find.textContaining('HOLD TO GIVE')),
    );
    await settle(tester, 36);
    await give.up();
    await settle(tester, 30);
    await shootWidget(tester, key, 'screen_rite_2b_giving');
    await tester.pumpWidget(const SizedBox());

    // The rest given: ready, then the rite.
    await tester.runAsync(() async {
      for (final sp in species.skip(4)) {
        await db.altarDao.placeAlchemon(
          bossId: fire.id,
          speciesId: sp,
          instanceId: 'gone-$sp',
          snapshotJson: '{"scaleVersion":2,"speedPotential":70}',
        );
      }
    });
    await mount();
    await shootWidget(tester, key, 'screen_rite_3_ready');
    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO PERFORM THE RITE')),
    );
    await settle(tester, 30);
    await shootWidget(tester, key, 'screen_rite_4_holding');
    await settle(tester, 30);
    await hold.up();
    var shot = 5;
    for (final frames in [24, 30, 24, 9, 12, 30, 30, 50]) {
      await settle(tester, frames);
      await shootWidget(tester, key, 'screen_rite_${shot++}');
    }
    await tester.tap(find.text('SEAL AND DEPART'));
    await settle(tester, 14);
    await shootWidget(tester, key, 'screen_rite_${shot++}_seal');
    await settle(tester, 40);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });

  testWidgets('blood altar', (tester) async {
    if (outDir == null) return;
    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    final blood = altarEntryForElement('Blood')!;
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
      await OnboardingTaskService(db).markVisited('rite');
      await db.settingsDao.setBossRelicScreenStoryIntroSeen();
      await db.settingsDao.setSetting(
        'blood_mystic_relic_story_intro_seen_v1',
        '1',
      );
      await db.altarDao.setRelicPlaced(blood.id);
      for (final e in kAltarEntries.take(11)) {
        await db.settingsDao.setSetting('altar_summoned_${e.id}', '2026');
      }
      final mystic = catalog.mysticByElement('Blood')!;
      final kinds = [
        for (final c in catalog.byType('Blood'))
          if (c.id != mystic.id) c.id,
      ];
      for (final k in kinds.take(3)) {
        await db.altarDao.placeAlchemon(
          bossId: blood.id,
          speciesId: k,
          instanceId: 'g$k',
        );
      }
    });
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: BossAltarDetailScreen(boss: blood),
          ),
        ),
      ),
    );
    await settle(tester, 60);
    await shootWidget(tester, key, 'screen_blood');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });

  testWidgets('hub reveal', (tester) async {
    if (outDir == null) return;
    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
      await OnboardingTaskService(db).markVisited('rite');
      await db.inventoryDao.addItemQty(
        BossLootKeys.traitKeyForElement('Water'),
        1,
      );
    });
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: const MysticAltarScreen(),
          ),
        ),
      ),
    );
    await settle(tester, 70);
    await shootWidget(tester, key, 'reveal_0_veiled');
    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO SET THE RELIC')),
    );
    await settle(tester, 18);
    await shootWidget(tester, key, 'reveal_1_pressing');
    await settle(tester, 18);
    await hold.up();
    for (final (n, f) in const [('2', 10), ('3', 12), ('4', 14), ('5', 20)]) {
      await settle(tester, f);
      await shootWidget(tester, key, 'reveal_$n');
    }
    await settle(tester, 60);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });

  testWidgets('hub screen', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);
    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
      await seedMidgame(db);
    });
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(key: key, child: const MysticAltarScreen()),
        ),
      ),
    );
    await settle(tester, 70);
    await shootWidget(tester, key, 'screen_hub_1');
    // Turn to an awake seat.
    await tester.tap(find.byType(MysticAltarScreen), warnIfMissed: false);
    await tester.drag(
      find.byType(MysticAltarScreen),
      const Offset(-120, 0),
      warnIfMissed: false,
    );
    await settle(tester, 9);
    await shootWidget(tester, key, 'screen_hub_2_pouring');
    await settle(tester, 30);
    await shootWidget(tester, key, 'screen_hub_3');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });
}

// Silences the unused import lint in a file that only renders.
// ignore: unused_element
const _keep = SystemChannels.platform;
