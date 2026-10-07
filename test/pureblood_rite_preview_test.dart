@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/pureblood_rite_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Pureblood Rite on a phone, four offerings in: the pool waiting, a
// specimen placed (worthy, and not), and the offering played out.
//
//   RITE_OUT=/tmp/rite flutter test \
//     test/pureblood_rite_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['RITE_OUT'];
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

  testWidgets('rite screen and offering', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    // The phone the emblem passage preview uses, so its pool lines up.
    tester.view.padding = const FakeViewPadding(top: 44 * 2, bottom: 30 * 2);
    addTearDown(tester.view.reset);

    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
      await db.constellationDao.unlockSkill('breeder_lineage_analyzer', 0);
      await db.settingsDao.setSetting(
        'pureblood_rite_story_intro_seen_v1',
        '1',
      );
      // Four given; the fourth asks for an elementally pure Lavapip.
      await db.settingsDao.setSetting('pureblood_rite_stage_index_v2', '3');
      String idOf(String name) =>
          catalog.creatures.firstWhere((c) => c.name == name).id;
      await db.creatureDao.insertInstance(
        instanceId: 'pure',
        baseId: idOf('Lavapip'),
        level: 9,
        elementLineage: const {'Lava': 1},
        familyLineage: const {'Pip': 1},
      );
      await db.creatureDao.insertInstance(
        instanceId: 'mixed',
        baseId: idOf('Lavapip'),
        level: 4,
        generationDepth: 2,
        elementLineage: const {'Lava': 2, 'Fire': 1},
        familyLineage: const {'Pip': 3},
      );
      await db.creatureDao.insertInstance(
        instanceId: 'other',
        baseId: idOf('Firepip'),
        level: 6,
        elementLineage: const {'Fire': 1},
        familyLineage: const {'Pip': 1},
      );
    });

    final key = GlobalKey();
    Future<void> shoot(String name) => tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    final theme = factionThemeFor(
      FactionId.volcanic,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<FactionTheme>.value(value: theme),
          Provider<StaminaService>(create: (_) => StaminaService(db)),
          ChangeNotifierProvider<ConstellationEffectsService>(
            create: (_) => ConstellationEffectsService(db),
          ),
          ChangeNotifierProvider<TimedBoostService>(
            create: (_) => TimedBoostService(db.settingsDao)..load(),
          ),
          ChangeNotifierProvider<FactionService>(
            create: (_) => FactionService(db)..loadId(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => ShopService(
              db,
              ctx.read<ConstellationEffectsService>(),
              ctx.read<FactionService>(),
              ctx.read<TimedBoostService>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const PurebloodRiteScreen(),
        ),
      ),
    );
    await settle(50);
    await shoot('01_waiting');
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -520));
    await settle(16);
    await shoot('02_waiting_scrolled');
    await tester.dragFrom(const Offset(195, 300), const Offset(0, 700));
    await settle(16);

    Future<void> place(String name, int index) async {
      await tester.ensureVisible(find.textContaining('SPECIMEN').last);
      await settle(4);
      await tester.tap(find.textContaining('SPECIMEN').last);
      await settle(30);
      await shoot('${name}_picker');
      final cases = find.byWidgetPredicate(
        (w) => w.runtimeType.toString().contains('SpecimenCase'),
      );
      if (cases.evaluate().length > index) {
        await tester.tap(cases.at(index));
      } else {
        await tester.tap(find.textContaining('LV').at(index));
      }
      await settle(30);
      await tester.dragFrom(const Offset(195, 300), const Offset(0, 900));
      await settle(20);
    }

    await place('03', 1);
    await shoot('03_placed');
    await place('04', 2);
    await shoot('04_placed');
    await tester.dragFrom(const Offset(195, 700), const Offset(0, -520));
    await settle(16);
    await shoot('05_placed_scrolled');

    final perform = find.text('HOLD TO PERFORM THE RITE');
    if (perform.evaluate().isNotEmpty) {
      await tester.ensureVisible(perform);
      await settle(4);
      final hold = await tester.startGesture(tester.getCenter(perform));
      await settle(24);
      await shoot('06_holding');
      await settle(30);
      await hold.up();
      var n = 7;
      for (final frames in [14, 18, 18, 18, 22, 30, 40]) {
        await settle(frames);
        await shoot('${(n++).toString().padLeft(2, '0')}_offering');
      }
      final cont = find.text('CONTINUE');
      if (cont.evaluate().isNotEmpty) {
        await tester.tap(cont);
        await settle(40);
        await shoot('${n.toString().padLeft(2, '0')}_after');
      }
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
