import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'alchemons_family_mastery_migration',
    );
    databaseFile = File('${temporaryDirectory.path}/save.sqlite');
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test('schema 39 upgrades with both family mastery tables', () async {
    final legacy = sqlite3.open(databaseFile.path);
    legacy.execute('PRAGMA user_version = 39');
    legacy.dispose();

    final db = AlchemonsDatabase(NativeDatabase(databaseFile));
    addTearDown(db.close);

    await db.familyMasteryDao.saveFamilyMastery(
      familyId: 'mane',
      purchasedNodeIdsJson: '["mane.assault.honed_pair"]',
      updatedAtUtcMs: 123,
    );
    await db.familyMasteryDao.saveLoadout(
      instanceId: 'mane-a',
      familyId: 'mane',
      selectedPathId: 'mane.assault',
      updatedAtUtcMs: 456,
    );

    final progress = await db.familyMasteryDao.getFamilyMastery('mane');
    final loadout = await db.familyMasteryDao.getLoadout('mane-a');
    expect(progress?.purchasedNodeIdsJson, '["mane.assault.honed_pair"]');
    expect(progress?.updatedAtUtcMs, 123);
    expect(loadout?.selectedPathId, 'mane.assault');
    expect(loadout?.updatedAtUtcMs, 456);
  });
}
