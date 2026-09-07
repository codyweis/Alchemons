import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'cosmic_overlay_chrome.dart';
import 'cosmic_screen_styles.dart';
import 'package:alchemons/widgets/app_icons.dart';

class ChamberPickerOverlay extends StatefulWidget {
  const ChamberPickerOverlay({
    super.key,
    required this.chambers,
    required this.onAssign,
    required this.onClear,
    required this.onClose,
  });

  final List<OrbitalChamber> chambers;
  final Future<void> Function(int slotIndex, String instanceId) onAssign;
  final Future<void> Function(int slotIndex) onClear;
  final VoidCallback onClose;

  @override
  State<ChamberPickerOverlay> createState() => ChamberPickerOverlayState();
}

class ChamberPickerOverlayState extends State<ChamberPickerOverlay> {
  List<CreatureInstance> _ownedCreatures = [];
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCreatures();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreatures() async {
    final db = context.read<AlchemonsDatabase>();
    final creatures = await db.creatureDao.getAllInstances();
    if (mounted) {
      setState(() {
        _ownedCreatures = creatures;
        _loading = false;
      });
    }
  }

  List<CreatureInstance> _applySearch(List<CreatureInstance> instances) {
    final catalog = context.read<CreatureCatalog>();
    var filtered = instances;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((instance) {
        final species = catalog.getCreatureById(instance.baseId);
        if (species == null) return false;
        return species.name.toLowerCase().contains(query) ||
            species.types.any((t) => t.toLowerCase().contains(query)) ||
            (instance.nickname?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    filtered = List<CreatureInstance>.from(filtered)
      ..sort((a, b) => b.level.compareTo(a.level));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CreatureCatalog>();
    final palette = BracketPalette.dark; // cosmic overlay is always dark
    // The cosmic overlay always renders on a dark backdrop — lock the
    // FactionTheme to its dark variant so nested widgets (filter chips,
    // search field, etc.) never resolve light-mode palettes.
    final factionId = context.read<FactionService>().current;
    final theme = factionThemeFor(factionId, brightness: Brightness.dark);
    final assignedIds = widget.chambers
        .where((c) => c.instanceId != null)
        .map((c) => c.instanceId!)
        .toSet();
    final filtered = _applySearch(_ownedCreatures);

    return Provider<FactionTheme>.value(
      value: theme,
      child: Material(
        color: Colors.transparent,
        child: CosmicOverlayBackdrop(
          alpha: 0.96,
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 22,
                      color: CosmicScreenStyles.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alchemy chambers',
                            style: bracketText(
                              context,
                              17,
                              palette.ink,
                              weight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assign Alchemons to orbit your home planet.',
                            style: bracketText(
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
                    const SizedBox(width: 10),
                    _OverlayCloseButton(
                      palette: palette,
                      onTap: widget.onClose,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Chamber slots — compact 3-across row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(widget.chambers.length, (i) {
                    final chamber = widget.chambers[i];
                    final base = chamber.instanceId != null
                        ? catalog.getCreatureById(chamber.baseCreatureId ?? '')
                        : null;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i == widget.chambers.length - 1 ? 0 : 8,
                        ),
                        child: _ChamberSlotTile(
                          slotIndex: i,
                          chamber: chamber,
                          base: base,
                          palette: palette,
                          onClear: () => widget.onClear(i),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // ── Divider ──
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: BracketSectionDivider(label: 'Your alchemons'),
              ),
              const SizedBox(height: 10),

              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomPaint(
                  painter: BracketFramePainter(
                    color: palette.line.withValues(alpha: 0.6),
                    bracketSize: 7,
                    strokeWidth: 1.05,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceMutedFill(),
                      border: Border.all(
                        color: palette.lineSoft.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            AppIcons.search_rounded,
                            color: palette.muted,
                            size: 16,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            cursorColor: CosmicScreenStyles.teal,
                            style: bracketText(
                              context,
                              13,
                              palette.ink,
                              weight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: bracketText(
                                context,
                                13,
                                palette.muted,
                                weight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(
                                AppIcons.close_rounded,
                                color: palette.muted,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Creature grid ──
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: CosmicScreenStyles.teal,
                          strokeWidth: 2,
                        ),
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No Alchemons found.',
                          style: bracketText(
                            context,
                            12.5,
                            palette.muted,
                            weight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.74,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final inst = filtered[index];
                          final alreadyAssigned = assignedIds.contains(
                            inst.instanceId,
                          );
                          final species = catalog.getCreatureById(inst.baseId);
                          final typeName = (species?.types.isNotEmpty ?? false)
                              ? species!.types.first
                              : 'Earth';
                          final elemCol = BreedConstants.getTypeColor(typeName);
                          final displayName =
                              inst.nickname ?? species?.name ?? inst.baseId;
                          final emptySlot = widget.chambers.indexWhere(
                            (c) => c.instanceId == null,
                          );

                          return GestureDetector(
                            onTap: alreadyAssigned || emptySlot < 0
                                ? null
                                : () => widget.onAssign(
                                    emptySlot,
                                    inst.instanceId,
                                  ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: alreadyAssigned ? 0.4 : 1.0,
                              child: CustomPaint(
                                painter: BracketFramePainter(
                                  color: elemCol.withValues(alpha: 0.7),
                                  bracketSize: 8,
                                  strokeWidth: 1.05,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: elemCol.withValues(alpha: 0.07),
                                    border: Border.all(
                                      color: palette.lineSoft.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Color.lerp(
                                                elemCol,
                                                Colors.white,
                                                0.2,
                                              )!,
                                              elemCol,
                                            ],
                                          ),
                                        ),
                                        child: species?.image != null
                                            ? ClipOval(
                                                child: Image.asset(
                                                  'assets/images/${species!.image}',
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Center(
                                                        child: Text(
                                                          displayName[0]
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                      ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  displayName[0].toUpperCase(),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 7),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: bracketText(
                                            context,
                                            12,
                                            palette.ink,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Lv ${inst.level}  \u2022  $typeName',
                                        style: bracketText(
                                          context,
                                          10.5,
                                          elemCol,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (alreadyAssigned)
                                        Text(
                                          'IN ORBIT',
                                          style: bracketText(
                                            context,
                                            8.5,
                                            palette.muted,
                                            weight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ),
                                        )
                                      else if (emptySlot >= 0)
                                        Text(
                                          'ASSIGN',
                                          style: bracketText(
                                            context,
                                            8.5,
                                            CosmicScreenStyles.teal,
                                            weight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChamberSlotTile extends StatelessWidget {
  const _ChamberSlotTile({
    required this.slotIndex,
    required this.chamber,
    required this.base,
    required this.palette,
    required this.onClear,
  });

  final int slotIndex;
  final OrbitalChamber chamber;
  final Creature? base;
  final BracketPalette palette;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasCreature = chamber.instanceId != null;
    final elemCol = hasCreature ? chamber.color : palette.muted;

    return CustomPaint(
      painter: BracketFramePainter(
        color: elemCol.withValues(alpha: hasCreature ? 0.8 : 0.4),
        bracketSize: 8,
        strokeWidth: 1.1,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: hasCreature
              ? elemCol.withValues(alpha: 0.10)
              : palette.surfaceMutedFill(),
          border: Border.all(
            color: palette.lineSoft.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'SLOT ${slotIndex + 1}',
                  style: bracketText(
                    context,
                    9.5,
                    palette.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (hasCreature)
                  GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      AppIcons.close_rounded,
                      size: 14,
                      color: CosmicScreenStyles.danger.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.lerp(elemCol, Colors.white, 0.25)!,
                    elemCol,
                    Color.lerp(elemCol, Colors.black, 0.4)!,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: hasCreature && base?.image != null
                  ? ClipOval(
                      child: Image.asset(
                        'assets/images/${base!.image}',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    )
                  : Center(
                      child: Icon(
                        AppIcons.add_rounded,
                        color: palette.muted,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(height: 7),
            Text(
              hasCreature ? (chamber.displayName ?? 'Unknown') : 'Empty',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: bracketText(
                context,
                12,
                hasCreature ? palette.ink : palette.muted,
                weight: FontWeight.w700,
              ),
            ),
            if (base != null) ...[
              const SizedBox(height: 1),
              Text(
                base!.types.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  10.5,
                  elemCol,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayCloseButton extends StatelessWidget {
  const _OverlayCloseButton({required this.palette, required this.onTap});

  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: BracketFramePainter(
            color: palette.line.withValues(alpha: 0.7),
            bracketSize: 6,
            strokeWidth: 1,
          ),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            color: palette.surfaceMutedFill(),
            child: Icon(AppIcons.close_rounded, size: 16, color: palette.muted),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ELEMENTS CAPTURED POPUP (when summon fails recipe match)
// ─────────────────────────────────────────────────────────
