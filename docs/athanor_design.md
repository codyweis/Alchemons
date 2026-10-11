# The Athanor

The furnace on home where a pour draws a cosmetic. It replaces the Daily Treasure Chest. Decided with the author on 2026-10-10.

## Rules

- **What a pour draws.** A pour draws one cosmetic from a **batch**, a themed set of 8–10 pieces. Pieces are drawn **without replacement**: every pour gives a piece the player does not own yet, so a batch of N is finished in at most N pours. The player picks which batch to pour into.
- **Rarity.** Pieces are weighted common ×10, rare ×5, epic ×2, so rarer pieces tend to come later. The **capstone** comes with a batch's last piece and from nowhere else.
- **Paying for a pour.**
  - **Tincture**: 25 per pour (`kAthanorTincturePerPour`; 10 until 2026-10-11, when the one-time sources alone covered most of the content). Tincture is earned in play only and is never sold.
  - **Gold**: 50 per pour (`kAthanorGoldPerPour`). Gold can be bought, so this is a paid random draw. Gold pours are off where the storefront country is Belgium (`BE` / `BEL`). Tincture pours stay on there.
  - **Daily pour**: one free pour a day, on the UTC day, keyed like the chest. It also gives what the chest gave: 150–500 silver, a 15% chance of 1 gold, and a 25% chance of a common vial. When no batch has a piece left (or there are no batches), the day's chest rewards are taken without a draw (`takeDailyExtras`); either way spends the day.
- **Odds.** Before every pour the player can see the odds for the **next** pour: each piece left and its chance. `athanorNextPourOdds` is both the sheet and the draw (`lib/models/athanor.dart`).
- **Cosmetic only.** Nothing in a batch changes power, odds or the economy. Survival orb skins change orb HP and passives, so they never go in. Athanor pieces are never sold in the shop.
- **First fire.** The first time a player opens the Athanor they get 30 tincture (a pour and a bit), plus back-pay: 1 for every achievement and 3 for every dungeon star claimed before the Athanor existed, capped at 90 (`kAthanorFirstFireBackPayCap`). Claims that already paid tincture are counted (`athanor_paid_achievements_v1`, `athanor_paid_stars_v1`) and left out. Stars earned but not yet claimed pay when they are claimed. This is the launch gift for existing saves.

## Earning tincture

| Where | Tincture | Notes |
| --- | --- | --- |
| Survival, run end (death) | waves cleared ÷ 5 (floor) | w10 → 2, w30 → 6, w50 → 10. Quitting pays nothing, like the rest of the run's rewards. Gets its own results row. |
| Raid victory | L1 3, L2 5, L3 8 | In `grantRaidRewards`, plus a reward line |
| Dungeon star, first time | 3 per star | 51 stars in all, in `grantStarReward`, plus a reward line |
| Achievement claim | 1 each (3 until 2026-10-11; achievements already pay gold and silver) | In `CampaignJournalService.claim`, inside its transaction, plus the toast |
| Pureblood rite | completion +5, weekly +3 | In the rite's own transactions |
| Space contest win | 2 × level | One-time per level |

Owning everything takes 50 pours (1,250 tincture). The one-time sources (first fire, achievements, stars, contests) come to about 300 tincture, a dozen pours, so play and the daily pour carry the rest. Play earns about 0.7 of a pour a day for an engaged player (a couple of survival runs and a raid, about 17 tincture), and the daily pour is a whole one, so the daily is the main source: an engaged player finishes in about three to four weeks, and the daily alone takes 50 days. A gold pour (50 gold) is the shortcut.

Tincture is the inventory item `InvKeys.athanorTincture` (`'athanor.tincture'`). Its balance is `inventoryDao.getItemQty`, and grants are `addItemQty` inside the caller's existing transaction. Because it is an inventory row, it travels with save transfer and works with achievement `items` and loot pools.

## Service API (the contract the UI builds against)

`lib/services/athanor_service.dart`, a `ChangeNotifier` provided in `lib/providers/app_providers.dart` and reloaded in `reloadStateAfterSaveRestore`.

```dart
enum AthanorPayment { daily, tincture, gold }

class AthanorDailyExtras {
  final int silver; final int gold;
  final String? vialGroupName;        // ElementalGroup.name; null: no vial
  ElementalGroup? get vialGroup;
}

class AthanorPourResult {
  final AthanorBatch batch;
  final AthanorPiece piece;
  final AthanorPiece? capstone;       // given with this pour: the batch is done
  final AthanorDailyExtras? daily;    // the daily pour's chest rewards
}

class AthanorService extends ChangeNotifier {
  AthanorService(AlchemonsDatabase db, {List<AthanorBatch> batches = kAthanorBatches,
      Random? random, Future<String?> Function()? storefrontCountry,
      CreatureCatalog? catalog, DateTime Function()? clock});  // catalog: the daily vial
  Future<void> load();                          // hydrate everything; safe to call again
  bool get loaded;
  List<AthanorBatch> get batches;
  AthanorBatch? batchById(String batchId);
  Set<String> drawnIn(String batchId);
  bool isComplete(String batchId);
  int get tincture;                             // cached balance, refreshed by load()/pour()
  int get gold;
  bool get dailyPourReady;                      // today's (UTC) free pour not yet taken; read live
  bool get anyPiecesLeft;                       // false: take the daily with takeDailyExtras
  bool get goldPoursAvailable;                  // false in Belgium
  bool canPour(String batchId, AthanorPayment payment);
  List<(AthanorPiece, double)> nextPourOdds(String batchId);
  Future<AthanorPourResult?> pour(String batchId, AthanorPayment payment); // null if not allowed
  Future<AthanorDailyExtras?> takeDailyExtras(); // the daily's chest rewards, no draw; null if not ready
  Future<int> takeFirstFire();                  // 30 + back-pay (≤ 90) once; the amount given, 0 after
  bool ownsPiece(String pieceId);
}
```

`pour` runs in **one transaction**: re-check the payment, spend it, draw, grant the piece (and the capstone), record the draw and, for a daily pour, the day key and the extras. A pour that is not allowed changes nothing. `takeDailyExtras` is one transaction too: the extras and the day key, no draw.

State lives in one settings row, `athanor_v1` (JSON):

```json
{"drawn": {"<batchId>": ["<pieceId>"]}, "capstones": ["<batchId>"], "dailyKey": "2026-10-10", "firstFire": true}
```

It travels with save transfer.

## Granting, by kind

| Kind | Grant | Worn through |
| --- | --- | --- |
| `alchemyEffect` | `inventoryDao.addItemQty(grantRef, 1)` | `applyAlchemyEffect` (uses one up) |
| `homeDecor` | `addItemQty('home.<id>', 1)`; owning more lets more stand per realm | Arrange on home |
| `title` | `profile_titles_v1` (owned + worn), a new small system | Profile header, under the name |

Athanor-only decor and effects get a flag in their catalogs so `ShopService` never makes an offer for them.

## Home and screen

- **Entry point.** An `AthanorEmblem` sits in the chest's bottom-centre slot (`home_screen.dart` ≈2606, the same size budget, 106·hs + 128·hs). It follows the `AlchemyEmblem` pattern, with its own `PassageScene` through `EmblemPassage.pushScene`. When the daily pour is ready, the furnace mouth glows. The emblem re-checks the UTC day on resume, which fixes the chest's stale-after-midnight bug.
- **The screen.** A full-bleed field with the furnace and vessel in grains on black. It has a header with the tincture and gold balances, a strip to pick a batch, and the batch's pieces. Owned pieces are lit; pieces still left are dim ghosts. A counter reads "N of M left" and the capstone is shown sealed.
- **Buttons.** POUR · 10 TINCTURE, POUR · 50 GOLD (absent where gold pours are off), FREE POUR when the daily is ready, and ODDS.
- **The reveal.** Grains pour into the vessel and swirl. They settle into the piece (`GrainAssembly` gather onto a `SpecimenGrains.capture` of its preview), then its name forms in `GrainText`. All motion is eased and flowing, never a burst. The capstone gets a second settle after the piece.
- **Odds sheet.** Every piece left with its chance, grouped by rarity, plus the line "Every pour gives a piece you don't own yet." The capstone is shown as "Comes with the last piece."

## Store disclosures (the author's job)

- **App Store Connect:** declare random paid items in the age rating questionnaire. Guideline 3.1.1 also requires the odds before purchase, which the odds sheet covers.
- **Play Console:** declare random items in the content rating.

## Where it lives (as built, 2026-10-11)

- **Batches**: `lib/models/athanor_batches.dart`, five batches named in English only. Each has 4 common, 3 rare and 3 epic pieces plus a capstone, 55 pieces in all. The fusion style is one of the epics. The piece lists behind them are `docs/athanor/pieces_{wearables,decor,systems}.md`, and the catalog and its reasoning are `docs/crucible/cosmetics_concepts.md`. `test/athanor_batches_test.dart` checks that every piece resolves in its own system and that the shop sells none of them.
- **Kinds and where they're granted**
  - Alchemy effects: `lib/widgets/fx/alchemy_effects/{ink_bloom,quicksilver,gold_leaf,cinnabar,peacock_tail}.dart`.
  - Costumes: `red_king_crown.dart` and `brass_monocle.dart`. Each is exclusive with the party hat or the sunglasses respectively.
  - Faction-free dock sets: `DockSet.athanorOnly`.
  - Titles: `lib/models/profile_titles.dart`.
  - Home decor: 22 pieces in `HomeDecor.athanor`, drawn by `lib/widgets/fx/athanor_decor_art.dart`, with residents' visits in `home_life.dart`. A Curio draw gives 3.
  - The four new systems are owned through `lib/models/owned_cosmetics.dart` and worn through `lib/services/cosmetic_wear_service.dart`:
    - case styles, per creature
    - trails, per creature
    - sigil finishes, one global choice
    - home ambiences, per realm
- **Renders**: `docs/athanor/renders/` for the screen and reveal (`ATHANOR_REAL=1` adds the real batches) and `docs/athanor/content/{wearables,decor,systems}/` for the pieces. `docs/crucible/concepts/` holds the first concept sheets, whose prototype code is gone now that every piece is live.
