import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'alchemons_db.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Open the Drift database
    return driftDatabase(name: 'alchemons.sqlite');
  });
}

AlchemonsDatabase constructDb() => AlchemonsDatabase(_openConnection());
