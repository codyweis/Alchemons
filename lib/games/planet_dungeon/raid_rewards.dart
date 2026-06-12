// lib/games/planet_dungeon/raid_rewards.dart
//
// Raid victory loot: three rolls of the planet's elemental loot cache plus
// scaled currency. Granted once per raid (the raid's cleared flag is
// persisted by the caller right after the grant).

import 'dart:math';

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_popup_chrome.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/inventory_screen.dart'
    show InventoryImageHelper;
import 'package:alchemons/widgets/coin_icon.dart';
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
  Random? rng,
}) async {
  final r = rng ?? Random();
  final entries = <RaidRewardEntry>[];
  final registry = buildInventoryRegistry(db);

  // Three caches of the planet's elemental loot pool.
  final drops = LootBoxConfig.rollBossLootBoxDropsForQuantity(
    BossLootKeys.lootBoxKeyForElement(element),
    3,
    r,
  );
  for (final drop in drops) {
    await db.inventoryDao.addItemQty(drop.key, drop.value);
    final name = registry[drop.key]?.name ?? drop.key;
    entries.add(
      RaidRewardEntry(itemKey: drop.key, label: '+${drop.value} $name'),
    );
  }

  // Currency scaled by the element's altar order (harder elements pay more).
  final order = altarEntryForElement(element)?.order ?? 1;
  final currency = LootBoxConfig.rollBossRematchBonusCurrency(order, r);
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
  return entries;
}

// ─────────────────────────────────────────────────────────
// POPUP
// ─────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFF0B0909);
  static const text = Color(0xFFEDE3CF);
  static const muted = Color(0xFF9A8F7A);
  static const amberBright = Color(0xFFE4C16A);
  static const border = Color(0xFF74613A);
  static const danger = Color(0xFFB8503F);
}

/// "RAID BROKEN" loot popup, in the dungeon popup chrome. Grants on mount
/// (caller persists the cleared flag via [onGranted] immediately after).
class RaidRewardPopup extends StatefulWidget {
  const RaidRewardPopup({
    super.key,
    required this.element,
    required this.db,
    required this.onGranted,
    required this.onContinue,
  });

  final String element;
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
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _grant();
  }

  Future<void> _grant() async {
    final entries = await grantRaidRewards(
      db: widget.db,
      element: widget.element,
    );
    await widget.onGranted();
    if (mounted) setState(() => _entries = entries);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: _C.bg.withValues(alpha: 0.78),
          child: Center(
            child: FadeTransition(
              opacity: _intro,
              child: ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(curved),
                child: _panel(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    final entries = _entries;
    return CustomPaint(
      painter: const DungeonBracketPainter(
        color: _C.amberBright,
        bracketSize: 12,
      ),
      child: Container(
        width: 320,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: _C.bg.withValues(alpha: 0.96),
          border: Border.all(color: _C.border.withValues(alpha: 0.55)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.whatshot_rounded, color: _C.danger, size: 16),
                const SizedBox(width: 8),
                Text(
                  'RAID BROKEN — ${widget.element.toUpperCase()}',
                  style: const TextStyle(
                    color: _C.amberBright,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'The guardian\'s madness lifts. Its hoard is yours.',
              style: TextStyle(color: _C.muted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            if (entries == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text('…', style: TextStyle(color: _C.muted)),
                ),
              )
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      _entryArt(e, 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.label,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: entries == null ? null : widget.onContinue,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: entries == null ? 0.4 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _C.amberBright),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(
                        color: _C.amberBright,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryArt(RaidRewardEntry e, double size) {
    final key = e.itemKey;
    if (key == null) {
      // Currency: gold coin art for gold, tinted coin for silver.
      if (e.label.contains('Gold')) return CoinIcon.gold(size: size);
      return Icon(Icons.brightness_5_rounded, size: size, color: _C.muted);
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
