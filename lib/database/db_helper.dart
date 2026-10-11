import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'alchemons_db.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Open the Drift database. In the browser it is SQLite compiled to wasm,
    // run in a worker and stored in OPFS/IndexedDB; both files live in web/
    // (tool/build_web.sh rebuilds the worker).
    return driftDatabase(
      name: 'alchemons.sqlite',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  });
}

AlchemonsDatabase constructDb() => AlchemonsDatabase(_openConnection());
