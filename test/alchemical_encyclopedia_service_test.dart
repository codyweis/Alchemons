import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadNatures);

  test('a fresh encyclopedia includes every nature as undiscovered', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final snapshot = await AlchemicalEncyclopediaService.loadSnapshot(db: db);

    expect(
      snapshot.natureEntries.map((entry) => entry.nature.id).toSet(),
      NatureCatalog.all.map((nature) => nature.id).toSet(),
    );
    expect(snapshot.natureEntries.every((entry) => !entry.discovered), isTrue);
  });
}
