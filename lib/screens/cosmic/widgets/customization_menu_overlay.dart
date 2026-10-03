// The customization lab: the ship and the home planet, and everything that
// can be made for them.
//
// Each tab opens on a live stage — the ship flying, or the planet turning —
// and below it what can be made, as pictures: hulls and planet effects drawn
// by the painters that draw them in space, so the player sees what they are
// making before they make it. Tapping anything tries it on the stage and
// docks its card at the foot of the lab: what it costs, its options, the one
// thing to do with it. Upgrades are a short list of rows, not cards.
//
// Locked things keep their names to themselves ("???"), as they always have;
// the stage and the thumbnails show them, dimmed, so a craft is never blind.

import 'dart:ui' as ui;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

import 'cosmic_panel_kit.dart';
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
    this.canPreview = false,
    this.onPreview,
    this.initialTab = 0,
    this.onTabChanged,
    required this.onClose,
    this.onBack,
    required this.cargoLevel,
    required this.isNearHome,
    required this.onUpgradeCargo,
    required this.onUpgradePowerUp,
    required this.onGarrison,
    this.garrisonStationed = 0,
    this.garrisonSlots = 0,
    this.paintHome,
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

  /// True once the lab has changed something visible on the home planet.
  final bool canPreview;

  /// Hides the lab so the player can look at the planet itself.
  final VoidCallback? onPreview;

  /// Which tab to open on: 0 = SHIP, 1 = HOME.
  ///
  /// Owned by the cosmic screen, not by this widget's State. Preview tears the
  /// whole overlay down and rebuilds it, so State-local tab memory does not
  /// survive the round trip — it has to be held above.
  final int initialTab;

  /// Reports tab changes upward so [initialTab] can be kept current.
  final ValueChanged<int>? onTabChanged;

  /// Dismiss the whole panel stack back to the world.
  final VoidCallback onClose;

  /// Step up one level to whatever opened this. Falls back to [onClose].
  final VoidCallback? onBack;
  final VoidCallback onUpgradeCargo;
  final void Function(String type) onUpgradePowerUp;

  /// Opens the garrison picker. Who is stationed on the planet is part of
  /// how the planet is set up, so it lives here.
  final VoidCallback onGarrison;
  final int garrisonStationed;
  final int garrisonSlots;

  /// Draws the real home planet for the HOME stage and the effect pictures.
  /// Without it (tests, previews) the lab draws a plain sphere.
  final HomeShowcasePainter? paintHome;

  @override
  State<CustomizationMenuOverlay> createState() =>
      CustomizationMenuOverlayState();
}

// ── what can be picked ──────────────────────────────────────────────────────

enum _PickKind { recipe, standardHull, color, size }

/// The thing the lab is showing on its stage and in its dock.
class _Pick {
  const _Pick(this.kind, [this.id]);
  final _PickKind kind;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is _Pick && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

const _shipAccent = CosmicScreenStyles.teal;
const _homeAccent = CosmicScreenStyles.amberBright;
const _palette = panelPalette;

const _hullIds = ['skin_phantom', 'skin_solar', 'skin_inferno', 'skin_crystal'];
const _weaponIds = ['equip_machinegun', 'equip_missiles'];
const _systemIds = ['equip_orbitals', 'equip_matter_injector'];
const _ammoIds = ['storm_bolts', 'plasma_bolts', 'ice_shards', 'void_cannon'];
const _stationIds = ['refuel_station', 'missile_station', 'sentinel_station'];

/// Only one of each of these can be fitted at a time.
bool _isExclusive(String id) =>
    _hullIds.contains(id) || _weaponIds.contains(id) || _ammoIds.contains(id);

/// What a bolt of each ammo looks like in flight.
Color _ammoColor(String? id) => switch (id) {
  'storm_bolts' => const Color(0xFFFFEB3B),
  'plasma_bolts' => const Color(0xFFFFFFFF),
  'ice_shards' => const Color(0xFF00E5FF),
  'void_cannon' => const Color(0xFF9C27B0),
  _ => const Color(0xFF00E5FF),
};

HomeRecipe? _recipe(String id) {
  for (final r in kHomeRecipes) {
    if (r.id == id) return r;
  }
  return null;
}

class CustomizationMenuOverlayState extends State<CustomizationMenuOverlay> {
  late int _activeTab = widget.initialTab;
  _Pick? _pick;

  /// Pictures of the planet wearing each effect, by what they were drawn
  /// with (effect, colour, options).
  final Map<String, ui.Image> _thumbs = {};

  @visibleForTesting
  int get activeTabForTest => _activeTab;

  @override
  void dispose() {
    for (final img in _thumbs.values) {
      img.dispose();
    }
    super.dispose();
  }

  void _setTab(int index) {
    setState(() {
      _activeTab = index;
      _pick = null;
    });
    widget.onTabChanged?.call(index);
  }

  void _select(_Pick pick) =>
      setState(() => _pick = _pick == pick ? null : pick);

  /// After any change the parent makes to the state objects it owns.
  void _after(VoidCallback act) {
    act();
    setState(() {});
  }

  Map<String, double> get _stored => widget.elementStorage.stored;
  int get _shards => widget.homePlanet?.astralBank ?? 0;

  bool _canAfford(Map<String, int> cost) =>
      cost.entries.every((e) => (_stored[e.key] ?? 0) >= e.value);

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = _activeTab == 0 ? _shipAccent : _homeAccent;
    return Material(
      color: Colors.transparent,
      child: Container(
        color: CosmicScreenStyles.bg0.withValues(alpha: 0.96),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BracketTabs(
                  labels: const ['SHIP', 'HOME'],
                  icons: const [
                    AppIcons.rocket_launch_rounded,
                    AppIcons.public_rounded,
                  ],
                  selected: _activeTab,
                  onSelect: _setTab,
                  palette: _palette,
                  accent: accent,
                ),
              ),
              const SizedBox(height: 10),
              _stage(accent),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _activeTab == 0 ? _shipTab() : _homeTab(),
                ),
              ),
              _pick == null ? _backDock() : _dock(_pick!, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return PanelHeader(
      title: 'CUSTOMIZATION LAB',
      onClose: widget.onClose,
      // What there is to spend, a tap from the full list.
      trailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(() => _showResourcesPopup(context)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (widget.homePlanet != null) ...[
                ShardAmount(_shards, size: 12.5),
                const SizedBox(width: 10),
              ],
              Icon(
                AppIcons.inventory_2_rounded,
                size: 16,
                color: _palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom-docked exit, matching the other cosmic panels.
  Widget _backDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: CosmicScreenStyles.borderMid, width: 1.2),
        ),
      ),
      child: BracketButton(
        label: 'BACK',
        icon: AppIcons.arrow_back,
        primary: false,
        height: 40,
        palette: _palette,
        accent: _shipAccent,
        onTap: widget.onBack ?? widget.onClose,
      ),
    );
  }

  // ── the stage ──────────────────────────────────────────────────────────

  Widget _stage(Color accent) {
    final pick = _pick;
    final cs = widget.customizationState;
    final Widget stage;
    String caption;
    if (_activeTab == 0) {
      // The hull on show: the one picked, else the one flying.
      var skin = cs.activeShipSkin;
      if (pick?.kind == _PickKind.standardHull) skin = null;
      if (pick?.kind == _PickKind.recipe && _hullIds.contains(pick!.id)) {
        skin = pick.id;
      }
      // A weapon or an ammo on show fires, in the ammo it would carry.
      final id = pick?.kind == _PickKind.recipe ? pick!.id : null;
      final firing = _ammoIds.contains(id) || _weaponIds.contains(id);
      final ammo = _ammoIds.contains(id) ? id : cs.activeAmmo?.id;
      stage = ShipStage(
        skin: skin,
        orbitals: cs.hasOrbitals || id == 'equip_orbitals',
        bolts: firing ? _ammoColor(ammo) : null,
        repeater:
            id == 'equip_machinegun' ||
            (_ammoIds.contains(id) && cs.activeWeapon != null),
        missiles: id == 'equip_missiles',
      );
      caption = skin == null ? 'STANDARD HULL' : (_named(skin) ?? '???');
    } else {
      final planet = widget.homePlanet;
      var wearing = cs.activeIds
          .where((id) => _recipe(id)?.category == HomeRecipeCategory.visual)
          .toSet();
      var color = planet?.activeColor;
      if (pick?.kind == _PickKind.recipe &&
          _recipe(pick!.id!)?.category == HomeRecipeCategory.visual) {
        wearing = {...wearing, pick.id!};
      }
      if (pick?.kind == _PickKind.color) color = pick!.id;
      stage = HomeStage(
        paintHome: planet == null ? null : widget.paintHome,
        wearing: wearing,
        color: color,
      );
      caption = wearing.isEmpty ? 'YOUR PLANET' : 'WEARING ${wearing.length}';
    }
    return SizedBox(
      height: 176,
      child: Stack(
        children: [
          Positioned.fill(child: stage),
          Positioned(
            left: 16,
            bottom: 8,
            child: Text(caption, style: panelLabel(10.5, _palette.muted)),
          ),
          if (_activeTab == 1 && widget.canPreview && widget.onPreview != null)
            Positioned(
              right: 16,
              bottom: 4,
              child: SizedBox(
                height: 30,
                child: BracketButton(
                  label: 'PREVIEW ON PLANET',
                  icon: AppIcons.visibility_rounded,
                  height: 30,
                  palette: _palette,
                  accent: _homeAccent,
                  onTap: widget.onPreview,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _named(String id) {
    final r = _recipe(id);
    if (r == null) return null;
    return widget.customizationState.isUnlocked(id)
        ? r.name.toUpperCase()
        : null;
  }

  // ── SHIP ───────────────────────────────────────────────────────────────

  Widget _shipTab() {
    final cs = widget.customizationState;
    return ListView(
      key: const PageStorageKey<String>('cosmic.lab.ship'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        _section('HULL'),
        _grid(5, [_hullTile(null), for (final id in _hullIds) _hullTile(id)]),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('WEAPON'),
                  _grid(2, [for (final id in _weaponIds) _recipeTile(id)]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('SYSTEMS'),
                  _grid(2, [for (final id in _systemIds) _recipeTile(id)]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _section('AMMO'),
        _grid(4, [for (final id in _ammoIds) _recipeTile(id)]),
        const SizedBox(height: 14),
        _section('UPGRADES'),
        _cargoRow(),
        _powerRow(
          label: 'AMMO POWER',
          level: cs.ammoUpgradeLevel,
          max: HomeCustomizationState.maxUpgradeLevel,
          value:
              '+${((HomeCustomizationState.damageMultiplier(cs.ammoUpgradeLevel) - 1) * 100).round()}%',
          costs: HomeCustomizationState.upgradeCosts,
          onUpgrade: () => widget.onUpgradePowerUp('ammo'),
        ),
        _powerRow(
          label: 'MISSILE POWER',
          level: cs.missileUpgradeLevel,
          max: HomeCustomizationState.maxUpgradeLevel,
          value:
              '+${((HomeCustomizationState.missileDamageMultiplier(cs.missileUpgradeLevel) - 1) * 100).round()}%',
          costs: HomeCustomizationState.upgradeCosts,
          onUpgrade: () => widget.onUpgradePowerUp('missile'),
        ),
        _powerRow(
          label: 'FUEL TANK',
          level: cs.fuelUpgradeLevel,
          max: HomeCustomizationState.maxFuelUpgradeLevel,
          value:
              '${ShipFuel.capacityForLevel(cs.fuelUpgradeLevel).toInt()} UNITS',
          costs: HomeCustomizationState.fuelUpgradeCosts,
          onUpgrade: () => widget.onUpgradePowerUp('fuel'),
        ),
      ],
    );
  }

  Widget _hullTile(String? id) {
    final cs = widget.customizationState;
    final owned = id == null || cs.isUnlocked(id);
    final flying = cs.activeShipSkin == id;
    final pick = id == null
        ? const _Pick(_PickKind.standardHull)
        : _Pick(_PickKind.recipe, id);
    final recipe = id == null ? null : _recipe(id);
    return _Tile(
      key: ValueKey('lab.hull.${id ?? 'standard'}'),
      accent: _shipAccent,
      aspect: 0.82,
      equipped: flying,
      owned: owned,
      craftable: !owned && _canAfford(recipe!.ingredients),
      selected: _pick == pick,
      label: owned ? (id == null ? 'STANDARD' : _short(recipe!.name)) : null,
      onTap: () => _select(pick),
      child: CustomPaint(painter: _HullThumbPainter(id)),
    );
  }

  Widget _recipeTile(String id) {
    final cs = widget.customizationState;
    final recipe = _recipe(id)!;
    final owned = cs.isUnlocked(id);
    final pick = _Pick(_PickKind.recipe, id);
    final isStation = _stationIds.contains(id);
    final accent = _activeTab == 0 ? _shipAccent : _homeAccent;
    return _Tile(
      key: ValueKey('lab.recipe.$id'),
      accent: accent,
      equipped: owned && (isStation || cs.isActive(id)),
      owned: owned,
      craftable: !owned && _canAfford(recipe.ingredients),
      selected: _pick == pick,
      label: owned ? _short(recipe.name) : null,
      onTap: () => _select(pick),
      child: _RecipeGlyph(id: id, accent: accent),
    );
  }

  /// A name short enough for a tile: its last word ("RINGS", "VIPER"),
  /// or for a station, its first ("REFUEL").
  static String _short(String name) {
    final words = name.toUpperCase().split(' ');
    if (words.length < 2 || name.length <= 11) return name.toUpperCase();
    return words.last == 'STATION' ? words.first : words.last;
  }

  Widget _cargoRow() {
    final level = widget.cargoLevel;
    final maxed = level >= CargoUpgrade.maxLevel;
    final cost = maxed
        ? const <String, int>{}
        : CargoUpgrade.costForNextLevel(level);
    return _UpgradeRow(
      label: 'CARGO HOLD',
      level: level,
      max: CargoUpgrade.maxLevel,
      value: '${(CargoUpgrade.capacityForLevel(level) * 100).round()}% METER',
      accent: _shipAccent,
      maxed: maxed,
      cost: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          for (final e in cost.entries) CostChip(e.key, e.value, _stored),
        ],
      ),
      buttonLabel: widget.isNearHome ? 'UPGRADE' : 'DOCK AT HOME',
      enabled: widget.isNearHome && _canAfford(cost),
      onUpgrade: () => _after(widget.onUpgradeCargo),
    );
  }

  Widget _powerRow({
    required String label,
    required int level,
    required int max,
    required String value,
    required List<int> costs,
    required VoidCallback onUpgrade,
  }) {
    final maxed = level >= max;
    final next = maxed ? 0 : costs[level];
    return _UpgradeRow(
      label: label,
      level: level,
      max: max,
      value: value,
      accent: _shipAccent,
      maxed: maxed,
      cost: ShardAmount(next, size: 11.5, enabled: _shards >= next),
      buttonLabel: 'LV ${level + 1}',
      enabled: _shards >= next,
      onUpgrade: () => _after(onUpgrade),
    );
  }

  // ── HOME ───────────────────────────────────────────────────────────────

  Widget _homeTab() {
    final planet = widget.homePlanet;
    final cs = widget.customizationState;
    final visuals = [
      for (final r in kHomeRecipes)
        if (r.category == HomeRecipeCategory.visual) r.id,
    ];
    return ListView(
      key: const PageStorageKey<String>('cosmic.lab.home'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        BracketButton(
          key: const ValueKey('lab.garrison'),
          label: 'GARRISON',
          icon: AppIcons.shield,
          primary: false,
          height: 38,
          palette: _palette,
          accent: _homeAccent,
          trailing: Text(
            '${widget.garrisonStationed}/${widget.garrisonSlots}',
            style: panelLabel(
              11.5,
              widget.garrisonSlots > 0 &&
                      widget.garrisonStationed >= widget.garrisonSlots
                  ? CosmicScreenStyles.success
                  : _homeAccent,
            ),
          ),
          onTap: widget.onGarrison,
        ),
        if (planet != null) ...[
          const SizedBox(height: 14),
          _section(
            'SIZE',
            trailing: HomePlanet.tierNames[planet.activeSizeTier],
          ),
          _sizeRow(planet),
          const SizedBox(height: 14),
          _section('COLOUR', trailing: _colorName(planet.activeColor)),
          _colorSwatches(planet),
        ],
        const SizedBox(height: 14),
        _section(
          'EFFECTS',
          trailing: '${visuals.where(cs.isUnlocked).length}/${visuals.length}',
        ),
        _grid(4, [for (final id in visuals) _effectTile(id)]),
        const SizedBox(height: 14),
        _section('STATIONS'),
        _grid(4, [for (final id in _stationIds) _recipeTile(id)]),
      ],
    );
  }

  static String _colorName(String? id) =>
      (premiumHomeColor(id)?.label ?? id ?? 'Default Gray');

  Widget _sizeRow(HomePlanet planet) {
    final next = planet.sizeTierLevel + 1;
    final nextCost = planet.nextTierCost;
    return Row(
      children: [
        for (var i = 0; i < HomePlanet.tierNames.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _SizeCell(
              key: ValueKey('lab.size.$i'),
              name: HomePlanet.tierNames[i].toUpperCase(),
              active: planet.activeSizeTier == i,
              unlocked: i <= planet.sizeTierLevel,
              cost: i == next ? nextCost : null,
              selected: _pick == _Pick(_PickKind.size, '$i'),
              onTap: i <= planet.sizeTierLevel
                  ? () => _after(() => widget.onSelectSize(i))
                  : i == next && nextCost != null
                  ? () => _select(_Pick(_PickKind.size, '$i'))
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _colorSwatches(HomePlanet planet) {
    final ids = <String?>[
      null,
      ...kElementColors.keys,
      for (final p in kPremiumHomeColors) p.id,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final cols = box.maxWidth >= 470 ? 10 : 7;
        final cell = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final id in ids)
              SizedBox(
                width: cell,
                height: cell,
                child: _Swatch(
                  key: ValueKey('lab.color.${id ?? 'default'}'),
                  id: id,
                  active: planet.activeColor == id,
                  owned: id == null || planet.unlockedColors.contains(id),
                  craftable: id != null && _canAfford(_colorCost(id)),
                  selected: _pick == _Pick(_PickKind.color, id),
                  onTap: () {
                    final owned =
                        id == null || planet.unlockedColors.contains(id);
                    if (owned) {
                      // An owned colour is one tap: it is cheap to undo.
                      setState(() => _pick = null);
                      _after(() => widget.onSelectColor(id));
                    } else {
                      _select(_Pick(_PickKind.color, id));
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  static Map<String, int> _colorCost(String id) =>
      premiumHomeColor(id)?.cost ?? {id: HomePlanet.colorUnlockCost};

  Widget _effectTile(String id) {
    final cs = widget.customizationState;
    final recipe = _recipe(id)!;
    final owned = cs.isUnlocked(id);
    final pick = _Pick(_PickKind.recipe, id);
    return _Tile(
      key: ValueKey('lab.recipe.$id'),
      accent: _homeAccent,
      equipped: owned && cs.isActive(id),
      owned: owned,
      craftable: !owned && _canAfford(recipe.ingredients),
      selected: _pick == pick,
      label: owned ? _short(recipe.name) : null,
      onTap: () => _select(pick),
      child: CustomPaint(
        painter: _EffectThumbPainter(
          image: _thumbFor(id),
          fallbackColor: widget.homePlanet?.blendedColor ?? Colors.blueGrey,
        ),
      ),
    );
  }

  /// The planet wearing [id] alone, drawn once and kept until the colour or
  /// the effect's options change.
  ui.Image? _thumbFor(String id) {
    final paint = widget.paintHome;
    final planet = widget.homePlanet;
    if (paint == null || planet == null) return null;
    final cs = widget.customizationState;
    final opts = [
      for (final p in kRecipeParams[id] ?? const <CustomizationParam>[])
        cs.getOption(id, p.key),
    ].join(',');
    final key = '$id|${planet.activeColor}|$opts';
    final have = _thumbs[key];
    if (have != null) return have;
    _thumbs.removeWhere((k, img) {
      if (!k.startsWith('$id|')) return false;
      img.dispose();
      return true;
    });
    const px = 192;
    const frame = Rect.fromLTWH(0, 0, px + 0.0, px + 0.0);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, frame);
    // Once per picture, so the layer costs nothing a frame.
    canvas.saveLayer(frame, Paint());
    // Drawn a size up, so the planet fills the tile; only the farthest
    // reach of the widest effects falls off the edge.
    paint(
      canvas,
      Rect.fromCenter(
        center: frame.center,
        width: px * 1.45,
        height: px * 1.45,
      ),
      4.0,
      wearing: {id},
      color: planet.activeColor,
    );
    // Faded to nothing at the edge, so the picture has no corners.
    canvas.drawRect(
      frame,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          frame.center,
          px / 2,
          const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          const [0.0, 0.7, 1.0],
        ),
    );
    canvas.restore();
    return _thumbs[key] = rec.endRecording().toImageSync(px, px);
  }

  // ── the dock ───────────────────────────────────────────────────────────

  Widget _dock(_Pick pick, Color accent) {
    final content = switch (pick.kind) {
      _PickKind.recipe => _recipeDock(pick.id!, accent),
      _PickKind.standardHull => _standardHullDock(),
      _PickKind.color => _colorDock(pick.id),
      _PickKind.size => _sizeDock(int.parse(pick.id!)),
    };
    return Container(
      key: const ValueKey('lab.dock'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.46,
      ),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.2),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: content,
      ),
    );
  }

  Widget _dockTitle(String title, {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: panelLabel(13.5, _palette.ink, spacing: 1.8)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: panelLabel(10.5, _palette.muted)),
              ],
            ],
          ),
        ),
        BracketIconButton(
          icon: AppIcons.close_rounded,
          size: 30,
          palette: _palette,
          onTap: () => setState(() => _pick = null),
        ),
      ],
    );
  }

  Widget _prose(String text, {Color? color}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: appFontFamily(context),
        color: color ?? CosmicScreenStyles.textSecondary,
        fontSize: 13,
        height: 1.3,
      ),
    ),
  );

  Widget _costs(Map<String, int> cost) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final e in cost.entries)
          CostChip(e.key, e.value, _stored, size: 12.5),
      ],
    ),
  );

  Widget _action(
    String label,
    Color accent, {
    VoidCallback? onTap,
    bool enabled = true,
    bool primary = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: BracketButton(
      key: const ValueKey('lab.dock.action'),
      label: label,
      height: 42,
      palette: _palette,
      accent: accent,
      primary: primary,
      enabled: enabled && onTap != null,
      onTap: onTap,
    ),
  );

  Widget _recipeDock(String id, Color accent) {
    final cs = widget.customizationState;
    final recipe = _recipe(id)!;
    final owned = cs.isUnlocked(id);
    final active = cs.isActive(id);
    final isStation = _stationIds.contains(id);
    final params = kRecipeParams[id] ?? const <CustomizationParam>[];
    final planet = widget.homePlanet;
    final needsBig =
        id == 'orbiting_moon' && (planet == null || planet.sizeTierIndex < 3);

    if (!owned) {
      final affordable = _canAfford(recipe.ingredients);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dockTitle('???', subtitle: _kindName(recipe)),
          _costs(recipe.ingredients),
          _action(
            'CRAFT',
            accent,
            enabled: affordable,
            onTap: () => _after(() => widget.onTryRecipe(id)),
          ),
        ],
      );
    }

    final String label;
    if (isStation) {
      label = 'BUILT';
    } else if (_isExclusive(id)) {
      label = active ? 'UNEQUIP' : 'EQUIP';
    } else {
      label = active ? 'SWITCH OFF' : 'SWITCH ON';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dockTitle(
          recipe.name.toUpperCase(),
          subtitle: _kindName(recipe) + (active && !isStation ? ' · ON' : ''),
        ),
        _prose(recipe.description),
        if (needsBig)
          _prose('Shows on a Big planet.', color: CosmicScreenStyles.amber),
        for (final p in params) _paramRow(id, p, accent),
        _action(
          label,
          accent,
          primary: !active,
          onTap: isStation
              ? null
              : () => _after(() => widget.onToggleRecipe(id)),
          enabled: !isStation,
        ),
      ],
    );
  }

  static String _kindName(HomeRecipe r) {
    final id = r.id;
    if (_hullIds.contains(id)) return 'HULL';
    if (_weaponIds.contains(id)) return 'WEAPON';
    if (_systemIds.contains(id)) return 'SHIP SYSTEM';
    if (_ammoIds.contains(id)) return 'AMMO';
    if (_stationIds.contains(id)) return 'BASE STATION';
    return 'PLANET EFFECT';
  }

  Widget _paramRow(String id, CustomizationParam param, Color accent) {
    final current = widget.customizationState.getOption(id, param.key);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            param.label.toUpperCase(),
            style: panelLabel(10.5, _palette.muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final opt in param.options)
                _OptionChip(
                  label: opt,
                  selected: opt == current,
                  accent: accent,
                  onTap: () =>
                      _after(() => widget.onOptionChanged(id, param.key, opt)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _standardHullDock() {
    final flying = widget.customizationState.activeShipSkin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dockTitle('STANDARD HULL', subtitle: 'HULL'),
        _prose('The hull every ship leaves the yard with.'),
        _action(
          flying == null ? 'FLYING' : 'EQUIP',
          _shipAccent,
          enabled: flying != null,
          onTap: flying == null
              ? null
              : () => _after(() => widget.onToggleRecipe(flying)),
        ),
      ],
    );
  }

  Widget _colorDock(String? id) {
    final premium = premiumHomeColor(id);
    final cost = id == null ? const <String, int>{} : _colorCost(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dockTitle(
          _colorName(id).toUpperCase(),
          subtitle: premium != null ? 'PREMIUM COLOUR' : 'COLOUR',
        ),
        _costs(cost),
        _action(
          'UNLOCK',
          _homeAccent,
          enabled: id != null && _canAfford(cost),
          onTap: id == null
              ? null
              : () => _after(() {
                  widget.onUnlockColor(id);
                  _pick = null;
                }),
        ),
      ],
    );
  }

  Widget _sizeDock(int tier) {
    final cost = widget.homePlanet?.nextTierCost ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dockTitle(HomePlanet.tierNames[tier].toUpperCase(), subtitle: 'SIZE'),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ShardAmount(cost, size: 13, enabled: _shards >= cost),
        ),
        _action(
          'UNLOCK',
          _homeAccent,
          enabled: _shards >= cost,
          onTap: () => _after(() {
            widget.onUpgradeSize();
            _pick = null;
          }),
        ),
      ],
    );
  }

  // ── pieces ─────────────────────────────────────────────────────────────

  Widget _section(String title, {String? trailing}) =>
      PanelSectionHeader(title, trailing: trailing);

  /// [children] in rows of [columns].
  Widget _grid(int columns, List<Widget> children) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final w = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    );
  }

  void _showResourcesPopup(BuildContext context) {
    final entries =
        _stored.entries
            .where((e) => e.value > 0 && isKnownElement(e.key))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: _homeAccent.withValues(alpha: 0.8),
              bracketSize: 12,
              strokeWidth: 1.2,
            ),
            child: Container(
              width: 270,
              constraints: const BoxConstraints(maxHeight: 440),
              color: _palette.bg1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'RESOURCES',
                            style: panelLabel(12, _palette.ink, spacing: 2),
                          ),
                        ),
                        BracketIconButton(
                          icon: AppIcons.close_rounded,
                          size: 28,
                          palette: _palette,
                          onTap: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  if (widget.homePlanet != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Row(
                        children: [
                          Text(
                            'ASTRAL SHARDS',
                            style: panelLabel(
                              11.5,
                              CosmicScreenStyles.astralShardColor,
                            ),
                          ),
                          const Spacer(),
                          ShardAmount(_shards, size: 12),
                        ],
                      ),
                    ),
                  Container(height: 1, color: _palette.lineSoft),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No elements collected yet',
                        style: panelLabel(11.5, _palette.muted),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: [
                          for (final e in entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 3,
                              ),
                              child: Row(
                                children: [
                                  PanelDot(elementInk(e.key)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.key.toUpperCase(),
                                      style: panelLabel(
                                        11.5,
                                        elementInk(e.key),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    panelFmt(e.value),
                                    style: panelLabel(11.5, _palette.ink),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  Container(height: 1, color: _palette.lineSoft),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      children: [
                        Text('TOTAL', style: panelLabel(11.5, _palette.muted)),
                        const Spacer(),
                        Text(
                          panelFmt(widget.elementStorage.total),
                          style: panelLabel(11.5, _palette.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── small widgets ───────────────────────────────────────────────────────────

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      color: selected
          ? accent.withValues(alpha: 0.14)
          : _palette.surfaceMutedFill(),
      child: Text(
        label.toUpperCase(),
        style: panelLabel(10.5, selected ? _palette.ink : _palette.muted),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: selected ? accent : _palette.line.withValues(alpha: 0.6),
          bracketSize: 6,
          strokeWidth: selected ? 1.2 : 1,
        ),
        child: content,
      ),
    );
  }
}

/// One thing that can be made: its picture in a frame. Fitted, it wears the
/// accent's brackets; locked, it is dimmed with a lock, or marked with a
/// spark when everything it takes is already in the hold.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.accent,
    required this.child,
    required this.onTap,
    this.equipped = false,
    this.owned = true,
    this.craftable = false,
    this.selected = false,
    this.label,
    this.aspect = 1,
  });

  final Color accent;
  final Widget child;
  final VoidCallback onTap;
  final bool equipped, owned, craftable, selected;
  final String? label;

  /// Picture width over height.
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final frame = selected
        ? _palette.ink
        : equipped
        ? accent
        : _palette.line.withValues(alpha: 0.55);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: frame,
          bracketSize: 7,
          strokeWidth: selected || equipped ? 1.3 : 1,
        ),
        child: Container(
          color: equipped
              ? accent.withValues(alpha: 0.1)
              : _palette.bg1.withValues(alpha: 0.6),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(opacity: owned ? 1 : 0.5, child: child),
                    if (!owned)
                      Positioned(
                        top: 1,
                        right: 1,
                        child: craftable
                            ? const PanelDot(
                                CosmicScreenStyles.amberBright,
                                size: 6,
                              )
                            : Icon(
                                AppIcons.lock_rounded,
                                size: 10,
                                color: _palette.muted,
                              ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 14,
                child: label == null
                    ? null
                    : Center(
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: panelLabel(
                            9,
                            equipped ? _palette.ink : _palette.muted,
                            spacing: 0.6,
                          ),
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

class _SizeCell extends StatelessWidget {
  const _SizeCell({
    super.key,
    required this.name,
    required this.active,
    required this.unlocked,
    required this.selected,
    required this.onTap,
    this.cost,
  });
  final String name;
  final bool active, unlocked, selected;
  final int? cost;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final frame = selected
        ? _palette.ink
        : active
        ? _homeAccent
        : _palette.line.withValues(alpha: unlocked ? 0.55 : 0.25);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: frame,
          bracketSize: 6,
          strokeWidth: active || selected ? 1.3 : 1,
        ),
        child: Container(
          height: 46,
          color: active
              ? _homeAccent.withValues(alpha: 0.12)
              : _palette.bg1.withValues(alpha: 0.6),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                style: panelLabel(
                  10,
                  active
                      ? _palette.ink
                      : unlocked
                      ? _palette.ink.withValues(alpha: 0.75)
                      : _palette.muted.withValues(alpha: 0.6),
                  spacing: 0.6,
                ),
              ),
              if (cost != null) ...[
                const SizedBox(height: 3),
                FittedBox(child: ShardAmount(cost!, size: 9.5)),
              ] else if (!unlocked) ...[
                const SizedBox(height: 3),
                Icon(
                  AppIcons.lock_rounded,
                  size: 9,
                  color: _palette.muted.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.id,
    required this.active,
    required this.owned,
    required this.craftable,
    required this.selected,
    required this.onTap,
  });
  final String? id;
  final bool active, owned, craftable, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: active || selected
            ? BracketFramePainter(
                color: selected ? _palette.ink : _homeAccent,
                bracketSize: 6,
                strokeWidth: 1.3,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CustomPaint(
            painter: _SwatchPainter(id, owned: owned, craftable: craftable),
          ),
        ),
      ),
    );
  }
}

// ── painters ────────────────────────────────────────────────────────────────

/// A colour as a small lit sphere: owned ones full, locked ones a dim
/// ghost of themselves.
class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.id, {required this.owned, required this.craftable});
  final String? id;
  final bool owned, craftable;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final base = homeColorSwatch(id);
    final a = owned ? 1.0 : (craftable ? 0.55 : 0.28);
    final isVoid = id == 'Void';
    final isRadiant = id == 'Radiant';
    final lit = isVoid
        ? const Color(0xFF3A1E66)
        : Color.lerp(base, Colors.white, isRadiant ? 0.6 : 0.35)!;
    final dark = isVoid
        ? const Color(0xFF020006)
        : Color.lerp(base, Colors.black, 0.55)!;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.35, -r * 0.4),
          r * 1.4,
          [
            lit.withValues(alpha: a),
            base.withValues(alpha: a),
            dark.withValues(alpha: a),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    if (isVoid) {
      // Void black, rimmed in the violet it gives off.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              const Color(0x00000000),
              const Color(0x00000000),
              const Color(0xFF9A6AE0).withValues(alpha: 0.85 * a),
            ],
            const [0.0, 0.72, 1.0],
          ),
      );
    }
    if (!owned && !craftable) {
      final icon = AppIcons.lock_rounded;
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: r * 0.8,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.id != id || old.owned != owned || old.craftable != craftable;
}

/// A hull, still, as it flies.
class _HullThumbPainter extends CustomPainter {
  _HullThumbPainter(this.skin);
  final String? skin;

  @override
  void paint(Canvas canvas, Size size) {
    // Hulls stand about 58 units from crest to flame.
    final s = size.height / 64;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 2 * s);
    canvas.scale(s);
    paintShipHull(canvas, skin, 1.2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HullThumbPainter old) => old.skin != skin;
}

/// A planet effect's picture, or a plain sphere when there is no planet
/// painter to draw it with.
class _EffectThumbPainter extends CustomPainter {
  _EffectThumbPainter({required this.image, required this.fallbackColor});
  final ui.Image? image;
  final Color fallbackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    paintPlainPlanet(
      canvas,
      size.center(Offset.zero),
      size.shortestSide * 0.2,
      fallbackColor,
    );
  }

  @override
  bool shouldRepaint(_EffectThumbPainter old) =>
      old.image != image || old.fallbackColor != fallbackColor;
}

/// The picture on a ship-part tile: what it puts in the sky, in miniature.
class _RecipeGlyph extends StatelessWidget {
  const _RecipeGlyph({required this.id, required this.accent});
  final String id;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final IconData? icon = switch (id) {
      'equip_matter_injector' => AppIcons.rocket_launch_rounded,
      'refuel_station' => AppIcons.local_gas_station_rounded,
      'missile_station' => AppIcons.gps_fixed,
      'sentinel_station' => AppIcons.shield,
      _ => null,
    };
    if (icon != null) {
      return Center(
        child: Icon(icon, size: 26, color: accent.withValues(alpha: 0.85)),
      );
    }
    return CustomPaint(painter: _GlyphPainter(id));
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u = size.shortestSide / 40;
    switch (id) {
      case 'equip_orbitals':
        paintOrbitalSentinel(
          canvas,
          c,
          shipLight(null),
          time: 1.3,
          seed: 0.4,
          radius: 9 * u,
        );
      case 'equip_missiles':
        for (final dx in const [-6.0, 6.0]) {
          paintMissileGlyph(canvas, c + Offset(dx * u, dx.sign * 3 * u), u);
        }
      case 'equip_machinegun':
        for (var i = 0; i < 3; i++) {
          paintBoltGlyph(
            canvas,
            c + Offset(0, (i - 1) * 11 * u),
            u * 0.8,
            const Color(0xFF00E5FF),
          );
        }
      default:
        paintBoltGlyph(canvas, c, u * 1.25, _ammoColor(id));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.id != id;
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.label,
    required this.level,
    required this.max,
    required this.value,
    required this.accent,
    required this.maxed,
    required this.cost,
    required this.buttonLabel,
    required this.enabled,
    required this.onUpgrade,
  });

  final String label;
  final int level, max;
  final String value;
  final Color accent;
  final bool maxed;
  final Widget cost;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _palette.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: panelLabel(11.5, _palette.ink)),
              const SizedBox(width: 10),
              for (var i = 0; i < max; i++)
                Container(
                  width: 10,
                  height: 4,
                  margin: const EdgeInsets.only(right: 3),
                  color: i < level
                      ? accent.withValues(alpha: 0.85)
                      : _palette.lineSoft,
                ),
              const Spacer(),
              Text(
                value,
                style: panelLabel(
                  11,
                  maxed ? CosmicScreenStyles.success : accent,
                  spacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (maxed)
            Text('MAX', style: panelLabel(10.5, CosmicScreenStyles.success))
          else
            Row(
              children: [
                Expanded(child: cost),
                const SizedBox(width: 10),
                SizedBox(
                  width: 118,
                  child: BracketButton(
                    label: buttonLabel,
                    height: 30,
                    palette: _palette,
                    accent: accent,
                    enabled: enabled,
                    onTap: onUpgrade,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
