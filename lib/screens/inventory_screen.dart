// lib/screens/inventory_screen.dart - REDESIGNED
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';

/// Helper to get images for inventory items from ShopService
class InventoryImageHelper {
  static final Map<String, String?> _imageCache = {};

  static void _buildCache() {
    if (_imageCache.isNotEmpty) return;

    for (final offer in ShopService.allOffers) {
      if (offer.inventoryKey != null && offer.assetName != null) {
        _imageCache[offer.inventoryKey!] = offer.assetName;
      }
    }
  }

  static String? getImage(String inventoryKey) {
    _buildCache();
    return _imageCache[inventoryKey];
  }
}

class InventoryScreen extends StatefulWidget {
  final Color accent;

  const InventoryScreen({super.key, required this.accent});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _selectedTab = 0; // 0 = Items, 1 = Vials

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              _buildTabSelector(theme),
              Expanded(
                child: _selectedTab == 0
                    ? _buildVialsTab(theme)
                    : _buildItemsTab(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'INVENTORY',
              style: TextStyle(
                color: theme.text,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.accent.withOpacity(0.4), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  label: 'Vials',
                  isActive: _selectedTab == 0,
                  accent: widget.accent,
                  onTap: () {
                    setState(() => _selectedTab = 0);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _TabButton(
                  label: 'Items',
                  isActive: _selectedTab == 1,
                  accent: widget.accent,
                  onTap: () {
                    setState(() => _selectedTab = 1);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTab(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();
    final registry = buildInventoryRegistry(db);

    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return _buildEmptyState(
            theme,
            icon: Icons.inventory_2_outlined,
            message: 'No items in inventory',
            subtitle: 'Purchase items from the shop',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final def = registry[item.key];

            if (def == null) return const SizedBox.shrink();

            return _CleanItemCard(
              item: item,
              def: def,
              theme: theme,
              accent: widget.accent,
              onTap: () => _showItemDetailsDialog(item, def, theme),
            );
          },
        );
      },
    );
  }

  Widget _buildVialsTab(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();

    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];

        // Filter only vial items
        final vialItems = allItems
            .where((item) => item.key.startsWith('vial.'))
            .toList();

        if (vialItems.isEmpty) {
          return _buildEmptyState(
            theme,
            icon: Icons.science_outlined,
            message: 'No extraction vials',
            subtitle: 'Purchase vials from the Black Market',
          );
        }

        // Convert to ExtractionVial objects for display
        final vials = vialItems
            .map((item) {
              final parts = item.key.split('.');
              if (parts.length != 4) return null;

              final groupStr = parts[1];
              final rarityStr = parts[2];

              final group = ElementalGroup.values.firstWhere(
                (g) => g.name == groupStr,
                orElse: () => ElementalGroup.oceanic,
              );

              final rarity = VialRarity.values.firstWhere(
                (r) => r.name == rarityStr,
                orElse: () => VialRarity.common,
              );
              final name = parts.last;

              return ExtractionVial(
                id: item.key,
                name: name,
                group: group,
                rarity: rarity,
                quantity: item.qty,
                price: null,
              );
            })
            .whereType<ExtractionVial>()
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemCount: vials.length,
          itemBuilder: (context, index) {
            final vial = vials[index];
            return _CleanVialCard(
              vial: vial,
              theme: theme,
              accent: widget.accent,
              onTap: () => _showVialDetailsDialog(vial, theme),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    FactionTheme theme, {
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: theme.textMuted.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: theme.textMuted.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ITEM DETAILS DIALOG =====
  void _showItemDetailsDialog(
    InventoryItem item,
    InventoryItemDef def,
    FactionTheme theme,
  ) {
    final imagePath = InventoryImageHelper.getImage(item.key);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accent.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ITEM DETAILS',
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: theme.text.withOpacity(0.7),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Image/Icon Section
              Container(
                height: 160,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.accent.withOpacity(0.2)),
                ),
                child: imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(imagePath, fit: BoxFit.contain),
                      )
                    : Center(
                        child: Icon(
                          def.icon,
                          size: 64,
                          color: widget.accent.withOpacity(0.8),
                        ),
                      ),
              ),

              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  def.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // Quantity
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      color: theme.text,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quantity: x${item.qty}',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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

              const SizedBox(height: 24),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _deleteItem(item, def);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.red.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade300,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'DELETE',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _useItem(item, def);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: widget.accent.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: widget.accent.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: widget.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'USE ITEM',
                              style: TextStyle(
                                color: widget.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== VIAL DETAILS DIALOG =====
  void _showVialDetailsDialog(ExtractionVial vial, FactionTheme theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accent.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'VIAL DETAILS',
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: theme.text.withOpacity(0.7),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Vial Preview (using existing card)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 160,
                  child: ExtractionVialCard(vial: vial, compact: false),
                ),
              ),

              // Quantity
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.science_rounded, color: widget.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Available: x${vial.quantity}',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Extract this vial to capture the specimen inside and place it in your extraction chamber.',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _deleteVial(vial);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.red.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade300,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'DELETE',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _useVial(vial);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.green.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.science_rounded,
                              color: Colors.green.shade300,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'EXTRACT',
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useItem(InventoryItem item, InventoryItemDef def) async {
    _showToast(
      'Item usage not yet implemented',
      icon: Icons.info_rounded,
      color: Colors.blue,
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
          side: BorderSide(color: widget.accent.withOpacity(0.5), width: 2),
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

  Future<void> _useVial(ExtractionVial vial) async {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();

    final qty = await db.inventoryDao.getVialQty(
      vial.group,
      vial.rarity,
      vial.name,
    );
    if (qty <= 0) {
      _showToast(
        'No vials of this type available',
        icon: Icons.warning_rounded,
        color: Colors.orange,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: widget.accent.withOpacity(0.5), width: 2),
        ),
        title: Text(
          'Extract Vial?',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'This will consume the vial and place the specimen in the extraction chamber.',
          style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: widget.accent),
            child: const Text('Extract'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final creatureRarity = switch (vial.rarity) {
      VialRarity.common => 'Common',
      VialRarity.uncommon => 'Uncommon',
      VialRarity.rare => 'Rare',
      VialRarity.legendary => 'Legendary',
      VialRarity.mythic => 'Mythic',
    };

    final res = await EggHatching.extractViaVial(
      context: context,
      group: vial.group,
      rarity: creatureRarity,
      name: vial.name,
    );

    if (!res.success) {
      _showToast(
        res.message ?? 'Extraction failed',
        icon: res.icon ?? Icons.error,
        color: res.color ?? Colors.red,
      );
    } else {
      _showToast(
        'Extraction complete!',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      );
    }
  }

  Future<void> _deleteVial(ExtractionVial vial) async {
    final theme = context.read<FactionTheme>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: widget.accent.withOpacity(0.5), width: 2),
        ),
        title: Text(
          'Remove Vial',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'How would you like to remove ${vial.name}?\n\nYou currently have ${vial.quantity}.',
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
        await db.inventoryDao.removeItem(vial.id);
        _showToast(
          'Removed all ${vial.name} vials',
          icon: Icons.delete_rounded,
          color: Colors.red,
        );
      } else if (confirmed == 'one') {
        await db.inventoryDao.decrementItem(vial.id, by: 1);
        _showToast(
          'Removed 1 ${vial.name} vial',
          icon: Icons.remove_circle_rounded,
          color: Colors.orange,
        );
      }
    } catch (e) {
      _showToast(
        'Failed to remove vial',
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
      ),
    );
  }
}

// ===== CLEAN ITEM CARD (like shop cards) =====
class _CleanItemCard extends StatelessWidget {
  final InventoryItem item;
  final InventoryItemDef def;
  final FactionTheme theme;
  final Color accent;
  final VoidCallback onTap;

  const _CleanItemCard({
    required this.item,
    required this.def,
    required this.theme,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = InventoryImageHelper.getImage(item.key);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.text, width: .5),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image/Icon Area
                Expanded(
                  child: Container(
                    child: imagePath != null
                        ? Image.asset(imagePath, fit: BoxFit.contain)
                        : Center(
                            child: Icon(
                              def.icon,
                              size: 48,
                              color: accent.withOpacity(0.8),
                            ),
                          ),
                  ),
                ),

                // Quantity Badge at bottom
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Text(
                      'x${item.qty}',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== CLEAN VIAL CARD =====
class _CleanVialCard extends StatelessWidget {
  final ExtractionVial vial;
  final FactionTheme theme;
  final Color accent;
  final VoidCallback onTap;

  const _CleanVialCard({
    required this.vial,
    required this.theme,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Existing vial card
          ExtractionVialCard(vial: vial, compact: true),

          // Quantity badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Text(
                'x${vial.quantity}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== TAB BUTTON =====
class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? accent.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? accent.withOpacity(0.6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? theme.text : theme.text.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
