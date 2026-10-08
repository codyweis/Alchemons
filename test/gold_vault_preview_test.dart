@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/shop/gold_vault.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The gold vault at phone widths, with real fonts: opening on the popular
// pack, mid-pour into the biggest, settled, the smallest, signed out, and
// a purchase in flight — plus what a frame costs.
//
//   VAULT_OUT=/tmp/vault flutter test \
//     test/gold_vault_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['VAULT_OUT'];

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

  List<GoldVaultOffer> offers({String? pendingId, bool priced = true}) {
    const prices = [
      ('\$0.99', 0.99),
      ('\$2.99', 2.99),
      ('\$5.99', 5.99),
      ('\$12.99', 12.99),
    ];
    final packs = const [
      GoldPackDefinition(
        productId: 'alchemons_gold_cache',
        title: 'Gold Cache',
        subtitle: 'Quick refill for portal keys and summons.',
        goldAmount: 25,
        badge: 'STARTER',
      ),
      GoldPackDefinition(
        productId: 'alchemons_gold_stash',
        title: 'Gold Stash',
        subtitle: 'Balanced pack for regular premium play.',
        goldAmount: 75,
        badge: 'POPULAR',
      ),
      GoldPackDefinition(
        productId: 'alchemons_gold_vault',
        title: 'Gold Vault',
        subtitle: 'Big injection for cosmetics and unlocks.',
        goldAmount: 200,
        badge: 'VALUE',
      ),
      GoldPackDefinition(
        productId: 'alchemons_gold_celestial',
        title: 'Celestial',
        subtitle: 'Heavy stockpile for long-form progression.',
        goldAmount: 500,
        badge: 'PREMIUM',
      ),
    ];
    return [
      for (var i = 0; i < packs.length; i++)
        GoldVaultOffer(
          pack: packs[i],
          price: priced ? prices[i].$1 : null,
          rawPrice: priced ? prices[i].$2 : null,
          pending: packs[i].productId == pendingId,
        ),
    ];
  }

  testWidgets('gold vault preview', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);

    Future<void> shoot(GlobalKey key, String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final width in [360.0, 690.0]) {
      tester.view.physicalSize = Size(width * 2, 520 * 2);
      tester.view.devicePixelRatio = 2;
      final key = GlobalKey();
      final state = ValueNotifier<(List<GoldVaultOffer>, bool)>((
        offers(),
        false,
      ));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0B0D12),
            body: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFF0B0D12),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                child: ValueListenableBuilder(
                  valueListenable: state,
                  builder: (context, s, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoldVaultDeck(
                        offers: s.$1,
                        needsAccount: s.$2,
                        onBuy: (_) {},
                        onSignIn: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          final image = element.widget as Image;
          await precacheImage(image.image, element, onError: (_, _) {});
        }
      });
      final w = width.toInt();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_1_open_popular');

      await tester.tap(find.text('500').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_2_pouring');
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_3_celestial');

      await tester.tap(find.text('25').first);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_3b_giving_back');
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_4_cache');

      await tester.tap(find.text('200').first);
      state.value = (offers(), true);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_5_signed_out');

      state.value = (offers(pendingId: 'alchemons_gold_vault'), false);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_6_pending');

      state.value = (offers(priced: false), false);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await shoot(key, '${w}_7_no_prices');
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.reset();

    // Cost of one frame of the field at the biggest pack, mid-pour.
    final field = GoldVaultField([25, 75, 200, 500], selected: 3);
    final layout = GoldVaultLayout(388, 4);
    field.select(2);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 240; i++) {
      field.step(1 / 60);
      final rec = ui.PictureRecorder();
      field.paint(Canvas(rec), layout);
      rec.endRecording().dispose();
    }
    // ignore: avoid_print
    print(
      'gold vault: ${(sw.elapsedMicroseconds / 240).toStringAsFixed(0)} µs '
      'per frame (JIT, ${field.sunGrains} sun grains)',
    );
  });
}
