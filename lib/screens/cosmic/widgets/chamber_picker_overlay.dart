import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';

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

  // Filter / sort state (mirrors SurvivalFormationSelectorScreen)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortBy _sortBy = SortBy.levelHigh;
  bool _filterPrismatic = false;
  bool _filterFavorites = false;
  String? _filterSize;
  String? _filterTint;
  String? _filterVariant;
  String? _filterNature;

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

  List<CreatureInstance> _applyFiltersAndSort(
    List<CreatureInstance> instances,
  ) {
    var filtered = instances;
    if (_searchQuery.isNotEmpty) {
      final catalog = context.read<CreatureCatalog>();
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((instance) {
        final species = catalog.getCreatureById(instance.baseId);
        if (species == null) return false;
        return species.name.toLowerCase().contains(query) ||
            species.types.any((t) => t.toLowerCase().contains(query)) ||
            (instance.nickname?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    if (_filterFavorites) {
      filtered = filtered.where((i) => i.isFavorite == true).toList();
    }
    if (_filterPrismatic) {
      filtered = filtered.where((i) => i.isPrismaticSkin).toList();
    }
    if (_filterSize != null) {
      filtered = filtered
          .where((i) => decodeGenetics(i.geneticsJson)?.size == _filterSize)
          .toList();
    }
    if (_filterTint != null) {
      filtered = filtered
          .where((i) => decodeGenetics(i.geneticsJson)?.tinting == _filterTint)
          .toList();
    }
    if (_filterVariant != null) {
      filtered = filtered
          .where((i) => i.variantFaction == _filterVariant)
          .toList();
    }
    if (_filterNature != null) {
      filtered = filtered.where((i) => i.natureId == _filterNature).toList();
    }
    filtered.sort((a, b) {
      switch (_sortBy) {
        case SortBy.newest:
          return b.createdAtUtcMs.compareTo(a.createdAtUtcMs);
        case SortBy.oldest:
          return a.createdAtUtcMs.compareTo(b.createdAtUtcMs);
        case SortBy.levelHigh:
          return b.level.compareTo(a.level);
        case SortBy.levelLow:
          return a.level.compareTo(b.level);
        case SortBy.statSpeed:
          return b.statSpeed.compareTo(a.statSpeed);
        case SortBy.statIntelligence:
          return b.statIntelligence.compareTo(a.statIntelligence);
        case SortBy.statStrength:
          return b.statStrength.compareTo(a.statStrength);
        case SortBy.statBeauty:
          return b.statBeauty.compareTo(a.statBeauty);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CreatureCatalog>();
    final theme = context.read<FactionTheme>();
    final assignedIds = widget.chambers
        .where((c) => c.instanceId != null)
        .map((c) => c.instanceId!)
        .toSet();
    final filtered = _applyFiltersAndSort(_ownedCreatures);

    return Material(
      color: const Color(0xF0020010),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.bubble_chart_rounded,
                    color: Color(0xFF80DEEA),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ALCHEMY CHAMBERS',
                      style: TextStyle(
                        color: Color(0xFF80DEEA),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '\u2715',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Assign Alchemons to orbit your home planet.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Chamber slots ──
            ...List.generate(widget.chambers.length, (i) {
              final chamber = widget.chambers[i];
              final hasCreature = chamber.instanceId != null;
              final base = hasCreature
                  ? catalog.getCreatureById(chamber.baseCreatureId ?? '')
                  : null;
              final elemCol = hasCreature
                  ? chamber.color
                  : Colors.white.withValues(alpha: 0.3);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: elemCol.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: elemCol.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
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
                        boxShadow: [
                          BoxShadow(
                            color: elemCol.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: hasCreature && base?.image != null
                          ? ClipOval(
                              child: Image.asset(
                                'assets/images/${base!.image}',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.add,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Slot ${i + 1}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            hasCreature
                                ? (chamber.displayName ?? 'Unknown')
                                : 'Empty',
                            style: TextStyle(
                              color: hasCreature
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (base != null)
                            Text(
                              base.types.first,
                              style: TextStyle(
                                color: elemCol,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasCreature)
                      GestureDetector(
                        onTap: () => widget.onClear(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            'REMOVE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // ── Divider ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.white10)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'YOUR ALCHEMONS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.white10)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Filters panel ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InstanceFiltersPanel(
                theme: theme,
                sortBy: _sortBy,
                onSortChanged: (s) => setState(() => _sortBy = s),
                harvestMode: false,
                filterPrismatic: _filterPrismatic,
                onTogglePrismatic: () =>
                    setState(() => _filterPrismatic = !_filterPrismatic),
                filterFavorites: _filterFavorites,
                onToggleFavorites: () =>
                    setState(() => _filterFavorites = !_filterFavorites),
                sizeValueText: _filterSize != null
                    ? 'Size: $_filterSize'
                    : null,
                onCycleSize: () => setState(() {
                  _filterSize = switch (_filterSize) {
                    null => 'XS',
                    'XS' => 'S',
                    'S' => 'M',
                    'M' => 'L',
                    'L' => 'XL',
                    _ => null,
                  };
                }),
                tintValueText: _filterTint != null
                    ? 'Tint: $_filterTint'
                    : null,
                onCycleTint: () => setState(() {
                  _filterTint = switch (_filterTint) {
                    null => 'Red',
                    'Red' => 'Orange',
                    'Orange' => 'Yellow',
                    'Yellow' => 'Green',
                    'Green' => 'Blue',
                    'Blue' => 'Purple',
                    'Purple' => 'Pink',
                    _ => null,
                  };
                }),
                variantValueText: _filterVariant != null
                    ? 'Variant: $_filterVariant'
                    : null,
                onCycleVariant: () => setState(() {
                  _filterVariant = switch (_filterVariant) {
                    null => 'Alpha',
                    'Alpha' => 'Beta',
                    'Beta' => 'Gamma',
                    _ => null,
                  };
                }),
                filterNature: _filterNature,
                onPickNature: (n) => setState(() => _filterNature = n),
                natureOptions: const {
                  'hardy': 'Hardy',
                  'bold': 'Bold',
                  'modest': 'Modest',
                  'calm': 'Calm',
                  'timid': 'Timid',
                },
                onClearAll: () => setState(() {
                  _filterPrismatic = false;
                  _filterFavorites = false;
                  _filterSize = null;
                  _filterTint = null;
                  _filterVariant = null;
                  _filterNature = null;
                }),
              ),
            ),
            const SizedBox(height: 8),

            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'SEARCH...',
                          hintStyle: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                            letterSpacing: 1.0,
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
                        child: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white38,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Creature grid ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF80DEEA),
                        strokeWidth: 2,
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No Alchemons found.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
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
                              : () =>
                                    widget.onAssign(emptySlot, inst.instanceId),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: alreadyAssigned ? 0.35 : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: elemCol.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: elemCol.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Creature orb
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
                                                      style: const TextStyle(
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
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Lv ${inst.level}  \u2022  $typeName',
                                    style: TextStyle(
                                      color: elemCol,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (alreadyAssigned)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'IN ORBIT',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else if (emptySlot >= 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF00838F),
                                            Color(0xFF00BCD4),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ASSIGN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────
// ELEMENTS CAPTURED POPUP (when summon fails recipe match)
// ─────────────────────────────────────────────────────────
