// The tasks list has to be on the page the player actually opens.
//
// It was first put inside showArchive(), the pushed "STORY PROGRESS"
// sub-screen, which is technically "under the main story" and completely
// invisible unless you go looking. This pins it to the journal's own body,
// and pins that it leaves when the work is done.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/screens/story/campaign_journal_screen.dart';
import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpJournal(WidgetTester tester, AlchemonsDatabase db) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AlchemonsDatabase>.value(value: db),
        ChangeNotifierProvider<TimedBoostService>(
          create: (_) => TimedBoostService(db.settingsDao)..load(),
        ),
        // The task gates ask the shop whether the forge is unlocked.
        ChangeNotifierProvider<ShopService>(
          create: (ctx) => ShopService(
            db,
            ConstellationEffectsService(db),
            FactionService(db),
            ctx.read<TimedBoostService>(),
          ),
        ),
        Provider<FactionTheme>.value(
          value: factionThemeFor(
            FactionId.volcanic,
            brightness: Brightness.dark,
          ),
        ),
      ],
      child: const MaterialApp(home: CampaignJournalScreen()),
    ),
  );
  // The journal and the task list both load asynchronously. Bounded pumps
  // rather than pumpAndSettle: this screen has continuous animation on it,
  // so settling never finishes.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  testWidgets('tasks are on the journal itself, not behind a button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpJournal(tester, db);

    expect(find.text('TASKS'), findsOneWidget);
    // Three of the eight point at places a fresh save has not unlocked, and
    // a task advertising a door that will not open is worse than silence.
    final open = kOnboardingTasks
        .where((t) => t.gate == TaskGate.always)
        .toList();
    expect(find.text('${open.length} LEFT'), findsOneWidget);
    for (final task in kOnboardingTasks) {
      expect(
        find.text(task.title),
        task.gate == TaskGate.always ? findsOneWidget : findsNothing,
        reason: task.id,
      );
    }
    expect(find.text('GO'), findsWidgets);
  });

  testWidgets('the section disappears once every task is done', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      for (final task in kOnboardingTasks) {
        await OnboardingTaskService(db).markVisited(task.id);
      }
    });

    await pumpJournal(tester, db);

    expect(find.text('TASKS'), findsNothing);
    for (final task in kOnboardingTasks) {
      expect(find.text(task.title), findsNothing);
    }
  });
}
