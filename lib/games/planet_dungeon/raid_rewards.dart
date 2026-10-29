import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
// lib/games/planet_dungeon/raid_rewards.dart
//
// Raid victory loot escalates by level: one to three elemental cache rolls,
// one to four power-up orbs, increasing currency and tincture. Potential
// Souls are exclusive to level 3. The caller advances the persisted raid
// afterward.

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/games/planet_dungeon/reward_popup_parts.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/potential_soul.dart';
import 'package:alchemons/screens/inventory_screen.dart'
    show InventoryImageHelper;
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/grain_loader.dart';
import 'package:flutter/material.dart';

class RaidRewardEntry {
  final String? itemKey; // null = currency line
  final String label;
  const RaidRewardEntry({this.itemKey, required this.label});
}

/// Grant the raid's loot and return display entries for the popup.
Future<List<RaidRewardEntry>> grantRaidRewards({
  required AlchemonsDatabase db,
  required String element,
  required int raidLevel,
  Random? rng,
}) async {
  final r = rng ?? Random();
  final entries = <RaidRewardEntry>[];
  final registry = buildInventoryRegistry(db);

  final level = raidLevel.clamp(1, 3);

  // Cache volume rises one-for-one with raid level.
  final drops = LootBoxConfig.rollBossLootBoxDropsForQuantity(
    BossLootKeys.lootBoxKeyForElement(element),
    level,
    r,
  );
  for (final drop in drops) {
    await db.inventoryDao.addItemQty(drop.key, drop.value);
    final name = registry[drop.key]?.name ?? drop.key;
    entries.add(
      RaidRewardEntry(itemKey: drop.key, label: '+${drop.value} $name'),
    );
  }

  final orbs = LootBoxConfig.rollRaidPowerupDropsForLevel(level, r);
  for (final orb in orbs) {
    await db.inventoryDao.addItemQty(orb.key, orb.value);
    final name = registry[orb.key]?.name ?? orb.key;
    entries.add(
      RaidRewardEntry(itemKey: orb.key, label: '+${orb.value} $name'),
    );
  }

  // Potential-altering currency belongs exclusively to the final tier.
  if (level == 3 && PotentialSoulRules.rollsFromRaid(r)) {
    await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 1);
    final name = registry[InvKeys.potentialSoul]?.name ?? 'Potential Soul';
    entries.add(
      RaidRewardEntry(itemKey: InvKeys.potentialSoul, label: '+1 $name'),
    );
  }

  final currency = LootBoxConfig.rollRaidVictoryCurrency(level, r);
  final silver = currency['silver'] ?? 0;
  final gold = currency['gold'] ?? 0;
  if (silver > 0) {
    await db.currencyDao.addSilver(silver);
    entries.add(RaidRewardEntry(label: '+$silver Silver'));
  }
  if (gold > 0) {
    await db.currencyDao.addGold(gold);
    entries.add(RaidRewardEntry(label: '+$gold Gold'));
  }

  // Tincture for the Athanor. Its row draws the tincture glyph by its key.
  final tincture = athanorRaidTincture(level);
  await db.inventoryDao.addItemQty(InvKeys.athanorTincture, tincture);
  entries.add(
    RaidRewardEntry(
      itemKey: InvKeys.athanorTincture,
      label: '+$tincture Sparks',
    ),
  );
  return entries;
}

// ─────────────────────────────────────────────────────────
// POPUP
// ─────────────────────────────────────────────────────────

/// THE HOUSE POPUP PALETTE: `CosmicScreenStyles`, as the dungeon's star
/// popup uses, so the two payouts read as one game.
class _C {
  static const amber = CosmicScreenStyles.amber;
  static const amberBright = CosmicScreenStyles.amberBright;
  static const text = CosmicScreenStyles.textPrimary;
  static const muted = CosmicScreenStyles.textSecondary;
  static const silver = Color(0xFFC9CED6);
}

/// Raid-tier loot popup in the dungeon popup's chrome: the same light from
/// below, rows counted out one by one, and lit CONTINUE. Grants on mount, then
/// advances the persisted raid via [onGranted] immediately afterward.
class RaidRewardPopup extends StatefulWidget {
  const RaidRewardPopup({
    super.key,
    required this.element,
    required this.raidLevel,
    required this.level3ClearsBeforeFight,
    required this.db,
    required this.onGranted,
    required this.onContinue,
  });

  final String element;
  final int raidLevel;
  final int level3ClearsBeforeFight;
  final AlchemonsDatabase db;

  /// Called right after the loot lands in the inventory, before the player
  /// can dismiss — a force-quit here must not re-run the raid.
  final Future<void> Function() onGranted;
  final VoidCallback onContinue;

  @override
  State<RaidRewardPopup> createState() => _RaidRewardPopupState();
}

class _RaidRewardPopupState extends State<RaidRewardPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  List<RaidRewardEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: kRewardIntro)
      ..forward();
    _grant();
  }

  Future<void> _grant() async {
    final entries = await grantRaidRewards(
      db: widget.db,
      element: widget.element,
      raidLevel: widget.raidLevel,
    );
    // The clear is SAVED before Continue appears (a force-quit after the
    // loot must not re-run the tier). One retry for a transient write
    // failure; if it still fails the player is not held hostage behind a
    // popup over loot that has already landed — the tier stays replayable,
    // which costs them nothing.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await widget.onGranted();
        break;
      } catch (e, st) {
        debugPrint('Raid clear did not save (attempt ${attempt + 1}): $e\n$st');
      }
    }
    if (mounted) setState(() => _entries = entries);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  bool get _firstLevel3Clear =>
      widget.raidLevel == 3 && widget.level3ClearsBeforeFight == 0;
  bool get _finalLevel3Clear =>
      widget.raidLevel == 3 && widget.level3ClearsBeforeFight > 0;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // absorb taps to the game behind
        onTap: () {},
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, panel) {
            final t = Curves.easeOutCubic.transform(_intro.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                RewardBackdrop(t: _intro.value),
                Center(
                  child: Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 18),
                      child: panel,
                    ),
                  ),
                ),
              ],
            );
          },
          child: _panel(),
        ),
      ),
    );
  }

  Widget _panel() {
    final entries = _entries;
    return RewardPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entries == null)
                    const SizedBox(
                      height: 60,
                      child: Center(
                        child: GrainLoader(size: 28, color: _C.amber),
                      ),
                    )
                  else
                    for (var i = 0; i < entries.length; i++)
                      RewardStaggerIn(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _entryCard(entries[i]),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          RewardPopupButton(
            label: widget.raidLevel < 3
                ? 'RETURN FOR LEVEL ${widget.raidLevel + 1}'
                : _firstLevel3Clear
                ? 'RETURN TO ORBIT'
                : _finalLevel3Clear
                ? 'RAID CLEARED'
                : 'CONTINUE',
            enabled: entries != null,
            onTap: widget.onContinue,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        const RewardStarGrains(size: 84, delay: Duration(milliseconds: 120)),
        const SizedBox(height: 6),
        const Text(
          'RAID BROKEN',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'LEVEL ${widget.raidLevel}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _C.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _firstLevel3Clear
              ? 'The guardian reforms in 12 hours. One final echo remains.'
              : widget.raidLevel < 3
              ? 'Level ${widget.raidLevel + 1} is open.'
              : 'The raid is cleared.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _C.muted, fontSize: 11),
        ),
      ],
    );
  }

  /// What a loot line IS, for its row: accent, kind, amount and name.
  ({Color accent, String tag, String amount, String name}) _describe(
    RaidRewardEntry e,
  ) {
    final m = RegExp(r'^(\+\d+)\s+(.*)$').firstMatch(e.label);
    final amount = m?.group(1) ?? '';
    final name = m?.group(2) ?? e.label;
    final key = e.itemKey;
    ({Color accent, String tag, String amount, String name}) card(
      Color accent,
      String tag,
    ) => (accent: accent, tag: tag, amount: amount, name: name);
    if (key == null) {
      return card(
        name.contains('Gold') ? _C.amberBright : _C.silver,
        'CURRENCY',
      );
    }
    if (key == InvKeys.athanorTincture) {
      return card(_C.amberBright, 'ATHANOR');
    }
    if (key == InvKeys.potentialSoul) {
      return card(const Color(0xFFB79CFF), 'POTENTIAL');
    }
    for (final t in AlchemicalPowerupType.values) {
      if (key == t.inventoryKey) return card(_legible(t.color), 'POWERUP');
    }
    return card(_legible(elementColor(widget.element)), 'CACHE');
  }

  Widget _entryCard(RaidRewardEntry e) {
    final d = _describe(e);
    return RewardRow(
      accent: d.accent,
      art: _entryArt(e, 32),
      kind: d.tag,
      child: RewardAmountName(amount: d.amount, name: d.name, accent: d.accent),
    );
  }

  Widget _entryArt(RaidRewardEntry e, double size) {
    final key = e.itemKey;
    if (key == null) {
      return e.label.contains('Gold')
          ? CoinIcon.gold(size: size * 0.8)
          : CoinIcon.silver(size: size * 0.8);
    }
    return SizedBox(
      width: size,
      height: size,
      child: InventoryImageHelper.getVisualWidget(
        key: key,
        assetName: InventoryImageHelper.getImage(key),
        icon: null,
        size: size,
      ),
    );
  }
}

/// Lifts a color until it holds its own as an accent on the near-black
/// plate (the survival surge's rule, as the dungeon's popup uses it).
Color _legible(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 1.0))
      .withLightness(hsl.lightness.clamp(0.58, 0.78))
      .toColor();
}
