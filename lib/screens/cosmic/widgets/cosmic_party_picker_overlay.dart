import 'package:alchemons/audio/audio.dart';
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

/// Crew loadout console.
///
/// Cosmic space is landscape and short, so this is laid out as a console
/// rather than a stack of full-width blocks: the slot rack lives in a fixed
/// left rail and the roster fills the rest. The rack and the roster are both
/// on screen at once — the old build swapped between "slots" and "assign"
/// screens, which meant you could never see what you were replacing, and the
/// mode switch needed a second back control of its own.
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
    this.subtitle = 'SHIP CREW LOADOUT',
    this.maxSlots = 3,
    this.hintText = 'Pick a slot, then tap an Alchemon to assign it.',
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

  /// Kicker under the title. The garrison reuses this panel, so it cannot be
  /// the hardcoded "SHIP CREW LOADOUT" it once was.
  final String subtitle;
  final int maxSlots;
  final String hintText;
  final Set<String> excludeInstanceIds;

  @override
  State<CosmicPartyPickerOverlay> createState() =>
      CosmicPartyPickerOverlayState();
}

class CosmicPartyPickerOverlayState extends State<CosmicPartyPickerOverlay> {
  /// Below this the viewport is a landscape phone with the system bars eating
  /// into it. Every fixed-height piece of chrome steps down; the roster grid
  /// keeps whatever is left. Matches the ship console's own threshold.
  static const double _shortHeight = 460;

  /// Below this there is no room for a rail beside the roster, so the rack
  /// folds into a horizontal strip above it.
  static const double _railBreakpoint = 560;

  /// The slot the roster assigns into. -1 means "not chosen yet" and falls
  /// back to the first empty unlocked slot.
  int _targetSlot = -1;

  List<CreatureInstance> _allInstances = [];
  List<CreatureInstance> _filteredInstances = [];
  bool _loading = true;
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

  @override
  void didUpdateWidget(covariant CosmicPartyPickerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The party list is rebuilt by the parent after every assign/clear, and
    // the exclusion set is derived from it.
    if (!identical(oldWidget.partyMembers, widget.partyMembers) ||
        oldWidget.slotsUnlocked != widget.slotsUnlocked) {
      _applyFilters();
    }
  }

  Future<void> _loadInstances() async {
    final db = context.read<AlchemonsDatabase>();
    final instances = await db.creatureDao.getAllInstances();
    if (!mounted) return;
    setState(() {
      _allInstances = instances;
      _loading = false;
      _applyFilters();
    });
  }

  // ── Slot bookkeeping ───────────────────────────────────

  int get _unlockedCount => widget.slotsUnlocked.clamp(0, widget.maxSlots);

  CosmicPartyMember? _memberAt(int i) =>
      i >= 0 && i < widget.partyMembers.length ? widget.partyMembers[i] : null;

  int get _filledCount {
    var n = 0;
    for (var i = 0; i < _unlockedCount; i++) {
      if (_memberAt(i) != null) n++;
    }
    return n;
  }

  /// Where a roster tap lands. Explicit choice wins; otherwise the first empty
  /// unlocked slot, otherwise the first unlocked slot.
  int get _effectiveTarget {
    if (_targetSlot >= 0 && _targetSlot < _unlockedCount) return _targetSlot;
    for (var i = 0; i < _unlockedCount; i++) {
      if (_memberAt(i) == null) return i;
    }
    return _unlockedCount > 0 ? 0 : -1;
  }

  void _selectSlot(int i) {
    setState(() {
      _targetSlot = i;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final catalog = context.read<CreatureCatalog>();
    var list = List<CreatureInstance>.from(_allInstances);

    final q = _searchController.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((ci) {
        final species = catalog.getCreatureById(ci.baseId);
        final name = (ci.nickname ?? species?.name ?? ci.baseId).toLowerCase();
        return name.contains(q) || ci.baseId.toLowerCase().contains(q);
      }).toList();
    }

    if (_filterPrismatic) {
      list = list.where((ci) => ci.isPrismaticSkin).toList();
    }
    if (_filterFavorites) {
      list = list.where((ci) => ci.isFavorite).toList();
    }

    // Anything already in another slot is not assignable. The target slot's
    // own occupant stays listed so the tile reads as "currently equipped"
    // rather than vanishing.
    final target = _effectiveTarget;
    final assignedIds = <String>{};
    for (var i = 0; i < widget.partyMembers.length; i++) {
      if (i != target && widget.partyMembers[i] != null) {
        assignedIds.add(widget.partyMembers[i]!.instanceId);
      }
    }
    list = list.where((ci) => !assignedIds.contains(ci.instanceId)).toList();

    if (widget.excludeInstanceIds.isNotEmpty) {
      list = list
          .where((ci) => !widget.excludeInstanceIds.contains(ci.instanceId))
          .toList();
    }

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

  Future<void> _assign(CreatureInstance ci) async {
    final slot = _effectiveTarget;
    if (slot < 0) return;
    await widget.onAssign(slot, ci.instanceId);
    if (!mounted) return;
    // Walk on to the next empty slot so filling a rack is one tap per slot.
    var next = -1;
    for (var i = 0; i < _unlockedCount; i++) {
      if (i != slot && _memberAt(i) == null) {
        next = i;
        break;
      }
    }
    setState(() {
      _targetSlot = next >= 0 ? next : slot;
      _applyFilters();
    });
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < _shortHeight;

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: widget.onClose,
        alpha: 0.94,
        safeArea: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: SafeArea(
            child: Column(
              children: [
                _header(short),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rail = constraints.maxWidth >= _railBreakpoint;
                      if (!rail) return _stackedBody(short);
                      final railWidth = (constraints.maxWidth * 0.34).clamp(
                        180.0,
                        260.0,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: railWidth,
                            child: _rackRail(short),
                          ),
                          Container(
                            width: 1,
                            color: CosmicScreenStyles.borderDim,
                          ),
                          Expanded(child: _rosterPane(short)),
                        ],
                      );
                    },
                  ),
                ),
                _footer(short),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────

  Widget _header(bool short) {
    return Container(
      margin: EdgeInsets.fromLTRB(10, short ? 5 : 8, 10, short ? 4 : 6),
      padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
      height: short ? 34 : 40,
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: CosmicScreenStyles.amber),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textPrimary,
                fontSize: short ? 11 : 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
          ),
          if (!short) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 12, color: CosmicScreenStyles.borderMid),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.amber.withValues(alpha: 0.72),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
          const Spacer(),
          _countPill(),
          SizedBox(
            width: short ? 32 : 38,
            height: short ? 30 : 36,
            child: CosmicCloseButton(onTap: widget.onClose),
          ),
        ],
      ),
    );
  }

  Widget _countPill() {
    final full = _filledCount >= _unlockedCount && _unlockedCount > 0;
    final tint = full ? CosmicScreenStyles.success : CosmicScreenStyles.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: tint.withValues(alpha: 0.38), width: 0.8),
      ),
      child: Text(
        '$_filledCount/$_unlockedCount',
        style: TextStyle(
          fontFamily: appFontFamily(context),
          color: tint,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ── Body layouts ───────────────────────────────────────

  /// Narrow / portrait: the rack is a horizontal strip of the same tiles.
  Widget _stackedBody(bool short) {
    final rowHeight = short ? 46.0 : 54.0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: _paneLabel('SLOTS', CosmicScreenStyles.amber),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: widget.maxSlots,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) =>
                SizedBox(width: 156, child: _slotRow(i, short)),
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: CosmicScreenStyles.borderDim),
        Expanded(child: _rosterPane(short)),
      ],
    );
  }

  Widget _rackRail(bool short) {
    // A three-slot rack in a full-height rail left most of the rail empty, so
    // the rows grow to use it — up to a point — and the whole stack centres
    // when it fits. A nine-slot garrison overflows that and simply scrolls.
    final gap = short ? 4.0 : 6.0;
    return Container(
      color: CosmicScreenStyles.bg1.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: _paneLabel('SLOTS', CosmicScreenStyles.amber),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final n = widget.maxSlots;
                final avail = constraints.maxHeight - (short ? 6 : 10);
                final natural = _slotRowHeight(short);
                final ceiling = short
                    ? 56.0
                    : n <= 4
                    ? 84.0
                    : 68.0;
                final grown = n <= 0
                    ? natural
                    : ((avail - gap * (n - 1)) / n).clamp(natural, ceiling);
                final total = grown * n + gap * (n - 1);
                final rows = <Widget>[];
                for (var i = 0; i < n; i++) {
                  if (i > 0) rows.add(SizedBox(height: gap));
                  rows.add(_slotRow(i, short, height: grown));
                }
                final stack = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                );
                if (total <= avail) {
                  // Top-aligned, under its label — centring floated the rack
                  // away from the "SLOTS" heading.
                  return Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, short ? 6 : 10),
                    child: Align(alignment: Alignment.topCenter, child: stack),
                  );
                }
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(10, 0, 10, short ? 6 : 10),
                  child: stack,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _slotRowHeight(bool short) => short ? 46 : 54;

  Widget _paneLabel(String label, Color accent, {Widget? trailing}) {
    return Row(
      children: [
        CosmicTag(label: label, color: accent, small: true),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Slot tile ──────────────────────────────────────────

  /// One rack slot. Locked / empty / filled share a frame and a footprint so
  /// the rack reads as one row of sockets; only the ink changes.
  Widget _slotRow(int slotIndex, bool short, {double? height}) {
    final locked = slotIndex >= _unlockedCount;
    final member = locked ? null : _memberAt(slotIndex);
    final isActive = widget.activeSlot == slotIndex && member != null;
    final selected = !locked && _effectiveTarget == slotIndex;
    final rowHeight = height ?? _slotRowHeight(short);
    final spriteSize = (rowHeight - (short ? 16 : 18)).clamp(28.0, 44.0);

    final Color stateColor = locked
        ? CosmicScreenStyles.textMuted
        : member == null
        ? CosmicScreenStyles.teal
        : elementInk(member.element);
    final Color frame = selected
        ? CosmicScreenStyles.amberBright
        : stateColor.withValues(alpha: locked ? 0.22 : 0.34);

    Widget leading;
    if (locked) {
      leading = Icon(
        AppIcons.lock_outline,
        size: spriteSize * 0.55,
        color: CosmicScreenStyles.textMuted.withValues(alpha: 0.7),
      );
    } else if (member == null) {
      leading = Icon(
        AppIcons.add_circle_outline,
        size: spriteSize * 0.62,
        color: CosmicScreenStyles.teal.withValues(alpha: 0.6),
      );
    } else {
      leading = _memberSprite(member, spriteSize);
    }

    final String primary = locked
        ? 'LOCKED'
        : member?.displayName ?? 'EMPTY SLOT';
    final String secondary = locked
        ? 'SLOT ${slotIndex + 1}'
        : member == null
        ? 'TAP TO FILL'
        : '${member.element.toUpperCase()} · LV ${member.level}';

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : context.soundAction(() => _selectSlot(slotIndex)),
        child: Container(
          height: rowHeight,
          decoration: BoxDecoration(
            color: selected
                ? CosmicScreenStyles.bg3
                : CosmicScreenStyles.bg2.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: frame, width: selected ? 1.4 : 0.9),
          ),
          child: Row(
            children: [
              // Slot index rail — doubles as the selection marker.
              Container(
                width: short ? 14 : 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? CosmicScreenStyles.amber.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.22),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(2),
                  ),
                ),
                child: Text(
                  '${slotIndex + 1}',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: selected
                        ? CosmicScreenStyles.amberBright
                        : CosmicScreenStyles.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: short ? 4 : 6),
              SizedBox(
                width: spriteSize,
                height: spriteSize,
                child: Center(child: leading),
              ),
              SizedBox(width: short ? 5 : 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: appFontFamily(context),
                        color: member != null
                            ? CosmicScreenStyles.textPrimary
                            : stateColor.withValues(alpha: 0.85),
                        fontSize: short ? 10.5 : 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: member != null ? 0.2 : 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: appFontFamily(context),
                        color: member != null
                            ? stateColor.withValues(alpha: 0.9)
                            : CosmicScreenStyles.textMuted,
                        fontSize: short ? 8 : 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: CosmicScreenStyles.success,
                    shape: BoxShape.circle,
                  ),
                ),
              if (member != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(
                    () => _showSlotOptions(slotIndex, member),
                  ),
                  child: SizedBox(
                    width: short ? 22 : 26,
                    height: rowHeight,
                    child: Icon(
                      AppIcons.more_vert,
                      size: short ? 14 : 16,
                      color: CosmicScreenStyles.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberSprite(CosmicPartyMember member, double size) {
    if (member.spriteSheet != null) {
      return SizedBox(
        width: size,
        height: size,
        child: CreatureSprite(
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
          effectSlotSize: size,
        ),
      );
    }
    if (member.imagePath != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          member.imagePath!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            AppIcons.catching_pokemon,
            color: elementInk(member.element),
            size: size * 0.6,
          ),
        ),
      );
    }
    return Icon(
      AppIcons.catching_pokemon,
      color: elementInk(member.element),
      size: size * 0.6,
    );
  }

  // ── Roster pane ────────────────────────────────────────

  Widget _rosterPane(bool short) {
    final target = _effectiveTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(10, short ? 4 : 6, 10, 4),
          child: _paneLabel(
            target >= 0 ? 'ROSTER → SLOT ${target + 1}' : 'ROSTER',
            CosmicScreenStyles.teal,
            trailing: Text(
              '${_filteredInstances.length}',
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _searchBar(short),
        ),
        SizedBox(height: short ? 4 : 6),
        SizedBox(height: short ? 22 : 26, child: _filterRow(short)),
        SizedBox(height: short ? 4 : 6),
        Expanded(child: _rosterGrid(short)),
      ],
    );
  }

  Widget _searchBar(bool short) {
    return Container(
      height: short ? 28 : 32,
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
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilters),
              cursorColor: CosmicScreenStyles.teal,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textPrimary,
                fontSize: 12.5,
              ),
              decoration: InputDecoration(
                hintText: 'Search roster',
                hintStyle: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textMuted,
                  fontSize: 12.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: context.soundAction(() {
                _searchController.clear();
                setState(_applyFilters);
              }),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7),
                child: Icon(
                  AppIcons.clear,
                  color: CosmicScreenStyles.textMuted,
                  size: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Sort chips scroll; the two filter toggles stay pinned. Five chips plus
  /// two toggles in a plain Row overflowed on anything narrower than a tablet.
  Widget _filterRow(bool short) {
    return Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _sortChip('LV', SortBy.levelHigh),
              _sortChip('SPD', SortBy.statSpeed),
              _sortChip('STR', SortBy.statStrength),
              _sortChip('INT', SortBy.statIntelligence),
              _sortChip('BEA', SortBy.statBeauty),
            ],
          ),
        ),
        _filterToggle(
          AppIcons.star_rounded,
          _filterFavorites,
          CosmicScreenStyles.amberBright,
          () => setState(() {
            _filterFavorites = !_filterFavorites;
            _applyFilters();
          }),
        ),
        const SizedBox(width: 5),
        _filterToggle(
          AppIcons.auto_awesome,
          _filterPrismatic,
          CosmicScreenStyles.astralShardColor,
          () => setState(() {
            _filterPrismatic = !_filterPrismatic;
            _applyFilters();
          }),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _rosterGrid(bool short) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: CosmicScreenStyles.teal,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_filteredInstances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No Alchemons match this filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: CosmicScreenStyles.textMuted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // A fixed cross-axis count sized tiles off the viewport width: four
    // columns across a landscape phone produced 210x280 cards holding a 42px
    // sprite, and only one row fitted on screen. Extent-based tiles stay the
    // same size everywhere and just reflow.
    final tileHeight = short ? 74.0 : 84.0;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(10, 0, 10, short ? 6 : 10),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: short ? 74 : 84,
        mainAxisExtent: tileHeight,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: _filteredInstances.length,
      itemBuilder: (_, idx) => _instanceTile(_filteredInstances[idx], short),
    );
  }

  Widget _instanceTile(CreatureInstance ci, bool short) {
    final catalog = context.read<CreatureCatalog>();
    final species = catalog.getCreatureById(ci.baseId);
    final primaryType = species?.types.firstOrNull ?? 'fire';
    final ink = elementInk(primaryType);
    final name = ci.nickname ?? species?.name ?? ci.baseId;
    final hasSprite = species?.spriteData != null;
    SpriteSheetDef? sheet;
    SpriteVisuals? visuals;
    if (hasSprite) {
      sheet = sheetFromCreature(species!);
      visuals = visualsFromInstance(species, ci);
    }
    final equipped = _memberAt(_effectiveTarget)?.instanceId == ci.instanceId;
    final spriteSize = short ? 32.0 : 38.0;

    return FastLongPressDetector(
      onTap: () => _assign(ci),
      onLongPress: () {
        if (species == null) return;
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
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 3),
        decoration: BoxDecoration(
          color: equipped
              ? CosmicScreenStyles.bg3
              : CosmicScreenStyles.bg2.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: equipped
                ? CosmicScreenStyles.amberBright.withValues(alpha: 0.8)
                : ink.withValues(alpha: 0.3),
            width: equipped ? 1.3 : 0.9,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: spriteSize,
                  height: spriteSize,
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
                          effectSlotSize: spriteSize,
                        )
                      : Icon(
                          AppIcons.catching_pokemon,
                          color: ink,
                          size: spriteSize * 0.55,
                        ),
                ),
                const SizedBox(height: 2),
                // Ellipsised, not chopped at seven characters — "Salaman…"
                // was being produced by hand even when the tile had room.
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: ink,
                    fontSize: short ? 9 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                // Level is always readable, and the active sort's stat rides
                // beside it instead of replacing it.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _sortBy.isStatSort
                        ? 'LV${ci.level} · ${_statLabelForSort(_sortBy, ci)}'
                        : 'LV ${ci.level}',
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: _sortBy.isStatSort
                          ? CosmicScreenStyles.teal
                          : CosmicScreenStyles.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (ci.isFavorite)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  AppIcons.star_rounded,
                  size: 9,
                  color: CosmicScreenStyles.amberBright.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────

  Widget _footer(bool short) {
    final pad = short ? 6.0 : 9.0;
    return Container(
      padding: EdgeInsets.fromLTRB(10, pad, 10, pad),
      decoration: const BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: CosmicScreenStyles.borderMid, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.hintText,
              maxLines: short ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textMuted,
                fontSize: short ? 9.5 : 10.5,
                height: 1.25,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: context.soundAction(widget.onBack ?? widget.onClose),
            child: Container(
              width: 116,
              height: short ? 28 : 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: CosmicScreenStyles.borderMid),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    AppIcons.arrow_back,
                    size: 13,
                    color: CosmicScreenStyles.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'BACK',
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: CosmicScreenStyles.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final ink = elementInk(element);
    Widget statRow(String label, double value, Color barColor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: CosmicScreenStyles.bg3,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: CosmicScreenStyles.borderDim,
                        width: 0.8,
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: AlchemonStatSystem.displayFraction(value),
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 28,
              child: Text(
                AlchemonStatSystem.displayRating(value).toString(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: appFontFamily(context),
                  color: CosmicScreenStyles.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) {
        // Landscape space is short — the card must never outgrow it.
        final maxH = MediaQuery.sizeOf(dialogContext).height - 40;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 260, maxHeight: maxH),
              child: CosmicPlate(
                accent: ink,
                background: CosmicScreenStyles.bg1,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (spriteSheet != null)
                        SizedBox(
                          width: 56,
                          height: 56,
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
                            effectSlotSize: 56,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${element.toUpperCase()} · LV $level',
                        style: TextStyle(
                          fontFamily: appFontFamily(context),
                          color: ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const CosmicEtchedDivider(),
                      const SizedBox(height: 8),
                      statRow('SPD', speed, const Color(0xFF0EA5E9)),
                      statRow('STR', strength, CosmicScreenStyles.danger),
                      statRow('INT', intelligence, const Color(0xFFA855F7)),
                      statRow('BEA', beauty, CosmicScreenStyles.amberBright),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSlotOptions(int slotIndex, CosmicPartyMember member) {
    final ink = elementInk(member.element);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: CosmicPlate(
            accent: ink,
            background: CosmicScreenStyles.bg1,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: CosmicScreenStyles.bg2,
                        border: Border.all(color: ink.withValues(alpha: 0.42)),
                      ),
                      child: _memberSprite(member, 40),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SLOT ${slotIndex + 1} · '
                            '${member.element.toUpperCase()} · '
                            'LV ${member.level}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontFamily: appFontFamily(context),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const CosmicEtchedDivider(),
                const SizedBox(height: 4),
                _slotActionRow(
                  icon: AppIcons.info_outline,
                  label: 'View details',
                  color: CosmicScreenStyles.textSecondary,
                  onTap: () {
                    Navigator.pop(sheetContext);
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
                  label: 'Replace from roster',
                  color: CosmicScreenStyles.teal,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _selectSlot(slotIndex);
                  },
                ),
                _slotActionRow(
                  icon: AppIcons.remove_circle_outline,
                  label: 'Remove from slot',
                  color: CosmicScreenStyles.danger,
                  onTap: () {
                    Navigator.pop(sheetContext);
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
      onTap: context.soundAction(onTap),
      splashColor: color.withValues(alpha: 0.08),
      highlightColor: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: appFontFamily(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
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
        return 'pSPD ${ci.statSpeedPotential.round()}';
      case SortBy.potentialStrength:
        return 'pSTR ${ci.statStrengthPotential.round()}';
      case SortBy.potentialIntelligence:
        return 'pINT ${ci.statIntelligencePotential.round()}';
      case SortBy.potentialBeauty:
        return 'pBEA ${ci.statBeautyPotential.round()}';
      default:
        return '';
    }
  }

  Widget _sortChip(String label, SortBy sort) {
    final active = _sortBy == sort;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: context.soundAction(
          () => setState(() {
            _sortBy = sort;
            _applyFilters();
          }),
        ),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: active
                ? CosmicScreenStyles.teal.withValues(alpha: 0.14)
                : CosmicScreenStyles.bg2,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: active
                  ? CosmicScreenStyles.teal.withValues(alpha: 0.55)
                  : CosmicScreenStyles.borderDim,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: active
                  ? CosmicScreenStyles.teal
                  : CosmicScreenStyles.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
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
      onTap: context.soundAction(onTap),
      child: Container(
        width: 28,
        height: double.infinity,
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.14)
              : CosmicScreenStyles.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.55)
                : CosmicScreenStyles.borderDim,
          ),
        ),
        child: Icon(
          icon,
          size: 13,
          color: active ? color : CosmicScreenStyles.textMuted,
        ),
      ),
    );
  }
}
