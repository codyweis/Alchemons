import 'dart:async';
import 'package:alchemons/widgets/inventory_item_artwork.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/services/inventory_service.dart';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/costume/costume_color_sheet.dart';
// lib/screens/inventory_screen.dart - REDESIGNED
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/utils/alchemy_effect_apply.dart';
import 'package:alchemons/widgets/harvester_glyph.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/wallet_panel.dart';
import 'package:alchemons/widgets/shelf_look.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/game_snack.dart';
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

  /// [animate] is for the places where the item is the subject — the detail
  /// dialog, a reveal — not for grids. A tile is one of dozens on screen and
  /// a painter per tile is exactly the per-frame cost this app watches for,
  /// so the default is a still frame. Note this used to be backwards for
  /// harvesters alone: HarvesterGlyph animates by default, so the one item
  /// that moved was the one in the grid.
  static Widget getVisualWidget({
    required String key,
    String? assetName,
    IconData? icon,
    required double size,
    bool animate = false,
  }) {
    final harvester = harvesterBiomeForKey(key);
    if (harvester != null) {
      return HarvesterGlyph(biomeId: harvester, size: size, animate: animate);
    }
    // Preserve relic and caller-supplied artwork for items without shop offers.
    if (assetName != null && InventoryItemArtwork.offerFor(key) == null) {
      return SizedBox.square(
        dimension: size,
        child: Image.asset(assetName, fit: BoxFit.contain),
      );
    }
    return InventoryItemArtwork(
      inventoryKey: key,
      size: size,
      animate: animate,
      fallbackIcon: icon,
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const Set<String> _spaceOnlyInventoryKeys = {
    'wallet_astral_shards',
    'item.astral_shard',
    'item.astral_shards',
  };

  /// Everything held on one page: the shop's header, then a sideways shelf
  /// per kind — vials, items, effects and costumes, special. (Four tabs of
  /// grey tiles until 2026-10.)
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.read<AlchemonsDatabase>();
    final registry = buildInventoryRegistry(db);
    final palette = _InventoryPalette.fromTheme(theme);

    Widget section(String title, List<Widget> things, String empty) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfSectionHeader(
          title,
          trailing: things.isEmpty
              ? null
              : Text(
                  '${things.length}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: things.isEmpty
              ? Text(empty, style: bracketText(context, 13, palette.muted))
              : ShelfLayout(
                  kind: ShelfKind.featured,
                  heroIndex: -1,
                  children: things,
                ),
        ),
      ],
    );

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<InventoryItem>>(
            stream: db.inventoryDao.watchItemInventory(),
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <InventoryItem>[];
              Widget item(InventoryItem it) {
                final def = registry[it.key]!;
                return _CleanItemCard(
                  item: it,
                  def: def,
                  onTap: context.soundTap(
                    () => _showItemDetailsDialog(it, def, theme),
                  ),
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                // Room under the last shelf for the dock and its raised icon.
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 48,
                ),
                children: [
                  _buildHeader(theme),
                  section(
                    'VIALS',
                    [
                      for (final v in _vialsOf(all))
                        _CleanVialCard(
                          vial: v,
                          onTap: context.soundTap(
                            () => _showVialDetailsDialog(v, theme),
                          ),
                        ),
                    ],
                    'None. The Black Market sells them.',
                  ),
                  section(
                    'ITEMS',
                    [for (final it in _itemsOf(all, registry)) item(it)],
                    'None. The shop sells them.',
                  ),
                  section(
                    'EFFECTS & COSTUMES',
                    [
                      for (final it in _itemsOf(all, registry, costumes: true))
                        item(it),
                    ],
                    'None. The shop sells them.',
                  ),
                  section(
                    'SPECIAL',
                    [for (final it in _keyItemsOf(all, registry)) item(it)],
                    'None yet.',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The shop's header: the name and the purse on one row, the element
  /// stores under them.
  Widget _buildHeader(FactionTheme theme) {
    final palette = _InventoryPalette.fromTheme(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Inventory',
                  maxLines: 1,
                  style: bracketText(context, 24, palette.ink),
                ),
              ),
              const CurrencyDisplayWidget(),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: WalletPanel(showCoins: false),
        ),
      ],
    );
  }

  /// The plain items, or with [costumes] only the alchemy effects and
  /// costumes.
  List<InventoryItem> _itemsOf(
    List<InventoryItem> all,
    Map<String, InventoryItemDef> registry, {
    bool costumes = false,
  }) => [
    for (final item in all)
      if (!_isSpaceOnlyInventoryItem(item.key) &&
          !shouldHideInventoryItem(item.key) &&
          !item.key.startsWith('vial.') &&
          (FamilyCostume.ofItem(item.key) != null ||
                  InvKeys.alchemyEffectFor(item.key) != null) ==
              costumes &&
          registry[item.key] != null &&
          !registry[item.key]!.isKeyItem)
        item,
  ];

  List<InventoryItem> _keyItemsOf(
    List<InventoryItem> all,
    Map<String, InventoryItemDef> registry,
  ) => [
    for (final item in all)
      if (!_isSpaceOnlyInventoryItem(item.key) &&
          !shouldHideInventoryItem(item.key) &&
          (registry[item.key]?.isKeyItem ?? false))
        item,
  ];

  /// The vials, read back out of their keys (`vial.<group>.<rarity>.<name>`).
  List<ExtractionVial> _vialsOf(List<InventoryItem> all) => [
    for (final item in all)
      if (item.key.startsWith('vial.') && item.key.split('.').length == 4)
        () {
          final parts = item.key.split('.');
          return ExtractionVial(
            id: item.key,
            name: parts.last,
            group: ElementalGroup.values.firstWhere(
              (g) => g.name == parts[1],
              orElse: () => ElementalGroup.oceanic,
            ),
            rarity: VialRarity.values.firstWhere(
              (r) => r.name == parts[2],
              orElse: () => VialRarity.common,
            ),
            quantity: item.qty,
            price: null,
          );
        }(),
  ];

  bool _isSpaceOnlyInventoryItem(String key) {
    final normalized = key.toLowerCase();
    return _spaceOnlyInventoryKeys.contains(normalized) ||
        normalized.contains('astral_shard');
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
      animate: true,
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
                        onTap: context.soundTap(() => Navigator.pop(ctx)),
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
                              label: item.key.startsWith('lootbox.boss.')
                                  ? 'Open box'
                                  : 'Use item',
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
                        onTap: context.soundTap(() => Navigator.pop(ctx)),
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
        color: Colors.indigo,
      );
      return;
    }

    if (item.key.startsWith('lootbox.boss.')) {
      final service = InventoryService(context.read<AlchemonsDatabase>());
      final rewards = await service.openLootBox(item.key);
      service.dispose();
      if (!mounted) return;
      if (rewards.isEmpty) {
        _showToast('No boxes remaining', color: Colors.orange);
        return;
      }
      final registry = buildInventoryRegistry(
        context.read<AlchemonsDatabase>(),
      );
      await showLootOpeningDialog(
        context: context,
        title: def.name,
        entries: rewards.map((reward) {
          final rewardDef = registry[reward.key];
          return LootOpeningEntry(
            icon: rewardDef?.icon ?? AppIcons.inventory_2_rounded,
            name: rewardDef?.name ?? reward.key,
            label: 'x${reward.value}',
            color: context.read<FactionTheme>().accent,
            visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
              key: reward.key,
              assetName: InventoryImageHelper.getImage(reward.key),
              icon: rewardDef?.icon,
              size: size,
              animate: true,
            ),
          );
        }).toList(),
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

    _showToast('Item usage not yet implemented', color: Colors.blue);
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
      _showToast('No Alchemons available', color: Colors.orange);
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
      _showToast('Failed to restore stamina', color: Colors.red);
      return;
    }

    // Consume the potion
    await db.inventoryDao.decrementItem(item.key, by: 1);

    final selectedSpecies = repo.getCreatureById(selectedInstance.baseId);
    _showToast(
      'Restored stamina for ${selectedSpecies?.name ?? 'specimen'}!',
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
      _showToast('No Alchemons to apply effect to', color: Colors.orange);
      return;
    }

    final selectedInstance = await _pickInventoryInstance(
      theme: theme,
      searchHint: 'SELECT SPECIMEN',
      prefsScopeKey: 'inventory_effect_specimens',
      effectItemKey: item.key,
    );

    if (selectedInstance == null || !mounted) return;

    // A costume goes on in a color picked on the creature, beside its
    // effect and any other costumes.
    final costume = FamilyCostume.ofItem(item.key);
    if (costume != null) {
      final color = await pickCostumeColor(
        context,
        instance: selectedInstance,
        costume: costume,
        confirmLabel: 'WEAR ${costume.noun.toUpperCase()}',
      );
      if (color == null || !mounted) return;
      if (!await wearCostume(
        db,
        instanceId: selectedInstance.instanceId,
        costume: costume,
        color: color,
      )) {
        return;
      }
      _showToast('Wearing ${def.name}!', color: Colors.green);
      return;
    }

    // Whatever effect it replaces goes back into the inventory.
    final applied = await applyAlchemyEffect(
      db,
      instanceId: selectedInstance.instanceId,
      itemKey: item.key,
    );
    if (!applied) return;

    _showToast('Applied ${def.name}!', color: Colors.green);
  }

  Future<CreatureInstance?> _pickInventoryInstance({
    required FactionTheme theme,
    required String searchHint,
    required String prefsScopeKey,
    String? effectItemKey,
  }) {
    return showSpecimenPickerRoute(
      context: context,
      theme: theme,
      searchHint: searchHint,
      prefsScopeKey: prefsScopeKey,
      onWillSelectInstance: (instance) {
        final costume = FamilyCostume.ofItem(effectItemKey);
        if (costume == null || costume.fits(instance.baseId)) return true;
        _showToast(
          '${costume.title} fits ${FamilyCostume.fittedFamiliesText}.',
          color: Colors.orange,
        );
        return false;
      },
    );
  }

  Future<void> _deleteItem(InventoryItem item, InventoryItemDef def) async {
    if (!def.canDispose) {
      _showToast('Special items cannot be removed', color: Colors.indigo);
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
            color: const Color(0xFFB89656),
            secondary: true,
          ),
          _InventoryDialogOption(
            value: 'all',
            label: 'Remove all',
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
        _showToast('Removed all ${def.name}', color: Colors.red);
      } else if (confirmed == 'one') {
        await db.inventoryDao.decrementItem(item.key, by: 1);
        _showToast('Removed 1 ${def.name}', color: Colors.orange);
      }
    } catch (e) {
      _showToast('Failed to remove item', color: Colors.red);
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
      _showToast('No vials of this type available', color: Colors.orange);
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
        color: res.color ?? Colors.red,
      );
    } else {
      _showToast('Extraction complete!', color: Colors.green);
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
            color: const Color(0xFFB89656),
            secondary: true,
          ),
          _InventoryDialogOption(
            value: 'all',
            label: 'Remove all',
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
        _showToast('Removed all ${vial.name} vials', color: Colors.red);
      } else if (confirmed == 'one') {
        await db.inventoryDao.decrementItem(vial.id, by: 1);
        _showToast('Removed 1 ${vial.name} vial', color: Colors.orange);
      }
    } catch (e) {
      _showToast('Failed to remove vial', color: Colors.red);
    }
  }

  void _showToast(String msg, {Color? color}) {
    if (!mounted) return;
    showGameSnack(context, msg, accent: color);
  }
}

// ===== ITEM ON A SHELF =====
class _CleanItemCard extends StatelessWidget {
  final InventoryItem item;
  final InventoryItemDef def;
  final VoidCallback onTap;

  const _CleanItemCard({
    required this.item,
    required this.def,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: ShelfEntry(
        art: (size) => InventoryImageHelper.getVisualWidget(
          key: item.key,
          assetName: InventoryImageHelper.getImage(item.key),
          icon: def.icon,
          size: size,
        ),
        name: def.name,
        description: def.description,
        count: def.isKeyItem ? null : '×${item.qty}',
      ),
    );
  }
}

// ===== VIAL ON A SHELF =====
class _CleanVialCard extends StatelessWidget {
  final ExtractionVial vial;
  final VoidCallback onTap;

  const _CleanVialCard({required this.vial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: ShelfEntry(
        art: (size) => ExtractionVialOrb(vial: vial, size: size),
        name: vial.name,
        description: '${vial.rarity.badgeLabel} · ${vial.group.displayName}',
        count: '×${vial.quantity}',
      ),
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
      onTap: context.soundAction(onTap),
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
    required this.color,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final palette = _InventoryPalette.of(context);
    return GestureDetector(
      onTap: context.soundAction(onTap),
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
    required this.color,
    this.secondary = false,
  });

  final String value;
  final String label;
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
                    onTap: context.soundTap(() => Navigator.pop(context)),
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
                    color: option.color,
                    onTap: context.soundTap(
                      () => Navigator.pop(context, option.value),
                    ),
                    secondary: option.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _DialogActionButton(
                label: 'Cancel',
                color: palette.line,
                secondary: true,
                onTap: context.soundTap(() => Navigator.pop(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
