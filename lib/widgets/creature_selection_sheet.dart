import 'package:alchemons/constants/breed_constants.dart';
import 'package:flutter/material.dart';
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

  /// Static method to show as a modal bottom sheet
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

  final List<String> _filterOptions = [
    'All',
    'Fire',
    'Water',
    'Earth',
    'Air',
    'Steam',
    'Lava',
    'Lightning',
    'Mud',
    'Ice',
    'Dust',
    'Crystal',
    'Plant',
    'Poison',
    'Spirit',
    'Dark',
    'Light',
    'Blood',
  ];

  final List<String> _sortOptions = ['Name', 'Rarity', 'Type'];

  @override
  Widget build(BuildContext context) {
    final filteredCreatures = _filterAndSortCreatures(
      widget.discoveredCreatures,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.blue.shade50],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.indigo.shade200, width: 2),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          widget.customHeader ?? _buildDefaultHeader(),
          _buildFiltersAndSort(),
          Expanded(
            child: _isGridView
                ? _buildCreatureGrid(filteredCreatures)
                : _buildCreatureList(filteredCreatures),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDefaultHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.biotech_rounded, color: Colors.indigo.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title ?? 'Select Specimen',
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.showViewToggle)
            GestureDetector(
              onTap: () => setState(() => _isGridView = !_isGridView),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isGridView
                      ? Colors.indigo.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isGridView
                        ? Colors.indigo.shade300
                        : Colors.orange.shade300,
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: _isGridView
                      ? Colors.indigo.shade600
                      : Colors.orange.shade600,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSort() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              'Type Filter',
              _filterOptions,
              _selectedFilter,
              (value) => setState(() => _selectedFilter = value!),
              Icons.filter_list_rounded,
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
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: Icon(icon, color: Colors.indigo.shade600, size: 16),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: Colors.indigo.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCreatureGrid(List<Map<String, dynamic>> creatures) {
    if (creatures.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: creatures.length,
      itemBuilder: (context, index) => _buildCreatureCard(creatures[index]),
    );
  }

  Widget _buildCreatureList(List<Map<String, dynamic>> creatures) {
    if (creatures.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: creatures.length,
      itemBuilder: (context, index) => _buildCreatureListItem(creatures[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 40),
          const SizedBox(height: 12),
          Text(
            widget.emptyStateMessage ?? 'No specimens match current filters',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreatureCard(Map<String, dynamic> creatureData) {
    final creature = creatureData['creature'] as Creature;
    final typeColor = BreedConstants.getTypeColor(creature.types.first);

    return GestureDetector(
      onTap: () => widget.onSelectCreature(creature.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: typeColor.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: typeColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                creature.name,
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 80,
                    maxWidth: 80,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/creatures/${creature.rarity.toLowerCase()}/'
                      '${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            BreedConstants.getTypeIcon(creature.types.first),
                            size: 32,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: BreedConstants.getRarityColor(
                    creature.rarity,
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  creature.rarity,
                  style: TextStyle(
                    color: BreedConstants.getRarityColor(creature.rarity),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatureListItem(Map<String, dynamic> creatureData) {
    final creature = creatureData['creature'] as Creature;
    final typeColor = BreedConstants.getTypeColor(creature.types.first);

    return GestureDetector(
      onTap: () => widget.onSelectCreature(creature.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: typeColor.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: typeColor.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Creature image
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/creatures/${creature.rarity.toLowerCase()}/'
                  '${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        BreedConstants.getTypeIcon(creature.types.first),
                        size: 20,
                        color: typeColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Creature info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creature.name,
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontSize: 14,
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
                          color: BreedConstants.getRarityColor(
                            creature.rarity,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          creature.rarity,
                          style: TextStyle(
                            color: BreedConstants.getRarityColor(
                              creature.rarity,
                            ),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
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
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: BreedConstants.getTypeColor(
                                  type,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: BreedConstants.getTypeColor(
                                    type,
                                  ).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: BreedConstants.getTypeColor(type),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
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
          return _getRarityOrder(
            creatureA.rarity,
          ).compareTo(_getRarityOrder(creatureB.rarity));
        case 'Type':
          return creatureA.types.first.compareTo(creatureB.types.first);
        case 'Name':
        default:
          return creatureA.name.compareTo(creatureB.name);
      }
    });

    return filtered;
  }

  int _getRarityOrder(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 0;
      case 'uncommon':
        return 1;
      case 'rare':
        return 2;
      case 'mythic':
        return 3;
      case 'legendary':
        return 4;
      default:
        return 0;
    }
  }
}
