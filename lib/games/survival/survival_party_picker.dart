// lib/games/survival/survival_formation_selector_screen.dart
//
// REDESIGNED FORMATION SELECTOR
// Aesthetic: Scorched Forge — matches survival_game_screen + boss_battle_screen
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/instance_widgets/intance_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080A0E);
  static const bg1 = Color(0xFF0E1117);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);

  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const amberDim = Color(0xFF92400E);

  static const success = Color(0xFF16A34A);
  static const successDim = Color(0xFF14532D);
  static const successGlow = Color(0xFF22C55E);

  static const warn = Color(0xFFF97316);

  static const textPrimary = Color(0xFFE8DCC8);
  static const textSecondary = Color(0xFF8A7B6A);
  static const textMuted = Color(0xFF4A3F35);

  static const borderDim = Color(0xFF252D3A);
  static const borderMid = Color(0xFF3A3020);
  static const borderAccent = Color(0xFF6B4C20);
}

class _T {
  static const heading = TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static const label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  static const body = TextStyle(
    color: _C.textSecondary,
    fontSize: 12,
    height: 1.5,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: _C.borderMid)),
      if (label != null) ...[
        const SizedBox(width: 10),
        Text(label!, style: _T.label),
        const SizedBox(width: 10),
      ],
      Expanded(child: Container(height: 1, color: _C.borderMid)),
    ],
  );
}

class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool secondary;
  final Color? color;

  const _ForgeButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.secondary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final c = color ?? _C.amber;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: secondary ? 42 : 52,
        decoration: BoxDecoration(
          color: secondary ? Colors.transparent : (isDisabled ? _C.bg3 : c),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: secondary
                ? _C.borderAccent.withOpacity(0.6)
                : (isDisabled ? _C.borderDim : c),
          ),
          boxShadow: (!secondary && !isDisabled)
              ? [
                  BoxShadow(
                    color: c.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: secondary ? 15 : 17,
              color: secondary
                  ? _C.textSecondary
                  : (isDisabled ? _C.textMuted : _C.bg0),
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: secondary ? 11 : 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: secondary
                    ? _C.textSecondary
                    : (isDisabled ? _C.textMuted : _C.bg0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withOpacity(0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class SurvivalFormationSelectorScreen extends StatefulWidget {
  const SurvivalFormationSelectorScreen({super.key});
  @override
  State<SurvivalFormationSelectorScreen> createState() =>
      _SurvivalFormationSelectorScreenState();
}

class _SurvivalFormationSelectorScreenState
    extends State<SurvivalFormationSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortBy _sortBy = SortBy.levelHigh;
  bool _filterPrismatic = false;
  String? _filterSize;
  String? _filterTint;
  String? _filterVariant;
  String? _filterNature;

  final List<String> _selectedCreatures = [];

  static const int minSquadSize = 4;
  static const int maxSquadSize = 10;

  bool get _hasMinimumSquad => _selectedCreatures.length >= minSquadSize;
  int get _remaining => minSquadSize - _selectedCreatures.length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: _C.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ── Squad panel ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: _buildSquadPanel(db),
                    ),
                  ),
                  // ── Filters + search ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _EtchedDivider(label: 'CREATURE ROSTER'),
                          const SizedBox(height: 12),
                          _buildFiltersPanel(),
                          const SizedBox(height: 10),
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // ── Creature grid ──
                  StreamBuilder<List<CreatureInstance>>(
                    stream: db.creatureDao.watchAllInstances(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: _C.amber),
                          ),
                        );
                      }
                      final allInstances = snapshot.data!;
                      final instances = _applyFiltersAndSort(allInstances);
                      if (instances.isEmpty) {
                        return SliverFillRemaining(child: _buildEmptyState());
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final instance = instances[index];
                            final repo = context.read<CreatureCatalog>();
                            final species = repo.getCreatureById(
                              instance.baseId,
                            );
                            final isSelected = _selectedCreatures.contains(
                              instance.instanceId,
                            );

                            // Block duplicate species (same baseId already in squad)
                            final hasSameSpecies =
                                !isSelected &&
                                _selectedCreatures.any((id) {
                                  final sel = allInstances.firstWhereOrNull(
                                    (i) => i.instanceId == id,
                                  );
                                  return sel?.baseId == instance.baseId;
                                });

                            // Block a second Mystic
                            final isMystic =
                                species?.mutationFamily == 'Mystic';
                            final hasMysticAlready =
                                !isSelected &&
                                isMystic &&
                                _selectedCreatures.any((id) {
                                  final sel = allInstances.firstWhereOrNull(
                                    (i) => i.instanceId == id,
                                  );
                                  final selSp = sel != null
                                      ? repo.getCreatureById(sel.baseId)
                                      : null;
                                  return selSp?.mutationFamily == 'Mystic';
                                });

                            final canSelect =
                                !isSelected &&
                                _selectedCreatures.length < maxSquadSize &&
                                !hasSameSpecies &&
                                !hasMysticAlready;

                            return _CreatureGridCard(
                              instance: instance,
                              species: species,
                              isSelected: isSelected,
                              squadPosition: isSelected
                                  ? _selectedCreatures.indexOf(
                                          instance.instanceId,
                                        ) +
                                        1
                                  : null,
                              canSelect: canSelect,
                              onTap: () {
                                if (isSelected) {
                                  setState(
                                    () => _selectedCreatures.remove(
                                      instance.instanceId,
                                    ),
                                  );
                                } else if (_selectedCreatures.length >=
                                    maxSquadSize) {
                                  // Squad full — silent
                                } else if (hasSameSpecies) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${species?.name ?? 'This species'} is already in your squad.',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      backgroundColor: _C.warn,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else if (hasMysticAlready) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Only one Mystic is allowed per squad.',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      backgroundColor: _C.warn,
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  setState(
                                    () => _selectedCreatures.add(
                                      instance.instanceId,
                                    ),
                                  );
                                }
                              },
                              onLongPress: species != null
                                  ? () => CreatureDetailsDialog.show(
                                      context,
                                      species,
                                      true,
                                      instanceId: instance.instanceId,
                                      openBattleTab: true,
                                    )
                                  : null,
                            );
                          }, childCount: instances.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.72,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.borderDim),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _C.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8, bottom: 1),
                      decoration: const BoxDecoration(
                        color: _C.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text('ASSEMBLE SQUAD', style: _T.heading),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'SELECT $minSquadSize–$maxSquadSize CREATURES',
                  style: _T.label.copyWith(color: _C.textMuted),
                ),
              ],
            ),
          ),
          if (_selectedCreatures.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _selectedCreatures.clear()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _C.bg2,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _C.borderDim),
                ),
                child: const Text(
                  'CLEAR',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _C.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SQUAD PANEL
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSquadPanel(AlchemonsDatabase db) {
    final repo = context.watch<CreatureCatalog>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _hasMinimumSquad ? _C.success.withOpacity(0.55) : _C.borderDim,
          width: _hasMinimumSquad ? 1.5 : 1,
        ),
        boxShadow: _hasMinimumSquad
            ? [BoxShadow(color: _C.success.withOpacity(0.10), blurRadius: 16)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<List<CreatureInstance>>(
                future: db.creatureDao.getAllInstances(),
                builder: (context, snapshot) {
                  final allInstances = snapshot.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row header
                      Row(
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            color: _hasMinimumSquad
                                ? _C.success
                                : _C.textSecondary,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SQUAD  ${_selectedCreatures.length} / $maxSquadSize',
                            style: _T.label.copyWith(
                              color: _hasMinimumSquad
                                  ? _C.success
                                  : _C.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _hasMinimumSquad
                                ? Row(
                                    key: const ValueKey('ready'),
                                    children: [
                                      const Icon(
                                        Icons.check_rounded,
                                        color: _C.success,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'READY',
                                        style: _T.label.copyWith(
                                          color: _C.success,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    key: const ValueKey('need'),
                                    'NEED $_remaining MORE',
                                    style: _T.label.copyWith(color: _C.warn),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Slot rows — 5 + 5
                      _buildSlotRow(allInstances, repo, 0, 5),
                      const SizedBox(height: 6),
                      _buildSlotRow(allInstances, repo, 5, 10),
                      const SizedBox(height: 10),
                      // Hint
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 10,
                            color: _C.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DEPLOYMENT POSITIONS CHOSEN NEXT STEP',
                            style: _T.label.copyWith(
                              color: _C.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotRow(
    List<CreatureInstance> allInstances,
    CreatureCatalog repo,
    int from,
    int to,
  ) {
    return Row(
      children: List.generate(to - from, (i) {
        final slotIndex = from + i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < (to - from - 1) ? 5 : 0),
            child: _buildSquadSlot(allInstances, repo, slotIndex),
          ),
        );
      }),
    );
  }

  Widget _buildSquadSlot(
    List<CreatureInstance> allInstances,
    CreatureCatalog repo,
    int slotIndex,
  ) {
    final instanceId = slotIndex < _selectedCreatures.length
        ? _selectedCreatures[slotIndex]
        : null;
    final instance = instanceId != null
        ? allInstances.where((i) => i.instanceId == instanceId).firstOrNull
        : null;
    final isRequired = slotIndex < minSquadSize;
    final isFilled = instance != null;
    final species = isFilled ? repo.getCreatureById(instance.baseId) : null;

    return GestureDetector(
      onTap: isFilled
          ? () => setState(() => _selectedCreatures.remove(instanceId))
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 58,
        decoration: BoxDecoration(
          color: isFilled ? _C.success.withOpacity(0.10) : _C.bg1,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isFilled
                ? _C.success.withOpacity(0.55)
                : isRequired
                ? _C.warn.withOpacity(0.35)
                : _C.borderDim,
            width: isFilled ? 1.5 : 1,
          ),
        ),
        child: isFilled
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (species != null)
                    Expanded(
                      child: Center(
                        child: InstanceSprite(
                          creature: species,
                          instance: instance,
                          size: 28,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.help_outline,
                      size: 20,
                      color: _C.textMuted,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      '${slotIndex + 1}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: _C.success,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRequired
                        ? Icons.add_circle_outline_rounded
                        : Icons.add_rounded,
                    size: 16,
                    color: isRequired ? _C.warn.withOpacity(0.5) : _C.textMuted,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${slotIndex + 1}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isRequired
                          ? _C.warn.withOpacity(0.5)
                          : _C.textMuted,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FILTERS + SEARCH
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildFiltersPanel() {
    return InstanceFiltersPanel(
      theme: context.read<FactionTheme>(),
      sortBy: _sortBy,
      onSortChanged: (sort) => setState(() => _sortBy = sort),
      harvestMode: false,
      filterPrismatic: _filterPrismatic,
      onTogglePrismatic: () =>
          setState(() => _filterPrismatic = !_filterPrismatic),
      sizeValueText: _filterSize != null ? 'Size: $_filterSize' : null,
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
      tintValueText: _filterTint != null ? 'Tint: $_filterTint' : null,
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
      onPickNature: (nature) => setState(() => _filterNature = nature),
      natureOptions: const {
        'hardy': 'Hardy',
        'bold': 'Bold',
        'modest': 'Modest',
        'calm': 'Calm',
        'timid': 'Timid',
      },
      onClearAll: () => setState(() {
        _filterPrismatic = false;
        _filterSize = null;
        _filterTint = null;
        _filterVariant = null;
        _filterNature = null;
      }),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _C.borderDim),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(Icons.search_rounded, color: _C.textMuted, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _C.textPrimary,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: 'SEARCH CREATURES...',
                hintStyle: _T.label.copyWith(letterSpacing: 1.0),
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
                child: Icon(Icons.close_rounded, color: _C.textMuted, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FOOTER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: _C.bg1,
        border: Border(top: BorderSide(color: _C.borderDim)),
      ),
      child: _ForgeButton(
        label: _hasMinimumSquad
            ? 'Continue to Deployment  ·  ${_selectedCreatures.length} Selected'
            : 'Select ${_remaining} More to Continue',
        icon: _hasMinimumSquad
            ? Icons.arrow_forward_rounded
            : Icons.hourglass_empty_rounded,
        color: _hasMinimumSquad ? _C.success : null,
        onTap: _hasMinimumSquad
            ? () {
                final result = <int, String>{};
                for (int i = 0; i < _selectedCreatures.length; i++) {
                  result[i] = _selectedCreatures[i];
                }
                Navigator.of(context).pop(result);
              }
            : null,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _C.borderDim),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _C.textMuted,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text('NO CREATURES FOUND', style: _T.heading),
          const SizedBox(height: 4),
          const Text('Adjust filters or clear your search', style: _T.body),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FILTER / SORT LOGIC (unchanged)
  // ──────────────────────────────────────────────────────────────────────────

  List<CreatureInstance> _applyFiltersAndSort(
    List<CreatureInstance> instances,
  ) {
    var filtered = instances;

    if (_searchQuery.isNotEmpty) {
      final repo = context.read<CreatureCatalog>();
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((instance) {
        final species = repo.getCreatureById(instance.baseId);
        if (species == null) return false;
        return species.name.toLowerCase().contains(query) ||
            species.types.any((type) => type.toLowerCase().contains(query)) ||
            (instance.nickname?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_filterPrismatic)
      filtered = filtered.where((i) => i.isPrismaticSkin).toList();
    if (_filterSize != null)
      filtered = filtered
          .where((i) => decodeGenetics(i.geneticsJson)?.size == _filterSize)
          .toList();
    if (_filterTint != null)
      filtered = filtered
          .where((i) => decodeGenetics(i.geneticsJson)?.tinting == _filterTint)
          .toList();
    if (_filterVariant != null)
      filtered = filtered
          .where((i) => i.variantFaction == _filterVariant)
          .toList();
    if (_filterNature != null)
      filtered = filtered.where((i) => i.natureId == _filterNature).toList();

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
}

// ──────────────────────────────────────────────────────────────────────────────
// CREATURE GRID CARD — extracted stateless widget for performance
// ──────────────────────────────────────────────────────────────────────────────

class _CreatureGridCard extends StatefulWidget {
  final CreatureInstance instance;
  final Creature? species;
  final bool isSelected;
  final int? squadPosition;
  final bool canSelect;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CreatureGridCard({
    required this.instance,
    required this.species,
    required this.isSelected,
    required this.squadPosition,
    required this.canSelect,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_CreatureGridCard> createState() => _CreatureGridCardState();
}

class _CreatureGridCardState extends State<_CreatureGridCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectCtrl;
  late final Animation<double> _selectScale;

  @override
  void initState() {
    super.initState();
    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _selectScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _selectCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_CreatureGridCard old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _selectCtrl.forward().then((_) => _selectCtrl.reverse());
      }
    }
  }

  @override
  void dispose() {
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = !widget.canSelect && !widget.isSelected;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _selectScale,
        builder: (context, child) =>
            Transform.scale(scale: _selectScale.value, child: child),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: dimmed ? 0.35 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.isSelected ? _C.success.withOpacity(0.10) : _C.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: widget.isSelected
                    ? _C.success.withOpacity(0.6)
                    : _C.borderDim,
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: _C.success.withOpacity(0.14),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Scanlines
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: CustomPaint(painter: _ScanlinePainter()),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sprite
                      Expanded(
                        child: Center(
                          child: widget.species != null
                              ? InstanceSprite(
                                  creature: widget.species!,
                                  instance: widget.instance,
                                  size: 54,
                                )
                              : const Icon(
                                  Icons.help_outline,
                                  size: 40,
                                  color: _C.textMuted,
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Name
                      Text(
                        (widget.instance.nickname ??
                                widget.species?.name ??
                                'UNKNOWN')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: _C.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      // Level badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _C.amberDim.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: _C.borderAccent,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'LV ${widget.instance.level}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: _C.amberBright,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Squad position badge — top left
                if (widget.isSelected && widget.squadPosition != null)
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _C.success,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.squadPosition}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: _C.bg0,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Checkmark overlay on selected
                if (widget.isSelected)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _C.success.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _C.bg0,
                        size: 11,
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
}
