// lib/screens/cosmic/widgets/elemental_cache_popup.dart
//
// The payout card shown once a sealed elemental cache gives way. Rows arrive
// one at a time, tinted by the element that broke the seal.

import 'package:alchemons/games/cosmic/cosmic_cache_data.dart';
import 'package:alchemons/games/cosmic/cosmic_cache_rewards.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_popup_chrome.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:flutter/material.dart';

/// The house popup palette, matched to the dungeon reward popup so a cache
/// payout does not read as a screen from a different game.
class _C {
  static const panel = Color(0xFF14120E);
  static const panelDeep = Color(0xFF0B0A07);
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const border = Color(0xFF74613A);
  static const text = Color(0xFFE8DFC8);
  static const muted = Color(0xFF9C9078);
}

class _RewardLine {
  const _RewardLine({
    required this.label,
    required this.qty,
    this.invKey,
    this.isGold = false,
    this.rare = false,
  });

  final String label;
  final int qty;

  /// Drives the artwork — the same art the shop shows for this item.
  final String? invKey;
  final bool isGold;
  final bool rare;
}

const Map<String, String> _itemNames = {
  InvKeys.powerupSpeed: 'Velocity Orb',
  InvKeys.powerupIntelligence: 'Insight Orb',
  InvKeys.powerupStrength: 'Forge Orb',
  InvKeys.powerupBeauty: 'Radiance Orb',
  InvKeys.staminaPotion: 'Stamina Elixir',
  InvKeys.harvesterGuaranteed: 'Stabilized Harvester',
  InvKeys.instantHatch: 'Instant Fusion Extractor',
};

class ElementalCachePopup extends StatefulWidget {
  const ElementalCachePopup({
    super.key,
    required this.reward,
    required this.onDismiss,
  });

  final ElementalCacheReward reward;
  final VoidCallback onDismiss;

  @override
  State<ElementalCachePopup> createState() => _ElementalCachePopupState();
}

class _ElementalCachePopupState extends State<ElementalCachePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_RewardLine> _lines;

  @override
  void initState() {
    super.initState();
    final r = widget.reward;
    _lines = [
      _RewardLine(label: 'Gold', qty: r.gold, isGold: true),
      for (final entry in r.powerups.entries)
        _RewardLine(
          label: _itemNames[entry.key] ?? entry.key,
          qty: entry.value,
          invKey: entry.key,
        ),
      if (r.staminaElixirs > 0)
        _RewardLine(
          label: 'Stamina Elixir',
          qty: r.staminaElixirs,
          invKey: InvKeys.staminaPotion,
        ),
      if (r.stabilizedHarvesters > 0)
        _RewardLine(
          label: 'Stabilized Harvester',
          qty: r.stabilizedHarvesters,
          invKey: InvKeys.harvesterGuaranteed,
        ),
      if (r.fusionExtractors > 0)
        _RewardLine(
          label: 'Instant Fusion Extractor',
          qty: r.fusionExtractors,
          invKey: InvKeys.instantHatch,
          rare: true,
        ),
    ];

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 420 + _lines.length * 170),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 0 → 1 reveal progress for the row at [index].
  double _rowProgress(int index) {
    final total = _ctrl.duration!.inMilliseconds;
    final start = (240 + index * 170) / total;
    const window = 0.32;
    return ((_ctrl.value - start) / window).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = elementColor(widget.reward.element);
    final font = appFontFamily(context);

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final open = Curves.easeOutBack.transform(
                (_ctrl.value / 0.28).clamp(0.0, 1.0),
              );
              return Transform.scale(
                scale: 0.86 + 0.14 * open,
                child: Opacity(
                  opacity: (_ctrl.value / 0.16).clamp(0.0, 1.0),
                  child: CustomPaint(
                    // Bracket corners + warm panel: the same chrome the dungeon
                    // reward popup uses. This card was a blue-black rounded
                    // rect with an element-coloured hairline, which belonged to
                    // no other screen in the game.
                    foregroundPainter: const DungeonBracketPainter(
                      color: _C.amber,
                      bracketSize: 12,
                      strokeWidth: 1.6,
                    ),
                    child: Container(
                      width: 340,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_C.panel, _C.panelDeep],
                        ),
                        border: Border.all(color: _C.border, width: 1.2),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0xB3000000),
                            blurRadius: 32,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: accent.withValues(alpha: 0.16),
                            blurRadius: 48,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(accent, font),
                          const SizedBox(height: 16),
                          for (var i = 0; i < _lines.length; i++)
                            _row(_lines[i], _rowProgress(i), accent, font),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              'TAP TO CLOSE',
                              style: TextStyle(
                                fontFamily: font,
                                color: _C.muted.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(Color accent, String? font) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEAL BROKEN',
                style: TextStyle(
                  fontFamily: font,
                  color: _C.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'IT ANSWERED ${cacheHintFor(widget.reward.element).toUpperCase()}',
                style: TextStyle(
                  fontFamily: font,
                  color: accent.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(_RewardLine line, double p, Color accent, String? font) {
    if (p <= 0) {
      return const SizedBox(height: 38);
    }
    final tint = line.rare ? _C.amberBright : accent;
    return Opacity(
      opacity: p,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - p)),
        child: Container(
          height: 42,
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: line.rare
                ? _C.amberBright.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: line.rare
                  ? _C.amberBright.withValues(alpha: 0.45)
                  : _C.border.withValues(alpha: 0.55),
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              // The item's real artwork — the same orb sphere or asset the
              // shop shows. These rows used flat Material icons, so a Forge
              // Orb here looked nothing like the Forge Orb you bought.
              if (line.isGold)
                const CoinIcon(kind: CoinKind.gold, size: 26)
              else if (line.invKey != null)
                InventoryItemArtwork(inventoryKey: line.invKey!, size: 28)
              else
                const SizedBox(width: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: font,
                    color: _C.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                '+${line.qty}',
                style: TextStyle(
                  fontFamily: font,
                  color: tint,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
