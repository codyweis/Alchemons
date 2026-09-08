import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalEntry {
  const JournalEntry(this.id, this.title, this.text);
  final String id;
  final String title;
  final String text;
}

/// The presence remembers what the alchemist has chosen to forget.
const campaignEntries = [
  JournalEntry(
    'awakening',
    'Waking',
    'You made somewhere beautiful enough to wake without remembering why you needed it.',
  ),
  JournalEntry(
    'extraction',
    'The first form',
    'A living thing leaves the vial. You call it a discovery. The word comes easily.',
  ),
  JournalEntry(
    'memory',
    'A memory returns',
    'Am I beginning to remember? But what is remembrance without truth, if not illusion.',
  ),
  JournalEntry(
    'ship',
    'Beyond the valley',
    'You follow the ship beyond the world that soothed you. Something there remembers your work.',
  ),
  JournalEntry(
    'revelation',
    'Beauty obstructs reality',
    'You did not make the valley to hide the world from danger. You made it to hide your work from yourself.',
  ),
  JournalEntry(
    'guardian',
    'The first relic',
    'It was guarding this place from alchemy. You have called what remains a relic.',
  ),
  JournalEntry(
    'mystic',
    'Another creature',
    'The guardian resisted you. The creature you make from its relic will enter your collection. You know the difference. You continue.',
  ),
  JournalEntry(
    'blood',
    'The last guardian',
    'Nothing beautiful stands between you and your work now. Still, you prepare another ritual.',
  ),
  JournalEntry(
    'ending',
    'Rebirth',
    'You called it sacrifice. You kept what you wanted. Once, you made a world to escape this hunger. Now you remember, and your hands return to their work.',
  ),
];

class CampaignAchievement {
  const CampaignAchievement(
    this.id,
    this.title,
    this.description,
    this.metric,
    this.target,
    this.gold,
    this.silver,
  );
  final String id, title, description, metric;
  final int target, gold, silver;
}

const campaignAchievements = [
  CampaignAchievement(
    'blood_guardian',
    'The last guardian',
    'Overcome Sanguorath on Hemavorn.',
    'bloodGuardian',
    1,
    4,
    500,
  ),
  CampaignAchievement(
    'witnesses_16',
    'Sixteen witnesses',
    'Complete all 16 non-Blood Mystic rituals.',
    'witnesses',
    16,
    8,
    1000,
  ),
  CampaignAchievement(
    'blood_mystic',
    'The final form',
    'Complete the Blood Mystic ritual.',
    'bloodMystic',
    1,
    5,
    750,
  ),
  CampaignAchievement(
    'collection_10',
    'First specimens',
    'Discover 10 species.',
    'collection',
    10,
    1,
    100,
  ),
  CampaignAchievement(
    'collection_25',
    'A growing collection',
    'Discover 25 species.',
    'collection',
    25,
    2,
    250,
  ),
  CampaignAchievement(
    'collection_50',
    'The collector',
    'Discover 50 species.',
    'collection',
    50,
    3,
    500,
  ),
  CampaignAchievement(
    'collection_100',
    'A hundred forms',
    'Discover 100 species.',
    'collection',
    100,
    5,
    1000,
  ),
  CampaignAchievement(
    'collection_all',
    'Every form',
    'Discover every catalog species.',
    'collectionPercent',
    100,
    10,
    1500,
  ),
  CampaignAchievement(
    'first_extraction',
    'Awakened',
    'Extract your first specimen.',
    'extraction',
    1,
    1,
    100,
  ),
  CampaignAchievement(
    'ship',
    'Beyond the veil',
    'Recover the cosmic ship.',
    'ship',
    1,
    2,
    200,
  ),
  CampaignAchievement(
    'revelation',
    'Beauty falls away',
    'Witness the first planetary revelation.',
    'revelation',
    1,
    2,
    250,
  ),
  CampaignAchievement(
    'guardian_1',
    'What remained',
    'Overcome a planetary guardian.',
    'guardians',
    1,
    2,
    250,
  ),
  CampaignAchievement(
    'guardian_16',
    'The unsealed worlds',
    'Overcome all 16 non-Blood guardians.',
    'guardians',
    16,
    8,
    1000,
  ),
  CampaignAchievement(
    'mystic_1',
    'A familiar practice',
    'Complete a Mystic summoning ritual.',
    'mystics',
    1,
    2,
    250,
  ),
  CampaignAchievement(
    'ending',
    'Reborn',
    'Complete the Blood Ring ritual.',
    'ending',
    1,
    10,
    1500,
  ),
  CampaignAchievement(
    'survival_20',
    'Through the plague',
    'Clear Survival wave 20.',
    'survivalCleared',
    20,
    3,
    300,
  ),
  CampaignAchievement(
    'survival_50',
    'The fiftieth silence',
    'Clear Survival wave 50.',
    'survivalCleared',
    50,
    8,
    1000,
  ),
  CampaignAchievement(
    'rites_5',
    'Five offerings',
    'Complete five Pureblood rites.',
    'rites',
    5,
    3,
    400,
  ),
  CampaignAchievement(
    'speed_win',
    'Ahead of the wind',
    'Win a Speed contest round.',
    'speed',
    1,
    2,
    250,
  ),
  CampaignAchievement(
    'beauty_win',
    'The judges approve',
    'Win a Beauty contest round.',
    'beauty',
    1,
    2,
    250,
  ),
  CampaignAchievement(
    'strength_win',
    'An answer in force',
    'Win a Strength contest round.',
    'strength',
    1,
    2,
    250,
  ),
  CampaignAchievement(
    'intelligence_win',
    'A pattern understood',
    'Win an Intelligence contest round.',
    'intelligence',
    1,
    2,
    250,
  ),
];

/// Existing achievement IDs are also mission rewards: one milestone, one payout.
const campaignMissionIds = [
  'first_extraction',
  'ship',
  'revelation',
  'guardian_1',
  'mystic_1',
  'guardian_16',
  'blood_guardian',
  'witnesses_16',
  'blood_mystic',
  'ending',
];

final campaignMissions = [
  for (final id in campaignMissionIds)
    campaignAchievements.firstWhere((a) => a.id == id),
];

const campaignMissionInstructions = {
  'first_extraction': 'Open your Chamber and extract the starter vial.',
  'ship':
      'Finish the wilderness fusion and harvest tutorials. Visit Valley, Sky, Swamp, and Volcano, then return to Valley to recover the ship.',
  'revelation':
      'In cosmic space, complete a planet’s elemental gate offering. Assemble its required descent party and enter.',
  'guardian_1':
      'Explore a planet, reach its guardian, and defeat it to claim its relic.',
  'mystic_1':
      'Take a guardian relic to the Mystic Altar. Commit every required non-Mystic species of its element and perform the ritual.',
  'guardian_16':
      'Overcome all 16 non-Blood planetary guardians. Their relics unlock the corresponding Mystic rituals.',
  'blood_guardian':
      'Complete Hemavorn’s gate offering, descend with Blood, Dark, and Light, and overcome Sanguorath.',
  'witnesses_16':
      'Complete all 16 non-Blood Mystic rituals. Each needs its guardian relic and the required specimens. The altar remembers completed summons.',
  'blood_mystic':
      'At the Blood altar, commit all eight required Blood species and use the Blood relic to perform the final Mystic ritual.',
  'ending':
      'Extract Sanguorath, summon it in cosmic space, and bring another companion in reserve to the Blood Ring. That companion becomes Bloodborn with 95 in all four Potentials.',
};

class CampaignSnapshot {
  const CampaignSnapshot(this.metrics, this.seen, this.claimed);
  final Map<String, int> metrics;
  final Set<String> seen, claimed;
  int progress(CampaignAchievement a) => min(a.target, metrics[a.metric] ?? 0);
  bool earned(CampaignAchievement a) => progress(a) >= a.target;
  List<CampaignAchievement> get ready => campaignAchievements
      .where((a) => earned(a) && !claimed.contains(a.id))
      .toList();
  CampaignAchievement? get currentMission {
    if ((metrics['ending'] ?? 0) > 0) return null;
    for (final mission in campaignMissions) {
      if (!earned(mission)) return mission;
    }
    return null;
  }

  String get objective => currentMission == null
      ? 'The ritual is complete. The collection remains. Survival, contests, rites, constellations, and exploration are yours to continue.'
      : campaignMissionInstructions[currentMission!.id]!;
}

class CampaignJournalService {
  CampaignJournalService(this.db);
  final AlchemonsDatabase db;
  static const revelationKey = 'campaign_revelation_seen_v1';
  static const endingKey = 'campaign_blood_rebirth_v1';
  static const _seenKey = 'campaign_journal_seen_v1';
  static Future<Set<String>>? _catalogIds;

  static Set<String> _decodeSet(String? raw) {
    try {
      return (jsonDecode(raw ?? '[]') as List).whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> record(String id) => db.transaction(() async {
    if (!campaignEntries.any((e) => e.id == id)) return;
    final seen = _decodeSet(await db.settingsDao.getSetting(_seenKey))..add(id);
    await db.settingsDao.setSetting(_seenKey, jsonEncode(seen.toList()));
  });

  Future<CampaignSnapshot> load() async {
    final settings = {
      for (final r in await db.select(db.settings).get()) r.key: r.value,
    };
    final prefs = await SharedPreferences.getInstance();
    final stars = PlanetStarState.deserialise(
      prefs.getString('cosmic_planet_stars') ?? '',
    );
    final contests = CosmicContestProgress.deserialise(
      prefs.getString('cosmic_trait_contests_v1') ?? '',
    );
    final ids = await (_catalogIds ??= rootBundle
        .loadString('assets/data/alchemons_creatures.json')
        .then((raw) {
          final rows =
              (jsonDecode(raw) as Map<String, dynamic>)['creatures'] as List;
          return rows.map((r) => r['id'] as String).toSet();
        }));
    final discovered = (await db.select(db.playerCreatures).get())
        .where((r) => r.discovered && ids.contains(r.id))
        .length;
    bool flag(String key) => settings[key] == '1';
    bool summoned(String id) =>
        (settings['altar_summoned_$id'] ?? '').isNotEmpty;
    final witnesses = kAltarEntries
        .where((e) => e.order < 17 && summoned(e.id))
        .length;
    final blood = summoned('boss_017');
    final ring = BloodRing.deserialise(
      prefs.getString('cosmic_blood_ring_v1') ?? '',
    );
    final legacyScore = await db.getSurvivalHighScore();
    final reached = max(
      int.tryParse(settings['cosmic_survival_best_wave'] ?? '') ?? 0,
      legacyScore?.bestWave ?? 0,
    );
    final metrics = <String, int>{
      'collection': discovered,
      'collectionPercent': ids.isEmpty ? 0 : discovered * 100 ~/ ids.length,
      // Older profiles can predate the starter flag. Recovering the ship
      // already requires the starter sequence; never send them back to it.
      'extraction':
          flag('first_extraction_done') || flag('cosmic_ship_unlocked') ? 1 : 0,
      'ship': flag('cosmic_ship_unlocked') ? 1 : 0,
      'revelation': flag(revelationKey) ? 1 : 0,
      'guardians': kCosmicPlanetEntry.keys
          .where((e) => e != 'Blood' && stars.hasStar(e, 2))
          .length,
      'bloodGuardian': stars.hasStar('Blood', 2) ? 1 : 0,
      'witnesses': witnesses,
      'mystics': witnesses + (blood ? 1 : 0),
      'bloodMystic': blood ? 1 : 0,
      'ending': (settings[endingKey] ?? '').isNotEmpty || ring.ritualCompleted
          ? 1
          : 0,
      // A saved wave is the wave reached, not the wave cleared.
      'survivalCleared': max(
        max(0, reached - 1),
        int.tryParse(settings['campaign_survival_cleared_v1'] ?? '') ?? 0,
      ),
      'rites':
          (int.tryParse(settings['pureblood_rite_stage_index_v2'] ?? '') ?? 0) +
          (int.tryParse(settings['campaign_weekly_rites_v1'] ?? '') ?? 0),
      for (final t in CosmicContestTrait.values)
        t.name: contests.completedLevels(t),
    };
    final seen = _decodeSet(settings[_seenKey]);
    // Recover milestone records for older saves without inventing missing quotes.
    if (metrics['extraction'] == 1) seen.addAll(['awakening', 'extraction']);
    if (flag('cosmic_memory_tutorial_completed_v1')) seen.add('memory');
    if (metrics['ship'] == 1) seen.add('ship');
    if (metrics['revelation'] == 1) seen.add('revelation');
    if (metrics['guardians']! > 0) seen.add('guardian');
    if (metrics['mystics']! > 0) seen.add('mystic');
    if (metrics['bloodGuardian'] == 1) seen.add('blood');
    if (metrics['ending'] == 1) seen.add('ending');
    return CampaignSnapshot(metrics, seen, {
      for (final a in campaignAchievements)
        if (flag('campaign_claim_${a.id}')) a.id,
    });
  }

  /// Validate current progress inside the transaction; never trust UI state.
  Future<void> recordSurvivalClear(int wave) => db.transaction(() async {
    final previous =
        int.tryParse(
          await db.settingsDao.getSetting('campaign_survival_cleared_v1') ?? '',
        ) ??
        0;
    if (wave > previous) {
      await db.settingsDao.setSetting(
        'campaign_survival_cleared_v1',
        wave.toString(),
      );
    }
  });

  Future<bool> claim(String id) => db.transaction(() async {
    final matches = campaignAchievements.where((a) => a.id == id);
    if (matches.isEmpty) return false;
    final a = matches.first;
    final snapshot = await load();
    if (!snapshot.earned(a) || snapshot.claimed.contains(id)) return false;
    await db.settingsDao.setSetting('campaign_claim_$id', '1');
    await db.currencyDao.addGold(a.gold);
    await db.currencyDao.addSilver(a.silver);
    return true;
  });
}
