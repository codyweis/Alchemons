import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/cosmic/widgets/cosmic_settings_overlay.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The ship settings panel in space, with and without the developer tools:
//
//   COSMIC_SETTINGS_OUT=/tmp/cs flutter test test/cosmic_settings_preview_test.dart
//
// Without COSMIC_SETTINGS_OUT the test returns at once and passes.
void main() {
  testWidgets('cosmic settings preview', (tester) async {
    final out = Platform.environment['COSMIC_SETTINGS_OUT'];
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
    }

    await tester.runAsync(() async {
      await loadFont(
        'monospace',
        '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      );
      await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    });

    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final devWas = DebugSettingsService.enabledNotifier.value;
    addTearDown(() => DebugSettingsService.enabledNotifier.value = devWas);

    for (final dev in [false, true]) {
      DebugSettingsService.enabledNotifier.value = dev;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF1B2230)),
                ),
                CosmicSettingsOverlay(
                  joystickEnabled: true,
                  largeJoystickEnabled: false,
                  autoFireGunEnabled: true,
                  autoFireMissilesEnabled: false,
                  boostToggleEnabled: false,
                  onClose: () {},
                  onLeaveSpace: () {},
                  onToggleJoystick: (_) {},
                  onToggleLargeJoystick: (_) {},
                  onToggleAutoFireGun: (_) {},
                  onToggleAutoFireMissiles: (_) {},
                  onToggleBoostToggle: (_) {},
                  onReplayPrologue: () {},
                  onKinPortal: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/settings${dev ? '_dev' : ''}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
