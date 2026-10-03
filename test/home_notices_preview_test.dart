@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/notification_banner_system.dart';
import 'package:alchemons/widgets/particle_title.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The home screen's notices where home puts them, over stand-ins for the
// avatar and the currency, the faction realm and the particle title, on a
// phone. All three open, then folded to tabs (on the left for the light
// theme, to see the other side); dark theme and light.
//
//   NOTICES_OUT=/tmp/notices flutter test \
//     test/home_notices_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['NOTICES_OUT'];

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
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('home notices preview (${brightness.name})', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      // The realm listens to the accelerometer; there is none here.
      final messenger = tester.binding.defaultBinaryMessenger;
      for (final channel in const [
        'dev.fluttercommunity.plus/sensors/method',
        'dev.fluttercommunity.plus/sensors/accelerometer',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
          return null;
        });
      }
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 44 * 3);
      addTearDown(tester.view.reset);

      final left = brightness == Brightness.light;
      SharedPreferences.setMockInitialValues({
        if (left) 'home_banner_right_side': false,
      });
      final db = AlchemonsDatabase(NativeDatabase.memory());
      final theme = factionThemeFor(FactionId.oceanic, brightness: brightness);
      final dark = brightness == Brightness.dark;

      final notices = [
        NotificationBanner(
          type: NotificationBannerType.eggReady,
          title: '2 cultivations ready',
          subtitle: 'Tap to extract them',
          count: 2,
          stateKey: 'slots:1,2',
          onTap: () {},
        ),
        NotificationBanner(
          type: NotificationBannerType.harvestReady,
          title: 'Harvest ready',
          subtitle: 'Tap to collect',
          stateKey: 'biomes:volcanic',
          onTap: () {},
        ),
        NotificationBanner(
          type: NotificationBannerType.wildernessSpawn,
          title: 'Wild Alchemons',
          subtitle: 'Detected in 3 realms',
          count: 5,
          stateKey: 'wild:5',
          onTap: () {},
        ),
      ];

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

      Future<void> settle([int frames = 10]) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: FactionRealmView(
                      faction: FactionId.oceanic,
                      ink: !dark,
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        // Stand-ins for the avatar and the currency.
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.surfaceAlt,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 120,
                              height: 34,
                              margin: const EdgeInsets.only(right: 12),
                              color: theme.surfaceAlt,
                            ),
                          ],
                        ),
                        ParticleTitle(darkBackdrop: dark),
                      ],
                    ),
                  ),
                  NotificationBannerStack(notifications: notices),
                ],
              ),
            ),
          ),
        ),
      );
      await settle(24);
      await shoot('${brightness.name}_open');

      // Fold all three with a swipe toward the docked edge.
      for (final n in notices) {
        await tester.drag(
          find.text(n.title.toUpperCase()),
          Offset(left ? -140 : 140, 0),
        );
        await settle(4);
      }
      await settle(6);
      await shoot('${brightness.name}_folded');

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.runAsync(db.close);
    });
  }
}
