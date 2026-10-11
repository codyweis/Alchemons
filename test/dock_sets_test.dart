import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/dock_sets.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late FactionService factions;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    factions = FactionService(db);
  });
  tearDown(() => db.close());

  DockSet set(String id) => DockSet.byId(id)!;

  test('every faction has its own set and two to buy', () {
    for (final f in FactionId.values) {
      final sets = DockSet.ofFaction(f);
      expect(sets.length, 3);
      expect(sets.first, DockSet.of(f));
      expect(sets.where((s) => s.free).length, 1);
      for (final s in sets) {
        expect(s.companions.length, 2);
        expect(s.companions.every((c) => c.faction == f && c != s), isTrue);
      }
    }
    expect(
      [for (final s in DockSet.ofFaction(FactionId.earthen)) s.name],
      ['Mudlet', 'Earthlet', 'Dustlet'],
    );
  });

  test('a faction change keeps the old set and wears the new one', () async {
    // A player from before dock sets: a faction, no dock rows.
    await db.settingsDao.setSetting('player_faction_v1', 'oceanic');
    await factions.loadId();
    expect(factions.dockSet, set('waterlet'));
    expect(factions.ownsDockSet(set('waterlet')), isTrue);
    expect(factions.ownsDockSet(set('firelet')), isFalse);

    await factions.setId(FactionId.volcanic);
    expect(factions.dockSet, set('firelet'));
    expect(factions.ownsDockSet(set('waterlet')), isTrue);
    expect(factions.ownsDockSet(set('icelet')), isFalse);

    await factions.wearDockSet(set('waterlet'));
    expect(factions.dockSet, set('waterlet'));

    // A set not owned cannot be worn.
    await factions.wearDockSet(set('lavalet'));
    expect(factions.dockSet, set('waterlet'));

    // All of it survives a reload (a cloud restore, a relaunch).
    final again = FactionService(db);
    await again.loadId();
    expect(again.dockSet, set('waterlet'));
    expect(again.ownsDockSet(set('waterlet')), isTrue);
    expect(again.ownsDockSet(set('firelet')), isTrue);
  });

  test('a bought set is owned for good, and worn', () async {
    await factions.setId(FactionId.volcanic);
    await factions.grantDockSet(set('lavalet'));
    expect(factions.dockSet, set('lavalet'));

    await factions.setId(FactionId.verdant);
    expect(factions.dockSet, set('airlet'));
    expect(factions.ownsDockSet(set('lavalet')), isTrue);
    expect(factions.ownsDockSet(set('firelet')), isTrue);
    await factions.wearDockSet(set('lavalet'));
    expect(factions.dockSet, set('lavalet'));
  });

  test('choosing the same faction again leaves the dock alone', () async {
    await factions.setId(FactionId.earthen);
    await factions.grantDockSet(set('dustlet'));
    await factions.setId(FactionId.earthen);
    expect(factions.dockSet, set('dustlet'));
  });
}
