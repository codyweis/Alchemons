// lib/screens/inventory_screen.dart - REDESIGNED
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/loading_widget.dart';
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
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';

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
    // Boss trait relics: key.boss_trait.{element} → relics/{element}relic.png
    if (inventoryKey.startsWith('key.boss_trait.')) {
      final element = inventoryKey.substring('key.boss_trait.'.length);
      return 'assets/images/relics/${element}relic.png';
    }
    return _imageCache[inventoryKey];
  }

  static Widget getVisualWidget({
    required String key,
    String? assetName,
    IconData? icon,
    required double size,
  }) {
    final powerupType = alchemicalPowerupTypeFromInventoryKey(key);
    if (powerupType != null) {
      return AlchemicalPowerupOrbSphere(type: powerupType, size: size);
    }

    // 1. Check if it's an alchemy effect using the key prefix
    if (key.startsWith('alchemy.')) {
      final preview = ShopService.getAlchemyEffectPreview(key, size: size);
      if (preview != null) {
        // Return the animated widget, constrained to the size
        return SizedBox.square(dimension: size, child: preview);
      }
    }

    // 2. Fallback to static image asset
    if (assetName != null) {
      return Image.asset(assetName, fit: BoxFit.contain);
    }

    // 3. Final fallback to icon
    if (icon != null) {
      return Icon(icon, size: size * 0.75);
    }

    // Default fallback (placeholder)
    return SizedBox.square(
      dimension: size,
      child: Container(color: Colors.grey.withValues(alpha: 0.1)),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _tabLabels = ['Vials', 'Items', 'Special'];
  static const Set<String> _spaceOnlyInventoryKeys = {
    'wallet_astral_shards',
    'item.astral_shard',
    'item.astral_shards',
  };

  // ADD: Mixin for TabController

  // REMOVE: int _selectedTab = 0; // 0 = Items, 1 = Vials

  // ADD: TabController
  late TabController _tabController;

  int get _tabCount => _tabLabels.length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncTabController();

    final theme = context.watch<FactionTheme>();

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(theme),
              // REPLACE: _buildTabSelector(theme),
              _buildTabBar(theme), // NEW: TabBar for tabs
              Expanded(
                // REPLACE: Conditional content with TabBarView
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVialsTab(theme), // Tab 1: Vials
                    _buildItemsTab(theme), // Tab 2: Items
                    _buildKeyItemsTab(theme), // Tab 3: Key Items
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncTabController() {
    if (_tabController.length == _tabCount) return;

    final priorIndex = _tabController.index;
    _tabController.dispose();
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: priorIndex.clamp(0, _tabCount - 1),
    );
  }

  Widget _buildTabBar(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TabBar(
        controller: _tabController,

        indicatorPadding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,

        // Color for the SELECTED tab text
        labelColor: theme.text,
        // Color for the UNSELECTED tab text
        unselectedLabelColor: theme.text.withValues(alpha: 0.6),

        tabs: _tabLabels
            .map(
              (label) => Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
        onTap: (index) {
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.accentSoft.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CurrencyDisplayWidget(accentColor: theme.accentSoft),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 58,
                    child: ResourceCollectionWidget(theme: theme),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();
    final registry = buildInventoryRegistry(db);

    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final items = allItems.where((item) {
          if (_isSpaceOnlyInventoryItem(item.key)) return false;
          if (shouldHideInventoryItem(item.key)) return false;
          if (item.key.startsWith('vial.')) return false;
          final def = registry[item.key];
          if (def == null) return false;
          return !def.isKeyItem;
        }).toList();

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
              accent: theme.accent,
              onTap: () => _showItemDetailsDialog(item, def, theme),
            );
          },
        );
      },
    );
  }

  Widget _buildKeyItemsTab(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();
    final registry = buildInventoryRegistry(db);

    return StreamBuilder<List<InventoryItem>>(
      stream: db.inventoryDao.watchItemInventory(),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final keyItems = allItems.where((item) {
          if (_isSpaceOnlyInventoryItem(item.key)) return false;
          if (shouldHideInventoryItem(item.key)) return false;
          final def = registry[item.key];
          return def != null && def.isKeyItem;
        }).toList();

        if (keyItems.isEmpty) {
          return _buildEmptyState(
            theme,
            icon: Icons.vpn_key_outlined,
            message: 'No special items yet',
            subtitle: '',
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
          itemCount: keyItems.length,
          itemBuilder: (context, index) {
            final item = keyItems[index];
            final def = registry[item.key];
            if (def == null) return const SizedBox.shrink();

            return _CleanItemCard(
              item: item,
              def: def,
              theme: theme,
              accent: theme.accent,
              onTap: () => _showItemDetailsDialog(item, def, theme),
            );
          },
        );
      },
    );
  }

  bool _isSpaceOnlyInventoryItem(String key) {
    final normalized = key.toLowerCase();
    return _spaceOnlyInventoryKeys.contains(normalized) ||
        normalized.contains('astral_shard');
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
            Icon(icon, size: 80, color: theme.textMuted.withValues(alpha: 0.3)),
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
                color: theme.textMuted.withValues(alpha: 0.7),
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
    final t = ForgeTokens(theme);

    final canUse = def.canUse;
    final canDelete = def.canDispose;

    final Widget visualWidget = InventoryImageHelper.getVisualWidget(
      key: item.key,
      assetName: InventoryImageHelper.getImage(item.key),
      icon: def.icon,
      size: 100,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderAccent, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.amber.withValues(alpha: 0.08),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: t.bg0,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),
                  border: Border(
                    bottom: BorderSide(color: t.borderAccent, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ITEM DETAILS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: t.bg2,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: t.borderDim, width: 1),
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

              // ── Preview ─────────────────────────────────────────────────
              Container(
                height: 130,
                color: t.bg0,
                child: Center(child: visualWidget),
              ),

              // ── Name ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  def.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Quantity badge ───────────────────────────────────────────
              if (!def.isKeyItem) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: t.amberDim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: t.borderAccent, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          color: t.amber,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'QTY: ${item.qty}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Description ──────────────────────────────────────────────
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  def.description,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Buttons ──────────────────────────────────────────────────
              if (canDelete || canUse) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      if (canDelete) ...[
                        GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _deleteItem(item, def);
                          },
                          child: Container(
                            height: 44,
                            width: 72,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: t.danger.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 13,
                                  color: t.danger.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'DEL',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: t.danger.withValues(alpha: 0.8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (canUse)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _useItem(item, def);
                            },
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: t.amberDim.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: t.amber, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: t.amber.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 15,
                                    color: t.amberBright,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'USE ITEM',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: t.amberBright,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (!canDelete && !canUse) const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ===== VIAL DETAILS DIALOG =====
  void _showVialDetailsDialog(ExtractionVial vial, FactionTheme theme) {
    final t = ForgeTokens(theme);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderAccent, width: 1),
            boxShadow: [
              BoxShadow(
                color: t.amber.withValues(alpha: 0.08),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: t.bg0,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(2),
                  ),
                  border: Border(
                    bottom: BorderSide(color: t.borderAccent, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'VIAL DETAILS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: t.bg2,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: t.borderDim, width: 1),
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

              // ── Vial card preview ────────────────────────────────────────
              Container(
                height: 150,
                color: t.bg0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                child: ExtractionVialCard(vial: vial, compact: false),
              ),

              // ── Title ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  'EXTRACTION VIAL',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Description ──────────────────────────────────────────────
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Extract this vial to capture the specimen inside and place it in your extraction chamber.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Buttons ──────────────────────────────────────────────────
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    // DELETE
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _deleteVial(vial);
                      },
                      child: Container(
                        height: 44,
                        width: 72,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: t.danger.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 13,
                              color: t.danger.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DEL',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.danger.withValues(alpha: 0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // EXTRACT
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _useVial(vial);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.amberDim.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: t.amber, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: t.amber.withValues(alpha: 0.15),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.science_rounded,
                                size: 15,
                                color: t.amberBright,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'EXTRACT',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.amberBright,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
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
    if (!def.canUse) {
      _showToast(
        'This is a key item and cannot be used right now',
        icon: Icons.vpn_key_rounded,
        color: Colors.indigo,
      );
      return;
    }

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

    // Get all instances so we can choose one
    final allInstances = await db.creatureDao.listAllInstances();

    if (allInstances.isEmpty) {
      _showToast(
        'No Alchemons available',
        icon: Icons.error_rounded,
        color: Colors.orange,
      );
      return;
    }

    // Unique species IDs for which we have instances
    final eligibleSpeciesIds = allInstances.map((inst) => inst.baseId).toSet();

    // STEP 1: pick species
    if (!mounted) return;
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
                      stateScopeKey: 'inventory_restore_species',
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

    // STEP 2: pick instance of that species
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
          prefsScopeKey: 'inventory_restore_instances',
          onTap: (inst) {
            Navigator.pop(context, inst.instanceId);
          },
        ),
      ),
    );

    if (instanceId == null || !mounted) return;

    // STEP 3: restore stamina using the service
    final updated = await staminaService.restoreToFull(instanceId);
    if (updated == null) {
      _showToast(
        'Failed to restore stamina',
        icon: Icons.error_rounded,
        color: Colors.red,
      );
      return;
    }

    // Consume the potion
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

    // Get all instances to determine which species are eligible
    final allInstances = await db.creatureDao.listAllInstances();

    if (allInstances.isEmpty) {
      _showToast(
        'No Alchemons to apply effect to',
        icon: Icons.error_rounded,
        color: Colors.orange,
      );
      return;
    }

    // Get unique species IDs that have instances
    final eligibleSpeciesIds = allInstances.map((inst) => inst.baseId).toSet();

    // STEP 1: Show species picker
    if (!mounted) return;
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
            // Use withGameData to get discovered creatures
            return withGameData(
              context, // Use the original context that has the providers
              loadingBuilder: buildLoadingScreen,
              builder:
                  (
                    context, {
                    required theme,
                    required catalog,
                    required entries,
                    required discovered,
                  }) {
                    // Filter to only show species with instances
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
                      stateScopeKey: 'inventory_effect_species',
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

    // STEP 2: Show instance picker
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
          prefsScopeKey: 'inventory_effect_instances',
          onTap: (inst) {
            Navigator.pop(context, inst.instanceId);
          },
        ),
      ),
    );

    if (instanceId == null || !mounted) return;

    // Determine effect type
    final effectType = switch (item.key) {
      InvKeys.alchemyGlow => 'alchemy_glow',
      InvKeys.alchemyElementalAura => 'elemental_aura',
      InvKeys.alchemyVolcanicAura => 'volcanic_aura',
      InvKeys.alchemyVoidRift => 'void_rift',
      InvKeys.alchemyPrismaticCascade => 'prismatic_cascade',
      InvKeys.alchemyRitualGold => 'ritual_gold',
      InvKeys.alchemyBeautyRadiance => 'beauty_radiance',
      InvKeys.alchemySpeedFlux => 'speed_flux',
      InvKeys.alchemyStrengthForge => 'strength_forge',
      InvKeys.alchemyIntelligenceHalo => 'intelligence_halo',
      InvKeys.alchemyBloodAura => 'blood_aura',
      _ => null,
    };

    if (effectType == null) return;

    // Apply the effect
    await db.creatureDao.updateAlchemyEffect(
      instanceId: instanceId,
      effect: effectType,
    );

    // Consume the item
    await db.inventoryDao.decrementItem(item.key, by: 1);

    _showToast(
      'Applied ${def.name}!',
      icon: Icons.check_circle_rounded,
      color: Colors.green,
    );
  }

  Future<void> _deleteItem(InventoryItem item, InventoryItemDef def) async {
    if (!def.canDispose) {
      _showToast(
        'Special items cannot be removed',
        icon: Icons.lock_rounded,
        color: Colors.indigo,
      );
      return;
    }

    final theme = context.read<FactionTheme>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.accent.withValues(alpha: 0.5),
            width: 2,
          ),
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

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.accent.withValues(alpha: 0.5),
            width: 2,
          ),
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
            style: ElevatedButton.styleFrom(backgroundColor: theme.accent),
            child: Text('Extract', style: TextStyle(color: theme.text)),
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
          side: BorderSide(
            color: theme.accent.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        title: Text(
          'Remove Vial',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'How would you like to remove ${vial.name}?',
          style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w600),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'one'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Remove 1'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'all'),
                child: Text('Remove All', style: TextStyle(color: theme.text)),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel', style: TextStyle(color: theme.textMuted)),
            ),
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
    final visualWidget = InventoryImageHelper.getVisualWidget(
      key: item.key,
      assetName: InventoryImageHelper.getImage(item.key),
      icon: def.icon,
      size: 48,
    );
    final showQuantity = !def.isKeyItem;

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
                Expanded(child: Center(child: visualWidget)),

                // Quantity Badge at bottom (non-special items only)
                if (showQuantity)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
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
  final VoidCallback onTap;

  const _CleanVialCard({required this.vial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ExtractionVialCard(vial: vial, compact: true),
    );
  }
}
