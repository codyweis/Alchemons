import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh account is stocked so the tutorial can run', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final wilderness = WildernessService(db, rng: Random(1));

    // The wilderness tutorial spends one of these per fusion attempt, so an
    // empty starting inventory makes that lesson unplayable.
    expect(await wilderness.wildFusionQuantity(), 10);
  });

  test(
    'wild fusion attempts consume their own item instead of stamina',
    () async {
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final wilderness = WildernessService(db, rng: Random(1));

      // Drain the seeded stock so the refusal-at-empty case is reachable.
      var stock = await wilderness.wildFusionQuantity();
      expect(stock, greaterThan(0));
      while (stock > 0) {
        expect(await wilderness.consumeWildFusion(), isTrue);
        stock -= 1;
      }
      expect(await wilderness.wildFusionQuantity(), 0);
      expect(await wilderness.consumeWildFusion(), isFalse);

      await db.inventoryDao.addItemQty(InvKeys.wildFusion, 2);
      expect(await wilderness.consumeWildFusion(), isTrue);
      expect(await wilderness.wildFusionQuantity(), 1);
      expect(await wilderness.consumeWildFusion(), isTrue);
      expect(await wilderness.wildFusionQuantity(), 0);
      expect(await wilderness.consumeWildFusion(), isFalse);
    },
  );
}
