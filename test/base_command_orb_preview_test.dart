@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Base Command's ORB tab on the Fold (475 × 751): every core as the run
// draws it, beside what it does.
//
//   BC_OUT=/tmp/bc flutter test test/base_command_orb_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['BC_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  testWidgets('base command orbs', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont('monospace', '/System/Library/Fonts/Supplemental/Andale Mono.ttf');
    SharedPreferences.setMockInitialValues({});
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final mastery = FamilyMasteryService(db);
    await tester.runAsync(mastery.load);
    tester.view.physicalSize = const Size(475 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
          ChangeNotifierProvider(create: (_) => SurvivalUpgradeService(db)),
          ChangeNotifierProvider(
            create: (_) => ShopService(
              db,
              ConstellationEffectsService(db),
              FactionService(db),
              TimedBoostService(db.settingsDao),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const CosmicSurvivalBaseCommandScreen(hideAbilities: true),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('ORB').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/base_command_orbs.png').writeAsBytesSync(
        bytes!.buffer.asUint8List(),
      );
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    mastery.dispose();
    await tester.runAsync(db.close);
  });
}
