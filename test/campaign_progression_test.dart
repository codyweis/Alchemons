import 'dart:convert';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/blood_rebirth_service.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:alchemons/services/mystic_ritual_service.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AlchemonsDatabase db;
  late Creature species;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AlchemonsDatabase(NativeDatabase.memory());
    final catalog =
        jsonDecode(
              await rootBundle.loadString(
                'assets/data/alchemons_creatures.json',
              ),
            )
            as Map;
    species = Creature.fromJson(
      (catalog['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
        (r) => r['id'] == 'LET02',
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> companion([String id = 'favorite']) =>
      db.creatureDao.insertInstance(
        instanceId: id,
        baseId: species.id,
        level: 8,
        xp: 234,
        nickname: 'Still Here',
        statSpeedEnhancement: 2,
        statStrengthEnhancement: 3,
        statSpeedPotential: 81,
        statIntelligencePotential: 82,
        statStrengthPotential: 83,
        statBeautyPotential: 84,
      );

  test(
    'rebirth keeps identity and training, sets 95, and grants once',
    () async {
      await companion();
      final before = (await db.creatureDao.getInstance('favorite'))!;
      final service = BloodRebirthService(db);
      await Future.wait([
        service.transform('favorite', species),
        service.transform('favorite', species),
      ]);
      final after = (await db.creatureDao.getInstance('favorite'))!;
      expect(await db.creatureDao.countBySpecies(species.id), 1);
      expect(after.nickname, before.nickname);
      expect(after.level, before.level);
      expect(after.xp, before.xp);
      expect(after.dominantStats, before.dominantStats);
      expect(after.statStrengthEnhancement, before.statStrengthEnhancement);
      expect(after.variantFaction, 'bloodborn');
      expect([
        after.statSpeedPotential,
        after.statIntelligencePotential,
        after.statStrengthPotential,
        after.statBeautyPotential,
      ], everyElement(95));
      expect(
        after.statSpeed,
        closeTo(
          AlchemonStatSystem.effectiveInternal(
            speciesBase: species.baseStats!.speed,
            level: 8,
            potential: 95,
            enhancementRank: 2,
          ),
          .000001,
        ),
      );
      expect(await db.inventoryDao.getItemQty(InvKeys.alchemyBloodAura), 1);
      expect(
        await db.settingsDao.getSetting(CampaignJournalService.endingKey),
        'favorite',
      );
      expect(await db.select(db.eggs).get(), isEmpty);
    },
  );

  test(
    'failed rebirth rolls back specimen changes and remains retryable',
    () async {
      await companion();
      await db.customStatement(
        "CREATE TRIGGER fail_rebirth BEFORE INSERT ON settings WHEN NEW.key = 'campaign_blood_rebirth_v1' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        BloodRebirthService(db).transform('favorite', species),
        throwsA(anything),
      );
      expect(
        (await db.creatureDao.getInstance('favorite'))!.statSpeedPotential,
        81,
      );
      expect(await db.inventoryDao.getItemQty(InvKeys.alchemyBloodAura), 0);
      expect(
        await db.settingsDao.getSetting(CampaignJournalService.endingKey),
        isNull,
      );
      await db.customStatement('DROP TRIGGER fail_rebirth');
      await BloodRebirthService(db).transform('favorite', species);
      expect(
        (await db.creatureDao.getInstance('favorite'))!.statSpeedPotential,
        95,
      );
    },
  );

  test('missing companion cannot complete the ending', () async {
    await expectLater(
      BloodRebirthService(db).transform('missing', species),
      throwsStateError,
    );
    expect(
      await db.settingsDao.getSetting(CampaignJournalService.endingKey),
      isNull,
    );
  });

  Future<void> commit() async {
    await companion();
    await MysticRitualService(db).commit(
      bossId: 'boss_002',
      speciesId: species.id,
      instanceId: 'favorite',
      snapshotJson: '{"scaleVersion":2,"speedPotential":81}',
    );
    await db.inventoryDao.addItemQty(
      BossLootKeys.traitKeyForElement('Water'),
      1,
    );
  }

  Future<void> summon() => MysticRitualService(db).summon(
    bossId: 'boss_002',
    element: 'Water',
    targetSpeciesId: 'MYS02',
    requiredSpecies: {species.id},
    payload: (_) => {'baseId': 'MYS02', 'source': 'boss_summon'},
  );

  test(
    'failed commitment cannot delete a specimen or leave a ghost slot',
    () async {
      await companion();
      await db.customStatement(
        "CREATE TRIGGER fail_commit BEFORE DELETE ON creature_instances BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        MysticRitualService(db).commit(
          bossId: 'boss_002',
          speciesId: species.id,
          instanceId: 'favorite',
          snapshotJson: '{}',
        ),
        throwsA(anything),
      );
      expect(await db.creatureDao.getInstance('favorite'), isNotNull);
      expect(await db.altarDao.getPlacementsForBoss('boss_002'), isEmpty);
    },
  );

  test('full chambers use storage and do not purchase a new slot', () async {
    await commit();
    final slots = await db.select(db.incubatorSlots).get();
    for (final slot in slots) {
      await db.incubatorDao.placeEgg(
        slotId: slot.id,
        eggId: 'occupied_${slot.id}',
        resultCreatureId: 'LET01',
        rarity: 'Common',
        hatchAtUtc: DateTime.now().toUtc(),
      );
    }
    await summon();
    expect((await db.select(db.incubatorSlots).get()).length, slots.length);
    expect((await db.select(db.eggs).get()).single.resultCreatureId, 'MYS02');
    expect(await db.altarDao.getPlacementsForBoss('boss_002'), isEmpty);
    expect(
      await db.settingsDao.getSetting('altar_summoned_boss_002'),
      isNotNull,
    );
  });

  test(
    'failed summoning preserves commitments and does not duplicate its vial',
    () async {
      await commit();
      await db.customStatement(
        "CREATE TRIGGER fail_summon BEFORE INSERT ON settings WHEN NEW.key = 'altar_summoned_boss_002' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(summon(), throwsA(anything));
      expect(await db.altarDao.getPlacementsForBoss('boss_002'), hasLength(1));
      expect(
        (await db.select(db.incubatorSlots).get()).where(
          (s) => s.resultCreatureId == 'MYS02',
        ),
        isEmpty,
      );
      expect(await db.select(db.eggs).get(), isEmpty);
      await db.customStatement('DROP TRIGGER fail_summon');
      await summon();
      await expectLater(summon(), throwsStateError);
      final chamber = (await db.select(db.incubatorSlots).get())
          .where((s) => s.resultCreatureId == 'MYS02')
          .length;
      final storage = (await db.select(db.eggs).get())
          .where((s) => s.resultCreatureId == 'MYS02')
          .length;
      expect(chamber + storage, 1);
    },
  );

  test('Blood ritual cannot bypass the 16 recorded witnesses', () async {
    await db.altarDao.placeAlchemon(
      bossId: 'boss_017',
      speciesId: 'LET17',
      instanceId: 'paid',
    );
    await db.inventoryDao.addItemQty(
      BossLootKeys.traitKeyForElement('Blood'),
      1,
    );
    await expectLater(
      MysticRitualService(db).summon(
        bossId: 'boss_017',
        element: 'Blood',
        targetSpeciesId: 'MYS17',
        requiredSpecies: {'LET17'},
        payload: (_) => {},
      ),
      throwsStateError,
    );
    expect(await db.altarDao.getPlacementsForBoss('boss_017'), hasLength(1));
  });

  test('repeated achievement taps grant a single gold/silver payout', () async {
    await db.settingsDao.setSetting('first_extraction_done', '1');
    final service = CampaignJournalService(db);
    final gold = await db.currencyDao.getGoldBalance();
    final silver = await db.currencyDao.getSilverBalance();
    final results = await Future.wait([
      service.claim('first_extraction'),
      service.claim('first_extraction'),
    ]);
    expect(results.where((r) => r), hasLength(1));
    expect(await db.currencyDao.getGoldBalance(), gold + 1);
    expect(await db.currencyDao.getSilverBalance(), silver + 100);
    expect(await service.claim('ending'), isFalse);
    expect(await service.claim('invented'), isFalse);
  });

  test('a payout failure rolls back its claim marker and currency', () async {
    await db.settingsDao.setSetting('first_extraction_done', '1');
    final gold = await db.currencyDao.getGoldBalance();
    await db.customStatement(
      "CREATE TRIGGER fail_claim BEFORE INSERT ON settings WHEN NEW.key = 'wallet_silver' BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    await expectLater(
      CampaignJournalService(db).claim('first_extraction'),
      throwsA(anything),
    );
    expect(
      await db.settingsDao.getSetting('campaign_claim_first_extraction'),
      isNull,
    );
    expect(await db.currencyDao.getGoldBalance(), gold);
  });

  test(
    'wave reached is not credited as cleared, actual clears bank immediately',
    () async {
      final service = CampaignJournalService(db);
      await db.settingsDao.setSetting('cosmic_survival_best_wave', '20');
      expect(await service.claim('survival_20'), isFalse);
      await service.recordSurvivalClear(20);
      await service.recordSurvivalClear(5);
      expect(await service.claim('survival_20'), isTrue);
      expect(await service.claim('survival_50'), isFalse);
      await service.recordSurvivalClear(50);
      expect(await service.claim('survival_50'), isTrue);
    },
  );

  test('launched but unfinished memory recovers after interruption', () async {
    final s = db.settingsDao;
    await CosmicMemoryTutorialService.markHarvestTutorialCompleted(s);
    await CosmicMemoryTutorialService.markHomePortalLaunched(s);
    await CosmicMemoryTutorialService.recoverPendingForExistingProfile(
      s,
      ownedInstanceCount: 3,
    );
    expect(await CosmicMemoryTutorialService.isHomePortalPending(s), isTrue);
    await CosmicMemoryTutorialService.markCompleted(s);
    await CosmicMemoryTutorialService.recoverPendingForExistingProfile(
      s,
      ownedInstanceCount: 3,
    );
    expect(await CosmicMemoryTutorialService.isHomePortalPending(s), isFalse);
  });

  test('memory story stays pending until the reader acknowledges it', () async {
    final s = db.settingsDao;
    await CosmicMemoryTutorialService.markCompleted(s);
    expect(await CosmicMemoryTutorialService.isStoryPending(s), isTrue);
    expect(await CosmicMemoryTutorialService.isStoryPending(s), isTrue);
    await CosmicMemoryTutorialService.acknowledgeStory(s);
    expect(await CosmicMemoryTutorialService.isStoryPending(s), isFalse);
  });

  test('queued story survives restart until the reader finishes it', () async {
    final first = StoryManager(db.settingsDao);
    await first.loadSeen();
    first.trigger(StoryEvent.firstBreeding);
    expect(first.drainQueue(), isNotEmpty);
    final restarted = StoryManager(db.settingsDao);
    await restarted.loadSeen();
    expect(restarted.hasSeen(StoryEvent.firstBreeding), isFalse);
    restarted.trigger(StoryEvent.firstBreeding);
    expect(restarted.drainQueue(), isNotEmpty);
    await restarted.acknowledge(StoryEvent.firstBreeding);
    final completed = StoryManager(db.settingsDao);
    await completed.loadSeen();
    completed.trigger(StoryEvent.firstBreeding);
    expect(completed.drainQueue(), isEmpty);
    first.dispose();
    restarted.dispose();
    completed.dispose();
  });

  test('legacy ship owners are not sent back to the starter mission', () async {
    await db.settingsDao.setSetting('cosmic_ship_unlocked', '1');
    final snapshot = await CampaignJournalService(db).load();
    expect(snapshot.currentMission?.id, 'revelation');
    expect(snapshot.metrics['extraction'], 1);
  });
  test(
    'main missions advance through the whole campaign without requiring claims',
    () {
      final metrics = <String, int>{};
      for (final mission in campaignMissions) {
        final snapshot = CampaignSnapshot(metrics, {}, {});
        expect(snapshot.currentMission?.id, mission.id);
        metrics[mission.metric] = mission.target;
      }
      final completed = CampaignSnapshot(metrics, {}, {});
      expect(completed.currentMission, isNull);
      expect(
        completed.ready.where((a) => campaignMissionIds.contains(a.id)),
        hasLength(10),
      );
    },
  );

  test(
    'late story rewards are claimable once and old story claims remain honored',
    () async {
      final service = CampaignJournalService(db);
      await db.settingsDao.setSetting('altar_summoned_boss_017', 'complete');
      await db.settingsDao.setSetting('campaign_claim_first_extraction', '1');
      await db.settingsDao.setSetting('first_extraction_done', '1');
      expect(await service.claim('first_extraction'), isFalse);
      expect(await service.claim('blood_mystic'), isTrue);
      expect(await service.claim('blood_mystic'), isFalse);
    },
  );
}
