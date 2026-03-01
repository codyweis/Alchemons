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
    final t = ForgeTokens(context.read<FactionTheme>());
    final db = context.read<AlchemonsDatabase>();
    final registry = buildInventoryRegistry(db);

    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final items = allItems
            .where((item) => !item.key.startsWith('vial.'))
            .toList();

        if (items.isEmpty) {
          return _buildEmptyState(t);
        }

        return Column(
          children: [
            // Header
            Container(
              color: t.bg2,
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: t.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    'ITEMS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg3,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: t.borderDim),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: t.bg3,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: t.borderDim),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: t.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: t.borderAccent.withValues(alpha: 0.4)),
            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
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
                    t: t,
                    onTap: () => _showItemQuickActions(item, def, t),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ForgeTokens t) {
    return Column(
      children: [
        Container(
          color: t.bg2,
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: t.amber,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                'ITEMS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: t.bg3,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: t.borderDim),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: t.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: t.borderAccent.withValues(alpha: 0.4)),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 36,
                  color: t.borderAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'NO ITEMS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visit the shop',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.5,
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
    ForgeTokens t,
  ) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final t2 = ForgeTokens(ctx.read<FactionTheme>());
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: t2.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t2.borderAccent, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: t2.bg2,
                    border: Border(bottom: BorderSide(color: t2.borderDim)),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: t2.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          def.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t2.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: t2.bg3,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: t2.borderDim),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: t2.textSecondary,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Icon + qty row
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: t2.bg2,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: t2.borderAccent.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Center(
                          child: InventoryImageHelper.getVisualWidget(
                            key: item.key,
                            assetName: InventoryImageHelper.getImage(item.key),
                            icon: def.icon,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t2.bg3,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: t2.borderMid),
                            ),
                            child: Text(
                              'QTY  ${item.qty}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t2.amberBright,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Description
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Text(
                    def.description,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t2.textSecondary,
                      fontSize: 10,
                      height: 1.6,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _useItem(InventoryItem item, InventoryItemDef def) async {
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
      InvKeys.alchemyVoidRift => 'void_rift',
      InvKeys.alchemyPrismaticCascade => 'prismatic_cascade',
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

  // ignore: unused_element
  Future<void> _deleteItem(InventoryItem item, InventoryItemDef def) async {
    final theme = context.read<FactionTheme>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.accent.withValues(alpha: 0.5), width: 2),
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
  final ForgeTokens t;
  final VoidCallback onTap;

  const _CompactItemCard({
    required this.item,
    required this.def,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.borderMid, width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: InventoryImageHelper.getVisualWidget(
                key: item.key,
                assetName: InventoryImageHelper.getImage(item.key),
                icon: def.icon,
                size: 28,
              ),
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: t.bg3,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: t.borderAccent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '${item.qty}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 8,
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
