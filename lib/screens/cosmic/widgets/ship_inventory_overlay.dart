import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/models/inventory.dart';
import 'cosmic_screen_styles.dart';

class ShipInventoryOverlay extends StatefulWidget {
  const ShipInventoryOverlay({
    super.key,
    required this.inventory,
    required this.loading,
    required this.onClose,
  });

  final Map<String, int> inventory;
  final bool loading;
  final VoidCallback onClose;

  @override
  State<ShipInventoryOverlay> createState() => ShipInventoryOverlayState();
}

class ShipInventoryOverlayState extends State<ShipInventoryOverlay> {
  String? _selectedKey;

  static bool _isSpaceItem(String key) =>
      key.contains('harvest') ||
      key.contains('portal_key') ||
      key == InvKeys.staminaPotion;

  static String _invDisplayName(String key) => switch (key) {
    InvKeys.portalKeyVolcanic => 'Volcanic Key',
    InvKeys.portalKeyOceanic => 'Oceanic Key',
    InvKeys.portalKeyVerdant => 'Verdant Key',
    InvKeys.portalKeyEarthen => 'Earthen Key',
    InvKeys.portalKeyArcane => 'Arcane Key',
    InvKeys.harvesterStdVolcanic => 'Harvester – Volcanic',
    InvKeys.harvesterStdOceanic => 'Harvester – Oceanic',
    InvKeys.harvesterStdVerdant => 'Harvester – Verdant',
    InvKeys.harvesterStdEarthen => 'Harvester – Earthen',
    InvKeys.harvesterStdArcane => 'Harvester – Arcane',
    InvKeys.harvesterGuaranteed => 'Stabilized Harvester',
    InvKeys.staminaPotion => 'Stamina Elixir',
    _ => key.split('.').last,
  };

  static String _invDescription(String key) => switch (key) {
    InvKeys.portalKeyVolcanic =>
      'Grants entry into a Volcanic Rift portal. Consumed on entry.',
    InvKeys.portalKeyOceanic =>
      'Grants entry into an Oceanic Rift portal. Consumed on entry.',
    InvKeys.portalKeyVerdant =>
      'Grants entry into a Verdant Rift portal. Consumed on entry.',
    InvKeys.portalKeyEarthen =>
      'Grants entry into an Earthen Rift portal. Consumed on entry.',
    InvKeys.portalKeyArcane =>
      'Grants entry into an Arcane Rift portal. Consumed on entry.',
    InvKeys.harvesterStdVolcanic => 'Standard device. Chance-based.',
    InvKeys.harvesterStdOceanic => 'Standard device. Chance-based.',
    InvKeys.harvesterStdVerdant => 'Standard device. Chance-based.',
    InvKeys.harvesterStdEarthen => 'Standard device. Chance-based.',
    InvKeys.harvesterStdArcane => 'Standard device. Chance-based.',
    InvKeys.harvesterGuaranteed => 'Guaranteed capture device.',
    InvKeys.staminaPotion =>
      'Fully restores an Alchemon\'s stamina. Use from your creature list.',
    _ => 'A mysterious item from the cosmos.',
  };

  static Color _invColor(String key) {
    if (key == InvKeys.staminaPotion) return const Color(0xFF00E676);
    if (key.contains('volcanic')) return const Color(0xFFFF5722);
    if (key.contains('oceanic')) return const Color(0xFF2196F3);
    if (key.contains('verdant')) return const Color(0xFF4CAF50);
    if (key.contains('earthen')) return const Color(0xFFFF8F00);
    if (key.contains('arcane')) return const Color(0xFFCE93D8);
    if (key.contains('guaranteed')) return const Color(0xFFFFD54F);
    return const Color(0xFF8A7B6A);
  }

  static IconData _invIcon(String key) {
    if (key.contains('portal_key')) return Icons.vpn_key_rounded;
    if (key.contains('harvest')) return Icons.catching_pokemon_rounded;
    if (key == InvKeys.staminaPotion) return Icons.local_drink_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: CosmicScreenStyles.bg0.withValues(alpha: 0.95),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: CosmicScreenStyles.bg2,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: CosmicScreenStyles.borderDim,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: CosmicScreenStyles.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'INVENTORY',
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.inventory.entries.where((e) => _isSpaceItem(e.key)).fold(0, (s, e) => s + e.value)} ITEMS',
                      style: TextStyle(
                        fontFamily: appFontFamily(context),
                        color: CosmicScreenStyles.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: CosmicScreenStyles.borderDim),

              // ── Body ──
              Expanded(
                child: widget.loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: CosmicScreenStyles.amber,
                            strokeWidth: 1.5,
                          ),
                        ),
                      )
                    : widget.inventory.entries
                          .where((e) => _isSpaceItem(e.key))
                          .isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: CosmicScreenStyles.textMuted,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'NO ITEMS ABOARD',
                              style: TextStyle(
                                fontFamily: appFontFamily(context),
                                color: CosmicScreenStyles.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Collect items from the shop or rifts.',
                              style: TextStyle(
                                color: CosmicScreenStyles.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: widget.inventory.entries
                            .where((e) => _isSpaceItem(e.key))
                            .map((e) {
                              final col = _invColor(e.key);
                              final isSelected = _selectedKey == e.key;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedKey = isSelected ? null : e.key;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? col.withValues(alpha: 0.08)
                                        : CosmicScreenStyles.bg2,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isSelected
                                          ? col.withValues(alpha: 0.5)
                                          : CosmicScreenStyles.borderDim,
                                      width: isSelected ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: col.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border.all(
                                                color: col.withValues(
                                                  alpha: 0.30,
                                                ),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Icon(
                                              _invIcon(e.key),
                                              color: col,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _invDisplayName(e.key),
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: isSelected
                                                    ? col
                                                    : CosmicScreenStyles
                                                          .textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: col.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              border: Border.all(
                                                color: col.withValues(
                                                  alpha: 0.35,
                                                ),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              'x${e.value}',
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: col,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // ── Description (shown when selected) ──
                                      if (isSelected) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: CosmicScreenStyles.bg1,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            border: Border.all(
                                              color:
                                                  CosmicScreenStyles.borderMid,
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            _invDescription(e.key),
                                            style: TextStyle(
                                              color: CosmicScreenStyles
                                                  .textSecondary,
                                              fontSize: 11,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Forge-style status bar row for ship menu.
