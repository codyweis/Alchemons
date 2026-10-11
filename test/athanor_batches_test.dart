import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The five batches the Athanor ships with. Every piece must be something its
/// system can grant and show: a grantRef that names nothing would be a pour
/// that gives the player nothing.
void main() {
  test('five batches of five common, three rare, two epic and a capstone', () {
    expect(kAthanorBatches.map((b) => b.name), [
      'The Black Work',
      'The White Work',
      'The Yellow Work',
      'The Red Work',
      'The Still-Room',
    ]);
    for (final batch in kAthanorBatches) {
      int count(AthanorRarity r) =>
          batch.pieces.where((p) => p.rarity == r).length;
      expect(count(AthanorRarity.common), 5, reason: batch.id);
      expect(count(AthanorRarity.rare), 3, reason: batch.id);
      expect(count(AthanorRarity.epic), 2, reason: batch.id);
    }
  });

  test('every piece id is unique and names its batch', () {
    final ids = <String>{};
    for (final batch in kAthanorBatches) {
      for (final piece in [...batch.pieces, batch.capstone]) {
        expect(ids.add(piece.id), isTrue, reason: 'duplicate ${piece.id}');
        expect(piece.id, startsWith('${batch.id}.'));
        expect(piece.name.trim(), isNotEmpty);
        expect(piece.description.trim(), isNotEmpty);
      }
    }
    expect(ids, hasLength(55));
  });

  test('every piece resolves in the system that grants it', () {
    for (final batch in kAthanorBatches) {
      for (final piece in [...batch.pieces, batch.capstone]) {
        final ref = piece.grantRef;
        final where = '${piece.id} → $ref';
        switch (piece.kind) {
          case AthanorPieceKind.alchemyEffect:
            expect(InvKeys.alchemyEffectFor(ref), isNotNull, reason: where);
          case AthanorPieceKind.homeDecor:
            final decor = HomeDecor.byId(ref);
            expect(decor, isNotNull, reason: where);
            expect(decor!.athanorOnly, isTrue, reason: where);
            expect(HomeDecor.all, contains(decor), reason: where);
          case AthanorPieceKind.title:
            expect(ref, isNotEmpty, reason: where);
          case AthanorPieceKind.costume:
            expect(FamilyCostume.ofItem(ref), isNotNull, reason: where);
          case AthanorPieceKind.dockSet:
            final set = kDockSets.where((s) => s.id == ref).firstOrNull;
            expect(set, isNotNull, reason: where);
            expect(set!.athanorOnly, isTrue, reason: where);
          case AthanorPieceKind.caseStyle:
            expect(CaseStyle.values.map((s) => s.id), contains(ref));
          case AthanorPieceKind.trail:
            expect(TrailStyle.values.map((s) => s.id), contains(ref));
          case AthanorPieceKind.fusionStyle:
            expect(FusionStyle.values.map((s) => s.id), contains(ref));
          case AthanorPieceKind.ambience:
            expect(HomeAmbience.values.map((s) => s.id), contains(ref));
        }
      }
    }
  });

  test('the shop sells none of it', () {
    final granted = athanorInventoryKeys(kAthanorBatches);
    expect(granted, isNotEmpty);
    for (final offer in ShopService.allOffers) {
      if (!ShopService.sells(offer)) continue;
      expect(
        granted,
        isNot(contains(offer.inventoryKey)),
        reason: '${offer.id} sells an Athanor piece',
      );
    }
  });
}
