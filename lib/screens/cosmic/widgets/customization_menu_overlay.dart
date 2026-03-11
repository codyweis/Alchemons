import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'cosmic_screen_styles.dart';

class CustomizationMenuOverlay extends StatefulWidget {
  const CustomizationMenuOverlay({
    super.key,
    required this.customizationState,
    required this.elementStorage,
    required this.homePlanet,
    required this.onTryRecipe,
    required this.onToggleRecipe,
    required this.onOptionChanged,
    required this.onUpgradeSize,
    required this.onSelectSize,
    required this.onUnlockColor,
    required this.onSelectColor,
    required this.onClose,
    required this.cargoLevel,
    required this.isNearHome,
    required this.onUpgradeCargo,
    required this.onChambers,
    required this.onUpgradePowerUp,
  });

  final HomeCustomizationState customizationState;
  final ElementStorage elementStorage;
  final HomePlanet? homePlanet;
  final int cargoLevel;
  final bool isNearHome;
  final void Function(String recipeId) onTryRecipe;
  final void Function(String recipeId) onToggleRecipe;
  final void Function(String recipeId, String paramKey, String value)
  onOptionChanged;
  final VoidCallback onUpgradeSize;
  final void Function(int tier) onSelectSize;
  final void Function(String element) onUnlockColor;
  final void Function(String? element) onSelectColor;
  final VoidCallback onClose;
  final VoidCallback onUpgradeCargo;
  final VoidCallback onChambers;
  final void Function(String type) onUpgradePowerUp;

  @override
  State<CustomizationMenuOverlay> createState() =>
      CustomizationMenuOverlayState();
}

class CustomizationMenuOverlayState extends State<CustomizationMenuOverlay> {
  /// When non-null, shows the sub-customization detail view for this recipe.
  String? _detailRecipeId;

  /// Which tab is active: 0 = SHIP, 1 = HOME
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    // If showing a detail view, render that instead
    if (_detailRecipeId != null) {
      return _buildDetailView(_detailRecipeId!);
    }

    // Group recipes by category
    final weapons = kHomeRecipes
        .where(
          (r) =>
              r.category == HomeRecipeCategory.equipment &&
              (r.id == 'equip_machinegun' || r.id == 'equip_missiles'),
        )
        .toList();
    final systems = kHomeRecipes
        .where(
          (r) =>
              r.category == HomeRecipeCategory.equipment &&
              (r.id == 'equip_booster' || r.id == 'equip_orbitals'),
        )
        .toList();
    final ammos = kHomeRecipes
        .where((r) => r.category == HomeRecipeCategory.ammo)
        .toList();
    final skins = kHomeRecipes
        .where(
          (r) =>
              r.category == HomeRecipeCategory.equipment &&
              r.id.startsWith('skin_'),
        )
        .toList();
    final visuals = kHomeRecipes
        .where((r) => r.category == HomeRecipeCategory.visual)
        .toList();
    final stations = kHomeRecipes
        .where((r) => r.category == HomeRecipeCategory.upgrade)
        .toList();

    final maxTier = widget.homePlanet?.sizeTierLevel ?? 0;
    final activeTier = widget.homePlanet?.activeSizeTier ?? 0;
    final nextCost = widget.homePlanet?.nextTierCost;
    final canAffordUpgrade =
        nextCost != null && (widget.homePlanet?.astralBank ?? 0) >= nextCost;
    final bankBalance = widget.homePlanet?.astralBank ?? 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: CosmicScreenStyles.bg0.withValues(alpha: 0.95),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      color: CosmicScreenStyles.amber,
                      margin: const EdgeInsets.only(right: 10),
                    ),
                    const Expanded(
                      child: Text(
                        'CUSTOMIZATION LAB',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close,
                          color: CosmicScreenStyles.textSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _etchedDivider(),
              const SizedBox(height: 10),

              // Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _tabButton('SHIP', 0, CosmicScreenStyles.teal),
                    const SizedBox(width: 6),
                    _tabButton('HOME', 1, CosmicScreenStyles.amberBright),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Storage summary button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _showResourcesPopup(context, bankBalance),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: CosmicScreenStyles.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: CosmicScreenStyles.borderDim),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_rounded,
                          color: CosmicScreenStyles.textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'RESOURCES',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: CosmicScreenStyles.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        if (widget.homePlanet != null) ...[
                          const Icon(
                            Icons.diamond_rounded,
                            color: CosmicScreenStyles.amberBright,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _fmt(bankBalance),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: CosmicScreenStyles.amberBright,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: CosmicScreenStyles.textMuted,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Tab content
              Expanded(
                child: _activeTab == 0
                    ? _buildShipTab(weapons, systems, ammos, skins)
                    : _buildHomeTab(
                        maxTier,
                        activeTier,
                        nextCost,
                        canAffordUpgrade,
                        visuals,
                        stations,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _etchedDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: CosmicScreenStyles.borderMid),
        ),
        const SizedBox(width: 6),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: CosmicScreenStyles.amber.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(height: 1, color: CosmicScreenStyles.borderMid),
        ),
      ],
    );
  }

  void _showResourcesPopup(BuildContext context, int bankBalance) {
    final stored = widget.elementStorage.stored;
    // Sort elements by amount descending, filter out zero
    final entries = stored.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: CosmicScreenStyles.bg0,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: CosmicScreenStyles.borderMid),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: CosmicScreenStyles.borderMid),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 12,
                        color: CosmicScreenStyles.amber,
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      const Expanded(
                        child: Text(
                          'RESOURCES',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: CosmicScreenStyles.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: const Icon(
                          Icons.close,
                          color: CosmicScreenStyles.textMuted,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Astral shards
                if (widget.homePlanet != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: CosmicScreenStyles.borderDim),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.diamond_rounded,
                          color: CosmicScreenStyles.amberBright,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ASTRAL SHARDS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: CosmicScreenStyles.amberBright,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmt(bankBalance),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: CosmicScreenStyles.amberBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Element list
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No elements collected yet',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: CosmicScreenStyles.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        final color =
                            kElementColors[e.key] ?? const Color(0xFF9E9E9E);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: color.withValues(alpha: 0.85),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Text(
                                _fmt(e.value),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: CosmicScreenStyles.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                // Total
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: CosmicScreenStyles.borderMid),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science_rounded,
                        color: CosmicScreenStyles.textSecondary,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: CosmicScreenStyles.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(widget.elementStorage.total),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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

  Widget _tabButton(String label, int index, Color color) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.12)
                : CosmicScreenStyles.bg2,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.45)
                  : CosmicScreenStyles.borderDim,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: active ? color : CosmicScreenStyles.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShipTab(
    List<HomeRecipe> weapons,
    List<HomeRecipe> systems,
    List<HomeRecipe> ammos,
    List<HomeRecipe> skins,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _sectionHeader('CARGO UPGRADE'),
        _buildCargoSection(),
        const SizedBox(height: 12),
        _sectionHeader('WEAPONS'),
        ...weapons.map((r) => _recipeCard(r)),
        const SizedBox(height: 12),
        _sectionHeader('POWER-UPS', accent: CosmicScreenStyles.amberBright),
        _buildPowerUpCard(
          label: 'AMMO POWER',
          description: 'Increase regular projectile damage.',
          level: widget.customizationState.ammoUpgradeLevel,
          icon: Icons.bolt_rounded,
          onUpgrade: () => widget.onUpgradePowerUp('ammo'),
        ),
        _buildPowerUpCard(
          label: 'MISSILE POWER',
          description: 'Increase homing missile damage.',
          level: widget.customizationState.missileUpgradeLevel,
          icon: Icons.rocket_launch_rounded,
          onUpgrade: () => widget.onUpgradePowerUp('missile'),
        ),
        _buildFuelUpgradeCard(),
        const SizedBox(height: 12),
        _sectionHeader('SHIP SYSTEMS'),
        ...systems.map((r) => _recipeCard(r)),
        const SizedBox(height: 12),
        _sectionHeader('AMMO TYPES'),
        ...ammos.map((r) => _recipeCard(r)),
        const SizedBox(height: 12),
        _sectionHeader('SHIP DESIGNS'),
        ...skins.map((r) => _recipeCard(r)),
      ],
    );
  }

  Widget _buildHomeTab(
    int maxTier,
    int activeTier,
    int? nextCost,
    bool canAffordUpgrade,
    List<HomeRecipe> visuals,
    List<HomeRecipe> stations,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Planet size
        if (widget.homePlanet != null) ...[
          _sectionHeader('PLANET SIZE', accent: CosmicScreenStyles.teal),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CosmicScreenStyles.bg2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: CosmicScreenStyles.borderDim),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selectable tier pills
                Row(
                  children: [
                    const Text(
                      'SIZE: ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: CosmicScreenStyles.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...List.generate(5, (i) {
                      final unlocked = i <= maxTier;
                      final selected = i == activeTier;
                      final name = HomePlanet.tierNames[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: unlocked ? () => widget.onSelectSize(i) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? CosmicScreenStyles.teal.withValues(
                                      alpha: 0.2,
                                    )
                                  : unlocked
                                  ? CosmicScreenStyles.bg3
                                  : CosmicScreenStyles.bg1,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: selected
                                    ? CosmicScreenStyles.teal.withValues(
                                        alpha: 0.5,
                                      )
                                    : unlocked
                                    ? CosmicScreenStyles.borderDim
                                    : CosmicScreenStyles.borderDim.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: selected
                                    ? CosmicScreenStyles.teal
                                    : unlocked
                                    ? CosmicScreenStyles.textSecondary
                                    : CosmicScreenStyles.textMuted,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 6),
                // Upgrade button
                if (nextCost != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: canAffordUpgrade ? widget.onUpgradeSize : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: canAffordUpgrade
                              ? CosmicScreenStyles.amberBright.withValues(
                                  alpha: 0.15,
                                )
                              : CosmicScreenStyles.bg2,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: canAffordUpgrade
                                ? CosmicScreenStyles.amberBright.withValues(
                                    alpha: 0.4,
                                  )
                                : CosmicScreenStyles.borderDim,
                          ),
                        ),
                        child: Text(
                          'UNLOCK ${HomePlanet.tierNames[(maxTier + 1).clamp(0, 4)].toUpperCase()} ($nextCost ✦)',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: canAffordUpgrade
                                ? CosmicScreenStyles.amberBright
                                : CosmicScreenStyles.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (nextCost == null)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ALL SIZES UNLOCKED',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: CosmicScreenStyles.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Planet colour
        _sectionHeader('PLANET COLOUR', accent: CosmicScreenStyles.amberBright),
        _buildColorGrid(),
        const SizedBox(height: 12),
        // Base stations
        _sectionHeader('BASE STATIONS', accent: CosmicScreenStyles.teal),
        ...stations.map((r) => _recipeCard(r)),
        const SizedBox(height: 12),
        // Planet visuals
        _sectionHeader(
          'PLANET VISUALS',
          accent: CosmicScreenStyles.amberBright,
        ),
        ...visuals.map((r) => _recipeCard(r)),
        const SizedBox(height: 12),
        // Chambers
        _sectionHeader('ORBITAL CHAMBERS', accent: CosmicScreenStyles.teal),
        GestureDetector(
          onTap: widget.onChambers,
          child: Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: CosmicScreenStyles.teal.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bubble_chart_rounded,
                  size: 16,
                  color: CosmicScreenStyles.teal,
                ),
                SizedBox(width: 8),
                Text(
                  'CHAMBERS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: CosmicScreenStyles.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildColorGrid() {
    final planet = widget.homePlanet;
    final activeCol = planet?.activeColor;
    final unlocked = planet?.unlockedColors ?? <String>{};
    final elements = kElementColors.entries.toList();
    const cost = HomePlanet.colorUnlockCost;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Default gray
          GestureDetector(
            onTap: () => widget.onSelectColor(null),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: activeCol == null
                    ? CosmicScreenStyles.teal.withValues(alpha: 0.12)
                    : CosmicScreenStyles.bg3,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: activeCol == null
                      ? CosmicScreenStyles.teal.withValues(alpha: 0.45)
                      : CosmicScreenStyles.borderDim,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF607D8B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DEFAULT GRAY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: activeCol == null
                          ? CosmicScreenStyles.teal
                          : CosmicScreenStyles.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Element colours grid
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: elements.map((e) {
              final isUnlocked = unlocked.contains(e.key);
              final isActive = activeCol == e.key;
              final canAfford =
                  (widget.elementStorage.stored[e.key] ?? 0) >= cost;

              return GestureDetector(
                onTap: isUnlocked
                    ? () => widget.onSelectColor(e.key)
                    : canAfford
                    ? () => widget.onUnlockColor(e.key)
                    : null,
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? CosmicScreenStyles.teal.withValues(alpha: 0.15)
                        : isUnlocked
                        ? CosmicScreenStyles.bg3
                        : CosmicScreenStyles.bg1,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isActive
                          ? CosmicScreenStyles.teal.withValues(alpha: 0.5)
                          : isUnlocked
                          ? CosmicScreenStyles.borderDim
                          : CosmicScreenStyles.borderDim.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUnlocked || canAfford
                              ? e.value
                              : e.value.withValues(alpha: 0.3),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: e.value.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: !isUnlocked
                            ? const Icon(
                                Icons.lock,
                                size: 10,
                                color: Colors.white54,
                              )
                            : null,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        e.key,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isUnlocked
                              ? CosmicScreenStyles.textSecondary
                              : CosmicScreenStyles.textMuted,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            'Unlock: $cost elements each',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: CosmicScreenStyles.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCargoSection() {
    final level = widget.cargoLevel;
    final maxed = level >= CargoUpgrade.maxLevel;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${CargoUpgrade.nameForLevel(level)} (Lv $level/${CargoUpgrade.maxLevel})',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: CosmicScreenStyles.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Teleport with ${(CargoUpgrade.capacityForLevel(level) * 100).round()}% meter',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: CosmicScreenStyles.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!maxed) ...[
            const SizedBox(height: 6),
            Text(
              'Next: ${CargoUpgrade.nextDescription(level)}',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: CosmicScreenStyles.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 3,
              children: CargoUpgrade.costForNextLevel(level).entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: CosmicScreenStyles.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${e.key}: ${_fmt(e.value)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: CosmicScreenStyles.amberBright,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.isNearHome ? widget.onUpgradeCargo : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: widget.isNearHome
                      ? CosmicScreenStyles.amber.withValues(alpha: 0.15)
                      : CosmicScreenStyles.bg2,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: widget.isNearHome
                        ? CosmicScreenStyles.amber.withValues(alpha: 0.4)
                        : CosmicScreenStyles.borderDim,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.isNearHome
                      ? 'UPGRADE CARGO'
                      : 'DOCK AT HOME TO UPGRADE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: widget.isNearHome
                        ? CosmicScreenStyles.amberBright
                        : CosmicScreenStyles.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'MAX LEVEL REACHED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: CosmicScreenStyles.success,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Color? accent}) {
    final a = accent ?? CosmicScreenStyles.amber;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 10,
            color: a,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              color: a,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerUpCard({
    required String label,
    required String description,
    required int level,
    required IconData icon,
    required VoidCallback onUpgrade,
  }) {
    final maxed = level >= HomeCustomizationState.maxUpgradeLevel;
    final nextCost = maxed ? 0 : HomeCustomizationState.upgradeCosts[level];
    final shards = widget.homePlanet?.astralBank ?? 0;
    final canAfford = !maxed && shards >= nextCost;
    final pct = (level * 16);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CosmicScreenStyles.amberBright, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: CosmicScreenStyles.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '+$pct%',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: maxed
                      ? CosmicScreenStyles.success
                      : CosmicScreenStyles.amberBright,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: CosmicScreenStyles.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Stage pips
          Row(
            children: List.generate(HomeCustomizationState.maxUpgradeLevel, (
              i,
            ) {
              final filled = i < level;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    right: i < HomeCustomizationState.maxUpgradeLevel - 1
                        ? 3
                        : 0,
                  ),
                  decoration: BoxDecoration(
                    color: filled
                        ? CosmicScreenStyles.amberBright.withValues(alpha: 0.7)
                        : CosmicScreenStyles.bg1,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: filled
                          ? CosmicScreenStyles.amberBright.withValues(
                              alpha: 0.5,
                            )
                          : CosmicScreenStyles.borderDim.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Upgrade button
          if (maxed)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'MAX LEVEL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: CosmicScreenStyles.success,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: canAfford ? onUpgrade : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? CosmicScreenStyles.amberBright.withValues(alpha: 0.15)
                        : CosmicScreenStyles.bg2,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: canAfford
                          ? CosmicScreenStyles.amberBright.withValues(
                              alpha: 0.4,
                            )
                          : CosmicScreenStyles.borderDim,
                    ),
                  ),
                  child: Text(
                    'UPGRADE LV${level + 1} ($nextCost ✦)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: canAfford
                          ? CosmicScreenStyles.amberBright
                          : CosmicScreenStyles.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFuelUpgradeCard() {
    final level = widget.customizationState.fuelUpgradeLevel;
    const maxLevel = HomeCustomizationState.maxFuelUpgradeLevel;
    final maxed = level >= maxLevel;
    final nextCost = maxed ? 0 : HomeCustomizationState.fuelUpgradeCosts[level];
    final shards = widget.homePlanet?.astralBank ?? 0;
    final canAfford = !maxed && shards >= nextCost;
    final currentCap = ShipFuel.capacityForLevel(level).toInt();
    final nextCap = maxed
        ? currentCap
        : ShipFuel.capacityForLevel(level + 1).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_gas_station_rounded,
                color: Color(0xFFFF6F00),
                size: 14,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'FUEL TANK',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: CosmicScreenStyles.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '$currentCap units',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: maxed
                      ? CosmicScreenStyles.success
                      : const Color(0xFFFF6F00),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            maxed
                ? 'Maximum capacity reached.'
                : 'Upgrade to $nextCap unit capacity.',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: CosmicScreenStyles.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Stage pips
          Row(
            children: List.generate(maxLevel, (i) {
              final filled = i < level;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < maxLevel - 1 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFFFF6F00).withValues(alpha: 0.7)
                        : CosmicScreenStyles.bg1,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: filled
                          ? const Color(0xFFFF6F00).withValues(alpha: 0.5)
                          : CosmicScreenStyles.borderDim.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          if (maxed)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'MAX LEVEL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: CosmicScreenStyles.success,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: canAfford ? () => widget.onUpgradePowerUp('fuel') : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? const Color(0xFFFF6F00).withValues(alpha: 0.15)
                        : CosmicScreenStyles.bg2,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: canAfford
                          ? const Color(0xFFFF6F00).withValues(alpha: 0.4)
                          : CosmicScreenStyles.borderDim,
                    ),
                  ),
                  child: Text(
                    'UPGRADE LV${level + 1} ($nextCost ✦)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: canAfford
                          ? const Color(0xFFFF6F00)
                          : CosmicScreenStyles.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recipeCard(HomeRecipe recipe) {
    final unlocked = widget.customizationState.isUnlocked(recipe.id);
    final active = widget.customizationState.isActive(recipe.id);
    final hasParams = kRecipeParams.containsKey(recipe.id);

    // Check if player can afford it
    bool canAfford = true;
    if (!unlocked) {
      for (final e in recipe.ingredients.entries) {
        if ((widget.elementStorage.stored[e.key] ?? 0) < e.value) {
          canAfford = false;
          break;
        }
      }
    }

    // Moon requires Big size
    final needsBigPlanet = recipe.id == 'orbiting_moon';
    final planetBigEnough =
        widget.homePlanet != null && widget.homePlanet!.sizeTierIndex >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? (active
                  ? CosmicScreenStyles.teal.withValues(alpha: 0.08)
                  : CosmicScreenStyles.bg2)
            : CosmicScreenStyles.bg1,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: unlocked
              ? (active
                    ? CosmicScreenStyles.teal.withValues(alpha: 0.4)
                    : CosmicScreenStyles.borderDim)
              : CosmicScreenStyles.borderDim.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unlocked ? recipe.name : '???',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: unlocked
                        ? CosmicScreenStyles.textPrimary
                        : CosmicScreenStyles.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (unlocked && hasParams)
                GestureDetector(
                  onTap: () => setState(() => _detailRecipeId = recipe.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: CosmicScreenStyles.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: CosmicScreenStyles.amber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: CosmicScreenStyles.amber,
                      size: 12,
                    ),
                  ),
                ),
              if (unlocked)
                GestureDetector(
                  onTap: () => widget.onToggleRecipe(recipe.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? CosmicScreenStyles.teal.withValues(alpha: 0.15)
                          : CosmicScreenStyles.bg3,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: active
                            ? CosmicScreenStyles.teal.withValues(alpha: 0.45)
                            : CosmicScreenStyles.borderDim,
                      ),
                    ),
                    child: Text(
                      active ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: active
                            ? CosmicScreenStyles.teal
                            : CosmicScreenStyles.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (unlocked) ...[
            const SizedBox(height: 4),
            Text(
              recipe.description,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: CosmicScreenStyles.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (needsBigPlanet && !planetBigEnough) ...[
              const SizedBox(height: 4),
              const Text(
                '⚠ Requires Big planet size',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: CosmicScreenStyles.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
          if (!unlocked) ...[
            const SizedBox(height: 6),
            // Ingredient hints
            Wrap(
              spacing: 4,
              runSpacing: 3,
              children: recipe.ingredients.entries.map((e) {
                final has = (widget.elementStorage.stored[e.key] ?? 0);
                final enough = has >= e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: elementColor(e.key).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: enough
                          ? elementColor(e.key).withValues(alpha: 0.4)
                          : CosmicScreenStyles.borderDim,
                    ),
                  ),
                  child: Text(
                    '${e.key}: ${_fmt(has)}/${_fmt(e.value)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: enough
                          ? elementColor(e.key)
                          : CosmicScreenStyles.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: canAfford ? () => widget.onTryRecipe(recipe.id) : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: canAfford
                      ? CosmicScreenStyles.amber.withValues(alpha: 0.15)
                      : CosmicScreenStyles.bg2,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: canAfford
                        ? CosmicScreenStyles.amber.withValues(alpha: 0.4)
                        : CosmicScreenStyles.borderDim,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  canAfford ? 'CRAFT' : 'NEED MORE ELEMENTS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: canAfford
                        ? CosmicScreenStyles.amberBright
                        : CosmicScreenStyles.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Detail sub-customization view for a specific recipe.
  Widget _buildDetailView(String recipeId) {
    final recipe = kHomeRecipes.firstWhere((r) => r.id == recipeId);
    final params = kRecipeParams[recipeId] ?? [];

    return Material(
      color: Colors.transparent,
      child: Container(
        color: CosmicScreenStyles.bg0.withValues(alpha: 0.95),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _detailRecipeId = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CosmicScreenStyles.bg3,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: CosmicScreenStyles.borderDim,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: CosmicScreenStyles.textSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 3,
                      height: 14,
                      color: CosmicScreenStyles.amber,
                      margin: const EdgeInsets.only(right: 8),
                    ),
                    Expanded(
                      child: Text(
                        recipe.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _etchedDivider(),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  recipe.description,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: CosmicScreenStyles.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Parameters
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: params.map((param) {
                    final current = widget.customizationState.getOption(
                      recipeId,
                      param.key,
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: CosmicScreenStyles.bg2,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: CosmicScreenStyles.borderDim),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Param header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: const BoxDecoration(
                              color: CosmicScreenStyles.bg3,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: CosmicScreenStyles.borderDim,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 10,
                                  color: CosmicScreenStyles.teal,
                                  margin: const EdgeInsets.only(right: 8),
                                ),
                                Text(
                                  param.label.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: CosmicScreenStyles.teal,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 5,
                              children: param.options.map((opt) {
                                final selected = current == opt;
                                return GestureDetector(
                                  onTap: () {
                                    widget.onOptionChanged(
                                      recipeId,
                                      param.key,
                                      opt,
                                    );
                                    setState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? CosmicScreenStyles.teal.withValues(
                                              alpha: 0.15,
                                            )
                                          : CosmicScreenStyles.bg3,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: selected
                                            ? CosmicScreenStyles.teal
                                                  .withValues(alpha: 0.5)
                                            : CosmicScreenStyles.borderDim,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      opt,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: selected
                                            ? CosmicScreenStyles.teal
                                            : CosmicScreenStyles.textSecondary,
                                        fontSize: 10,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHIP MENU – SCORCHED FORGE DESIGN TOKENS
// ─────────────────────────────────────────────────────────

/// Format a number with commas (e.g. 1234567 → "1,234,567").
String _fmt(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
