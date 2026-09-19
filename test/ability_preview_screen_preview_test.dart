@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/ability_preview_screen.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the Battle tab's ability preview screen to a PNG so its layout can
/// be looked at without a device.
///
///   ABILITY_PREVIEW_OUT=/tmp/prev flutter test \
///     test/ability_preview_screen_preview_test.dart --tags preview
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['ABILITY_PREVIEW_OUT'];

  testWidgets('ability preview screen renders at phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final subject = AbilityPreviewSubject(
      member: CosmicPartyMember(
        instanceId: 'preview-shot',
        baseId: 'MAN06',
        displayName: 'Lavamane',
        family: 'Mane',
        element: 'Lava',
        level: 10,
        slotIndex: 0,
        statSpeed: 4,
        statIntelligence: 4,
        statStrength: 4,
        statBeauty: 4,
        statSpeedPotential: 60,
        statIntelligencePotential: 60,
        statStrengthPotential: 60,
        statBeautyPotential: 60,
        staminaBars: 3,
        staminaMax: 3,
      ),
      autoAttackName: 'Lava Twin Blades',
      autoAttackDescription:
          'Throws two Lava blades side by side. The damage is in landing both on the same enemy.',
      autoAttackIcon: AppIcons.waves,
      specialName: 'Magma Catapult',
      specialSubtitle: 'Catapult · Piercing • Activates when ready',
      specialDescription: 'One big piercing boulder that leaves lava pools.',
      specialIcon: AppIcons.auto_awesome,
      accent: const Color(0xFFFF7A20),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(child: AbilityPreviewScreen(subject: subject)),
      ),
    );
    // Let the game load, the companion come out and a special land.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    final game = tester
        .widget<AbilityPreviewScreen>(find.byType(AbilityPreviewScreen))
        .subject;
    expect(game.member.displayName, 'Lavamane');
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('AUTO ATTACK'), findsOneWidget);
    expect(find.text('SPECIAL ABILITY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final live = tester.state<State<AbilityPreviewScreen>>(
      find.byType(AbilityPreviewScreen),
    );
    // ignore: avoid_print
    print(
      'ABILITY_PREVIEW ${(live as dynamic).debugGame.debugDescribeField()}',
    );

    final boundary =
        tester.firstRenderObject(find.byType(RepaintBoundary)) as dynamic;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png, isNotNull);
      if (outDir != null && outDir.isNotEmpty) {
        Directory(outDir).createSync(recursive: true);
        File(
          '$outDir/ability_preview.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      }
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
