import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'cosmic_overlay_chrome.dart';
import 'cosmic_screen_styles.dart';
import 'package:alchemons/widgets/app_icons.dart';

class CosmicPartyPickerOverlay extends StatefulWidget {
  const CosmicPartyPickerOverlay({
    super.key,
    required this.slotsUnlocked,
    required this.partyMembers,
    this.activeSlot,
    required this.onAssign,
    required this.onClear,
    this.onSummon,
    this.onReturn,
    required this.onClose,
    this.onBack,
    this.title = 'ALCHEMONS PARTY',
    this.maxSlots = 3,
    this.hintText =
        'Tap a slot to assign an Alchemon.\nSummon one to fight alongside your ship!',
    this.excludeInstanceIds = const {},
  });

  final int slotsUnlocked;
  final List<CosmicPartyMember?> partyMembers;
  final int? activeSlot;
  final Future<void> Function(int slotIndex, String instanceId) onAssign;
  final Future<void> Function(int slotIndex) onClear;
  final void Function(int slotIndex)? onSummon;
  final void Function()? onReturn;

  /// Dismiss the whole panel stack back to the world.
  final VoidCallback onClose;

  /// Step up one level to whatever opened this. Falls back to [onClose].
  final VoidCallback? onBack;
  final String title;
  final int maxSlots;
  final String hintText;
  final Set<String> excludeInstanceIds;

  @override
  State<CosmicPartyPickerOverlay> createState() =>
      CosmicPartyPickerOverlayState();
}

class CosmicPartyPickerOverlayState extends State<CosmicPartyPickerOverlay> {
  static const double _slotCardHeight = 118.0;
  static const double _slotSpriteSize = 46.0;

  // Which slot is being assigned (-1 = not assigning)
  int _assigningSlot = -1;

  // Instance list for assigning
  List<CreatureInstance> _allInstances = [];
  List<CreatureInstance> _filteredInstances = [];
  final TextEditingController _searchController = TextEditingController();
  SortBy _sortBy = SortBy.levelHigh;
  bool _filterPrismatic = false;
  bool _filterFavorites = false;

  @override
  void initState() {
    super.initState();
    _loadInstances();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstances() async {
    final db = context.read<AlchemonsDatabase>();
    final instances = await db.creatureDao.getAllInstances();
    if (!mounted) return;
    setState(() {
      _allInstances = instances;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final catalog = context.read<CreatureCatalog>();
    var list = List<CreatureInstance>.from(_allInstances);

    // Search
    final q = _searchController.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((ci) {
        final species = catalog.getCreatureById(ci.baseId);
        final name = (ci.nickname ?? species?.name ?? ci.baseId).toLowerCase();
        return name.contains(q) || ci.baseId.toLowerCase().contains(q);
      }).toList();
    }

    // Prismatic filter
    if (_filterPrismatic) {
      list = list.where((ci) => ci.isPrismaticSkin).toList();
    }

    // Favorites filter
    if (_filterFavorites) {
      list = list.where((ci) => ci.isFavorite).toList();
    }

    // Exclude already-assigned instances (except for the slot being assigned)
    final assignedIds = <String>{};
    for (var i = 0; i < widget.partyMembers.length; i++) {
      if (i != _assigningSlot && widget.partyMembers[i] != null) {
        assignedIds.add(widget.partyMembers[i]!.instanceId);
      }
    }
    list = list.where((ci) => !assignedIds.contains(ci.instanceId)).toList();

    // Exclude instances from the other list (e.g. ship party vs garrison)
    if (widget.excludeInstanceIds.isNotEmpty) {
      list = list
          .where((ci) => !widget.excludeInstanceIds.contains(ci.instanceId))
          .toList();
    }

    // Sort
    list.sort((a, b) {
      switch (_sortBy) {
        case SortBy.levelHigh:
          return b.level.compareTo(a.level);
        case SortBy.levelLow:
          return a.level.compareTo(b.level);
        case SortBy.newest:
          return b.createdAtUtcMs.compareTo(a.createdAtUtcMs);
        case SortBy.oldest:
          return a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
        case SortBy.statSpeed:
          return b.statSpeed.compareTo(a.statSpeed);
        case SortBy.statIntelligence:
          return b.statIntelligence.compareTo(a.statIntelligence);
        case SortBy.statStrength:
          return b.statStrength.compareTo(a.statStrength);
        case SortBy.statBeauty:
          return b.statBeauty.compareTo(a.statBeauty);
        case SortBy.potentialSpeed:
          return b.statSpeedPotential.compareTo(a.statSpeedPotential);
        case SortBy.potentialIntelligence:
          return b.statIntelligencePotential.compareTo(
            a.statIntelligencePotential,
          );
        case SortBy.potentialStrength:
          return b.statStrengthPotential.compareTo(a.statStrengthPotential);
        case SortBy.potentialBeauty:
          return b.statBeautyPotential.compareTo(a.statBeautyPotential);
      }
    });

    _filteredInstances = list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CosmicOverlayBackdrop(
      onTap: widget.onClose,
      alpha: 0.84,
      child: GestureDetector(
        onTap: () {}, // absorb inner taps
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.2, -0.35),
              radius: 1.2,
              colors: [
                CosmicScreenStyles.bg3.withValues(alpha: 0.34),
                CosmicScreenStyles.bg0.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.54, 1.0],
            ),
          ),
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: CosmicPlate(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  accent: CosmicScreenStyles.amber,
                  background: CosmicScreenStyles.bg1.withValues(alpha: 0.92),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontFamily: appFontFamily(context),
                                color: CosmicScreenStyles.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'SHIP CREW LOADOUT',
                              style: TextStyle(
                                fontFamily: appFontFamily(context),
                                color: CosmicScreenStyles.amber.withValues(
                                  alpha: 0.78,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // X closes out entirely; the docked BACK steps up.
                      CosmicCloseButton(onTap: widget.onClose),
                    ],
                  ),
                ),
              ),

              // ── Party Slots ──
              if (_assigningSlot < 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const crossAxisCount = 3;
                      const gap = 10.0;
                      final cardWidth =
                          (constraints.maxWidth - gap * (crossAxisCount - 1)) /
                          crossAxisCount;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: List.generate(widget.maxSlots, (i) {
                          final locked = i >= widget.slotsUnlocked;
                          final member = i < widget.partyMembers.length
                              ? widget.partyMembers[i]
                              : null;
                          final isActive = widget.activeSlot == i;

                          return SizedBox(
                            width: cardWidth,
                            child: _buildPartySlotCard(
                              i,
                              locked,
                              member,
                              isActive,
                              theme,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),

              // ── Instance picker (when assigning) ──
              if (_assigningSlot >= 0) ...[
                // Back button + slot info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          AppIcons.arrow_back,
                          color: CosmicScreenStyles.textSecondary,
                        ),
                        onPressed: () => setState(() => _assigningSlot = -1),
                      ),
                      Text(
                        'ASSIGN TO SLOT ${_assigningSlot + 1}',
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: CosmicScreenStyles.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: CosmicScreenStyles.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: CosmicScreenStyles.borderDim),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Icon(
                          AppIcons.search,
                          color: CosmicScreenStyles.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() => _applyFilters()),
                            style: TextStyle(
                              color: CosmicScreenStyles.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search…',
                              hintStyle: TextStyle(
                                color: CosmicScreenStyles.textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _applyFilters());
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                AppIcons.clear,
                                color: CosmicScreenStyles.textMuted,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Sort + filter row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _sortChip('Level', SortBy.levelHigh),
                      const SizedBox(width: 6),
                      _sortChip('SPD', SortBy.statSpeed),
                      const SizedBox(width: 6),
                      _sortChip('STR', SortBy.statStrength),
                      const SizedBox(width: 6),
                      _sortChip('INT', SortBy.statIntelligence),
                      const SizedBox(width: 6),
                      _sortChip('BEA', SortBy.statBeauty),
                      const Spacer(),
                      _filterToggle(
                        AppIcons.star_rounded,
                        _filterFavorites,
                        const Color(0xFFFFD700),
                        () => setState(() {
                          _filterFavorites = !_filterFavorites;
                          _applyFilters();
                        }),
                      ),
                      const SizedBox(width: 6),
                      _filterToggle(
                        AppIcons.auto_awesome,
                        _filterPrismatic,
                        const Color(0xFFE040FB),
                        () => setState(() {
                          _filterPrismatic = !_filterPrismatic;
                          _applyFilters();
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Instance grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: _filteredInstances.length,
                    itemBuilder: (_, idx) {
                      final ci = _filteredInstances[idx];
                      return _buildInstanceCard(ci, theme);
                    },
                  ),
                ),
              ] else
                // Hint text when not assigning
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 22, 32, 12),
                  child: Text(
                    widget.hintText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: CosmicScreenStyles.textSecondary.withValues(
                        alpha: 0.72,
                      ),
                      fontSize: 13,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // ── Docked BACK ──
              // Full-screen overlay: the header X alone is easy to miss, so
              // the way out is also pinned where every other cosmic panel
              // puts it.
              _backDock(),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom-docked exit. When assigning a slot it steps back to the slot grid
  /// first, so BACK always means "up one level", never "abandon the panel".
  Widget _backDock() {
    final assigning = _assigningSlot >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: CosmicScreenStyles.borderMid, width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: assigning
              ? () => setState(() => _assigningSlot = -1)
              : (widget.onBack ?? widget.onClose),
          child: Container(
            width: double.infinity,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: CosmicScreenStyles.borderMid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  AppIcons.arrow_back,
                  size: 15,
                  color: CosmicScreenStyles.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  assigning ? 'BACK TO SLOTS' : 'BACK',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: CosmicScreenStyles.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartySlotCard(
    int slotIndex,
    bool locked,
    CosmicPartyMember? member,
    bool isActive,
    ThemeData theme,
  ) {
    if (locked) {
      return Container(
        height: _slotCardHeight,
        decoration: BoxDecoration(
          color: CosmicScreenStyles.bg1.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: CosmicScreenStyles.borderDim.withValues(alpha: 0.82),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.lock_outline,
                color: CosmicScreenStyles.textMuted,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                'LOCKED',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (member == null) {
      return GestureDetector(
        onTap: () => setState(() => _assigningSlot = slotIndex),
        child: Container(
          height: _slotCardHeight,
          decoration: BoxDecoration(
            color: CosmicScreenStyles.bg1.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: CosmicScreenStyles.teal.withValues(alpha: 0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: CosmicScreenStyles.teal.withValues(alpha: 0.05),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.add_circle_outline,
                  color: CosmicScreenStyles.teal.withValues(alpha: 0.5),
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  'SLOT ${slotIndex + 1}',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: CosmicScreenStyles.teal.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filled slot
    final eColor = elementColor(member.element);
    return GestureDetector(
      onTap: () => _showSlotOptions(slotIndex, member),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: _slotCardHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              eColor.withValues(alpha: isActive ? 0.22 : 0.10),
              CosmicScreenStyles.bg1.withValues(alpha: 0.94),
              CosmicScreenStyles.bg0.withValues(alpha: 0.90),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? eColor.withValues(alpha: 0.92)
                : eColor.withValues(alpha: 0.35),
            width: isActive ? 1.6 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: eColor.withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: Text(
                'SLOT ${slotIndex + 1}',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textMuted.withValues(alpha: 0.82),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: eColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: eColor.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 18, 7, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Creature sprite
                  SizedBox(
                    width: _slotSpriteSize,
                    height: _slotSpriteSize,
                    child: member.spriteSheet != null
                        ? CreatureSprite(
                            spritePath: member.spriteSheet!.path,
                            totalFrames: member.spriteSheet!.totalFrames,
                            rows: member.spriteSheet!.rows,
                            frameSize: member.spriteSheet!.frameSize,
                            stepTime: member.spriteSheet!.stepTime,
                            scale: member.spriteVisuals?.scale ?? 1.0,
                            saturation: member.spriteVisuals?.saturation ?? 1.0,
                            brightness: member.spriteVisuals?.brightness ?? 1.0,
                            hueShift: member.spriteVisuals?.hueShiftDeg ?? 0.0,
                            isPrismatic:
                                member.spriteVisuals?.isPrismatic ?? false,
                            tint: member.spriteVisuals?.tint,
                            alchemyEffect: member.spriteVisuals?.alchemyEffect,
                            variantFaction:
                                member.spriteVisuals?.variantFaction,
                            effectSlotSize: _slotSpriteSize,
                          )
                        : member.imagePath != null
                        ? ClipOval(
                            child: Image.asset(
                              member.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                AppIcons.catching_pokemon,
                                color: eColor,
                                size: 22,
                              ),
                            ),
                          )
                        : Icon(
                            AppIcons.catching_pokemon,
                            color: eColor,
                            size: 22,
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    member.displayName,
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: eColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isActive ? 'ACTIVE' : 'Lv${member.level}',
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: isActive
                          ? CosmicScreenStyles.textPrimary
                          : CosmicScreenStyles.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: isActive ? 1.2 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Condensed stats popup ───────────────────────────────
  void _showCondensedStats({
    required String name,
    required String element,
    required int level,
    required double speed,
    required double strength,
    required double intelligence,
    required double beauty,
    SpriteSheetDef? spriteSheet,
    SpriteVisuals? spriteVisuals,
  }) {
    final eColor = elementColor(element);
    Widget statRow(String label, double value, Color barColor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Color(0xFF8A7B6A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final pct = AlchemonStatSystem.displayFraction(value);
                  return Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141820),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 32,
              child: Text(
                AlchemonStatSystem.displayRating(value).toString(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Color(0xFFE8DCC8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3A3020)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Sprite ──
                if (spriteSheet != null)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CreatureSprite(
                      spritePath: spriteSheet.path,
                      totalFrames: spriteSheet.totalFrames,
                      rows: spriteSheet.rows,
                      frameSize: spriteSheet.frameSize,
                      stepTime: spriteSheet.stepTime,
                      scale: spriteVisuals?.scale ?? 1.0,
                      saturation: spriteVisuals?.saturation ?? 1.0,
                      brightness: spriteVisuals?.brightness ?? 1.0,
                      hueShift: spriteVisuals?.hueShiftDeg ?? 0.0,
                      isPrismatic: spriteVisuals?.isPrismatic ?? false,
                      tint: spriteVisuals?.tint,
                      alchemyEffect: spriteVisuals?.alchemyEffect,
                      variantFaction: spriteVisuals?.variantFaction,
                      effectSlotSize: 64,
                    ),
                  ),
                const SizedBox(height: 8),

                // ── Name + Level ──
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: eColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: eColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      element.toUpperCase(),
                      style: TextStyle(
                        fontFamily: appFontFamily(context),
                        color: eColor.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LV $level',
                      style: TextStyle(
                        fontFamily: appFontFamily(context),
                        color: Color(0xFF8A7B6A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                // ── 3px accent bar ──
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Stats ──
                statRow('SPD', speed, const Color(0xFF0EA5E9)),
                statRow('STR', strength, const Color(0xFFC0392B)),
                statRow('INT', intelligence, const Color(0xFFA855F7)),
                statRow('BEA', beauty, const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSlotOptions(int slotIndex, CosmicPartyMember member) {
    final eColor = elementColor(member.element);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: CosmicPlate(
            accent: eColor,
            background: CosmicScreenStyles.bg1,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 3,
                  decoration: BoxDecoration(
                    color: CosmicScreenStyles.borderAccent.withValues(
                      alpha: 0.78,
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: eColor.withValues(alpha: 0.10),
                        border: Border.all(
                          color: eColor.withValues(alpha: 0.42),
                        ),
                      ),
                      child: member.spriteSheet != null
                          ? CreatureSprite(
                              spritePath: member.spriteSheet!.path,
                              totalFrames: member.spriteSheet!.totalFrames,
                              rows: member.spriteSheet!.rows,
                              frameSize: member.spriteSheet!.frameSize,
                              stepTime: member.spriteSheet!.stepTime,
                              scale: member.spriteVisuals?.scale ?? 1.0,
                              saturation:
                                  member.spriteVisuals?.saturation ?? 1.0,
                              brightness:
                                  member.spriteVisuals?.brightness ?? 1.0,
                              hueShift:
                                  member.spriteVisuals?.hueShiftDeg ?? 0.0,
                              isPrismatic:
                                  member.spriteVisuals?.isPrismatic ?? false,
                              tint: member.spriteVisuals?.tint,
                              alchemyEffect:
                                  member.spriteVisuals?.alchemyEffect,
                              variantFaction:
                                  member.spriteVisuals?.variantFaction,
                              effectSlotSize: 46,
                            )
                          : Icon(
                              AppIcons.catching_pokemon,
                              color: eColor,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: CosmicScreenStyles.textPrimary,
                              fontFamily: appFontFamily(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${member.element.toUpperCase()} · LV ${member.level}',
                            style: TextStyle(
                              color: eColor.withValues(alpha: 0.86),
                              fontFamily: appFontFamily(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const CosmicEtchedDivider(),
                const SizedBox(height: 8),
                _slotActionRow(
                  icon: AppIcons.info_outline,
                  label: 'View Details',
                  color: CosmicScreenStyles.textSecondary,
                  onTap: () {
                    Navigator.pop(context);
                    _showCondensedStats(
                      name: member.displayName,
                      element: member.element,
                      level: member.level,
                      speed: member.statSpeed,
                      strength: member.statStrength,
                      intelligence: member.statIntelligence,
                      beauty: member.statBeauty,
                      spriteSheet: member.spriteSheet,
                      spriteVisuals: member.spriteVisuals,
                    );
                  },
                ),
                _slotActionRow(
                  icon: AppIcons.swap_horiz,
                  label: 'Replace',
                  color: CosmicScreenStyles.textSecondary,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _assigningSlot = slotIndex);
                  },
                ),
                _slotActionRow(
                  icon: AppIcons.remove_circle_outline,
                  label: 'Remove',
                  color: const Color(0xFFE53935),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onClear(slotIndex);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slotActionRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: color.withValues(alpha: 0.08),
      highlightColor: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: appFontFamily(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstanceCard(CreatureInstance ci, ThemeData theme) {
    final catalog = context.read<CreatureCatalog>();
    final species = catalog.getCreatureById(ci.baseId);
    final primaryType = species?.types.firstOrNull ?? 'fire';
    final eColor = elementColor(primaryType);
    final name = ci.nickname ?? species?.name ?? ci.baseId;
    // Build sprite data for animated rendering
    final hasSprite = species?.spriteData != null;
    SpriteSheetDef? sheet;
    SpriteVisuals? visuals;
    if (hasSprite) {
      sheet = sheetFromCreature(species!);
      visuals = visualsFromInstance(species, ci);
    }

    return FastLongPressDetector(
      onTap: () async {
        await widget.onAssign(_assigningSlot, ci.instanceId);
        if (mounted) setState(() => _assigningSlot = -1);
      },
      onLongPress: () {
        if (species != null) {
          _showCondensedStats(
            name: name,
            element: primaryType,
            level: ci.level,
            speed: ci.statSpeed,
            strength: ci.statStrength,
            intelligence: ci.statIntelligence,
            beauty: ci.statBeauty,
            spriteSheet: sheet,
            spriteVisuals: visuals,
          );
        }
      },
      child: Opacity(
        opacity: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: eColor.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: hasSprite
                        ? CreatureSprite(
                            spritePath: sheet!.path,
                            totalFrames: sheet.totalFrames,
                            rows: sheet.rows,
                            frameSize: sheet.frameSize,
                            stepTime: sheet.stepTime,
                            scale: visuals?.scale ?? 1.0,
                            saturation: visuals?.saturation ?? 1.0,
                            brightness: visuals?.brightness ?? 1.0,
                            hueShift: visuals?.hueShiftDeg ?? 0.0,
                            isPrismatic: visuals?.isPrismatic ?? false,
                            tint: visuals?.tint,
                            alchemyEffect: visuals?.alchemyEffect,
                            variantFaction: visuals?.variantFaction,
                            effectSlotSize: 42,
                          )
                        : Icon(
                            AppIcons.catching_pokemon,
                            color: eColor,
                            size: 18,
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.length > 7 ? '${name.substring(0, 7)}…' : name,
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: eColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Stat value for active sort
                  if (_sortBy.isStatSort)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        _statLabelForSort(_sortBy, ci),
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: Color(0xFF00E5FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              // Level badge – always visible
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: eColor.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'LV${ci.level}',
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: Colors.white70,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
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

  String _statLabelForSort(SortBy sort, CreatureInstance ci) {
    switch (sort) {
      case SortBy.levelHigh:
      case SortBy.levelLow:
        return 'LV ${ci.level}';
      case SortBy.statSpeed:
        return 'SPD ${AlchemonStatSystem.displayRating(ci.statSpeed)}';
      case SortBy.statStrength:
        return 'STR ${AlchemonStatSystem.displayRating(ci.statStrength)}';
      case SortBy.statIntelligence:
        return 'INT ${AlchemonStatSystem.displayRating(ci.statIntelligence)}';
      case SortBy.statBeauty:
        return 'BEA ${AlchemonStatSystem.displayRating(ci.statBeauty)}';
      case SortBy.potentialSpeed:
        return 'PSPD ${ci.statSpeedPotential.round()}';
      case SortBy.potentialStrength:
        return 'PSTR ${ci.statStrengthPotential.round()}';
      case SortBy.potentialIntelligence:
        return 'PINT ${ci.statIntelligencePotential.round()}';
      case SortBy.potentialBeauty:
        return 'PBEA ${ci.statBeautyPotential.round()}';
      default:
        return '';
    }
  }

  Widget _sortChip(String label, SortBy sort) {
    final active = _sortBy == sort;
    return GestureDetector(
      onTap: () => setState(() {
        _sortBy = sort;
        _applyFilters();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: active ? const Color(0xFF00E5FF) : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _filterToggle(
    IconData icon,
    bool active,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 26,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : Colors.white12,
          ),
        ),
        child: Icon(icon, size: 14, color: active ? color : Colors.white24),
      ),
    );
  }
}
