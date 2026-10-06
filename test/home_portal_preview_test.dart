@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:alchemons/widgets/home_portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The home screen's portal over the faction's sand: shut with the guide
// going round, opening, dark grains while the field builds, and standing
// open on a stand-in for it (any landscape PNG; the live field needs the
// app's providers).
//
//   HOME_PORTAL_OUT=/tmp/portal HOME_PORTAL_PEEK=/tmp/biome/valley.png \
//     flutter test test/home_portal_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['HOME_PORTAL_OUT'];
  final peekPath = Platform.environment['HOME_PORTAL_PEEK'];
  VoidCallback? ready;

  testWidgets('home portal preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in const [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async {
        return null;
      });
    }
    tester.view.physicalSize = const Size(1248, 2772);
    tester.view.devicePixelRatio = 1248 / 412;

    ui.Image? peek;
    if (peekPath != null) {
      peek = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          File(peekPath).readAsBytesSync(),
        );
        return (await codec.getNextFrame()).image;
      });
    }

    final shot = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> circle(Offset c, double r) async {
      final g = await tester.startGesture(c + Offset(r, 0));
      for (var k = 1; k <= 40; k++) {
        final a = math.pi * 2 * k / 40;
        await g.moveTo(c + Offset(r * math.cos(a), r * math.sin(a)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
    }

    for (final (id, tone) in const [
      (FactionId.earthen, Color(0xFFD6A35C)),
      (FactionId.volcanic, Color(0xFFE0703C)),
    ]) {
      final field = FactionRealmField(faction: id);
      final heroKey = GlobalKey();
      var open = false, guide = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: shot,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FactionRealmView(faction: id, field: field),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 130,
                  height: 260,
                  child: StatefulBuilder(
                    builder: (context, setState) => HomePortalHero(
                      key: heroKey,
                      open: open,
                      spriteKey: GlobalKey(),
                      tone: tone,
                      window: (context, onReady) {
                        ready = onReady;
                        return peek == null
                            ? const SizedBox.expand()
                            : FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: RawImage(image: peek),
                              );
                      },
                      guide: guide,
                      onToggle: (v) => setState(() {
                        open = v;
                        guide = false;
                      }),
                      onEnter: (_, __) {},
                      onSwirl: (g, reach, spin, pull) {
                        final box =
                            shot.currentContext!.findRenderObject()!
                                as RenderBox;
                        field.swirl(
                          box.globalToLocal(g),
                          reach,
                          spin: spin,
                          pull: pull,
                        );
                      },
                      onStir: (g, d, dt) {
                        final box =
                            shot.currentContext!.findRenderObject()!
                                as RenderBox;
                        field.stir(box.globalToLocal(g), d, dt);
                      },
                      child: Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFF8FB3D9), Color(0x008FB3D9)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await frames(30);
      await shoot('${id.name}_1_shut_guide');
      final c = tester.getCenter(find.byKey(heroKey));
      await circle(c, 125);
      await frames(20);
      await shoot('${id.name}_2_opening');
      await frames(40);
      await shoot('${id.name}_3_opening_late');
      await frames(70);
      await shoot('${id.name}_3b_loading');
      ready?.call();
      await frames(80);
      await shoot('${id.name}_4_open');
      await frames(600);
      await shoot('${id.name}_5_open_panned');
      await circle(c, 125);
      await frames(25);
      await shoot('${id.name}_6_closing');
      await frames(80);
      field.dispose();
    }
  });
}
