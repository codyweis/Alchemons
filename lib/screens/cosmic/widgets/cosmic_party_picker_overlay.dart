import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

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
  final VoidCallback onClose;
  final String title;
  final int maxSlots;
  final String hintText;
  final Set<String> excludeInstanceIds;

  @override
  State<CosmicPartyPickerOverlay> createState() =>
      CosmicPartyPickerOverlayState();
}

class CosmicPartyPickerOverlayState extends State<CosmicPartyPickerOverlay> {
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
      // Sort 0-stamina to the bottom
      final aStam = _effectiveStamina(a);
      final bStam = _effectiveStamina(b);
      final aHas = aStam >= 1 ? 1 : 0;
      final bHas = bStam >= 1 ? 1 : 0;
      if (aHas != bHas) return bHas - aHas;

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

  /// Compute effective stamina bars with time-based regen.
  int _effectiveStamina(CreatureInstance ci) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final elapsed = nowMs - ci.staminaLastUtcMs;
    final regenBars = elapsed ~/ (6 * 3600 * 1000);
    return (ci.staminaBars + regenBars).clamp(0, ci.staminaMax);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: GestureDetector(
          onTap: () {}, // absorb inner taps
          child: SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontFamily: appFontFamily(context),
                            color: Color(0xFF00E5FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),

                // ── Party Slots ──
                if (_assigningSlot < 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisCount = 3;
                        const gap = 8.0;
                        final cardWidth =
                            (constraints.maxWidth -
                                gap * (crossAxisCount - 1)) /
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
                            Icons.arrow_back,
                            color: Colors.white54,
                          ),
                          onPressed: () => setState(() => _assigningSlot = -1),
                        ),
                        Text(
                          'ASSIGN TO SLOT ${_assigningSlot + 1}',
                          style: TextStyle(
                            fontFamily: appFontFamily(context),
                            color: Colors.white70,
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
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.search,
                            color: Colors.white38,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() => _applyFilters()),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search…',
                                hintStyle: TextStyle(color: Colors.white24),
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
                                  Icons.clear,
                                  color: Colors.white38,
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
                          Icons.star_rounded,
                          _filterFavorites,
                          const Color(0xFFFFD700),
                          () => setState(() {
                            _filterFavorites = !_filterFavorites;
                            _applyFilters();
                          }),
                        ),
                        const SizedBox(width: 6),
                        _filterToggle(
                          Icons.auto_awesome,
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
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.hintText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
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
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: Colors.white24, size: 24),
              SizedBox(height: 4),
              Text(
                'LOCKED',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Colors.white24,
                  fontSize: 9,
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
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  'SLOT ${slotIndex + 1}',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    fontSize: 9,
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
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isActive
              ? eColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? eColor : eColor.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Creature sprite
            SizedBox(
              width: 52,
              height: 52,
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
                      isPrismatic: member.spriteVisuals?.isPrismatic ?? false,
                      tint: member.spriteVisuals?.tint,
                      alchemyEffect: member.spriteVisuals?.alchemyEffect,
                      variantFaction: member.spriteVisuals?.variantFaction,
                      effectSlotSize: 52,
                    )
                  : member.imagePath != null
                  ? ClipOval(
                      child: Image.asset(
                        member.imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.catching_pokemon,
                          color: eColor,
                          size: 22,
                        ),
                      ),
                    )
                  : Icon(Icons.catching_pokemon, color: eColor, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              member.displayName.length > 8
                  ? '${member.displayName.substring(0, 8)}…'
                  : member.displayName,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: eColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              isActive ? '▶ ACTIVE' : 'Lv${member.level}',
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: isActive ? eColor : Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            // Stamina dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                member.staminaMax,
                (si) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: si < member.staminaBars
                        ? const Color(0xFF00E676)
                        : Colors.white12,
                    border: Border.all(
                      color: si < member.staminaBars
                          ? const Color(0xFF00E676).withValues(alpha: 0.5)
                          : Colors.white10,
                      width: 0.5,
                    ),
                  ),
                ),
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
    final maxStat = [
      speed,
      strength,
      intelligence,
      beauty,
    ].reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final pct = (value / maxStat).clamp(0.0, 1.0);
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
                value.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Color(0xFFE8DCC8),
                  fontSize: 10,
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
                        fontSize: 9,
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
                        fontSize: 9,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                member.displayName,
                style: TextStyle(
                  color: elementColor(member.element),
                  fontFamily: appFontFamily(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white54),
                title: Text(
                  'View Details',
                  style: TextStyle(color: Colors.white70),
                ),
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
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.white54),
                title: Text(
                  'Replace',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _assigningSlot = slotIndex);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Color(0xFFE53935),
                ),
                title: Text(
                  'Remove',
                  style: TextStyle(color: Color(0xFFE53935)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onClear(slotIndex);
                },
              ),
            ],
          ),
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
    final stamina = _effectiveStamina(ci);
    final hasStamina = stamina >= 1;

    // Build sprite data for animated rendering
    final hasSprite = species?.spriteData != null;
    SpriteSheetDef? sheet;
    SpriteVisuals? visuals;
    if (hasSprite) {
      sheet = sheetFromCreature(species!);
      visuals = visualsFromInstance(species, ci);
    }

    return FastLongPressDetector(
      onTap: hasStamina
          ? () async {
              await widget.onAssign(_assigningSlot, ci.instanceId);
              if (mounted) setState(() => _assigningSlot = -1);
            }
          : () => _showStaminaPotionDialog(ci),
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
        opacity: hasStamina ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasStamina
                  ? eColor.withValues(alpha: 0.3)
                  : Colors.white12,
            ),
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
                        : Icon(Icons.catching_pokemon, color: eColor, size: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.length > 7 ? '${name.substring(0, 7)}…' : name,
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: eColor,
                      fontSize: 8,
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
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  // Stamina dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      ci.staminaMax,
                      (si) => Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: si < stamina
                              ? const Color(0xFF00E676)
                              : Colors.white12,
                        ),
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

  /// Show dialog to use a stamina potion on a 0-stamina creature.
  Future<void> _showStaminaPotionDialog(CreatureInstance ci) async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final potionQty = await db.inventoryDao.getItemQty(InvKeys.staminaPotion);
    final species = catalog.getCreatureById(ci.baseId);
    final name = ci.nickname ?? species?.name ?? ci.baseId;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1117),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.battery_0_bar_rounded,
              color: Color(0xFFFF9800),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'NO STAMINA',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Color(0xFFFF9800),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name has no stamina remaining.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (potionQty > 0)
              Row(
                children: [
                  const Icon(
                    Icons.local_drink_rounded,
                    color: Color(0xFF00E676),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Stamina Potion ×$potionQty',
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: Color(0xFF00E676),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else
              Text(
                'No stamina potions available.\nWait for stamina to regenerate.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
          if (potionQty > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'USE POTION',
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: Color(0xFF00E676),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Use potion and restore stamina
      await db.inventoryDao.addItemQty(InvKeys.staminaPotion, -1);
      final staminaService = StaminaService(db);
      await staminaService.restoreToFull(ci.instanceId);
      // Reload instances to reflect updated stamina
      await _loadInstances();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.local_drink_rounded,
                  color: Color(0xFF00E676),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${name.toUpperCase()} STAMINA RESTORED',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _statLabelForSort(SortBy sort, CreatureInstance ci) {
    switch (sort) {
      case SortBy.levelHigh:
      case SortBy.levelLow:
        return 'LV ${ci.level}';
      case SortBy.statSpeed:
        return 'SPD ${ci.statSpeed.toStringAsFixed(1)}';
      case SortBy.statStrength:
        return 'STR ${ci.statStrength.toStringAsFixed(1)}';
      case SortBy.statIntelligence:
        return 'INT ${ci.statIntelligence.toStringAsFixed(1)}';
      case SortBy.statBeauty:
        return 'BEA ${ci.statBeauty.toStringAsFixed(1)}';
      case SortBy.potentialSpeed:
        return 'PSPD ${ci.statSpeedPotential.toStringAsFixed(1)}';
      case SortBy.potentialStrength:
        return 'PSTR ${ci.statStrengthPotential.toStringAsFixed(1)}';
      case SortBy.potentialIntelligence:
        return 'PINT ${ci.statIntelligencePotential.toStringAsFixed(1)}';
      case SortBy.potentialBeauty:
        return 'PBEA ${ci.statBeautyPotential.toStringAsFixed(1)}';
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
            fontSize: 10,
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
