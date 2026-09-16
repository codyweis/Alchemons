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

  test('schema 39 upgrades with shared family mastery selection', () async {
    final legacy = sqlite3.open(databaseFile.path);
    legacy.execute('PRAGMA user_version = 39');
    legacy.dispose();

    final db = AlchemonsDatabase(NativeDatabase(databaseFile));
    addTearDown(db.close);

    await db.familyMasteryDao.saveFamilyMastery(
      familyId: 'mane',
      purchasedNodeIdsJson: '["mane.assault.honed_pair"]',
      selectedPathId: 'mane.assault',
      updatedAtUtcMs: 123,
    );

    final progress = await db.familyMasteryDao.getFamilyMastery('mane');
    expect(progress?.purchasedNodeIdsJson, '["mane.assault.honed_pair"]');
    expect(progress?.selectedPathId, 'mane.assault');
    expect(progress?.updatedAtUtcMs, 123);
  });

  test('schema 40 promotes the latest creature path to the family', () async {
    final legacy = sqlite3.open(databaseFile.path);
    legacy.execute('''
      CREATE TABLE survival_family_masteries (
        family_id TEXT NOT NULL PRIMARY KEY,
        purchased_node_ids_json TEXT NOT NULL DEFAULT '[]',
        updated_at_utc_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
    legacy.execute('''
      CREATE TABLE survival_family_loadouts (
        instance_id TEXT NOT NULL PRIMARY KEY,
        family_id TEXT NOT NULL,
        selected_path_id TEXT,
        preset_name TEXT,
        updated_at_utc_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');
    legacy.execute('''
      INSERT INTO survival_family_masteries VALUES
      ('mane', '["mane.assault.honed_pair","mane.control.sweeping_claws"]', 100)
    ''');
    legacy.execute('''
      INSERT INTO survival_family_loadouts VALUES
      ('mane-a', 'mane', 'mane.assault', NULL, 200),
      ('mane-b', 'mane', 'mane.control', NULL, 300)
    ''');
    legacy.execute('PRAGMA user_version = 40');
    legacy.dispose();

    final db = AlchemonsDatabase(NativeDatabase(databaseFile));
    addTearDown(db.close);

    final progress = await db.familyMasteryDao.getFamilyMastery('mane');
    expect(progress?.selectedPathId, 'mane.control');
  });
}
