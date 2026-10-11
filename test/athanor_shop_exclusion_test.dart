// Athanor pieces are never sold (docs/athanor_design.md). The shop makes
// no offer for decor marked athanorOnly, and never lists or sells an offer
// marked athanorOnly or one for an item an Athanor batch gives. Tincture is
// earned only: it has no offer at all.

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';

ShopOffer _offer(String key, {bool athanorOnly = false}) => ShopOffer(
  id: 'effects.$key',
  name: key,
  description: 'A test effect.',
  icon: AppIcons.auto_awesome_rounded,
  cost: const {'gold': 10},
  reward: const {},
  rewardType: 'boost',
  limit: PurchaseLimit.unlimited,
  inventoryKey: key,
  athanorOnly: athanorOnly,
);

void main() {
  test('athanorOnly decor gets no shop offer; the rest still do', () {
    const sold = HomeDecor(
      'test_sold',
      'Sold',
      'A test piece.',
      tier: DecorTier.curio,
      silver: 100,
    );
    const drawn = HomeDecor(
      'test_drawn',
      'Drawn',
      'A test piece.',
      tier: DecorTier.curio,
      athanorOnly: true,
    );
    final offers = ShopService.offersForDecor(const [sold, drawn]);
    expect(offers.map((o) => o.id), [sold.offerId]);
  });

  test('an athanorOnly offer is never sold', () {
    expect(ShopService.sells(_offer('alchemy.test_plain')), isTrue);
    expect(
      ShopService.sells(_offer('alchemy.test_drawn', athanorOnly: true)),
      isFalse,
    );
  });

  test('an offer for an item a batch gives is never sold', () {
    const batches = [
      AthanorBatch(
        id: 'b',
        name: 'B',
        description: 'A test batch.',
        pieces: [
          AthanorPiece(
            id: 'b.aura',
            name: 'Aura',
            description: 'A test aura.',
            kind: AthanorPieceKind.alchemyEffect,
            rarity: AthanorRarity.common,
            grantRef: 'alchemy.test_batch_aura',
          ),
        ],
        capstone: AthanorPiece(
          id: 'b.lamp',
          name: 'Lamp',
          description: 'A test lamp.',
          kind: AthanorPieceKind.homeDecor,
          rarity: AthanorRarity.epic,
          grantRef: 'test_lamp',
        ),
      ),
    ];
    expect(
      ShopService.sells(_offer('alchemy.test_batch_aura'), batches: batches),
      isFalse,
    );
    expect(
      ShopService.sells(_offer('home.test_lamp'), batches: batches),
      isFalse,
    );
    expect(
      ShopService.sells(_offer('alchemy.test_other'), batches: batches),
      isTrue,
    );
  });

  test('every real offer is still sold while no batch claims it', () {
    final claimed = athanorInventoryKeys(kAthanorBatches);
    for (final offer in ShopService.allOffers) {
      if (offer.athanorOnly || claimed.contains(offer.inventoryKey)) continue;
      expect(ShopService.sells(offer), isTrue, reason: offer.id);
    }
    for (final d in HomeDecor.all.where((d) => !d.athanorOnly)) {
      expect(
        ShopService.allOffers.where((o) => o.id == d.offerId),
        hasLength(1),
        reason: d.id,
      );
    }
  });

  test('tincture has no shop offer', () {
    expect(
      ShopService.allOffers.where(
        (o) => o.inventoryKey == InvKeys.athanorTincture,
      ),
      isEmpty,
    );
  });
}
