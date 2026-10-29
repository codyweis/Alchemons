@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// The shop's one purchase dialog: a stack of something with the stepper, a
// price the purse cannot meet, and a thing already owned.
//
//   SHOP_DIALOG_OUT=/tmp/shop_dialog flutter test \
//     test/shop_offer_dialog_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SHOP_DIALOG_OUT'];
  setUpAll(loadLobbyFonts);

  ShopOffer offer(String id) =>
      ShopService.allOffers.firstWhere((o) => o.id == id);

  for (final (name, id, purse, canPurchase, quantity, steps) in [
    ('harvester', 'device.harvest.std.volcanic', 5000, true, true, 2),
    ('short', 'effects.void_rift', 3, true, false, 0),
    ('owned', 'unlock.fusion_slot.1', 900, false, false, 0),
  ]) {
    testWidgets('offer dialog $name', (tester) async {
      if (out == null) return;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final theme = FactionTheme.scorchForge();
      final key = GlobalKey();
      final o = offer(id);
      final currencies = {
        for (final k in [...o.cost.keys, 'gold', 'silver']) k: purse,
      };
      await tester.pumpWidget(
        Provider<FactionTheme>.value(
          value: theme,
          child: MaterialApp(
            // Round the navigator, so the dialog's route is in the shot.
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child),
            home: SizedBox.expand(
              child: Scaffold(
                backgroundColor: const Color(0xFF09090B),
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showOfferDialog(
                      context: context,
                      offer: o,
                      theme: theme,
                      currencies: currencies,
                      inventoryQty: name == 'harvester' ? 3 : 0,
                      canPurchase: canPurchase,
                      canAfford: o.cost.entries.every(
                        (e) => (currencies[e.key] ?? 0) >= e.value,
                      ),
                      allowQuantity: quantity,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      for (var i = 0; i < steps; i++) {
        await tester.tap(find.byIcon(AppIcons.add_rounded).last);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File(
          '$out/offer_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
