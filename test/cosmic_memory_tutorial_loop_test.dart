import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;

  setUp(() {
    db = AlchemonsDatabase(NativeDatabase.memory());
    CosmicMemoryTutorialService.resetSessionDeferral();
  });

  tearDown(() async {
    await db.close();
    CosmicMemoryTutorialService.resetSessionDeferral();
  });

  Future<void> queueTutorial() =>
      CosmicMemoryTutorialService.debugQueueTutorial(db.settingsDao);

  Future<void> recover() =>
      CosmicMemoryTutorialService.recoverPendingForExistingProfile(
        db.settingsDao,
        ownedInstanceCount: 0,
      );

  test('an abandoned memory is re-queued so it is not lost', () async {
    await queueTutorial();
    await CosmicMemoryTutorialService.markHomePortalLaunched(db.settingsDao);

    // Left without finishing: no completion marker was ever written.
    expect(await CosmicMemoryTutorialService.isCompleted(db.settingsDao), false);

    await recover();

    expect(
      await CosmicMemoryTutorialService.isHomePortalPending(db.settingsDao),
      true,
    );
  });

  test('abandoning defers the relaunch for the rest of the session', () async {
    await queueTutorial();
    await CosmicMemoryTutorialService.markHomePortalLaunched(db.settingsDao);

    expect(CosmicMemoryTutorialService.isDeferredThisSession, false);
    CosmicMemoryTutorialService.deferForThisSession();

    // Still queued for next launch...
    await recover();
    expect(
      await CosmicMemoryTutorialService.isHomePortalPending(db.settingsDao),
      true,
    );
    // ...but home will not act on it again until the process restarts, which is
    // what stops the relaunch loop.
    expect(CosmicMemoryTutorialService.isDeferredThisSession, true);
  });

  test('a fresh session picks the abandoned memory back up', () async {
    await queueTutorial();
    await CosmicMemoryTutorialService.markHomePortalLaunched(db.settingsDao);
    CosmicMemoryTutorialService.deferForThisSession();

    // A new process starts with no deferral; the flag never persisted.
    CosmicMemoryTutorialService.resetSessionDeferral();

    await recover();
    expect(CosmicMemoryTutorialService.isDeferredThisSession, false);
    expect(
      await CosmicMemoryTutorialService.isHomePortalPending(db.settingsDao),
      true,
    );
  });

  test('completing it stops the re-queue for good', () async {
    await queueTutorial();
    await CosmicMemoryTutorialService.markHomePortalLaunched(db.settingsDao);
    await CosmicMemoryTutorialService.markCompleted(db.settingsDao);

    expect(await CosmicMemoryTutorialService.isCompleted(db.settingsDao), true);

    await recover();

    expect(
      await CosmicMemoryTutorialService.isHomePortalPending(db.settingsDao),
      false,
    );
    // The closing story line is queued exactly once.
    expect(await CosmicMemoryTutorialService.isStoryPending(db.settingsDao), true);
    await CosmicMemoryTutorialService.acknowledgeStory(db.settingsDao);
    expect(
      await CosmicMemoryTutorialService.isStoryPending(db.settingsDao),
      false,
    );
  });

  test('re-queuing from the debug menu clears a session deferral', () async {
    CosmicMemoryTutorialService.deferForThisSession();
    expect(CosmicMemoryTutorialService.isDeferredThisSession, true);

    await queueTutorial();

    expect(CosmicMemoryTutorialService.isDeferredThisSession, false);
    expect(
      await CosmicMemoryTutorialService.isHomePortalPending(db.settingsDao),
      true,
    );
  });
}
