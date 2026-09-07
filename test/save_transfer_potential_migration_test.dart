import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/save_transfer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LegacySchemaDatabase extends AlchemonsDatabase {
  _LegacySchemaDatabase(super.executor);

  @override
  int get schemaVersion => 36;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AlchemonsDatabase> restoreFrom(
    AlchemonsDatabase source, {
    required String accountId,
  }) async {
    final saveCode = await SaveTransferService(
      source,
    ).exportSaveCode(ownerAccountId: accountId);
    final restored = AlchemonsDatabase(NativeDatabase.memory());
    await SaveTransferService(
      restored,
    ).importSaveCode(saveCode, ownerAccountId: accountId);
    return restored;
  }

  test('cloud restore converts pre-37 Potential from 0-5 to 1-100', () async {
    final source = _LegacySchemaDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    await source.creatureDao.insertInstance(
      instanceId: 'legacy-mon',
      baseId: 'aerwyn',
      statSpeedPotential: 1,
      statIntelligencePotential: 2,
      statStrengthPotential: 3,
      statBeautyPotential: 4,
    );

    final restored = await restoreFrom(source, accountId: 'legacy-account');
    addTearDown(restored.close);
    final instance = await restored.creatureDao.getInstance('legacy-mon');

    expect(instance, isNotNull);
    expect(instance!.statSpeedPotential, 20);
    expect(instance.statIntelligencePotential, 40);
    expect(instance.statStrengthPotential, 60);
    expect(instance.statBeautyPotential, 80);
  });

  test(
    'cloud restore preserves legitimate schema-37 Potential of 1-4',
    () async {
      final source = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      await source.creatureDao.insertInstance(
        instanceId: 'modern-mon',
        baseId: 'aerwyn',
        statSpeedPotential: 1,
        statIntelligencePotential: 2,
        statStrengthPotential: 3,
        statBeautyPotential: 4,
      );

      final restored = await restoreFrom(source, accountId: 'modern-account');
      addTearDown(restored.close);
      final instance = await restored.creatureDao.getInstance('modern-mon');

      expect(instance, isNotNull);
      expect(instance!.statSpeedPotential, 1);
      expect(instance.statIntelligencePotential, 2);
      expect(instance.statStrengthPotential, 3);
      expect(instance.statBeautyPotential, 4);
    },
  );
}
