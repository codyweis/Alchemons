// lib/games/stadium/cup_rewards.dart
//
// What winning a cup in the Trials gives (the author, 2026-10-12) — a race
// cup or a gem cup alike: its cup as a keepsake for the home realm
// (home_keepsakes.dart), a title (profile_titles.dart), and its
// spotlight, an alchemy effect. The keepsake
// and the title are read off the Trials' progress wherever they show, so
// nothing can disagree; the spotlight is an item, given once for each cup.
//
// The Gold Cup and the gem cups also give what the retired space contests
// gave for mastering a stat (the author, 2026-10-12: "transfer their
// rewards to our new trials"): Speed with the Gold Cup's races, Strength
// with the Ruby island, Beauty with the Sapphire sky, Intelligence with the
// Emerald course — the stat's effect (unlocked in the shop, one given) and
// its keepsake. A save that mastered the contest keeps both.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/profile_titles.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';

class CupReward {
  const CupReward({
    required this.cupId,
    required this.name,
    required this.metal,
    required this.keepsake,
    required this.title,
    required this.effectItem,
    required this.effectName,
    this.statOffer,
    this.statEffectName,
    this.statKeepsake,
  });

  /// The cup: a race cup's or a gem cup's id, its name, what it is made of.
  final String cupId, name;
  final TrophyMetal metal;

  /// The keepsake's id, the title's id, and the spotlight's item and name
  /// (as the inventory calls it).
  final String keepsake, title, effectItem, effectName;

  String get keepsakeName => Keepsake.byId(keepsake)?.title ?? name;
  String get titleWords => kCupTitles[title]?.$2 ?? '';

  /// The effect the spotlight puts on an Alchemon.
  String get effect => InvKeys.alchemyEffectFor(effectItem) ?? '';

  /// What a stat's contest gave, for the cups that give it now: the shop
  /// offer its effect is unlocked as, the effect's name, and its keepsake.
  final String? statOffer, statEffectName, statKeepsake;

  String? get statKeepsakeName =>
      statKeepsake == null ? null : Keepsake.byId(statKeepsake!)?.title;
}

/// Every cup's, the races' then the gems'.
const List<CupReward> kCupRewards = [
  CupReward(
    cupId: 'copper',
    name: 'Copper Cup',
    metal: TrophyMetal.copper,
    keepsake: 'copper_cup',
    title: 'trials.copper',
    effectItem: InvKeys.alchemyCopperSpotlight,
    effectName: 'Copper Spotlight',
  ),
  CupReward(
    cupId: 'silver',
    name: 'Silver Cup',
    metal: TrophyMetal.silver,
    keepsake: 'silver_cup',
    title: 'trials.silver',
    effectItem: InvKeys.alchemySilverSpotlight,
    effectName: 'Silver Spotlight',
  ),
  CupReward(
    cupId: 'gold',
    name: 'Gold Cup',
    metal: TrophyMetal.gold,
    keepsake: 'gold_cup',
    title: 'trials.gold',
    effectItem: InvKeys.alchemyGoldSpotlight,
    effectName: 'Gold Spotlight',
    statOffer: ShopService.speedContestEffectOfferId,
    statEffectName: 'Speed Flux',
    statKeepsake: 'victory_arch',
  ),
  CupReward(
    cupId: 'ruby',
    name: 'Ruby Cup',
    metal: TrophyMetal.ruby,
    keepsake: 'ruby_cup',
    title: 'trials.ruby',
    effectItem: InvKeys.alchemyRubySpotlight,
    effectName: 'Ruby Spotlight',
    statOffer: ShopService.strengthContestEffectOfferId,
    statEffectName: 'Strength Forge',
    statKeepsake: 'titan_anvil',
  ),
  CupReward(
    cupId: 'sapphire',
    name: 'Sapphire Cup',
    metal: TrophyMetal.sapphire,
    keepsake: 'sapphire_cup',
    title: 'trials.sapphire',
    effectItem: InvKeys.alchemySapphireSpotlight,
    effectName: 'Sapphire Spotlight',
    statOffer: ShopService.beautyContestEffectOfferId,
    statEffectName: 'Beauty Radiance',
    statKeepsake: 'crown_mirror',
  ),
  CupReward(
    cupId: 'emerald',
    name: 'Emerald Cup',
    metal: TrophyMetal.emerald,
    keepsake: 'emerald_cup',
    title: 'trials.emerald',
    effectItem: InvKeys.alchemyEmeraldSpotlight,
    effectName: 'Emerald Spotlight',
    statOffer: ShopService.intelligenceContestEffectOfferId,
    statEffectName: 'Intelligence Halo',
    statKeepsake: 'prism_orrery',
  ),
];

/// Unlocks the stat effect of each cup [progress] has won (its first one
/// given free) — for a save that won the cup before cups gave it, too. Safe
/// to call again: an effect already unlocked (by the cup, or by a contest
/// mastered before contests were retired) gives nothing more. The cups
/// whose effect was unlocked now.
Future<List<CupReward>> unlockCupStatEffects(
  ShopService shop,
  RaceProgress progress,
) async {
  final out = <CupReward>[];
  for (final r in kCupRewards) {
    final offer = r.statOffer;
    if (offer == null || !trialsCupDone(progress, r.cupId)) continue;
    if (await shop.unlockContestEffectOffer(offer, freeQty: 1) != null) {
      out.add(r);
    }
  }
  return out;
}

/// Where the save keeps that a cup's spotlight has been given.
String cupGivenKey(String cupId) => 'trials_cup_given.$cupId';

/// Gives the spotlight of each cup [progress] has won that has not been
/// given it yet (a save that won one before rewards existed gets it the
/// next time the Trials open). The rewards given now, in cup order.
Future<List<CupReward>> giveCupRewards(
  AlchemonsDatabase db,
  RaceProgress progress,
) => db.transaction(() async {
  final out = <CupReward>[];
  for (final r in kCupRewards) {
    if (!trialsCupDone(progress, r.cupId)) continue;
    final key = cupGivenKey(r.cupId);
    if (await db.settingsDao.getSetting(key) == '1') continue;
    await db.inventoryDao.addItemQty(r.effectItem, 1);
    await db.settingsDao.setSetting(key, '1');
    out.add(r);
  }
  return out;
});
