@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/athanor/athanor_furnace.dart';
import 'package:alchemons/screens/athanor/athanor_reveal.dart';
import 'package:alchemons/screens/athanor/athanor_screen.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/services/athanor_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/athanor_emblem.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Athanor on a phone, with the app's own fonts (fetched from Google, so
// run with network): home's bottom slot with the furnace (free pour waiting,
// and taken), the way in, the screen with a nine-piece batch at 0, 4 and 9
// drawn, the odds, the gold confirm, the empty and finished states, and a
// pour's reveal at its beats (a piece, then a last piece with its capstone).
// The furnace sheet and the passage painted at its moments come first.
//
//   ATHANOR_OUT=docs/athanor/renders flutter test -j 1 \
//     test/athanor_screen_preview_test.dart --tags preview

const _ember = AthanorBatch(
  id: 'ember',
  name: 'Ember Works',
  description: 'Lights and heat for the home, and the auras of the forge.',
  pieces: [
    AthanorPiece(
      id: 'ember.lantern',
      name: 'Lantern Post',
      description: 'A lantern on a post. Stands in your home.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.common,
      grantRef: 'lantern_post',
    ),
    AthanorPiece(
      id: 'ember.candles',
      name: 'Candle Cluster',
      description: 'A cluster of lit candles. Stands in your home.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.common,
      grantRef: 'candles',
    ),
    AthanorPiece(
      id: 'ember.glow',
      name: 'Resonant Glow',
      description: 'A soft glow round the Alchemon wearing it.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.common,
      grantRef: InvKeys.alchemyGlow,
    ),
    AthanorPiece(
      id: 'ember.wisps',
      name: "Will-o'-Wisps",
      description: 'Small lights that circle the Alchemon wearing it.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.common,
      grantRef: InvKeys.alchemyWillOWisps,
    ),
    AthanorPiece(
      id: 'ember.keeper',
      name: 'Keeper of the Fire',
      description: 'A title worn under your name on your profile.',
      kind: AthanorPieceKind.title,
      rarity: AthanorRarity.common,
      grantRef: 'keeper_of_the_fire',
    ),
    AthanorPiece(
      id: 'ember.geode',
      name: 'Crystal Geode',
      description: 'A split geode. Stands in your home.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.rare,
      grantRef: 'geode',
    ),
    AthanorPiece(
      id: 'ember.gold',
      name: 'Ritual Gold',
      description: 'Gold light that rises off the Alchemon wearing it.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.rare,
      grantRef: InvKeys.alchemyRitualGold,
    ),
    AthanorPiece(
      id: 'ember.sky',
      name: 'Sky Lanterns',
      description: 'Lanterns that hang in the air over your home.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.rare,
      grantRef: 'sky_lanterns',
    ),
    AthanorPiece(
      id: 'ember.rift',
      name: 'Void Rift',
      description: 'A tear of dark light behind the Alchemon wearing it.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.epic,
      grantRef: InvKeys.alchemyVoidRift,
    ),
  ],
  capstone: AthanorPiece(
    id: 'ember.fountain',
    name: 'Grain Fountain',
    description: 'A fountain of falling grains. Stands in your home.',
    kind: AthanorPieceKind.homeDecor,
    rarity: AthanorRarity.epic,
    grantRef: 'fountain',
  ),
);

const _glass = AthanorBatch(
  id: 'glass',
  name: 'Glass Works',
  description: 'Glass and crystal.',
  pieces: [
    AthanorPiece(
      id: 'glass.planter',
      name: 'Glass Planter',
      description: 'A glass planter. Stands in your home.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.common,
      grantRef: 'planter',
    ),
    AthanorPiece(
      id: 'glass.halo',
      name: 'Intelligence Halo',
      description: 'A halo over the Alchemon wearing it.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.rare,
      grantRef: InvKeys.alchemyIntelligenceHalo,
    ),
  ],
  capstone: AthanorPiece(
    id: 'glass.chimes',
    name: 'Wind Chimes',
    description: 'Glass chimes. Hang in your home.',
    kind: AthanorPieceKind.homeDecor,
    rarity: AthanorRarity.epic,
    grantRef: 'wind_chimes',
  ),
);

void main() {
  final out = Platform.environment['ATHANOR_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  Future<void> savePicture(
    WidgetTester tester,
    ui.Picture picture,
    Size size,
    String name,
  ) async {
    await tester.runAsync(() async {
      final image = await picture.toImage(
        (size.width * 2).round(),
        (size.height * 2).round(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('furnace and passage sheets', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const cell = Size(300, 300);
    // Banked, lit, and worked hot (tincture poured; gold poured), large
    // and at the home emblem's size.
    final cells = <(double, AthanorBurn)>[
      (240, const AthanorBurn(fire: 0.3)),
      (240, const AthanorBurn(fire: 1)),
      (240, const AthanorBurn(fire: 1.6, heat: 1, glow: AthanorTone.tincture)),
      (100, const AthanorBurn(fire: 0.3)),
      (100, const AthanorBurn(fire: 1)),
      (100, const AthanorBurn(fire: 1.6, heat: 1, glow: AthanorTone.gold)),
    ];
    var rec = ui.PictureRecorder();
    var canvas = Canvas(rec)..scale(2);
    final sheet = Size(cell.width * 3, cell.height * 2);
    canvas.drawRect(Offset.zero & sheet, Paint()..color = AthanorTone.void0);
    for (var i = 0; i < cells.length; i++) {
      final (s, burn) = cells[i];
      final origin = Offset((i % 3) * cell.width, (i ~/ 3) * cell.height);
      final g = AthanorFurnaceGeo(
        origin + Offset(cell.width / 2, cell.height - 30),
        s,
      );
      paintAthanorFurnace(canvas, g, 3.2, burn);
    }
    await savePicture(tester, rec.endRecording(), sheet, '00_furnace_sheet');

    // The home emblem teaching before its first opening, through one breath
    // (trough, rising, peak, falling), banked and with a free pour.
    {
      const box = Size(160, 160);
      final teach = ui.PictureRecorder();
      final tc = Canvas(teach)..scale(2);
      final size = Size(box.width * 4, box.height * 2);
      tc.drawRect(Offset.zero & size, Paint()..color = AthanorTone.void0);
      for (var row = 0; row < 2; row++) {
        for (var i = 0; i < 4; i++) {
          final origin = Offset(i * box.width, row * box.height);
          paintAthanorEmblem(
            tc,
            EmblemStage(
              box: (origin + const Offset(16, 16)) & const Size(128, 128),
              screen: size,
              time: i * 2.6 / 4,
            ),
            ready: row == 1,
            teach: true,
          );
        }
      }
      await savePicture(tester, teach.endRecording(), size, '00_emblem_teach');
    }

    // What a frame of the screen's furnace at rest costs to record (JIT;
    // a release build is cheaper), and the home emblem's.
    for (final s in [234.0, 98.0]) {
      final g = AthanorFurnaceGeo(Offset(195, 430), s);
      final watch = Stopwatch()..start();
      const n = 300;
      for (var i = 0; i < n; i++) {
        final r = ui.PictureRecorder();
        paintAthanorFurnace(Canvas(r), g, i / 60, const AthanorBurn(fire: 1));
        r.endRecording().dispose();
      }
      // ignore: avoid_print
      print('furnace s=$s: ${watch.elapsedMicroseconds / n} us a frame');
    }

    // The way in, painted at its moments over a stand-in for home.
    const phone = Size(390, 844);
    const pad = EdgeInsets.only(top: 44, bottom: 30);
    final box = Rect.fromCenter(
      center: Offset(phone.width / 2, phone.height - 106 - 64 - 7),
      width: 128,
      height: 114,
    );
    final moments = [
      (0.0, 0.0),
      (0.35, 0.0),
      (0.7, 0.0),
      (1.0, 0.0),
      (1.0, 0.5),
    ];
    final strip = Size(phone.width * moments.length, phone.height);
    rec = ui.PictureRecorder();
    canvas = Canvas(rec)..scale(2);
    for (var i = 0; i < moments.length; i++) {
      final (open, land) = moments[i];
      canvas.save();
      canvas.translate(phone.width * i, 0);
      canvas.clipRect(Offset.zero & phone);
      canvas.drawRect(
        Offset.zero & phone,
        Paint()..color = const Color(0xFF1A1310),
      );
      paintAthanorEmblem(
        canvas,
        EmblemStage(
          box: box,
          screen: phone,
          pad: pad,
          time: 2 + i * 0.2,
          open: open,
          land: land,
        ),
        ready: true,
      );
      canvas.restore();
    }
    await savePicture(tester, rec.endRecording(), strip, '00_passage_sheet');
  });

  testWidgets('athanor preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );
    await tester.runAsync(() async {
      GoogleFonts.imFellEnglishTextTheme();
      await GoogleFonts.pendingFonts();
    });

    final theme = factionThemeFor(
      FactionId.volcanic,
      brightness: Brightness.dark,
    );
    final key = GlobalKey();

    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    // The furnace never stops burning, so nothing here settles: frames of
    // 50 ms (the screen's ticker steps at most that), with real time let
    // through now and then for the database and the grain reads.
    Future<void> settle([int frames = 16]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (i % 3 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
        }
      }
    }

    Future<AthanorService> save({
      List<AthanorBatch> batches = const [_ember, _glass],
      Set<String> drawn = const {},
      bool dailyTaken = false,
      bool firstFire = true,
      int tincture = 0,
      int gold = 0,
    }) async {
      late AthanorService svc;
      await tester.runAsync(() async {
        final db = AlchemonsDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final state = AthanorState(
          drawn: drawn.isEmpty ? const {} : {'ember': drawn},
          capstones: drawn.length == _ember.pieces.length ? {'ember'} : {},
          dailyKey: dailyTaken ? '2026-10-10' : null,
          firstFire: firstFire,
        );
        await db.settingsDao.setSetting(AthanorState.key, state.encode());
        if (tincture > 0) {
          await db.inventoryDao.addItemQty(InvKeys.athanorTincture, tincture);
        }
        final have = await db.currencyDao.getGoldBalance();
        await db.currencyDao.addGold(gold - have);
        svc = AthanorService(
          db,
          batches: batches,
          random: Random(7),
          storefrontCountry: () async => 'US',
          clock: () => DateTime.utc(2026, 10, 10, 15),
        );
        await svc.load();
      });
      return svc;
    }

    Future<void> show(Widget home, AthanorService svc) async {
      await tester.pumpWidget(
        MultiProvider(
          key: UniqueKey(),
          providers: [
            ChangeNotifierProvider<AthanorService>.value(value: svc),
            Provider<FactionTheme>.value(value: theme),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.toMaterialTheme(
              GoogleFonts.imFellEnglishTextTheme(ThemeData.dark().textTheme),
            ),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: home,
          ),
        ),
      );
      await settle(20);
    }

    // ── home ──
    var svc = await save(firstFire: false);
    await show(const _Home(), svc);
    await shoot('01_home_ready');

    // The way in, through the real route.
    await tester.tap(find.byType(AthanorHomeSlot));
    for (final (ms, name) in [
      (250, '02a_passage'),
      (350, '02b_passage'),
      (450, '02c_passage'),
    ]) {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(name);
    }
    await settle(30);
    await shoot('03_screen_landed_first_fire');

    svc = await save(dailyTaken: true);
    await show(const _Home(), svc);
    await shoot('04_home_taken');

    // ── the screen, 0 / 4 / 9 drawn ──
    svc = await save(tincture: 30, gold: 120, firstFire: true);
    await show(const AthanorScreen(), svc);
    await shoot('05_screen_0');

    const four = {'ember.lantern', 'ember.glow', 'ember.geode', 'ember.keeper'};
    svc = await save(drawn: four, dailyTaken: true, tincture: 6, gold: 300);
    await show(const AthanorScreen(), svc);
    await shoot('06_screen_4_short_of_tincture');

    await tester.tap(find.text('ODDS'));
    await settle(14);
    await shoot('07_odds');
    await tester.tap(find.text('CLOSE'));
    await settle(10);

    await tester.tap(find.bySemanticsLabel('POUR · 50 GOLD'));
    await settle(10);
    await shoot('08_gold_confirm');
    await tester.tap(find.text('CANCEL'));
    await settle(8);

    final nine = {for (final p in _ember.pieces) p.id};
    svc = await save(batches: const [_ember], drawn: nine, dailyTaken: true);
    await show(const AthanorScreen(), svc);
    await shoot('09_screen_9_all_done');

    svc = await save(batches: const [_ember], drawn: nine, tincture: 20);
    await show(const AthanorScreen(), svc);
    await shoot('10_screen_9_collect_daily');

    svc = await save(batches: const [], tincture: 30);
    await show(const AthanorScreen(), svc);
    await shoot('11_no_batches');

    // ── a pour, at its beats ──
    double revealT() {
      final f = find.byType(AthanorRevealView);
      if (f.evaluate().isEmpty) return -1;
      return tester.widget<AthanorRevealView>(f).reveal.t;
    }

    Future<void> runTo(double t, String name) async {
      for (var i = 0; i < 600 && revealT() < t - 0.001; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (i % 2 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
      }
      await shoot(name);
    }

    svc = await save(drawn: four, tincture: 30, gold: 300);
    await show(const AthanorScreen(), svc);
    await tester.tap(find.text('FREE POUR'));
    await runTo(0.9, '12_reveal_pour');
    await runTo(1.9, '13_reveal_roar');
    await runTo(3.3, '14_reveal_rise');
    await runTo(4.3, '15_reveal_gather');
    await runTo(AthanorBeats.rest + 0.6, '16_reveal_rest');
    await tester.tap(find.text('CONTINUE'));
    await settle(40);
    await shoot('17_daily_extras');

    final eight = {...nine}..remove('ember.rift');
    svc = await save(batches: const [_ember], drawn: eight, tincture: 30);
    await show(const AthanorScreen(), svc);
    await tester.tap(
      find.bySemanticsLabel('POUR · $kAthanorTincturePerPour TINCTURE'),
    );
    await runTo(AthanorBeats.settled + 0.3, '18_capstone_piece');
    await runTo(6.9, '19_capstone_gather');
    await runTo(AthanorBeats.rest2 + 0.6, '20_capstone_rest');
    await tester.tap(find.text('CONTINUE'));
    await settle(30);
    await shoot('21_after_capstone');

    // ── the batches it ships with (ATHANOR_REAL=1) ──
    if (Platform.environment['ATHANOR_REAL'] == null) return;
    for (final (i, batch) in kAthanorBatches.indexed) {
      // A few drawn in each, so lit pieces sit beside ghosts.
      late AthanorService real;
      await tester.runAsync(() async {
        final db = AlchemonsDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final state = AthanorState(
          drawn: {
            for (final b in kAthanorBatches)
              b.id: {for (final p in b.pieces.take(1 + i)) p.id},
          },
          dailyKey: '2026-10-10',
          firstFire: true,
        );
        await db.settingsDao.setSetting(AthanorState.key, state.encode());
        await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 40);
        await db.currencyDao.addGold(300);
        // One batch at a time, so the strip opens on it.
        real = AthanorService(
          db,
          batches: [batch],
          random: Random(7),
          storefrontCountry: () async => 'US',
          clock: () => DateTime.utc(2026, 10, 10, 15),
        );
        await real.load();
      });
      await show(const AthanorScreen(), real);
      await shoot('real_${i + 1}_${batch.id}');
      if (i == 0) {
        await tester.tap(find.text('ODDS'));
        await settle(14);
        await shoot('real_odds_${batch.id}');
        await tester.tap(find.text('CLOSE'));
        await settle(10);
      }
      // A piece's popup: one drawn, one not, the fusion style, the capstone.
      final tiles = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Tile',
      );
      final fusion = batch.pieces.indexWhere(
        (p) => p.kind == AthanorPieceKind.fusionStyle,
      );
      for (final (tile, name) in [
        (0, 'drawn'),
        (i + 2, 'left'),
        (fusion, 'fusion'),
        (batch.pieces.length, 'capstone'),
      ]) {
        await tester.tap(tiles.at(tile));
        await settle(12);
        await shoot('real_popup_${batch.id}_$name');
        await tester.tap(find.text('CLOSE').last);
        await settle(8);
      }
    }
  });

  // The way in, densely (ATHANOR_PASSAGE=1): the real route from the tap
  // through the grow, the landing and the screen's first half second, a
  // frame every 1/60 s. Each frame's build-to-paint time (the UI thread; a
  // test never rasterises) and the furnace's light — how much, and where —
  // are printed, and every second frame is kept for a contact sheet.
  testWidgets('passage, densely', (tester) async {
    if (out == null || Platform.environment['ATHANOR_PASSAGE'] == null) return;
    final dir = Directory('$out/passage')..createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    late AthanorService svc;
    await tester.runAsync(() async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.inventoryDao.addItemQty(InvKeys.athanorTincture, 40);
      svc = AthanorService(
        db,
        random: Random(7),
        storefrontCountry: () async => 'US',
        clock: () => DateTime.utc(2026, 10, 10, 15),
      );
      await svc.load();
    });
    final theme = factionThemeFor(
      FactionId.volcanic,
      brightness: Brightness.dark,
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AthanorService>.value(value: svc),
          Provider<FactionTheme>.value(value: theme),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.toMaterialTheme(ThemeData.dark().textTheme),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const _Home(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final rest = AthanorLayout(
      const Size(390, 844),
      const EdgeInsets.only(top: 44, bottom: 30),
    ).rest;
    final look = rest.bounds;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${dir.path}/before_tap.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byType(AthanorHomeSlot));
    final rows = <String>['frame,ms,ui_us,light,cx,cy,top'];
    for (var f = 0; f < 150; f++) {
      final watch = Stopwatch()..start();
      await tester.pump(const Duration(microseconds: 16667));
      final ui0 = watch.elapsedMicroseconds;
      // Real time for the database and the screen's first reads.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var light = 0.0, sx = 0.0, sy = 0.0;
        var top = 9999;
        final w = image.width;
        for (var y = look.top.floor(); y < look.bottom.floor(); y++) {
          for (var x = look.left.floor(); x < look.right.floor(); x++) {
            final o = (y * w + x) * 4;
            final l =
                0.3 * data.getUint8(o) +
                0.59 * data.getUint8(o + 1) +
                0.11 * data.getUint8(o + 2);
            if (l < 24) continue;
            light += l;
            sx += l * x;
            sy += l * y;
            if (y < top) top = y;
          }
        }
        rows.add(
          '$f,${(f * 16.667).round()},$ui0,${(light / 1000).toStringAsFixed(1)},'
          '${light == 0 ? 0 : (sx / light).toStringAsFixed(1)},'
          '${light == 0 ? 0 : (sy / light).toStringAsFixed(1)},$top',
        );
        if (f.isEven || f < 6) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${dir.path}/f${f.toString().padLeft(3, '0')}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
      });
    }
    File('${dir.path}/stats.csv').writeAsStringSync(rows.join('\n'));
  });
}

/// Home's bottom area: the realm, and the slot the chest had.
class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final GlobalKey _emblem = GlobalKey();
  final ValueNotifier<bool> _lifted = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: FactionRealmView(faction: FactionId.volcanic),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 106),
              child: AthanorHomeSlot(
                emblemKey: _emblem,
                lifted: _lifted,
                onTap: () =>
                    openAthanor(context, from: _emblem, lifted: _lifted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
