import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// The 41 -> 42 upgrade on a real file: existing Alchemons gain an empty
/// `mutation` column, and a mutated one round-trips through it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late File file;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('alchemons_migration');
    file = File('${tmp.path}/save.sqlite');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('upgrading from 41 adds an empty mutation column', () async {
    // A schema-41 creature_instances: no mutation column.
    final legacy = sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE creature_instances (
        instance_id TEXT NOT NULL PRIMARY KEY,
        base_id TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 1,
        xp INTEGER NOT NULL DEFAULT 0,
        locked INTEGER NOT NULL DEFAULT 0,
        nickname TEXT NULL,
        is_prismatic_skin INTEGER NOT NULL DEFAULT 0,
        nature_id TEXT NULL,
        nature_id2 TEXT NULL,
        source TEXT NOT NULL DEFAULT 'discovery',
        parentage_json TEXT NULL,
        genetics_json TEXT NULL,
        likelihood_analysis_json TEXT NULL,
        stamina_max INTEGER NOT NULL DEFAULT 3,
        stamina_bars INTEGER NOT NULL DEFAULT 3,
        stamina_last_utc_ms INTEGER NOT NULL DEFAULT 0,
        created_at_utc_ms INTEGER NOT NULL DEFAULT 0,
        alchemy_effect TEXT NULL,
        stat_speed REAL NOT NULL DEFAULT 3.0,
        stat_intelligence REAL NOT NULL DEFAULT 3.0,
        stat_strength REAL NOT NULL DEFAULT 3.0,
        stat_beauty REAL NOT NULL DEFAULT 3.0,
        stat_speed_potential REAL NOT NULL DEFAULT 50.0,
        stat_intelligence_potential REAL NOT NULL DEFAULT 50.0,
        stat_strength_potential REAL NOT NULL DEFAULT 50.0,
        stat_beauty_potential REAL NOT NULL DEFAULT 50.0,
        stat_speed_enhancement INTEGER NOT NULL DEFAULT 0,
        stat_intelligence_enhancement INTEGER NOT NULL DEFAULT 0,
        stat_strength_enhancement INTEGER NOT NULL DEFAULT 0,
        stat_beauty_enhancement INTEGER NOT NULL DEFAULT 0,
        generation_depth INTEGER NOT NULL DEFAULT 0,
        faction_lineage_json TEXT NULL,
        variant_faction TEXT NULL,
        is_pure INTEGER NOT NULL DEFAULT 0,
        element_lineage_json TEXT NULL,
        family_lineage_json TEXT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        dominant_stats TEXT NULL
      )
    ''');
    legacy.execute(
      "INSERT INTO creature_instances (instance_id, base_id) "
      "VALUES ('old-1', 'LET02')",
    );
    legacy.execute('PRAGMA user_version = 41');
    legacy.dispose();

    final db = AlchemonsDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final old = await db.creatureDao.getInstance('old-1');
    expect(old, isNotNull);
    expect(old!.mutation, isNull, reason: 'no existing Alchemon is mutated');

    await db.customStatement(
      "UPDATE creature_instances SET mutation = 'transmuted' "
      "WHERE instance_id = 'old-1'",
    );
    final mutated = await db.creatureDao.getInstance('old-1');
    expect(mutated!.mutation, 'transmuted');
  });
}
