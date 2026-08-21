// The shop grid used to run every alchemy sprite effect live: eleven cards,
// each with two or three AnimationControllers driving MaskFilter blurs and
// per-frame gradients, all of it on the scroll thread. Cards at rest now draw a
// one-off bake of the effect's resting frame instead, and the live animation is
// reserved for the item-detail preview.
//
// These tests pin that split down: nothing ticks behind a resting card, and the
// dialog still mounts the real, animating artwork.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/sprite_effects/static_effect_snapshot.dart';
import 'package:alchemons/widgets/animations/sprite_effects/volcanic_aura.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

ShopOffer _offerFor(String inventoryKey) => ShopOffer(
  id: 'effects.$inventoryKey',
  name: inventoryKey,
  description: 'A test offer carrying a live sprite effect.',
  icon: Icons.science,
  cost: const <String, int>{},
  reward: const <String, dynamic>{},
  rewardType: 'boost',
  limit: PurchaseLimit.unlimited,
  inventoryKey: inventoryKey,
);

final _volcanicAuraOffer = _offerFor(InvKeys.alchemyVolcanicAura);

/// Every alchemy effect the shop can put on a card.
const _allEffectKeys = <String>[
  InvKeys.alchemyGlow,
  InvKeys.alchemyElementalAura,
  InvKeys.alchemyVolcanicAura,
  InvKeys.alchemyVoidRift,
  InvKeys.alchemyPrismaticCascade,
  InvKeys.alchemyRitualGold,
  InvKeys.alchemyBeautyRadiance,
  InvKeys.alchemySpeedFlux,
  InvKeys.alchemyStrengthForge,
  InvKeys.alchemyIntelligenceHalo,
  InvKeys.alchemyBloodAura,
];

Widget _cardFor(
  FactionTheme theme,
  ShopOffer offer, {
  Key? boundaryKey,
  double width = 120,
  double height = 160,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: const Color(0xFF000000),
    body: Center(
      child: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: width,
          height: height,
          child: GameShopCard(
            title: offer.name,
            offer: offer,
            theme: theme,
            enabled: true,
            canAfford: true,
            costWidgets: const <Widget>[],
          ),
        ),
      ),
    ),
  ),
);

Widget _card(FactionTheme theme) => _cardFor(theme, _volcanicAuraOffer);

void main() {
  final theme = FactionTheme.scorchForge();

  setUp(EffectSnapshotCache.instance.clear);
  tearDown(EffectSnapshotCache.instance.clear);

  testWidgets('a shop card at rest drives no animation frames', (tester) async {
    await tester.pumpWidget(_card(theme));

    // The real artwork is mounted for the bake — this is a photograph of the
    // effect, not a reimplementation of it — but with its tickers muted.
    expect(find.byType(VolcanicAura), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    // Let the post-frame capture land and the raster take over.
    await tester.pump();
    await tester.pump();

    expect(find.byType(VolcanicAura), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    // And it stays quiet.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('the bake is reused across cards of the same effect', (
    tester,
  ) async {
    await tester.pumpWidget(_card(theme));
    await tester.pump();
    await tester.pump();
    expect(EffectSnapshotCache.instance.length, 1);
    final bytes = EffectSnapshotCache.instance.retainedBytes;
    expect(bytes, greaterThan(0));
    expect(bytes, lessThanOrEqualTo(EffectSnapshotCache.maxBytes));

    // A second mount of the same effect hits the cache: no live widget is ever
    // built, so there is no second bake.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_card(theme));
    expect(find.byType(VolcanicAura), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
    expect(EffectSnapshotCache.instance.length, 1);
    expect(EffectSnapshotCache.instance.retainedBytes, bytes);
  });

  testWidgets('the item-detail preview still plays the live effect', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: theme,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemDetailDialog(
                  context: context,
                  offer: _volcanicAuraOffer,
                  theme: theme,
                  currencies: const <String, int>{},
                  inventoryQty: 0,
                  canPurchase: true,
                  canAfford: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(VolcanicAura), findsOneWidget);
    expect(find.byType(StaticEffectSnapshot), findsNothing);
    // Live artwork means live tickers.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  // The capture box is a multiple of the 64pt preview slot, because several of
  // these effects deliberately bleed past it — the outer glows, the orbiting
  // sparks, the speed streaks. If that multiple is ever trimmed, the bake
  // starts cropping artwork the live widget draws, and this catches it: at
  // 1.5x the worst channel deltas for prismatic_cascade and speed_flux jump
  // past 200, versus <=70 at the shipped 2.0x.
  for (final key in _allEffectKeys) {
    testWidgets('the bake of $key crops nothing the live effect draws', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      // Deliberately oversized, so nothing but the capture box can clip.
      await tester.pumpWidget(
        _cardFor(
          theme,
          _offerFor(key),
          boundaryKey: boundaryKey,
          width: 260,
          height: 340,
        ),
      );

      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;

      Future<Uint8List> shot() async {
        final image = boundary.toImageSync(pixelRatio: 3.0);
        late Uint8List bytes;
        await tester.runAsync(() async {
          bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        });
        image.dispose();
        return bytes;
      }

      // Frame one is the live effect frozen at t = 0 — the reference.
      final live = await shot();
      await tester.pump();
      await tester.pump();
      expect(find.byType(RawImage), findsOneWidget, reason: key);
      final baked = await shot();

      expect(live.length, baked.length, reason: key);
      var worst = 0;
      for (var i = 0; i < live.length; i++) {
        final delta = (live[i] - baked[i]).abs();
        if (delta > worst) worst = delta;
      }
      // Cropped artwork shows up as near-full-scale deltas. Round-tripping the
      // layer through an 8-bit raster costs a couple of levels; anything under
      // 100 is quantisation, not lost pixels.
      expect(
        worst,
        lessThan(100),
        reason: '$key: baked frame diverges from the live resting frame',
      );
    });
  }
}
