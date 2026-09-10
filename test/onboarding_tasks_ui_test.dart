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
    expect(
      find.text('${kOnboardingTasks.length} LEFT'),
      findsOneWidget,
      reason: 'a fresh save owes every task',
    );
    // The first task's row and its way in.
    expect(find.text(kOnboardingTasks.first.title), findsOneWidget);
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
