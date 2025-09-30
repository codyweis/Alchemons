import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creature.dart';

class CreatureSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> discoveredCreatures;
  final Function(String) onSelectCreature;
  final ScrollController? scrollController;
  final String? title;
  final bool showViewToggle;
  final String? emptyStateMessage;
  final Widget? customHeader;

  const CreatureSelectionSheet({
    super.key,
    required this.discoveredCreatures,
    required this.onSelectCreature,
    this.scrollController,
    this.title,
    this.showViewToggle = true,
    this.emptyStateMessage,
    this.customHeader,
  });

  @override
  State<CreatureSelectionSheet> createState() => _CreatureSelectionSheetState();

  static Future<T?> show<T>({
    required BuildContext context,
    required List<Map<String, dynamic>> discoveredCreatures,
    required Function(String) onSelectCreature,
    String? title,
    bool showViewToggle = true,
    String? emptyStateMessage,
    Widget? customHeader,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return CreatureSelectionSheet(
              discoveredCreatures: discoveredCreatures,
              onSelectCreature: onSelectCreature,
              scrollController: scrollController,
              title: title,
              showViewToggle: showViewToggle,
              emptyStateMessage: emptyStateMessage,
              customHeader: customHeader,
            );
          },
        );
      },
    );
  }
}

class _CreatureSelectionSheetState extends State<CreatureSelectionSheet> {
  String _selectedFilter = 'All';
  String _selectedSort = 'Name';
  bool _isGridView = true;

  final List<String> _sortOptions = ['Name', 'Rarity', 'Type'];

  @override
  Widget build(BuildContext context) {
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;
    final secondaryColor = factionColors.$2;

    final filteredCreatures = _filterAndSortCreatures(
      widget.discoveredCreatures,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14).withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withOpacity(.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildDragHandle(),
                widget.customHeader ?? _buildDefaultHeader(primaryColor),
                _buildFiltersAndSort(primaryColor, secondaryColor),
                Expanded(
                  child: _isGridView
                      ? _buildCreatureGrid(filteredCreatures, primaryColor)
                      : _buildCreatureList(filteredCreatures, primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildDefaultHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withOpacity(.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(.3),
                    primaryColor.withOpacity(.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.biotech_rounded, color: primaryColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (widget.title ?? 'SELECT SPECIMEN').toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Research database',
                    style: TextStyle(
                      color: Color(0xFFB6C0CC),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showViewToggle)
              GestureDetector(
                onTap: () => setState(() => _isGridView = !_isGridView),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(.4)),
                  ),
                  child: Icon(
                    _isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersAndSort(Color primaryColor, Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              'Type Filter',
              CreatureFilterUtils.filterOptions,
              _selectedFilter,
              (value) => setState(() => _selectedFilter = value!),
              Icons.filter_list_rounded,
              primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDropdown(
              'Sort Order',
              _sortOptions,
              _selectedSort,
              (value) => setState(() => _selectedSort = value!),
              Icons.sort_rounded,
              primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String selectedValue,
    void Function(String?) onChanged,
    IconData icon,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: Icon(icon, color: primaryColor, size: 16),
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(
            color: Color(0xFFE8EAED),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCreatureGrid(
    List<Map<String, dynamic>> creatures,
    Color primaryColor,
  ) {
    if (creatures.isEmpty) {
      return _buildEmptyState(primaryColor);
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: creatures.length,
      itemBuilder: (context, index) =>
          _buildCreatureCard(creatures[index], primaryColor),
    );
  }

  Widget _buildCreatureList(
    List<Map<String, dynamic>> creatures,
    Color primaryColor,
  ) {
    if (creatures.isEmpty) {
      return _buildEmptyState(primaryColor);
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: creatures.length,
      itemBuilder: (context, index) =>
          _buildCreatureListItem(creatures[index], primaryColor),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: primaryColor.withOpacity(.6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No specimens found',
              style: TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.emptyStateMessage ?? 'No specimens match current filters',
              style: const TextStyle(
                color: Color(0xFFB6C0CC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatureCard(
    Map<String, dynamic> creatureData,
    Color primaryColor,
  ) {
    final creature = creatureData['creature'] as Creature;
    final typeColor = BreedConstants.getTypeColor(creature.types.first);
    final rarityColor = BreedConstants.getRarityColor(creature.rarity);

    return GestureDetector(
      onTap: () => widget.onSelectCreature(creature.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: typeColor.withOpacity(.4), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rarity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: rarityColor.withOpacity(.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: rarityColor.withOpacity(.4)),
                ),
                child: Text(
                  creature.rarity.toUpperCase(),
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Image container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(.12)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'assets/images/creatures/${creature.rarity.toLowerCase()}/'
                      '${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Icon(
                            BreedConstants.getTypeIcon(creature.types.first),
                            size: 28,
                            color: typeColor.withOpacity(.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Name
              Text(
                creature.name,
                style: const TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatureListItem(
    Map<String, dynamic> creatureData,
    Color primaryColor,
  ) {
    final creature = creatureData['creature'] as Creature;
    final typeColor = BreedConstants.getTypeColor(creature.types.first);
    final rarityColor = BreedConstants.getRarityColor(creature.rarity);

    return GestureDetector(
      onTap: () => widget.onSelectCreature(creature.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: typeColor.withOpacity(.4), width: 1.5),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(.12)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/creatures/${creature.rarity.toLowerCase()}/'
                  '${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Icon(
                        BreedConstants.getTypeIcon(creature.types.first),
                        size: 22,
                        color: typeColor.withOpacity(.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creature.name,
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rarityColor.withOpacity(.2),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: rarityColor.withOpacity(.4),
                          ),
                        ),
                        child: Text(
                          creature.rarity.toUpperCase(),
                          style: TextStyle(
                            color: rarityColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ...creature.types
                          .take(2)
                          .map(
                            (type) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: BreedConstants.getTypeColor(
                                  type,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: BreedConstants.getTypeColor(
                                    type,
                                  ).withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  color: BreedConstants.getTypeColor(type),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterAndSortCreatures(
    List<Map<String, dynamic>> creatures,
  ) {
    var filtered = creatures.where((creatureData) {
      final creature = creatureData['creature'] as Creature;
      if (_selectedFilter == 'All') return true;
      return creature.types.contains(_selectedFilter);
    }).toList();

    filtered.sort((a, b) {
      final creatureA = a['creature'] as Creature;
      final creatureB = b['creature'] as Creature;
      switch (_selectedSort) {
        case 'Rarity':
          return CreatureFilterUtils.getRarityOrder(
            creatureA.rarity,
          ).compareTo(CreatureFilterUtils.getRarityOrder(creatureB.rarity));
        case 'Type':
          return creatureA.types.first.compareTo(creatureB.types.first);
        case 'Name':
        default:
          return creatureA.name.compareTo(creatureB.name);
      }
    });

    return filtered;
  }
}
