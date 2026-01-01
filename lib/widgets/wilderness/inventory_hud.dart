// lib/widgets/wilderness/game_inventory_overlay.dart
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Condensed inventory overlay for in-game use - items only, no vials
class GameInventoryOverlay extends StatefulWidget {
  const GameInventoryOverlay({super.key});

  @override
  State<GameInventoryOverlay> createState() => _GameInventoryOverlayState();
}

class _GameInventoryOverlayState extends State<GameInventoryOverlay> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.read<AlchemonsDatabase>();
    final registry = buildInventoryRegistry(db);

    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];

        // Filter out vials - only show regular items
        final items = allItems
            .where((item) => !item.key.startsWith('vial.'))
            .toList();

        if (items.isEmpty) {
          return _buildEmptyState(theme);
        }

        return Column(
          children: [
            // Minimal header with close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'ITEMS',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length}',
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: theme.text.withOpacity(0.7),
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Thin divider
            Divider(
              color: theme.accent.withOpacity(0.15),
              height: 1,
              thickness: 0.5,
            ),

            // Ultra-compact grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.95,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final def = registry[item.key];

                  if (def == null) return const SizedBox.shrink();

                  return _CompactItemCard(
                    item: item,
                    def: def,
                    theme: theme,
                    onTap: () => _showItemQuickActions(item, def, theme),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(FactionTheme theme) {
    return Column(
      children: [
        // Header even when empty
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                'ITEMS',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
                color: theme.text.withOpacity(0.7),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
        Divider(
          color: theme.accent.withOpacity(0.15),
          height: 1,
          thickness: 0.5,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: theme.textMuted.withOpacity(0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Items',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visit the shop',
                  style: TextStyle(
                    color: theme.textMuted.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showItemQuickActions(
    InventoryItem item,
    InventoryItemDef def,
    FactionTheme theme,
  ) {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: theme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.accent.withOpacity(0.4), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        def.name,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.close_rounded),
                      color: theme.text.withOpacity(0.7),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Item icon/image
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.accent.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: InventoryImageHelper.getVisualWidget(
                      key: item.key,
                      assetName: InventoryImageHelper.getImage(item.key),
                      icon: def.icon,
                      size: 48,
                    ),
                  ),
                ),
              ),

              // Quantity
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.accent.withOpacity(0.3)),
                ),
                child: Text(
                  'Quantity: x${item.qty}',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  def.description,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useItem(InventoryItem item, InventoryItemDef def) async {
    final db = context.read<AlchemonsDatabase>();

    // Check if it's an alchemy effect
    if (item.key.startsWith('alchemy.')) {
      await _showCreatureSelectorForEffect(item, def);
      return;
    }

    if (item.key == InvKeys.staminaPotion) {
      await _useStaminaPotion(item, def);
      return;
    }

    _showToast(
      'Item usage not yet implemented',
      icon: Icons.info_rounded,
      color: Colors.blue,
    );
  }

  Future<void> _useStaminaPotion(
    InventoryItem item,
    InventoryItemDef def,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();
    final repo = context.read<CreatureCatalog>();
    final staminaService = StaminaService(db);

    final allInstances = await db.creatureDao.listAllInstances();

    if (allInstances.isEmpty) {
      _showToast(
        'No Alchemons available',
        icon: Icons.error_rounded,
        color: Colors.orange,
      );
      return;
    }

    final eligibleSpeciesIds = allInstances.map((inst) => inst.baseId).toSet();

    final selectedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetContext, scrollController) {
            return withGameData(
              context,
              loadingBuilder: buildLoadingScreen,
              builder:
                  (
                    context, {
                    required theme,
                    required catalog,
                    required entries,
                    required discovered,
                  }) {
                    final eligibleDiscovered = discovered
                        .where(
                          (entry) =>
                              eligibleSpeciesIds.contains(entry.creature.id),
                        )
                        .toList();

                    if (eligibleDiscovered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No Alchemons available',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return CreatureSelectionSheet(
                      scrollController: scrollController,
                      discoveredCreatures: eligibleDiscovered,
                      onSelectCreature: (creatureId) {
                        Navigator.pop(modalContext, creatureId);
                      },
                      showOnlyAvailableTypes: true,
                    );
                  },
            );
          },
        );
      },
    );

    if (selectedSpeciesId == null || !mounted) return;

    final selectedSpecies = repo.getCreatureById(selectedSpeciesId);
    if (selectedSpecies == null) return;

    final instanceId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetShell(
        title: 'Choose ${selectedSpecies.name}',
        theme: theme,
        child: InstancesSheet(
          species: selectedSpecies,
          theme: theme,
          onTap: (inst) {
            Navigator.pop(context, inst.instanceId);
          },
        ),
      ),
    );

    if (instanceId == null || !mounted) return;

    final updated = await staminaService.restoreToFull(instanceId);
    if (updated == null) {
      _showToast(
        'Failed to restore stamina',
        icon: Icons.error_rounded,
        color: Colors.red,
      );
      return;
    }

    await db.inventoryDao.decrementItem(item.key, by: 1);

    _showToast(
      'Restored stamina for ${selectedSpecies.name}!',
      icon: Icons.favorite_rounded,
      color: Colors.green,
    );
  }

  Future<void> _showCreatureSelectorForEffect(
    InventoryItem item,
    InventoryItemDef def,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();
    final repo = context.read<CreatureCatalog>();

    final allInstances = await db.creatureDao.listAllInstances();

    if (allInstances.isEmpty) {
      _showToast(
        'No Alchemons to apply effect to',
        icon: Icons.error_rounded,
        color: Colors.orange,
      );
      return;
    }

    final eligibleSpeciesIds = allInstances.map((inst) => inst.baseId).toSet();

    final selectedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetContext, scrollController) {
            return withGameData(
              context,
              loadingBuilder: buildLoadingScreen,
              builder:
                  (
                    context, {
                    required theme,
                    required catalog,
                    required entries,
                    required discovered,
                  }) {
                    final eligibleDiscovered = discovered
                        .where(
                          (entry) =>
                              eligibleSpeciesIds.contains(entry.creature.id),
                        )
                        .toList();

                    if (eligibleDiscovered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No Alchemons available',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return CreatureSelectionSheet(
                      scrollController: scrollController,
                      discoveredCreatures: eligibleDiscovered,
                      onSelectCreature: (creatureId) {
                        Navigator.pop(modalContext, creatureId);
                      },
                      showOnlyAvailableTypes: true,
                    );
                  },
            );
          },
        );
      },
    );

    if (selectedSpeciesId == null || !mounted) return;

    final selectedSpecies = repo.getCreatureById(selectedSpeciesId);
    if (selectedSpecies == null) return;

    final instanceId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetShell(
        title: 'Choose ${selectedSpecies.name}',
        theme: theme,
        child: InstancesSheet(
          species: selectedSpecies,
          theme: theme,
          onTap: (inst) {
            Navigator.pop(context, inst.instanceId);
          },
        ),
      ),
    );

    if (instanceId == null || !mounted) return;

    final effectType = switch (item.key) {
      InvKeys.alchemyGlow => 'alchemy_glow',
      InvKeys.alchemyElementalAura => 'elemental_aura',
      InvKeys.alchemyVolcanicAura => 'volcanic_aura',
      _ => null,
    };

    if (effectType == null) return;

    await db.creatureDao.updateAlchemyEffect(
      instanceId: instanceId,
      effect: effectType,
    );

    await db.inventoryDao.decrementItem(item.key, by: 1);

    _showToast(
      'Applied ${def.name}!',
      icon: Icons.check_circle_rounded,
      color: Colors.green,
    );
  }

  Future<void> _deleteItem(InventoryItem item, InventoryItemDef def) async {
    final theme = context.read<FactionTheme>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.accent.withOpacity(0.5), width: 2),
        ),
        title: Text(
          'Remove Item',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'How would you like to remove ${def.name}?\n\nYou currently have ${item.qty}.',
          style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'one'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove 1'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'all'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove All'),
          ),
        ],
      ),
    );

    if (confirmed == null || !mounted) return;

    final db = context.read<AlchemonsDatabase>();

    try {
      if (confirmed == 'all') {
        await db.inventoryDao.removeItem(item.key);
        _showToast(
          'Removed all ${def.name}',
          icon: Icons.delete_rounded,
          color: Colors.red,
        );
      } else if (confirmed == 'one') {
        await db.inventoryDao.decrementItem(item.key, by: 1);
        _showToast(
          'Removed 1 ${def.name}',
          icon: Icons.remove_circle_rounded,
          color: Colors.orange,
        );
      }
    } catch (e) {
      _showToast(
        'Failed to remove item',
        icon: Icons.error_rounded,
        color: Colors.red,
      );
    }
  }

  void _showToast(String msg, {IconData? icon, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 18),
            if (icon != null) const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Compact item card for game overlay
class _CompactItemCard extends StatelessWidget {
  final InventoryItem item;
  final InventoryItemDef def;
  final FactionTheme theme;
  final VoidCallback onTap;

  const _CompactItemCard({
    required this.item,
    required this.def,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.accent.withOpacity(0.25), width: 1),
        ),
        child: Stack(
          children: [
            // Item icon/image
            Center(
              child: InventoryImageHelper.getVisualWidget(
                key: item.key,
                assetName: InventoryImageHelper.getImage(item.key),
                icon: def.icon,
                size: 32,
              ),
            ),

            // Quantity badge
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.text.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${item.qty}',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
