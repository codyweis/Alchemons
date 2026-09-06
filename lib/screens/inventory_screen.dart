// lib/screens/inventory_screen.dart - REDESIGNED
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/widgets/potential_soul_sphere.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/screens/extract_vial_dialog.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/specimen_picker_route.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';
import 'package:alchemons/widgets/app_icons.dart';

typedef _InventoryPalette = BracketPalette;
typedef _BracketFramePainter = BracketFramePainter;

TextStyle _display(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) => bracketText(
  context,
  size,
  color,
  weight: weight,
  letterSpacing: letterSpacing,
  fontStyle: fontStyle,
);

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
    if (key == InvKeys.potentialSoul) {
      return PotentialSoulSphere(size: size);
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
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => _buildTabSelector(theme),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVialsTab(theme),
                    _buildItemsTab(theme),
                    _buildKeyItemsTab(theme),
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

  Widget _buildTabSelector(FactionTheme theme) {
    final palette = _InventoryPalette.fromTheme(theme);
    final activeAccent = bracketReadableAccent(theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: List.generate(_tabLabels.length, (index) {
          final selected = _tabController.index == index;
          final label = _tabLabels[index];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _tabLabels.length - 1 ? 0 : 8,
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _tabController.animateTo(index);
                },
                child: CustomPaint(
                  painter: _BracketFramePainter(
                    color: selected
                        ? activeAccent.withValues(alpha: 0.9)
                        : palette.line.withValues(alpha: 0.85),
                    bracketSize: 9,
                    strokeWidth: 1.1,
                  ),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    color: selected
                        ? palette.accentWash(theme.accent)
                        : palette.surfaceMutedFill(),
                    child: Text(
                      label,
                      style: _display(
                        context,
                        13,
                        selected ? palette.ink : palette.muted,
                        weight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme) {
    final palette = _InventoryPalette.fromTheme(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title + subtitle — full padding
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Inventory',
                style: _display(
                  context,
                  27,
                  palette.ink,
                  weight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Field supplies, vials, and rare findings.',
                style: _display(
                  context,
                  13,
                  palette.muted,
                  weight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Currency + resources — left padding only, resources bleed to edge
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Row(
            children: [
              Flexible(
                child: CurrencyDisplayWidget(
                  accentColor: bracketReadableAccent(theme),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ResourceCollectionWidget(
                  theme: theme,
                  horizontalPadding: 0,
                  alignToEnd: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: palette.lineSoft),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Collections',
                      style: _display(
                        context,
                        12,
                        palette.muted,
                        weight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(height: 1, color: palette.lineSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
            icon: AppIcons.inventory_2_outlined,
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
            childAspectRatio: 0.82,
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
            icon: AppIcons.vpn_key_outlined,
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
            childAspectRatio: 0.82,
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
            icon: AppIcons.science_outlined,
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
    final canUse = def.canUse;
    final canDelete = def.canDispose;
    final palette = _InventoryPalette.fromTheme(theme);
    final activeAccent = bracketReadableAccent(theme);

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
        child: CustomPaint(
          painter: _BracketFramePainter(
            color: activeAccent.withValues(alpha: 0.84),
            bracketSize: 12,
            strokeWidth: 1.2,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            color: palette.bg1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  color: palette.chromeFill(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item details',
                              style: _display(
                                context,
                                22,
                                palette.ink,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              def.isKeyItem
                                  ? 'A rare find carried for the long path.'
                                  : 'A useful field supply kept on hand.',
                              style: _display(
                                context,
                                12,
                                palette.muted,
                                weight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _DialogCloseButton(
                        color: palette.line,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 130,
                  color: palette.bg0,
                  child: Center(child: visualWidget),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    def.name,
                    style: _display(
                      context,
                      20,
                      palette.ink,
                      weight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!def.isKeyItem) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: CustomPaint(
                      painter: _BracketFramePainter(
                        color: activeAccent.withValues(alpha: 0.84),
                        bracketSize: 8,
                        strokeWidth: 1,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        color: palette.accentWash(theme.accent),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.inventory_2_rounded,
                              color: activeAccent,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.qty} in inventory',
                              style: _display(
                                context,
                                12,
                                palette.ink,
                                weight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    def.description,
                    style: _display(
                      context,
                      13,
                      palette.muted,
                      weight: FontWeight.w500,
                    ),
                    strutStyle: const StrutStyle(height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (canDelete || canUse) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        if (canDelete) ...[
                          SizedBox(
                            width: 102,
                            child: _DialogActionButton(
                              label: 'Remove',
                              icon: AppIcons.delete_outline_rounded,
                              color: const Color(0xFFC0392B),
                              secondary: true,
                              onTap: () async {
                                Navigator.pop(ctx);
                                await _deleteItem(item, def);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (canUse)
                          Expanded(
                            child: _DialogActionButton(
                              label: 'Use item',
                              icon: AppIcons.play_arrow_rounded,
                              color: bracketReadableAccent(theme),
                              onTap: () {
                                Navigator.pop(ctx);
                                _useItem(item, def);
                              },
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
      ),
    );
  }

  // ===== VIAL DETAILS DIALOG =====
  void _showVialDetailsDialog(ExtractionVial vial, FactionTheme theme) {
    final palette = _InventoryPalette.fromTheme(theme);
    final activeAccent = bracketReadableAccent(theme);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: CustomPaint(
          painter: _BracketFramePainter(
            color: activeAccent.withValues(alpha: 0.84),
            bracketSize: 12,
            strokeWidth: 1.2,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            color: palette.bg1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  color: palette.chromeFill(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vial details',
                              style: _display(
                                context,
                                22,
                                palette.ink,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Extract the specimen and send it to the chamber.',
                              style: _display(
                                context,
                                12,
                                palette.muted,
                                weight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _DialogCloseButton(
                        color: palette.line,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 150,
                  color: palette.bg0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  child: ExtractionVialCard(vial: vial, compact: false),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    'Extraction vial',
                    style: _display(
                      context,
                      20,
                      palette.ink,
                      weight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Extract this vial to capture the specimen inside and place it in your extraction chamber.',
                    style: _display(
                      context,
                      13,
                      palette.muted,
                      weight: FontWeight.w500,
                    ),
                    strutStyle: const StrutStyle(height: 1.45),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 102,
                        child: _DialogActionButton(
                          label: 'Remove',
                          icon: AppIcons.delete_outline_rounded,
                          color: const Color(0xFFC0392B),
                          secondary: true,
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _deleteVial(vial);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DialogActionButton(
                          label: 'Extract',
                          icon: AppIcons.science_rounded,
                          color: bracketReadableAccent(theme),
                          onTap: () {
                            Navigator.pop(ctx);
                            _useVial(vial);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _useItem(InventoryItem item, InventoryItemDef def) async {
    if (!def.canUse) {
      _showToast(
        'This is a key item and cannot be used right now',
        icon: AppIcons.vpn_key_rounded,
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
      icon: AppIcons.info_rounded,
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
        icon: AppIcons.error_rounded,
        color: Colors.orange,
      );
      return;
    }

    final selectedInstance = await _pickInventoryInstance(
      theme: theme,
      searchHint: 'SELECT SPECIMEN',
      prefsScopeKey: 'inventory_restore_specimens',
    );

    if (selectedInstance == null || !mounted) return;

    // Restore stamina using the service
    final updated = await staminaService.restoreToFull(
      selectedInstance.instanceId,
    );
    if (updated == null) {
      _showToast(
        'Failed to restore stamina',
        icon: AppIcons.error_rounded,
        color: Colors.red,
      );
      return;
    }

    // Consume the potion
    await db.inventoryDao.decrementItem(item.key, by: 1);

    final selectedSpecies = repo.getCreatureById(selectedInstance.baseId);
    _showToast(
      'Restored stamina for ${selectedSpecies?.name ?? 'specimen'}!',
      icon: AppIcons.favorite_rounded,
      color: Colors.green,
    );
  }

  Future<void> _showCreatureSelectorForEffect(
    InventoryItem item,
    InventoryItemDef def,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();

    // Get all instances to determine which species are eligible
    final allInstances = await db.creatureDao.listAllInstances();

    if (allInstances.isEmpty) {
      _showToast(
        'No Alchemons to apply effect to',
        icon: AppIcons.error_rounded,
        color: Colors.orange,
      );
      return;
    }

    final selectedInstance = await _pickInventoryInstance(
      theme: theme,
      searchHint: 'SELECT SPECIMEN',
      prefsScopeKey: 'inventory_effect_specimens',
    );

    if (selectedInstance == null || !mounted) return;

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
      InvKeys.alchemyWavebreakerCrown => 'wavebreaker_crown',
      _ => null,
    };

    if (effectType == null) return;

    // Apply the effect
    await db.creatureDao.updateAlchemyEffect(
      instanceId: selectedInstance.instanceId,
      effect: effectType,
    );

    // Consume the item
    await db.inventoryDao.decrementItem(item.key, by: 1);

    _showToast(
      'Applied ${def.name}!',
      icon: AppIcons.check_circle_rounded,
      color: Colors.green,
    );
  }

  Future<CreatureInstance?> _pickInventoryInstance({
    required FactionTheme theme,
    required String searchHint,
    required String prefsScopeKey,
  }) {
    return showSpecimenPickerRoute(
      context: context,
      theme: theme,
      searchHint: searchHint,
      prefsScopeKey: prefsScopeKey,
    );
  }

  Future<void> _deleteItem(InventoryItem item, InventoryItemDef def) async {
    if (!def.canDispose) {
      _showToast(
        'Special items cannot be removed',
        icon: AppIcons.lock_rounded,
        color: Colors.indigo,
      );
      return;
    }

    final theme = context.read<FactionTheme>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => _InventoryChoiceDialog(
        title: 'Remove item',
        subtitle: 'Choose how much to clear from your inventory.',
        message: 'You currently carry ${item.qty} ${def.name}.',
        accent: bracketReadableAccent(theme),
        options: [
          _InventoryDialogOption(
            value: 'one',
            label: 'Remove 1',
            icon: AppIcons.remove_circle_outline_rounded,
            color: const Color(0xFFD97706),
            secondary: true,
          ),
          _InventoryDialogOption(
            value: 'all',
            label: 'Remove all',
            icon: AppIcons.delete_sweep_rounded,
            color: const Color(0xFFC0392B),
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
          icon: AppIcons.delete_rounded,
          color: Colors.red,
        );
      } else if (confirmed == 'one') {
        await db.inventoryDao.decrementItem(item.key, by: 1);
        _showToast(
          'Removed 1 ${def.name}',
          icon: AppIcons.remove_circle_rounded,
          color: Colors.orange,
        );
      }
    } catch (e) {
      _showToast(
        'Failed to remove item',
        icon: AppIcons.error_rounded,
        color: Colors.red,
      );
    }
  }

  Future<void> _useVial(ExtractionVial vial) async {
    final db = context.read<AlchemonsDatabase>();

    final qty = await db.inventoryDao.getVialQty(
      vial.group,
      vial.rarity,
      vial.name,
    );
    if (qty <= 0) {
      _showToast(
        'No vials of this type available',
        icon: AppIcons.warning_rounded,
        color: Colors.orange,
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showExtractVialDialog(
      context: context,
      vial: vial,
      owned: qty,
      catalog: context.read<CreatureCatalog>().creatures,
    );

    if (!confirmed || !mounted) return;

    final res = await EggHatching.extractViaVial(
      context: context,
      group: vial.group,
      rarity: creatureRarityForVial(vial.rarity),
      name: vial.name,
    );

    if (!res.success) {
      _showToast(
        res.message ?? 'Extraction failed',
        icon: res.icon ?? AppIcons.error,
        color: res.color ?? Colors.red,
      );
    } else {
      _showToast(
        'Extraction complete!',
        icon: AppIcons.check_circle_rounded,
        color: Colors.green,
      );
    }
  }

  Future<void> _deleteVial(ExtractionVial vial) async {
    final theme = context.read<FactionTheme>();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => _InventoryChoiceDialog(
        title: 'Remove vial',
        subtitle: 'Choose how much to clear from your inventory.',
        message: 'This will discard ${vial.name} from your current stock.',
        accent: bracketReadableAccent(theme),
        options: [
          _InventoryDialogOption(
            value: 'one',
            label: 'Remove 1',
            icon: AppIcons.remove_circle_outline_rounded,
            color: const Color(0xFFD97706),
            secondary: true,
          ),
          _InventoryDialogOption(
            value: 'all',
            label: 'Remove all',
            icon: AppIcons.delete_sweep_rounded,
            color: const Color(0xFFC0392B),
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
          icon: AppIcons.delete_rounded,
          color: Colors.red,
        );
      } else if (confirmed == 'one') {
        await db.inventoryDao.decrementItem(vial.id, by: 1);
        _showToast(
          'Removed 1 ${vial.name} vial',
          icon: AppIcons.remove_circle_rounded,
          color: Colors.orange,
        );
      }
    } catch (e) {
      _showToast(
        'Failed to remove vial',
        icon: AppIcons.error_rounded,
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
    final palette = _InventoryPalette.fromTheme(theme);
    final activeAccent = bracketReadableAccent(theme);
    final visualWidget = InventoryImageHelper.getVisualWidget(
      key: item.key,
      assetName: InventoryImageHelper.getImage(item.key),
      icon: def.icon,
      size: 54,
    );
    final showQuantity = !def.isKeyItem;
    final frameColor = def.isKeyItem
        ? activeAccent.withValues(alpha: 0.84)
        : palette.line.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: frameColor,
          bracketSize: 10,
          strokeWidth: 1.05,
        ),
        child: Container(
          color: palette.surfaceFill(),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showQuantity)
                    Align(
                      alignment: Alignment.topRight,
                      child: Text(
                        'x${item.qty}',
                        style: _display(
                          context,
                          11,
                          palette.muted,
                          weight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Expanded(child: Center(child: visualWidget)),
                  const SizedBox(height: 8),
                  Text(
                    def.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _display(
                      context,
                      10.75,
                      palette.ink,
                      weight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _InventoryPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: color.withValues(alpha: 0.78),
          bracketSize: 8,
          strokeWidth: 1,
        ),
        child: Container(
          width: 34,
          height: 34,
          color: palette.surfaceFill(lightAlpha: 0.94),
          alignment: Alignment.center,
          child: Icon(AppIcons.close_rounded, color: palette.muted, size: 18),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final palette = _InventoryPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: color.withValues(alpha: secondary ? 0.55 : 0.8),
          bracketSize: 9,
          strokeWidth: 1.05,
        ),
        child: Container(
          height: 44,
          color: secondary
              ? palette.surfaceMutedFill()
              : palette.accentWash(color),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(
                    context,
                    13,
                    secondary ? _InventoryPalette.of(context).ink : color,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryDialogOption {
  const _InventoryDialogOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.secondary = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool secondary;
}

class _InventoryChoiceDialog extends StatelessWidget {
  const _InventoryChoiceDialog({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.accent,
    required this.options,
  });

  final String title;
  final String subtitle;
  final String message;
  final Color accent;
  final List<_InventoryDialogOption> options;

  @override
  Widget build(BuildContext context) {
    final palette = _InventoryPalette.of(context);
    final frameAccent = bracketReadableAccent(
      context.read<FactionTheme>(),
      color: accent,
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: frameAccent.withValues(alpha: 0.84),
          bracketSize: 12,
          strokeWidth: 1.2,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          color: palette.bg1,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: _display(
                            context,
                            22,
                            palette.ink,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: _display(
                            context,
                            12,
                            palette.muted,
                            weight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DialogCloseButton(
                    color: palette.line,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                message,
                style: _display(
                  context,
                  13,
                  palette.muted,
                  weight: FontWeight.w500,
                ),
                strutStyle: const StrutStyle(height: 1.45),
              ),
              const SizedBox(height: 18),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DialogActionButton(
                    label: option.label,
                    icon: option.icon,
                    color: option.color,
                    onTap: () => Navigator.pop(context, option.value),
                    secondary: option.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _DialogActionButton(
                label: 'Cancel',
                icon: AppIcons.close_rounded,
                color: palette.line,
                secondary: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
