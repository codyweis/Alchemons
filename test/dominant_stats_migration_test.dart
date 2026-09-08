import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Proves the 38 -> 39 upgrade actually runs on a real file, because a
/// migration that only ever executes on a phone is a migration nobody tested.
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

  test('upgrading from 38 backfills Dominants from the best two', () async {
    // A schema-38 creature_instances: no dominant_stats column.
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
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
    legacy.execute('''
      INSERT INTO creature_instances (
        instance_id, base_id,
        stat_speed_potential, stat_intelligence_potential,
        stat_strength_potential, stat_beauty_potential
      ) VALUES ('old-1', 'LET02', 30.0, 91.0, 74.0, 12.0)
    ''');
    legacy.execute('PRAGMA user_version = 38');
    legacy.dispose();

    // Opening it now runs the 38 -> 39 upgrade.
    final db = AlchemonsDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final migrated = await db.creatureDao.getInstance('old-1');
    expect(migrated, isNotNull);

    final dominants = DominantStats.decode(migrated!.dominantStats);
    expect(
      dominants,
      isNotNull,
      reason: 'the backfill must not leave existing creatures without them',
    );
    expect(dominants!.contains(StatKind.intelligence), isTrue);
    expect(dominants.contains(StatKind.strength), isTrue);
    expect(dominants.contains(StatKind.speed), isFalse);
    expect(dominants.contains(StatKind.beauty), isFalse);

    // The creature itself is otherwise untouched — no save gets rewritten.
    expect(migrated.statIntelligencePotential, 91.0);
    expect(migrated.baseId, 'LET02');
  });
}
