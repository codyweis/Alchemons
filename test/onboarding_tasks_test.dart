// Tasks are a map, not a scoreboard.
//
// They point at rooms the player may not know exist, pay a flat rate for
// walking in, and leave the list once walked. Arriving is the whole
// requirement — the arrival IS the lesson — which means the marking happens
// in a screen's initState and will fire on every single visit. The one thing
// that must hold is that it only ever pays once.

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  late OnboardingTaskService tasks;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    tasks = OnboardingTaskService(db);
  });
  tearDown(() async => db.close());

  test('a fresh save shows only the places that exist yet', () async {
    final left = await tasks.outstanding();
    final open = kOnboardingTasks.where((t) => t.gate == TaskGate.always);
    expect(left.map((r) => r.$1.id), open.map((t) => t.id));
    expect(left.map((r) => r.$2), everyElement(TaskState.todo));
    expect(await tasks.readyCount(), 0);
  });

  group('gates', () {
    test('the constellations appear with the ship', () async {
      final task = kOnboardingTasks.firstWhere((t) => t.id == 'constellation');
      expect(await tasks.unlocked(task), isFalse);
      await db.settingsDao.setSetting('cosmic_ship_unlocked', '1');
      expect(await tasks.unlocked(task), isTrue);
      expect(
        (await tasks.outstanding()).map((r) => r.$1.id),
        contains('constellation'),
      );
    });

    test('the altar appears with a relic in hand', () async {
      final task = kOnboardingTasks.firstWhere((t) => t.id == 'rite');
      expect(await tasks.unlocked(task), isFalse);
      await db.inventoryDao.addItemQty(
        BossLootKeys.traitKeyForElement(kAltarEntries.first.element),
        1,
      );
      expect(await tasks.unlocked(task), isTrue);
    });

    test('the forge needs the shop to answer', () async {
      final task = kOnboardingTasks.firstWhere((t) => t.id == 'enhance');
      // No ShopService means no claim either way, so it stays hidden rather
      // than advertising a locked door.
      expect(await tasks.unlocked(task), isFalse);
    });

    test('an earned reward survives its gate', () async {
      // Earn the constellation task, then take the ship away again.
      await db.settingsDao.setSetting('cosmic_ship_unlocked', '1');
      await tasks.markVisited('constellation');
      await db.settingsDao.setSetting('cosmic_ship_unlocked', '0');
      expect(
        (await tasks.outstanding()).map((r) => r.$1.id),
        contains('constellation'),
        reason: 'the player did the thing; the silver is theirs',
      );
      expect(await tasks.readyCount(), 1);
    });
  });

  test('arriving earns but does not pay', () async {
    final before = await db.currencyDao.getSilverBalance();

    expect(await tasks.markVisited('shop'), isTrue);
    expect(
      await db.currencyDao.getSilverBalance(),
      before,
      reason: 'the reward waits in the journal to be collected',
    );
    expect(await tasks.readyCount(), 1);

    // initState fires again on every revisit; it must stay a no-op.
    expect(await tasks.markVisited('shop'), isFalse);
    expect(await tasks.readyCount(), 1);
  });

  test('collecting pays exactly once', () async {
    final before = await db.currencyDao.getSilverBalance();
    await tasks.markVisited('shop');

    expect(await tasks.claim('shop'), isTrue);
    expect(
      await db.currencyDao.getSilverBalance(),
      before + kTaskSilverReward,
    );

    expect(await tasks.claim('shop'), isFalse);
    expect(
      await db.currencyDao.getSilverBalance(),
      before + kTaskSilverReward,
      reason: 'a collected task cannot be collected again',
    );
  });

  test('an unvisited task cannot be collected', () async {
    final before = await db.currencyDao.getSilverBalance();
    expect(await tasks.claim('rite'), isFalse);
    expect(await db.currencyDao.getSilverBalance(), before);
  });

  test('a task shows its three states in order', () async {
    final task = kOnboardingTasks.first;
    expect(await tasks.stateOf(task), TaskState.todo);
    await tasks.markVisited(task.id);
    expect(await tasks.stateOf(task), TaskState.earned);
    await tasks.claim(task.id);
    expect(await tasks.stateOf(task), TaskState.claimed);
  });

  test('an earned task stays listed until collected', () async {
    await tasks.markVisited('rite');
    var left = await tasks.outstanding();
    expect(
      left.map((r) => r.$1.id),
      contains('rite'),
      reason: 'it is still there, waiting to be collected',
    );

    await tasks.claim('rite');
    left = await tasks.outstanding();
    expect(left.map((r) => r.$1.id), isNot(contains('rite')));
  });

  test('the list empties only once everything is collected', () async {
    // A save opens with silver already in it, so this is the delta.
    final before = await db.currencyDao.getSilverBalance();
    for (final task in kOnboardingTasks) {
      await tasks.markVisited(task.id);
    }
    expect(
      (await tasks.outstanding()).length,
      kOnboardingTasks.length,
      reason: 'an earned task is listed whatever its gate says',
    );
    expect(await tasks.readyCount(), kOnboardingTasks.length);

    expect(await tasks.claimAll(), kOnboardingTasks.length);
    expect(await tasks.outstanding(), isEmpty);
    expect(await tasks.readyCount(), 0);
    expect(
      await db.currencyDao.getSilverBalance() - before,
      kOnboardingTasks.length * kTaskSilverReward,
    );
  });

  test('an unknown id neither earns nor pays', () async {
    final before = await db.currencyDao.getSilverBalance();
    expect(await tasks.markVisited('not_a_task'), isFalse);
    expect(await tasks.claim('not_a_task'), isFalse);
    expect(await db.currencyDao.getSilverBalance(), before);
  });

  group('the definitions themselves', () {
    test('ids are unique — they are storage keys', () {
      final ids = kOnboardingTasks.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      final keys = kOnboardingTasks.map((t) => t.settingKey).toSet();
      expect(keys.length, ids.length);
      final claimKeys = kOnboardingTasks.map((t) => t.claimedKey).toSet();
      expect(claimKeys.length, ids.length);
      expect(keys.intersection(claimKeys), isEmpty);
    });

    test('every task says where it goes', () {
      for (final task in kOnboardingTasks) {
        expect(task.title, isNotEmpty);
        expect(task.blurb, isNotEmpty, reason: '${task.id} needs a why');
      }
    });

    test('tab destinations name a real section', () {
      for (final task in kOnboardingTasks) {
        final section = task.destination.section;
        if (section != null) {
          expect(NavSection.values, contains(section));
        }
      }
    });
  });
}
