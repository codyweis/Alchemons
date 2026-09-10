// Tasks are a map, not a scoreboard.
//
// They point at rooms the player may not know exist, pay a flat rate for
// walking in, and leave the list once walked. Arriving is the whole
// requirement — the arrival IS the lesson — which means the marking happens
// in a screen's initState and will fire on every single visit. The one thing
// that must hold is that it only ever pays once.

import 'package:alchemons/database/alchemons_db.dart';
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

  test('a fresh save owes every task', () async {
    expect(await tasks.completed(), isEmpty);
    expect((await tasks.outstanding()).length, kOnboardingTasks.length);
  });

  test('arriving pays once, and only once', () async {
    final before = await db.currencyDao.getSilverBalance();

    expect(await tasks.markVisited('shop'), isTrue);
    expect(await db.currencyDao.getSilverBalance(), before + kTaskSilverReward);

    // initState fires again on every revisit; it must not pay again.
    expect(await tasks.markVisited('shop'), isFalse);
    expect(await tasks.markVisited('shop'), isFalse);
    expect(
      await db.currencyDao.getSilverBalance(),
      before + kTaskSilverReward,
      reason: 'a task cannot be farmed by walking in and out',
    );
  });

  test('a finished task leaves the list', () async {
    await tasks.markVisited('rite');
    final left = await tasks.outstanding();
    expect(left.map((t) => t.id), isNot(contains('rite')));
    expect(left.length, kOnboardingTasks.length - 1);
  });

  test('the list empties completely', () async {
    // A save opens with silver already in it, so this is the delta.
    final before = await db.currencyDao.getSilverBalance();
    for (final task in kOnboardingTasks) {
      await tasks.markVisited(task.id);
    }
    expect(await tasks.outstanding(), isEmpty);
    expect(
      await db.currencyDao.getSilverBalance() - before,
      kOnboardingTasks.length * kTaskSilverReward,
    );
  });

  test('an unknown id pays nothing', () async {
    final before = await db.currencyDao.getSilverBalance();
    expect(await tasks.markVisited('not_a_task'), isFalse);
    expect(await db.currencyDao.getSilverBalance(), before);
  });

  group('the definitions themselves', () {
    test('ids are unique — they are storage keys', () {
      final ids = kOnboardingTasks.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      final keys = kOnboardingTasks.map((t) => t.settingKey).toSet();
      expect(keys.length, ids.length);
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
